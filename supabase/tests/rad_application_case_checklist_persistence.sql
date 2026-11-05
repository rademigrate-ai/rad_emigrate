-- Rollback-only SQL contract for user-owned, versioned case checklist RPCs.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('a4000000-0000-4000-8000-000000000001','checklist-owner@example.invalid','{}'),
 ('a4000000-0000-4000-8000-000000000002','checklist-other@example.invalid','{}');
insert into public.applications(id,user_id,visa_type,status) values
 ('a4000000-0000-4000-8000-0000000000a1',
  'a4000000-0000-4000-8000-000000000001','synthetic-test-only','draft');

do $check$
declare v jsonb;
begin
  assert not has_table_privilege('authenticated',
    'public.application_case_checklists','SELECT'),
    'checklist data must not be directly exposed';
  assert not has_table_privilege('anon',
    'public.application_case_checklists','SELECT'),
    'anonymous data access must be denied';
  assert has_function_privilege('authenticated',
    'public.get_application_case_checklist(uuid)','EXECUTE');
  assert not has_function_privilege('anon',
    'public.get_application_case_checklist(uuid)','EXECUTE');
  assert not has_function_privilege('anon',
    'public.put_application_case_checklist(uuid,jsonb,integer)','EXECUTE');

  perform set_config('request.jwt.claims',
    '{"sub":"a4000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  assert public.get_application_case_checklist(
    'a4000000-0000-4000-8000-0000000000a1') is null;
  v := public.put_application_case_checklist(
    'a4000000-0000-4000-8000-0000000000a1',
    '[{"id":"step1","title":"Verify actual sources","status":"notStarted"}]'::jsonb, 0);
  assert (v->>'revision')::integer=1,'first save must persist at revision 1';
  v := public.get_application_case_checklist(
    'a4000000-0000-4000-8000-0000000000a1');
  assert (v->>'revision')::integer=1
      and v->'items'->0->>'title'='Verify actual sources',
    'owner must read persisted original data';
  begin
    perform public.put_application_case_checklist(
      'a4000000-0000-4000-8000-0000000000a1','[]'::jsonb, 0);
    raise exception 'FAIL stale checklist write accepted';
  exception when sqlstate 'PT409' then null; end;
  begin
    perform public.put_application_case_checklist(
      'a4000000-0000-4000-8000-0000000000a1',
      '[{"title":"missing id","status":"notStarted"}]'::jsonb, 1);
    raise exception 'FAIL invalid item accepted';
  exception when sqlstate '22023' then null; end;
  v := public.put_application_case_checklist(
    'a4000000-0000-4000-8000-0000000000a1',
    '[{"id":"step1","title":"Verified new note","status":"completed"}]'::jsonb, 1);
  assert (v->>'revision')::integer=2;
  assert (public.get_application_case_checklist(
      'a4000000-0000-4000-8000-0000000000a1')->'items'->0->>'title')
      = 'Verified new note',
    'owner must read the second acknowledged revision';

  perform set_config('request.jwt.claims',
    '{"sub":"a4000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
  begin
    perform public.get_application_case_checklist(
      'a4000000-0000-4000-8000-0000000000a1');
    raise exception 'FAIL cross-owner read';
  exception when sqlstate '42501' then null; end;
  begin
    perform public.put_application_case_checklist(
      'a4000000-0000-4000-8000-0000000000a1','[]'::jsonb, 2);
    raise exception 'FAIL cross-owner edit';
  exception when sqlstate '42501' then null; end;
end $check$;
rollback;
