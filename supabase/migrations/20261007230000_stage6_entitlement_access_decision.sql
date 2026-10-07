-- Stage 6: entitlement foundation + canonical AI access decision (no fabricated paid plans)

CREATE TABLE IF NOT EXISTS public.ai_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_code text NOT NULL DEFAULT 'base',
  status text NOT NULL DEFAULT 'inactive'
    CHECK (status IN ('active','inactive','expired','revoked','pending')),
  source text NOT NULL DEFAULT 'system'
    CHECK (source IN ('system','payment','admin','migration')),
  starts_at timestamptz,
  ends_at timestamptz,
  provider_ref text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ai_entitlements_user_active_uidx
  ON public.ai_entitlements (user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS ai_entitlements_user_idx ON public.ai_entitlements (user_id);

ALTER TABLE public.ai_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users read own entitlements" ON public.ai_entitlements;
CREATE POLICY "users read own entitlements" ON public.ai_entitlements
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "service manages entitlements" ON public.ai_entitlements;
CREATE POLICY "service manages entitlements" ON public.ai_entitlements
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "admins manage entitlements" ON public.ai_entitlements;
CREATE POLICY "admins manage entitlements" ON public.ai_entitlements
  FOR ALL TO authenticated
  USING (private.has_role(ARRAY['admin'::text, 'super_admin'::text]))
  WITH CHECK (private.has_role(ARRAY['admin'::text, 'super_admin'::text]));

GRANT SELECT ON public.ai_entitlements TO authenticated;
GRANT ALL ON public.ai_entitlements TO service_role;

CREATE OR REPLACE FUNCTION public.get_ai_daily_quota_status(
  p_user_id uuid,
  p_role text DEFAULT 'user'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_limit integer;
  v_token_limit integer;
  v_used integer;
  v_tokens integer;
  v_day timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_required' USING errcode = '22023';
  END IF;
  SELECT daily_requests, daily_output_tokens INTO v_limit, v_token_limit
  FROM public.ai_usage_limits WHERE role = coalesce(nullif(p_role, ''), 'user') LIMIT 1;
  IF v_limit IS NULL THEN v_limit := 50; v_token_limit := 100000; END IF;
  SELECT count(*)::int, coalesce(sum(output_tokens), 0)::int INTO v_used, v_tokens
  FROM public.ai_requests WHERE user_id = p_user_id AND created_at >= v_day;
  RETURN jsonb_build_object(
    'allowed', (v_used < v_limit AND v_tokens < v_token_limit),
    'count', v_used,
    'limit', v_limit,
    'tokens_used', v_tokens,
    'token_limit', v_token_limit,
    'error', CASE WHEN v_used >= v_limit OR v_tokens >= v_token_limit THEN 'daily_limit_reached' ELSE NULL END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_ai_access_decision(
  p_user_id uuid DEFAULT NULL,
  p_guest_key_hash text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_role text := 'anonymous';
  v_ent jsonb;
  v_quota jsonb;
  v_paid_active boolean := false;
  v_plan text := 'base';
BEGIN
  IF p_user_id IS NOT NULL THEN
    SELECT coalesce(role, 'user') INTO v_role FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND OR v_role IS NULL THEN v_role := 'user'; END IF;

    SELECT jsonb_build_object(
      'id', e.id,
      'plan_code', e.plan_code,
      'status', e.status,
      'starts_at', e.starts_at,
      'ends_at', e.ends_at,
      'source', e.source
    )
    INTO v_ent
    FROM public.ai_entitlements e
    WHERE e.user_id = p_user_id
      AND e.status = 'active'
      AND (e.starts_at IS NULL OR e.starts_at <= now())
      AND (e.ends_at IS NULL OR e.ends_at > now())
    ORDER BY e.created_at DESC
    LIMIT 1;

    v_paid_active := v_ent IS NOT NULL;
    IF v_paid_active THEN v_plan := coalesce(v_ent->>'plan_code', 'base'); END IF;

    v_quota := public.get_ai_daily_quota_status(p_user_id, v_role);

    RETURN jsonb_build_object(
      'identity', 'authenticated',
      'user_id', p_user_id,
      'role', v_role,
      'plan', v_plan,
      'paid_entitlement_active', v_paid_active,
      'payment_available', false,
      'entitlement', v_ent,
      'quota', v_quota,
      'capability_chat', true,
      'reason', CASE
        WHEN (v_quota->>'allowed')::boolean IS FALSE THEN coalesce(v_quota->>'error', 'daily_limit_reached')
        ELSE 'allowed'
      END
    );
  END IF;

  IF p_guest_key_hash IS NOT NULL AND length(p_guest_key_hash) >= 32 THEN
    RETURN jsonb_build_object(
      'identity', 'anonymous',
      'role', 'anonymous',
      'plan', 'guest',
      'paid_entitlement_active', false,
      'payment_available', false,
      'guest_limit', 5,
      'capability_chat', true,
      'reason', 'guest_path',
      'note', 'Actual guest consumption remains consume_ai_guest_quota (Stage 4)'
    );
  END IF;

  RETURN jsonb_build_object(
    'identity', 'none',
    'payment_available', false,
    'capability_chat', false,
    'reason', 'authentication_required'
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_ai_access_decision(uuid, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.get_ai_daily_quota_status(uuid, text) TO authenticated, service_role;
