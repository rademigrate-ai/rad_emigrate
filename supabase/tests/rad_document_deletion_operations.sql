-- Disposable synthetic rows only; no real Storage object is represented here.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('7b000000-0000-4000-8000-000000000001','deletion-ops@example.invalid','{}');
insert into public.documents(id,user_id,name,status,file_path) values
 ('7b000000-0000-4000-8000-0000000000a1','7b000000-0000-4000-8000-000000000001',
  'lease regression','uploaded','7b000000-0000-4000-8000-000000000001/lease.pdf');
do $$
declare r jsonb; token uuid;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"7b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  r := public.request_document_deletion('7b000000-0000-4000-8000-0000000000a1');
  begin
    execute 'set local role authenticated';
    insert into storage.objects(bucket_id,name,owner_id) values
      ('documents','7b000000-0000-4000-8000-000000000001/lease.pdf','7b000000-0000-4000-8000-000000000001');
    execute 'reset role';
    raise exception 'FAIL pending-deletion path can be recreated after physical removal';
  exception when insufficient_privilege then execute 'reset role'; end;
  update private.rad_document_deletions set attempts=4, requested_at='2000-01-01'
    where id=(r->>'request_id')::uuid;
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  r := public.claim_document_deletion();
  token := (r->>'lease_token')::uuid;
  assert (r->>'attempts')::int=5, 'fixture must claim the final allowed attempt';
  perform public.claim_document_deletion();
  assert exists(select 1 from private.rad_document_deletions
    where document_id='7b000000-0000-4000-8000-0000000000a1'
      and lease_token=token and state='pending_storage'),
    'another worker must not revoke the active fifth lease';
  perform public.finalize_document_deletion((r->>'request_id')::uuid,token);
end $$;

-- A caller-controlled documents.file_path must never become a service-role
-- deletion capability for another user's Storage object.
insert into public.documents(id,user_id,name,status,file_path) values
 ('7b000000-0000-4000-8000-0000000000a3','7b000000-0000-4000-8000-000000000001',
  'reference detach fixture','uploaded','7b000000-0000-4000-8000-000000000001/keep.pdf');
