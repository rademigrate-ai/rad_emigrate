-- Isolated Supabase clone only. No mutations to Production.
-- Verify authenticated caller UUID binding, forgery-resistant role limits,
-- service_role access and anonymous denial.
begin;

do $acl$
declare fn text;
begin
  foreach fn in array array[
    'public.get_ai_access_decision(uuid,text)',
    'public.get_ai_daily_quota_status(uuid,text)'
  ] loop
    if has_function_privilege('anon', fn, 'EXECUTE')
       or not has_function_privilege('authenticated', fn, 'EXECUTE')
       or not has_function_privilege('service_role', fn, 'EXECUTE') then
      raise exception 'Bad entitlement RPC grants: %',fn;
    end if;
  end loop;
end;
$acl$;

select set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111"}', true);
select set_config('request.jwt.claim.sub',
 '11111111-1111-4111-8111-111111111111', true);
set local role authenticated;

do $user$
declare
  own uuid := '11111111-1111-4111-8111-111111111111';
  other_user uuid := '22222222-2222-4222-8222-222222222222';
  decision jsonb;
  normal_quota jsonb;
  forged_quota jsonb;
begin
  decision := public.get_ai_access_decision(own, null);
  if decision->>'user_id' <> own::text then
    raise exception 'Self-access decision failed';
  end if;

  normal_quota := public.get_ai_daily_quota_status(own, 'user');
  forged_quota := public.get_ai_daily_quota_status(own, 'super_admin');
  if normal_quota->>'limit' is distinct from forged_quota->>'limit'
     or normal_quota->>'token_limit' is distinct from forged_quota->>'token_limit' then
    raise exception 'User-supplied role escalated quota visibility';
  end if;

  begin
    perform public.get_ai_access_decision(other_user, null);
    raise exception 'Cross-user entitlement access unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.get_ai_daily_quota_status(other_user, 'super_admin');
    raise exception 'Cross-user AI quota access unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$user$;
reset role;

select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
do $service$
declare
  v jsonb;
begin
  v := public.get_ai_access_decision(
    '22222222-2222-4222-8222-222222222222'::uuid, null);
  if v->>'identity' <> 'authenticated' then
    raise exception 'Service-role entitlement lookup denied';
  end if;
end;
$service$;
reset role;

select set_config('request.jwt.claims','{"role":"anon"}',true);
set local role anon;
do $guest$
begin
  begin
    perform public.get_ai_access_decision(null,null);
    raise exception 'Anonymous entitlement RPC unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$guest$;
rollback;
