-- Authorization and immutability contract for hard document deletion.
-- Storage behaviour cannot be asserted from SQL, so the real object deletion
-- is covered by scripts/verify_self_host_document_deletion.py; this file pins
-- the privilege boundary, the transient state and the receipt's immutability.
-- Local synthetic fixture, all writes roll back.
begin;

insert into auth.users(id,email,raw_user_meta_data) values
 ('7a000000-0000-4000-8000-000000000001','doc-del-owner@example.invalid','{}'),
 ('7a000000-0000-4000-8000-000000000002','doc-del-other@example.invalid','{}');
insert into public.documents(id,user_id,name,status,file_path) values
 ('7a000000-0000-4000-8000-0000000000a1','7a000000-0000-4000-8000-000000000001',
  'deletion contract fixture','uploaded','7a000000-0000-4000-8000-000000000001/f.pdf'),
 ('7a000000-0000-4000-8000-0000000000a2','7a000000-0000-4000-8000-000000000001',
  'not uploaded placeholder','missing',null);

do $$
declare r jsonb; v_request uuid; v_lease uuid;
begin
  -- Client-reachable surface: only the request and receipt-read RPCs.
  assert has_function_privilege('authenticated','public.request_document_deletion(uuid)','EXECUTE');
  assert has_function_privilege('authenticated','public.get_document_deletion_receipt(uuid)','EXECUTE');
  assert not has_function_privilege('anon','public.request_document_deletion(uuid)','EXECUTE');
  for r in select to_jsonb(f) from (values
      ('public.claim_document_deletion()'),
      ('public.finalize_document_deletion(uuid,uuid)'),
      ('public.fail_document_deletion(uuid,uuid,text)')) f(sig)
  loop
    assert not has_function_privilege('anon',(r->>'sig')::text,'EXECUTE'),
      format('anon must not execute %s', r->>'sig');
    assert not has_function_privilege('authenticated',(r->>'sig')::text,'EXECUTE'),
      format('client must not execute worker function %s', r->>'sig');
    assert has_function_privilege('service_role',(r->>'sig')::text,'EXECUTE'),
      format('service_role must execute %s', r->>'sig');
  end loop;

  -- Direct client DELETE is closed: it previously orphaned the Storage object.
  assert (select pg_catalog.pg_get_expr(polqual, polrelid) from pg_policy
          where polrelid='public.documents'::regclass and polname='documents delete own')
         = 'false', 'client DELETE on documents must be disabled';

  -- Receipts carry no permissive client policy and no direct table grant.
  assert not exists(select 1 from pg_policy
    where polrelid='public.document_deletion_receipts'::regclass and polpermissive),
    'receipts must not be client-readable except through the definer RPC';
  assert (select relrowsecurity from pg_class
          where oid='public.document_deletion_receipts'::regclass),
    'receipts must have RLS enabled';

  -- RLS on public.documents must not make a registered object invisible
  -- to the Storage deletion guard. A non-owner can never bypass registration.
  perform set_config('request.jwt.claims',
    '{"sub":"7a000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
  assert public.rad_document_storage_registered(
    '7a000000-0000-4000-8000-000000000001/f.pdf'),
    'Storage registration check must work even when the row is hidden by RLS';
  assert not public.rad_document_storage_registered(
    '7a000000-0000-4000-8000-000000000001/never-uploaded.pdf');
  assert has_function_privilege('authenticated',
    'public.rad_document_storage_registered(text)', 'EXECUTE');
  assert not has_function_privilege('anon',
    'public.rad_document_storage_registered(text)', 'EXECUTE');
  assert (select pg_catalog.pg_get_expr(polqual, polrelid) like
    '%rad_document_storage_registered%' from pg_policy
    where polrelid='storage.objects'::regclass
      and polname='documents storage delete own'),
    'direct Storage delete must check all registered document references';

  -- A non-owner cannot request deletion of someone else's document.
  begin
    perform public.request_document_deletion('7a000000-0000-4000-8000-0000000000a1');
    raise exception 'FAIL non-owner deletion request accepted';
  exception when sqlstate '42501' then null; end;

  -- SECURITY DEFINER trigger must also block direct SQL/service-side
  -- document deletion and ON DELETE CASCADE from Auth user deletion.
  begin
    delete from public.documents
    where id='7a000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL stored document row deleted outside worker';
  exception when sqlstate '42501' then null; end;
  assert exists(select 1 from public.documents
    where id='7a000000-0000-4000-8000-0000000000a1'),
    'direct delete must preserve stored document';
  begin
    delete from auth.users where id='7a000000-0000-4000-8000-000000000001';
    raise exception 'FAIL auth account cascade bypassed Storage guard';
  exception when sqlstate '42501' then null; end;
  assert exists(select 1 from public.documents
    where id='7a000000-0000-4000-8000-0000000000a1'),
    'failed user cascade must preserve stored document';
  assert exists(select 1 from pg_trigger
    where tgrelid='public.documents'::regclass
      and tgname='rad_stored_document_delete_guard' and not tgisinternal),
    'document hard-delete guard must cover cascades';

  -- The owner's request flips the document to the transient state.
  perform set_config('request.jwt.claims',
    '{"sub":"7a000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

  -- An unuploaded UI document-type placeholder must be deletable without
  -- inventing a Storage object or leaving a stale row.
  r := public.request_document_deletion('7a000000-0000-4000-8000-0000000000a2');
  assert r->>'state' = 'finalized' and (r->>'no_storage_object')::boolean,
    'missing document placeholder must finalize without Storage';
  assert not exists(select 1 from public.documents
    where id='7a000000-0000-4000-8000-0000000000a2'),
    'placeholder row must be hard deleted';
  assert exists(select 1 from public.document_deletion_receipts
    where document_id='7a000000-0000-4000-8000-0000000000a2'
      and storage_reference='no_storage_object' and attempts=0),
    'placeholder deletion must leave an auditable receipt';
  assert not exists(select 1 from private.rad_document_deletions
    where document_id='7a000000-0000-4000-8000-0000000000a2'),
    'placeholder must not enqueue a fictitious Storage deletion';

  r := public.request_document_deletion('7a000000-0000-4000-8000-0000000000a1');
  assert (r->>'already_requested')::boolean is false, 'first request must not be a repeat';
  assert (select status from public.documents
          where id='7a000000-0000-4000-8000-0000000000a1') = 'pending_deletion',
    'document must be marked pending_deletion immediately';

  -- The Storage read/update/delete policies must also deny the original
  -- object immediately, not merely hide its public.documents row.
  assert public.rad_document_storage_pending(
    '7a000000-0000-4000-8000-000000000001/f.pdf'),
    'owner must lose Storage access while the deletion worker is pending';
  assert has_function_privilege('authenticated',
    'public.rad_document_storage_pending(text)', 'EXECUTE');
  assert not has_function_privilege('anon',
    'public.rad_document_storage_pending(text)', 'EXECUTE');
  assert (select pg_catalog.pg_get_expr(polqual, polrelid) like
    '%rad_document_storage_pending%' from pg_policy
    where polrelid='storage.objects'::regclass
      and polname='documents storage read own'),
    'Storage read policy must check pending deletion';
  assert (select pg_catalog.pg_get_expr(polqual, polrelid) like
    '%rad_document_storage_pending%' from pg_policy
    where polrelid='storage.objects'::regclass
      and polname='documents storage update own'),
    'Storage update policy must check pending deletion';
  assert (select pg_catalog.pg_get_expr(polqual, polrelid) like
    '%rad_document_storage_pending%' from pg_policy
    where polrelid='storage.objects'::regclass
      and polname='documents storage delete own'),
    'Storage delete policy must check pending deletion';

  -- Idempotent: a second request returns the in-flight item, not a new one.
  r := public.request_document_deletion('7a000000-0000-4000-8000-0000000000a1');
  assert (r->>'already_requested')::boolean is true, 'repeat request must be idempotent';
  assert (select count(*) from private.rad_document_deletions
          where document_id='7a000000-0000-4000-8000-0000000000a1') = 1,
    'a repeat request must not enqueue a duplicate';

  -- A client cannot finalize its own deletion, even holding the identifiers.
  select id, lease_token into v_request, v_lease from private.rad_document_deletions
   where document_id='7a000000-0000-4000-8000-0000000000a1';
  begin
    perform public.finalize_document_deletion(v_request, v_lease);
    raise exception 'FAIL client finalized a deletion';
  exception when sqlstate 'PT403' then null; end;

  -- Worker path: claim, then finalize. The row goes, the receipt stays.
  perform set_config('request.jwt.claims','{"role":"service_role"}', true);
  r := public.claim_document_deletion();
  assert r is not null, 'service role must claim the pending item';
  perform public.finalize_document_deletion((r->>'request_id')::uuid,
                                            (r->>'lease_token')::uuid);
  assert not exists(select 1 from public.documents
    where id='7a000000-0000-4000-8000-0000000000a1'), 'document row must be hard deleted';
  assert exists(select 1 from public.document_deletion_receipts
    where document_id='7a000000-0000-4000-8000-0000000000a1' and result='deleted'),
    'an immutable receipt must remain';

  -- The receipt holds no file name or path, only a hashed reference.
  assert (select storage_reference not like '%f.pdf%'
          from public.document_deletion_receipts
          where document_id='7a000000-0000-4000-8000-0000000000a1'),
    'receipt must not retain the object path';

  -- A stale lease cannot be replayed to finalize again.
  begin
    perform public.finalize_document_deletion((r->>'request_id')::uuid,
                                              (r->>'lease_token')::uuid);
  exception when others then null; end;
  assert (select count(*) from public.document_deletion_receipts
          where document_id='7a000000-0000-4000-8000-0000000000a1') = 1,
    'finalizing twice must not duplicate the receipt';
end $$;

-- Immutability is enforced by trigger, not convention.
do $$
begin
  begin
    update public.document_deletion_receipts set result='failed'
     where document_id='7a000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL receipt accepted an UPDATE';
  exception when sqlstate '42501' then null; end;
  begin
    delete from public.document_deletion_receipts
     where document_id='7a000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL receipt accepted a DELETE';
  exception when sqlstate '42501' then null; end;
end $$;

rollback;
