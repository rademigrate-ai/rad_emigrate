-- Hard document deletion with an immutable audit receipt.
-- Storage objects cannot be removed from SQL, so deletion is two-phase: this
-- schema owns authorization, the transient pending_deletion state and the
-- receipt; the document-deletion Edge Function performs the authorized Storage
-- delete between the two phases. pending_deletion exists ONLY to deny access
-- during cleanup -- it is never a retention mechanism.
-- Additive: no existing row, column or migration is rewritten.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Retryable work item. Holds the storage reference after the document row is
-- gone so a failed Storage delete can still be retried and reconciled.
create table if not exists private.rad_document_deletions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null,
  bucket_id text not null,
  object_path text not null,
  -- Preserve an immutable actor UUID even if that Auth user is later deleted.
  -- A foreign key here would block legitimate account removal after the
  -- document itself has been erased and the queue entry is finalized.
  requested_by uuid not null,
  requested_at timestamptz not null default now(),
  state text not null default 'pending_storage'
    check (state in ('pending_storage','storage_deleted','finalized','failed')),
  attempts integer not null default 0 check (attempts >= 0 and attempts <= 10),
  last_error_code text,
  lease_token uuid,
  lease_until timestamptz,
  storage_deleted_at timestamptz,
  finalized_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (document_id)
);
create index if not exists rad_document_deletions_state_idx
  on private.rad_document_deletions (state, requested_at)
  where state in ('pending_storage','failed');

-- Immutable receipt. Deliberately holds no document contents, no credentials,
-- no file name and no application linkage -- only what an audit needs.
create table if not exists public.document_deletion_receipts (
  id bigint generated always as identity primary key,
  document_id uuid not null unique,
  owner_id uuid not null,
  requested_by uuid not null,
  requested_at timestamptz not null,
  confirmed_at timestamptz not null,
  result text not null check (result in ('deleted','failed')),
  storage_reference text not null,
  attempts integer not null,
  created_at timestamptz not null default now()
);
comment on table public.document_deletion_receipts is
  'Immutable hard-deletion receipts. No document contents or credentials. Append-only: UPDATE and DELETE are blocked by trigger.';

create or replace function private.rad_receipt_append_only() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  raise exception 'document deletion receipts are immutable' using errcode='42501';
end $$;
alter function private.rad_receipt_append_only() owner to postgres;

drop trigger if exists rad_receipt_no_update on public.document_deletion_receipts;
create trigger rad_receipt_no_update before update or delete
  on public.document_deletion_receipts
  for each row execute function private.rad_receipt_append_only();

alter table private.rad_document_deletions enable row level security;
alter table public.document_deletion_receipts enable row level security;
-- No permissive policy for clients: receipts are read through a definer RPC so
-- one owner can never enumerate another's deletions.