do $$
begin
  perform set_config('request.jwt.claims',
    '{"sub":"7b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  begin
    insert into public.documents(id,user_id,name,status,file_path) values
      ('7b000000-0000-4000-8000-0000000000a2','7b000000-0000-4000-8000-000000000001',
       'foreign reference fixture','uploaded','7b000000-0000-4000-8000-000000000002/foreign.pdf');
    raise exception 'FAIL a foreign Storage reference was registered for privileged deletion';
  exception when sqlstate '42501' then null; end;
  begin
    update public.documents set file_path=null,status='missing'
      where id='7b000000-0000-4000-8000-0000000000a3';
    raise exception 'FAIL stored reference detached, bypassing audited deletion';
  exception when sqlstate '42501' then null; end;
end $$;

insert into public.documents(id,user_id,name,status,file_path) values
 ('7b000000-0000-4000-8000-0000000000a4','7b000000-0000-4000-8000-000000000001',
  'preserved fixture','missing',null);
do $$
declare r jsonb; token uuid; req uuid;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"7b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  begin
    perform public.set_document_preservation_hold('7b000000-0000-4000-8000-0000000000a4',true);
    raise exception 'FAIL ordinary user set an administrative hold';
  exception when sqlstate '42501' then null; end;
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  update public.profiles set role='admin' where id='7b000000-0000-4000-8000-000000000001';
  perform set_config('request.jwt.claims',
    '{"sub":"7b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  perform public.set_document_preservation_hold('7b000000-0000-4000-8000-0000000000a4',true);
  begin
    perform public.request_document_deletion('7b000000-0000-4000-8000-0000000000a4');
    raise exception 'FAIL a preserved document was deleted';
  exception when sqlstate '55000' then null; end;
  begin
    delete from public.documents where id='7b000000-0000-4000-8000-0000000000a4';
    raise exception 'FAIL a direct delete bypassed preservation';
  exception when sqlstate '55000' then null; end;
  perform public.set_document_preservation_hold('7b000000-0000-4000-8000-0000000000a4',false);
  r:=public.request_document_deletion('7b000000-0000-4000-8000-0000000000a4');
  assert r->>'state'='finalized','released placeholder must be deletable';
  r:=public.request_document_deletion('7b000000-0000-4000-8000-0000000000a4');
  assert (r->>'already_requested')::boolean,'completed request retry must be idempotent';
  r:=public.list_document_deletions();
  assert jsonb_array_length(r)=2,'owner sees both completed receipts';
  assert r::text not like '%file_path%' and r::text not like '%object_path%',
    'lifecycle status must never return private paths';
  begin
    perform public.document_deletion_queue_health();
    raise exception 'FAIL user read worker queue health';
  exception when sqlstate 'PT403' then null; end;

  -- Failures preserve retry paths; expired leases can be reclaimed, old lease
  -- tokens cannot finalize and exhausted jobs remain visible without looping.
  r:=public.request_document_deletion('7b000000-0000-4000-8000-0000000000a3');
  req:=(r->>'request_id')::uuid;
  begin
    perform public.set_document_preservation_hold('7b000000-0000-4000-8000-0000000000a3',true);
    raise exception 'FAIL promised a hold after deletion was already accepted';
  exception when sqlstate '55000' then null; end;
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  r:=public.claim_document_deletion(); token:=(r->>'lease_token')::uuid;
  perform public.fail_document_deletion(req,token,'storage_network_error');
  assert (select object_path like '%keep.pdf' from private.rad_document_deletions where id=req),
    'retry must retain its original path';
  r:=public.claim_document_deletion(); token:=(r->>'lease_token')::uuid;
  update private.rad_document_deletions set lease_until=now()-interval '1 second' where id=req;
  r:=public.claim_document_deletion();
  assert (r->>'lease_token')::uuid<>token,'expired lease must rotate';
  begin
    perform public.finalize_document_deletion(req,token);
    raise exception 'FAIL stale lease finalized';
  exception when sqlstate '42501' then null; end;
  update private.rad_document_deletions set attempts=5,lease_until=now()-interval '1 second' where id=req;
  perform public.claim_document_deletion();
  r:=public.document_deletion_queue_health();
  assert (r->>'exhausted')::int=1,'exhausted job must be alertable';
  assert (select state='failed' and object_path like '%keep.pdf' from private.rad_document_deletions where id=req),
    'exhausted failure must preserve its recovery reference';
  perform set_config('request.jwt.claims',
    '{"sub":"7b000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
  assert public.list_document_deletions()='[]'::jsonb,'other users must see no lifecycle metadata';
end $$;

insert into auth.users(id,email,raw_user_meta_data) values
 ('7b000000-0000-4000-8000-000000000003','deletion-admin-boundary@example.invalid','{}');
insert into public.documents(id,user_id,name,status,file_path) values
 ('7b000000-0000-4000-8000-0000000000a5','7b000000-0000-4000-8000-000000000003','admin boundary','uploaded',
  '7b000000-0000-4000-8000-000000000003/admin.pdf'),
 ('7b000000-0000-4000-8000-0000000000a6','7b000000-0000-4000-8000-000000000003','super admin boundary','uploaded',
  '7b000000-0000-4000-8000-000000000003/super.pdf');
do $$
declare result jsonb;
begin
  perform set_config('request.jwt.claims','{"sub":"7b000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
  begin
    perform public.request_document_deletion('7b000000-0000-4000-8000-0000000000a5');
    raise exception 'FAIL ordinary caller obtained admin deletion rights';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims','{"sub":"7b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  result:=public.request_document_deletion('7b000000-0000-4000-8000-0000000000a5');
  assert result->>'state'='pending_storage','admin must queue an authorized cross-owner deletion';
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  update public.profiles set role='super_admin' where id='7b000000-0000-4000-8000-000000000001';
  perform set_config('request.jwt.claims','{"sub":"7b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  result:=public.request_document_deletion('7b000000-0000-4000-8000-0000000000a6');
  assert result->>'state'='pending_storage','super_admin must retain the existing authorization boundary';
end $$;
rollback;
