-- E1-04 / E7-03: Restrict cross-user entitlement and quota observation.
-- Production 2026-10-17 forensics found authenticated EXECUTE on SECURITY
-- DEFINER RPCs accepting arbitrary p_user_id. Those RPCs returned role/plan,
-- entitlement metadata, and per-user AI usage without an ownership check.
--
-- The current Flutter/Edge repository has no direct authenticated-client RPC
-- callers for these two functions; get_ai_access_decision calls the quota
-- helper internally as the function owner. Preserve service_role execution.
-- This is an intentional fail-closed API authorization change.
--
-- This file is a PROPOSAL ONLY pending canonical migration reconciliation,
-- clone isolation tests, real client tests and owner-approved release order.
-- Do NOT apply to RAD Production or change existing migration history.

begin;

revoke all on function public.get_ai_access_decision(uuid, text)
  from public, anon, authenticated;
revoke all on function public.get_ai_daily_quota_status(uuid, text)
  from public, anon, authenticated;

grant execute on function public.get_ai_access_decision(uuid, text)
  to service_role;
grant execute on function public.get_ai_daily_quota_status(uuid, text)
  to service_role;

do $guard$
begin
  if has_function_privilege('anon', 'public.get_ai_access_decision(uuid,text)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.get_ai_access_decision(uuid,text)', 'EXECUTE')
    or has_function_privilege('anon', 'public.get_ai_daily_quota_status(uuid,text)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.get_ai_daily_quota_status(uuid,text)', 'EXECUTE') then
    raise exception 'E1-04 security gate: AI entitlement RPC still callable by an untrusted client'
      using errcode = '42501';
  end if;

  if not has_function_privilege('service_role', 'public.get_ai_access_decision(uuid,text)', 'EXECUTE')
    or not has_function_privilege('service_role', 'public.get_ai_daily_quota_status(uuid,text)', 'EXECUTE') then
    raise exception 'E1-04 security gate: service-role AI entitlement access removed'
      using errcode = '42501';
  end if;
end;
$guard$;

commit;