-- Phase 1: accept an authorized request and deny access immediately.
create or replace function public.request_document_deletion(p_document_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.documents; v_actor uuid := auth.uid(); v_admin boolean;
        v_bucket text := 'documents'; v_request private.rad_document_deletions;
begin
  if v_actor is null then raise exception 'authentication required' using errcode='42501'; end if;
  v_admin := private.has_role(array['admin','super_admin']);
  select * into d from public.documents where id = p_document_id for update;
  if not found then raise exception 'document not found' using errcode='P0002'; end if;
  -- Owner scope mirrors the existing documents RLS predicate exactly.
  if not v_admin and not (
    d.user_id = v_actor and (
      d.application_id is null or exists (
        select 1 from public.applications a
        where a.id = d.application_id and a.user_id = v_actor
      )
    )
  ) then
    raise exception 'not authorized for this document' using errcode='42501';
  end if;
  if d.file_path is null or btrim(d.file_path) = '' then
    -- Some UI document-type placeholders have no uploaded file. They can be
    -- removed without a Storage call only in their explicit missing state;
    -- never treat an uploaded document with a blank reference as erased.
    if d.status <> 'missing' then
      raise exception 'document has no stored object' using errcode='22023';
    end if;
    delete from public.documents where id = p_document_id;
    insert into public.document_deletion_receipts
      (document_id, owner_id, requested_by, requested_at, confirmed_at, result,
       storage_reference, attempts)
    values (p_document_id, d.user_id, v_actor, now(), now(), 'deleted',
            'no_storage_object', 0);
    insert into public.admin_audit_logs(actor_id, action, resource_type, resource_id, safe_metadata)
    values (v_actor, 'finalize_deletion', 'document', p_document_id::text,
            jsonb_build_object('result','deleted','no_storage_object',true));
    return jsonb_build_object('state', 'finalized', 'already_requested', false,
                              'no_storage_object', true);
  end if;

  -- Idempotent: a repeat request returns the in-flight work item unchanged.
  select * into v_request from private.rad_document_deletions where document_id = p_document_id;
  if found then
    return jsonb_build_object('request_id', v_request.id, 'state', v_request.state,
                              'already_requested', true);
  end if;

  insert into private.rad_document_deletions
    (document_id, bucket_id, object_path, requested_by)
  values (p_document_id, v_bucket, d.file_path, v_actor)
  returning * into v_request;

  update public.documents set status = 'pending_deletion', updated_at = now()
  where id = p_document_id;

  insert into public.admin_audit_logs(actor_id, action, resource_type, resource_id, safe_metadata)
  values (v_actor, 'request_deletion', 'document', p_document_id::text,
          jsonb_build_object('state','pending_storage','admin_actor',v_admin));
  return jsonb_build_object('request_id', v_request.id, 'state', v_request.state,
                            'already_requested', false);
end $$;
alter function public.request_document_deletion(uuid) owner to postgres;
revoke all on function public.request_document_deletion(uuid) from public, anon;
grant execute on function public.request_document_deletion(uuid) to authenticated, service_role;

-- Claim a pending item for the worker. Bounded attempts, leased so concurrent
-- workers cannot both delete the same object.
create or replace function public.claim_document_deletion()
returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.rad_document_deletions;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='PT403';
  end if;
  update private.rad_document_deletions set state='failed', last_error_code='attempts_exhausted',
    lease_token=null, lease_until=null, updated_at=now()
  where state='pending_storage' and attempts >= 5;

  select * into r from private.rad_document_deletions
  where state in ('pending_storage','failed') and attempts < 5
    and (lease_until is null or lease_until < now())
  order by requested_at, id for update skip locked limit 1;
  if not found then return null; end if;

  update private.rad_document_deletions
  set state='pending_storage', attempts = attempts + 1, lease_token = gen_random_uuid(),
      lease_until = now() + interval '120 seconds', updated_at = now()
  where id = r.id returning * into r;

  return jsonb_build_object('request_id', r.id, 'lease_token', r.lease_token,
                            'bucket_id', r.bucket_id, 'object_path', r.object_path,
                            'attempts', r.attempts);
end $$;
alter function public.claim_document_deletion() owner to postgres;
revoke all on function public.claim_document_deletion() from public, anon, authenticated;
grant execute on function public.claim_document_deletion() to service_role;

-- Phase 2: only after Storage deletion is CONFIRMED. Deletes the row (cascading
-- to extractions and processing jobs) and writes the immutable receipt.
create or replace function public.finalize_document_deletion(
  p_request_id uuid, p_lease_token uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.rad_document_deletions; v_owner uuid; v_reference text;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='PT403';
  end if;
  select * into r from private.rad_document_deletions
  where id = p_request_id and lease_token = p_lease_token and lease_until > now()
  for update;
  if not found then raise exception 'invalid or expired deletion lease' using errcode='42501'; end if;

  -- Idempotent: finalizing twice returns the existing receipt rather than erroring.
  if r.state = 'finalized' then
    return jsonb_build_object('request_id', r.id, 'state', r.state, 'already_finalized', true);
  end if;

  select user_id into v_owner from public.documents where id = r.document_id;
  -- A missing row means a previous finalize already removed it; keep the
  -- recorded owner from the receipt path rather than inventing one.
  -- Hashed so the receipt carries a verifiable reference, not a live path.
  v_reference := r.bucket_id || '/' || encode(extensions.digest(r.object_path, 'sha256'), 'hex');

  delete from public.documents where id = r.document_id;

  insert into public.document_deletion_receipts
    (document_id, owner_id, requested_by, requested_at, confirmed_at, result,
     storage_reference, attempts)
  values (r.document_id, coalesce(v_owner, r.requested_by), r.requested_by,
          r.requested_at, now(), 'deleted', v_reference, r.attempts)
  on conflict (document_id) do nothing;

  update private.rad_document_deletions
  set state='finalized', storage_deleted_at = coalesce(storage_deleted_at, now()),
      finalized_at = now(), lease_token=null, lease_until=null, updated_at=now()
  where id = r.id;

  insert into public.admin_audit_logs(actor_id, action, resource_type, resource_id, safe_metadata)
  values (r.requested_by, 'finalize_deletion', 'document', r.document_id::text,
          jsonb_build_object('result','deleted','attempts',r.attempts));
  return jsonb_build_object('request_id', r.id, 'state', 'finalized', 'already_finalized', false);
end $$;
alter function public.finalize_document_deletion(uuid, uuid) owner to postgres;
revoke all on function public.finalize_document_deletion(uuid, uuid) from public, anon, authenticated;
grant execute on function public.finalize_document_deletion(uuid, uuid) to service_role;

-- Observable failure. Never reports success; the document stays pending_deletion
-- and the work item stays retryable until attempts are exhausted.
create or replace function public.fail_document_deletion(
  p_request_id uuid, p_lease_token uuid, p_error_code text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.rad_document_deletions;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='PT403';
  end if;
  if p_error_code is null or length(btrim(p_error_code)) not between 1 and 64
     or p_error_code !~ '^[a-z0-9_]+$' then
    raise exception 'safe error code required' using errcode='22023';
  end if;
  update private.rad_document_deletions
  set state = case when attempts >= 5 then 'failed' else 'pending_storage' end,
      last_error_code = p_error_code, lease_token = null, lease_until = null,
      updated_at = now()
  where id = p_request_id and lease_token = p_lease_token returning * into r;
  if not found then raise exception 'invalid deletion lease' using errcode='42501'; end if;
  return jsonb_build_object('request_id', r.id, 'state', r.state, 'attempts', r.attempts);
end $$;
alter function public.fail_document_deletion(uuid, uuid, text) owner to postgres;
revoke all on function public.fail_document_deletion(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fail_document_deletion(uuid, uuid, text) to service_role;

-- Owner-scoped receipt read. Clients never select the table directly.
create or replace function public.get_document_deletion_receipt(p_document_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid := auth.uid(); v_row public.document_deletion_receipts;
begin
  if v_actor is null then raise exception 'authentication required' using errcode='42501'; end if;
  select * into v_row from public.document_deletion_receipts where document_id = p_document_id;
  if not found then return null; end if;
  if v_row.owner_id <> v_actor and not private.has_role(array['admin','super_admin']) then
    raise exception 'not authorized for this receipt' using errcode='42501';
  end if;
  return jsonb_build_object('document_id', v_row.document_id, 'result', v_row.result,
                            'requested_at', v_row.requested_at, 'confirmed_at', v_row.confirmed_at,
                            'storage_reference', v_row.storage_reference);
end $$;
alter function public.get_document_deletion_receipt(uuid) owner to postgres;
revoke all on function public.get_document_deletion_receipt(uuid) from public, anon;
grant execute on function public.get_document_deletion_receipt(uuid) to authenticated, service_role;

-- Requirement 1: deny client access the moment a request is accepted. Replace
-- the owner read/update/delete predicates so a pending_deletion document is
-- invisible and immutable to its owner during cleanup, without touching the
-- admin policies or the insert path.
alter policy "documents select own" on public.documents
  using (
    status <> 'pending_deletion'
    and (select auth.uid()) = user_id
    and (application_id is null or exists (
      select 1 from public.applications a
      where a.id = documents.application_id and a.user_id = (select auth.uid())
    ))
  );
alter policy "documents update own" on public.documents
  using (
    status <> 'pending_deletion'
    and (select auth.uid()) = user_id
    and (application_id is null or exists (
      select 1 from public.applications a
      where a.id = documents.application_id and a.user_id = (select auth.uid())
    ))
  );
-- Direct DELETE is removed from clients: deletion must go through the audited
-- two-phase RPC so the Storage object cannot be orphaned (the previous direct
-- DELETE left the file readable forever).
alter policy "documents delete own" on public.documents
  using (false);

-- SECURITY DEFINER owners hold no rights on supabase_admin-owned private tables
-- on a clean self-hosted install. Grant exactly what these functions use.
grant select, insert, update on private.rad_document_deletions to postgres;

-- Deny direct Storage reads/updates while the deletion worker is pending.
-- Filtering public.documents alone would fail: its own SELECT RLS hides
-- pending_deletion rows. This narrowly scoped definer instead checks the
-- private queue, which remains present until the physical delete completes.
-- It reveals no cross-user path state to an authenticated caller.
create or replace function public.rad_document_storage_pending(p_object_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select case
    when (select auth.uid()) is null
      or split_part(p_object_path, '/', 1) is distinct from (select auth.uid())::text
    then true
    else exists (
      select 1 from private.rad_document_deletions r
      where r.bucket_id = 'documents' and r.object_path = p_object_path
        and r.state <> 'finalized'
    )
  end
$$;
alter function public.rad_document_storage_pending(text) owner to postgres;
revoke all on function public.rad_document_storage_pending(text) from public, anon;
grant execute on function public.rad_document_storage_pending(text)
  to authenticated, service_role;

alter policy "documents storage read own" on storage.objects
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not public.rad_document_storage_pending(name)
  );
alter policy "documents storage update own" on storage.objects
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not public.rad_document_storage_pending(name)
  )
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not public.rad_document_storage_pending(name)
  );

-- A registered document must use the audited two-phase delete API, not a
-- direct Storage DELETE that leaves a dangling documents row. Unregistered
-- uploads may still be discarded by their uploader.
alter policy "documents storage delete own" on storage.objects
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not public.rad_document_storage_pending(name)
    and not exists (
      -- Qualified outer reference is essential: an unqualified name resolves
      -- to public.documents.name, not storage.objects.name.
      select 1 from public.documents d
      where d.file_path = storage.objects.name
    )
  );
commit;
