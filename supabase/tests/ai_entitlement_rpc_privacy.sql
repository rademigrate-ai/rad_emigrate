-- Run ONLY on an isolated Supabase instance after all migrations.
-- This test performs no data writes; it proves untrusted API roles cannot
-- query other users' quota/entitlement details through public definer RPCs.
begin;
do $test$
declare
  v_fn text;
begin
  foreach v_fn in array ARRAY[
    'public.get_ai_access_decision(uuid,text)',
    'public.get_ai_daily_quota_status(uuid,text)'
  ] loop
    if has_function_privilege('anon', v_fn, 'EXECUTE') then
      raise exception '% unexpectedly executable by anon', v_fn;
    end if;
    if has_function_privilege('authenticated', v_fn, 'EXECUTE') then
      raise exception '% unexpectedly executable by authenticated', v_fn;
    end if;
    if not has_function_privilege('service_role', v_fn, 'EXECUTE') then
      raise exception '% unavailable to trusted service_role', v_fn;
    end if;
  end loop;
end;
$test$;

-- Exercise actual untrusted callers as well as checking ACL metadata.
-- Do not use real user IDs and do not write live fixture data.
set local role authenticated;
do $deny_auth$
begin
  begin
    perform public.get_ai_access_decision('11111111-1111-4111-8111-111111111111'::uuid, null);
    raise exception 'authenticated entitlement lookup was unexpectedly allowed';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.get_ai_daily_quota_status('22222222-2222-4222-8222-222222222222'::uuid, 'super_admin');
    raise exception 'authenticated cross-user quota lookup was unexpectedly allowed';
  exception when insufficient_privilege then
    null;
  end;
end;
$deny_auth$;
reset role;

set local role anon;
do $deny_anon$
begin
  begin
    perform public.get_ai_access_decision('11111111-1111-4111-8111-111111111111'::uuid, null);
    raise exception 'anonymous entitlement lookup was unexpectedly allowed';
  exception when insufficient_privilege then
    null;
  end;
end;
$deny_anon$;
reset role;

-- A valid service principal may still invoke the canonical decision RPC.
-- The empty identity branch is read-only and must not fabricate entitlement.
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $service$
declare
  v jsonb;
begin
  v := public.get_ai_access_decision(null,null);
  if v->>'identity' <> 'none' then
    raise exception 'Unexpected empty-identity decision: %', v;
  end if;
end;
$service$;
rollback;
