-- Owner projection of the existing immutable status log; no duplicate history.
begin;
do $$ begin
  assert to_regprocedure('public.list_application_status_history(uuid,bigint,integer)')
    is not null, 'owner history RPC is required';
end $$;
insert into auth.users(id,email,raw_user_meta_data) values
 ('b6100000-0000-4000-8000-000000000001','history-owner@example.invalid','{}'),
 ('b6100000-0000-4000-8000-000000000002','history-other@example.invalid','{}');
insert into public.applications(id,user_id,visa_type,status) values
 ('b6100000-0000-4000-8000-0000000000a1',
  'b6100000-0000-4000-8000-000000000001','synthetic-history-only','draft');
select set_config('request.jwt.claims',
 '{"sub":"b6100000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ begin
  assert public.list_application_status_history(
    'b6100000-0000-4000-8000-0000000000a1',null,50)='[]'::jsonb;
end $$;
-- Synthetic history fixtures are inserted by the privileged SQL test runner;
-- user-facing status transitions remain governed by private.guard_application_status.
insert into public.application_status_history
  (application_id, from_status, to_status, changed_by) values
  ('b6100000-0000-4000-8000-0000000000a1',
   'draft', 'submitted', 'b6100000-0000-4000-8000-000000000001'),
  ('b6100000-0000-4000-8000-0000000000a1',
   'submitted', 'in_review', 'b6100000-0000-4000-8000-000000000001');
do $check$
declare v jsonb; older jsonb;
begin
  assert not has_function_privilege('anon',
    'public.list_application_status_history(uuid,bigint,integer)','EXECUTE');
  assert has_function_privilege('authenticated',
    'public.list_application_status_history(uuid,bigint,integer)','EXECUTE');
  assert not has_table_privilege('authenticated',
    'public.application_status_history','INSERT');
  assert not has_table_privilege('authenticated',
    'public.application_status_history','UPDATE');
  assert not has_table_privilege('authenticated',
    'public.application_status_history','DELETE');
  v := public.list_application_status_history(
    'b6100000-0000-4000-8000-0000000000a1',null,1);
  assert jsonb_array_length(v)=1 and v->0->>'to_status'='in_review';
  assert v->0->>'changed_at' ~ 'Z$', 'history timestamps must be unambiguous UTC';
  assert not (v->0 ? 'changed_by') and not (v->0 ? 'owner_id'),
    'owner projection must not expose staff/user identities';
  older := public.list_application_status_history(
    'b6100000-0000-4000-8000-0000000000a1',(v->0->>'id')::bigint,1);
  assert jsonb_array_length(older)=1 and older->0->>'to_status'='submitted';
  assert public.list_application_status_history(
    'b6100000-0000-4000-8000-0000000000a1',(older->0->>'id')::bigint,1)='[]'::jsonb;
  begin
    perform public.list_application_status_history(
      'b6100000-0000-4000-8000-0000000000a1',null,101);
    raise exception 'FAIL unbounded history read';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.list_application_status_history(
      'b6100000-0000-4000-8000-0000000000a1',0,50);
    raise exception 'FAIL invalid history cursor';
  exception when sqlstate '22023' then null; end;
  perform set_config('request.jwt.claims',
    '{"sub":"b6100000-0000-4000-8000-000000000002","role":"authenticated"}',true);
  begin
    perform public.list_application_status_history(
      'b6100000-0000-4000-8000-0000000000a1',null,50);
    raise exception 'FAIL cross-owner history read';
  exception when sqlstate '42501' then null; end;
  perform set_config('request.jwt.claims','{}',true);
  begin
    perform public.list_application_status_history(
      'b6100000-0000-4000-8000-0000000000a1',null,50);
    raise exception 'FAIL anonymous history read';
  exception when sqlstate '42501' then null; end;
end $check$;
rollback;
