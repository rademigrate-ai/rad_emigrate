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
