-- E1-04 / E7-03: Make public entitlement and quota RPCs owner-scoped.
-- The 2026-10-17 live read-only audit confirmed unrestricted p_user_id
-- selection in two authenticated-executable SECURITY DEFINER functions.
-- Preserve legitimate self-service RPC behavior and service-side decisions.
-- Deliberately ignore p_role from untrusted JWT holders.
--
-- PROPOSAL ONLY: do not apply to RAD Production before canonical ledger
-- reconciliation, Stage 1 integration, backup/PITR, E2E and owner approval.
begin;

CREATE OR REPLACE FUNCTION public.get_ai_daily_quota_status(
  p_user_id uuid,
  p_role text DEFAULT 'user'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_limit integer;
  v_effective_role text := p_role;
  v_token_limit integer;
  v_used integer;
  v_tokens integer;
  v_day timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_required' USING errcode = '22023';
  END IF;
  -- Never accept a caller-supplied user ID or role from an untrusted client.
  -- Only service_role may inspect another user's quota.
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    IF auth.uid() IS DISTINCT FROM p_user_id THEN
      RAISE EXCEPTION 'forbidden' USING errcode = '42501';
    END IF;
    SELECT coalesce(role,'user') INTO v_effective_role
    FROM public.profiles WHERE id = p_user_id;
    v_effective_role := coalesce(nullif(v_effective_role, ''), 'user');
  END IF;
  SELECT daily_requests, daily_output_tokens INTO v_limit, v_token_limit
  FROM public.ai_usage_limits WHERE role = coalesce(nullif(v_effective_role, ''), 'user') LIMIT 1;
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
SET search_path TO ''
AS $function$
DECLARE
  v_role text := 'anonymous';
  v_ent jsonb;
  v_quota jsonb;
  v_paid_active boolean := false;
  v_plan text := 'base';
BEGIN
  -- This RPC may be executed with an authenticated JWT but must never read
  -- another user's entitlement or quota. A service JWT is trusted for
  -- server-side checks; the request's user UUID is otherwise authoritative.
  IF p_user_id IS NOT NULL
     AND coalesce(auth.jwt()->>'role','') <> 'service_role'
     AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'forbidden' USING errcode = '42501';
  END IF;

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

revoke all on function public.get_ai_access_decision(uuid,text)
  from public, anon;
revoke all on function public.get_ai_daily_quota_status(uuid,text)
  from public, anon;
grant execute on function public.get_ai_access_decision(uuid,text)
  to authenticated,service_role;
grant execute on function public.get_ai_daily_quota_status(uuid,text)
  to authenticated,service_role;

do $gate$
begin
  if has_function_privilege('anon','public.get_ai_access_decision(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.get_ai_daily_quota_status(uuid,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_ai_access_decision(uuid,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_ai_daily_quota_status(uuid,text)','EXECUTE')
     or not has_function_privilege('service_role','public.get_ai_access_decision(uuid,text)','EXECUTE')
     or not has_function_privilege('service_role','public.get_ai_daily_quota_status(uuid,text)','EXECUTE') then
    raise exception 'E1-04 entitlement RPC ACL regression' using errcode='42501';
  end if;
end;
$gate$;

commit;
