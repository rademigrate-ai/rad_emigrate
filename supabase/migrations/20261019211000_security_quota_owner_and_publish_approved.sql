-- Security hardening continuation (additive)
-- 1) consume_ai_daily_quota: require auth.uid() = p_user_id for authenticated callers
-- 2) publish_content_draft: only approved drafts may publish (not review)

CREATE OR REPLACE FUNCTION public.consume_ai_daily_quota(
  p_user_id uuid,
  p_role text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_role text;
  v_limit integer;
  v_token_limit integer;
  v_used integer;
  v_tokens integer;
  v_request_id uuid;
  v_day timestamptz := date_trunc('day', now() AT TIME ZONE 'utc') AT TIME ZONE 'utc';
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_required' USING ERRCODE = '22023';
  END IF;

  -- Ownership: authenticated non-service callers may only reserve their own quota.
  -- service_role (Edge Functions) may pass any user id intentionally.
  IF current_setting('role', true) IS DISTINCT FROM 'service_role'
     AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'forbidden_quota_user' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(p.role, 'user')
  INTO v_role
  FROM public.profiles p
  WHERE p.id = p_user_id;
  v_role := coalesce(v_role, 'user');

  SELECT l.daily_requests, l.daily_output_tokens
  INTO v_limit, v_token_limit
  FROM public.ai_usage_limits l
  WHERE l.role = v_role
  LIMIT 1;
  IF v_limit IS NULL THEN
    v_limit := 50;
    v_token_limit := 100000;
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text || ':' || v_day::text, 0)
  );

  SELECT count(*)::integer, coalesce(sum(r.output_tokens), 0)::integer
  INTO v_used, v_tokens
  FROM public.ai_requests r
  WHERE r.user_id = p_user_id AND r.created_at >= v_day;

  IF v_used >= v_limit OR v_tokens >= v_token_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'count', v_used,
      'limit', v_limit,
      'tokens_used', v_tokens,
      'token_limit', v_token_limit,
      'error', 'daily_limit_reached'
    );
  END IF;

  INSERT INTO public.ai_requests(
    user_id, capability, status, routing_reason
  ) VALUES (
    p_user_id, 'chat', 'running', 'atomic_quota_reservation'
  )
  RETURNING id INTO v_request_id;

  RETURN jsonb_build_object(
    'allowed', true,
    'count', v_used + 1,
    'limit', v_limit,
    'tokens_used', v_tokens,
    'token_limit', v_token_limit,
    'request_id', v_request_id
  );
END;
$function$;

ALTER FUNCTION public.consume_ai_daily_quota(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.consume_ai_daily_quota(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_ai_daily_quota(uuid, text) TO authenticated, service_role;

-- Publish gate: only approved drafts
CREATE OR REPLACE FUNCTION public.publish_content_draft(
  p_draft_id uuid,
  p_category text DEFAULT 'update',
  p_slug text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_draft public.content_drafts%ROWTYPE;
  v_feed_id uuid;
  v_slug text;
  v_category text;
BEGIN
  IF NOT private.has_role(ARRAY['admin', 'super_admin']) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_draft FROM public.content_drafts WHERE id = p_draft_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'draft not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_draft.status = 'published' AND v_draft.feed_item_id IS NOT NULL THEN
    RETURN v_draft.feed_item_id;
  END IF;

  IF v_draft.status = 'rejected' THEN
    RAISE EXCEPTION 'rejected draft cannot be published' USING ERRCODE = '22023';
  END IF;

  -- SEC-B fix: only approved may publish (not review/draft)
  IF v_draft.status IS DISTINCT FROM 'approved' THEN
    RAISE EXCEPTION 'only_approved_drafts_may_publish' USING ERRCODE = '22023';
  END IF;

  v_category := coalesce(nullif(btrim(p_category), ''), v_draft.category, 'update');
  IF v_category NOT IN ('update', 'guide', 'deadline', 'event', 'success_story', 'announcement') THEN
    RAISE EXCEPTION 'invalid category' USING ERRCODE = '22023';
  END IF;

  v_slug := coalesce(
    nullif(lower(regexp_replace(btrim(coalesce(p_slug, '')), '[^a-z0-9]+', '-', 'g')), ''),
    lower(regexp_replace(left(v_draft.title, 48), '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(v_draft.id::text, 1, 8)
  );
  v_slug := trim(both '-' from v_slug);
  IF v_slug !~ '^[a-z0-9-]+$' THEN
    v_slug := 'rad-update-' || substr(v_draft.id::text, 1, 12);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.feed_items
    WHERE slug = v_slug
      AND (v_draft.feed_item_id IS NULL OR id <> v_draft.feed_item_id)
  ) THEN
    v_slug := v_slug || '-' || substr(gen_random_uuid()::text, 1, 8);
  END IF;

  IF v_draft.feed_item_id IS NULL THEN
    INSERT INTO public.feed_items(
      slug, category, status, primary_source_id, source_url,
      published_at, created_by, reviewed_by
    ) VALUES (
      v_slug, v_category, 'published', v_draft.primary_source_id, v_draft.source_url,
      now(), auth.uid(), auth.uid()
    ) RETURNING id INTO v_feed_id;
  ELSE
    v_feed_id := v_draft.feed_item_id;
    UPDATE public.feed_items
    SET status = 'published',
        category = v_category,
        published_at = coalesce(published_at, now()),
        reviewed_by = auth.uid(),
        updated_at = now()
    WHERE id = v_feed_id;
  END IF;

  UPDATE public.content_drafts
  SET status = 'published',
      feed_item_id = v_feed_id,
      published_at = now(),
      reviewed_by = auth.uid(),
      updated_at = now()
  WHERE id = p_draft_id;

  INSERT INTO public.admin_audit_logs(actor_id, action, resource_type, resource_id, safe_metadata)
  VALUES (
    auth.uid(), 'publish', 'content_draft', p_draft_id::text,
    jsonb_build_object('feed_item_id', v_feed_id, 'slug', v_slug, 'category', v_category)
  );

  RETURN v_feed_id;
END;
$$;

ALTER FUNCTION public.publish_content_draft(uuid, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.publish_content_draft(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publish_content_draft(uuid, text, text) TO authenticated, service_role;
