-- Install after source-faithful publication and corrected admission.
-- This is not a database Restore or a complete committed-DDL inverse.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

create table if not exists private.rad_source_unpublish_receipts(
 id bigint generated always as identity primary key,
 batch_id uuid not null references private.rad_source_editorial_batches(id),
 actor_id uuid not null references auth.users(id),
 operation text not null check(operation='unpublish_source_editorial_batch'),
 manifest_sha256 text not null check(manifest_sha256~'^[a-f0-9]{64}$'),
 request_sha256 text not null check(request_sha256~'^[a-f0-9]{64}$'),
 members_sha256 text not null check(members_sha256~'^[a-f0-9]{64}$'),
 note text not null check(length(btrim(note))>=20),
 reversed_count integer not null check(reversed_count>=0),
 created_at timestamptz not null default now(),
 unique(batch_id)
);
alter table private.rad_source_unpublish_receipts enable row level security;
revoke all on private.rad_source_unpublish_receipts from public,anon,authenticated,service_role;
create trigger rad_source_unpublish_receipts_immutable before update or delete
 on private.rad_source_unpublish_receipts for each row execute function private.rad_immutable();

create table private.rad_source_unpublish_members(
 batch_id uuid not null references private.rad_source_editorial_batches(id),
 revision_id uuid not null references public.visa_article_revisions(id),
 article_id uuid not null references public.visa_articles(id),locale text not null check(locale in('en','fa')),
 expected_head_id uuid not null references public.visa_article_revisions(id),
 previous_published_id uuid not null references public.visa_article_revisions(id),
 content_hash text not null check(content_hash~'^[a-f0-9]{64}$'),
 original_author_id uuid not null references auth.users(id),
 unpublish_event_id uuid not null unique references public.visa_article_revision_events(id),
 actor_id uuid not null references auth.users(id),primary key(batch_id,revision_id)
);
alter table private.rad_source_unpublish_members enable row level security;
revoke all on private.rad_source_unpublish_members from public,anon,authenticated,service_role;
create trigger rad_source_unpublish_members_immutable before update or delete
 on private.rad_source_unpublish_members for each row execute function private.rad_immutable();

alter table public.visa_article_revision_events
 add column source_operation_xid xid8,
 drop constraint visa_article_revision_events_state_check,
 add constraint visa_article_revision_events_state_check check(state in('draft','review','approved','rejected','published','archived','unpublished')),
 drop constraint rad_source_event_basis_check,
 add constraint rad_source_event_basis_check check(
  (publication_basis='standard_editorial' and source_batch_id is null)
  or (publication_basis='source_faithful' and source_batch_id is not null and state in('approved','published','unpublished')));
create unique index rad_source_unpublish_once on public.visa_article_revision_events(revision_id,source_batch_id)
 where publication_basis='source_faithful'and state='unpublished';

-- xmin may name a savepoint subtransaction. Bind the full top-level xid at
-- insertion instead; callers cannot supply an old or future operation identity.
create function private.rad_source_event_transaction_guard()returns trigger
language plpgsql set search_path=''as $$begin
 new.source_operation_xid:=case when new.publication_basis='source_faithful'then pg_current_xact_id()else null end;
 return new;
end $$;
revoke all on function private.rad_source_event_transaction_guard()from public,anon,authenticated,service_role;
create trigger rad_source_event_transaction_guard before insert on public.visa_article_revision_events
 for each row execute function private.rad_source_event_transaction_guard();

-- A hold blocks approval/publication, never the withdrawal of held public content.
create or replace function private.rad_source_hold_event_guard()returns trigger
language plpgsql set search_path=''as $$begin
 if new.publication_basis='source_faithful'and new.state in('approved','published')and exists(
  select 1 from private.rad_production_reconciliation_journal j
  join private.rad_source_publication_holds h on h.package_sha256=j.package_sha256
   and h.operation_id=j.operation_id and h.payload_sha256=j.payload_sha256
   and h.article_id=j.article_id and h.locale=j.locale and h.revision_id=j.revision_id
  where j.revision_id=new.revision_id)then
  raise exception 'source_publication_hold_requires_evidence_reconciliation'using errcode='PT422';
 end if;
 return new;
end $$;
revoke all on function private.rad_source_hold_event_guard()from public,anon,authenticated,service_role;

-- Source-faithful reversal: only a currently published revision from the exact
-- approved batch can be unpublished, and only through an immutable unpublish
-- event. The head pointer guard checks this event before allowing NULL.
create or replace function private.rad_source_publication_pointer_guard() returns trigger
language plpgsql set search_path='' as $$begin
 if new.published_id is null then
  -- Preserve existing standard-editorial pointer semantics. Only a previously
  -- source-faithful published revision requires an explicit unpublish event.
  if tg_op='UPDATE' and old.published_id is not null
   and exists(select 1 from public.visa_article_revision_events e
    where e.revision_id=old.published_id and e.publication_basis='source_faithful') then
   perform private.rad_require_admin();
   if not exists(select 1 from public.visa_article_revision_events e
    join private.rad_source_editorial_batches b on b.id=e.source_batch_id
    join public.visa_article_revisions r on r.id=e.revision_id
    join private.rad_source_unpublish_members m on m.unpublish_event_id=e.id and m.batch_id=b.id
    where e.revision_id=old.published_id and e.state='unpublished' and e.publication_basis='source_faithful'
    and e.actor_id=auth.uid() and b.approved_by=auth.uid() and r.article_id=new.article_id and r.locale=new.locale
    and m.revision_id=r.id and m.content_hash=r.content_hash and m.actor_id=auth.uid()
    and m.article_id=new.article_id and m.locale=new.locale and m.expected_head_id=new.head_id
    and m.previous_published_id=old.published_id and private.rad_article_state(r.id)='unpublished'
    -- Only the event inserted by this same transaction authorizes reversal.
    and e.source_operation_xid=pg_current_xact_id())
   then raise exception 'explicit_source_unpublish_operation_required' using errcode='PT422';end if;
  end if;
  return new;
 end if;
 if tg_op='UPDATE' and new.published_id is not distinct from old.published_id then return new;end if;
 if exists(select 1 from public.visa_article_revision_events where revision_id=new.published_id and publication_basis='source_faithful') then
  perform private.rad_require_admin();
  if not exists(select 1 from public.visa_article_revision_events e join private.rad_source_editorial_batches b on b.id=e.source_batch_id
   join public.visa_article_revisions r on r.id=e.revision_id
   where e.revision_id=new.published_id and e.state='published' and e.publication_basis='source_faithful'
   and e.actor_id=auth.uid() and b.approved_by=auth.uid() and r.article_id=new.article_id and r.locale=new.locale
   and private.rad_article_state(r.id)='published'
   and e.source_operation_xid=pg_current_xact_id())
  then raise exception 'explicit_source_publication_operation_required' using errcode='PT422';end if;
 end if;
 return new;
end $$;
revoke all on function private.rad_source_publication_pointer_guard() from public,anon,authenticated,service_role;

create or replace function public.unpublish_source_editorial_batch(p_batch_id uuid,p_manifest_sha256 text,p_note text)
returns jsonb language plpgsql security definer set search_path=''set lock_timeout='2s'as $$
declare actor uuid:=private.rad_require_admin();batch private.rad_source_editorial_batches;entry jsonb;
 r public.visa_article_revisions;event public.visa_article_revision_events;head public.visa_article_heads;
 member private.rad_source_unpublish_members;prior private.rad_source_unpublish_receipts;
 receipts jsonb:='[]';n integer:=0;ct integer;rid bigint;request_sha text;members_sha text;
begin
 if p_batch_id is null or p_manifest_sha256 is null or p_manifest_sha256!~'^[a-f0-9]{64}$'
 or length(btrim(coalesce(p_note,'')))<20 then raise exception 'source_unpublish_review_required'using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('source-batch:'||p_batch_id::text,0));
 select * into batch from private.rad_source_editorial_batches where id=p_batch_id;
 if batch.id is null then raise exception 'source_batch_not_found'using errcode='PT404';end if;
 if batch.approved_by<>actor or p_manifest_sha256<>batch.manifest_sha256 then
  raise exception 'source_batch_actor_or_hash_conflict'using errcode='PT409';end if;
 if encode(extensions.digest(batch.manifest_text,'sha256'),'hex')<>batch.manifest_sha256
 or jsonb_typeof(batch.manifest_text::jsonb)<>'array'
 or jsonb_array_length(batch.manifest_text::jsonb)not between 1 and 100
 or exists(select 1 from jsonb_array_elements(batch.manifest_text::jsonb)e group by e->>'revision_id'having count(*)>1)then
  raise exception 'source_batch_manifest_integrity_required'using errcode='PT409';end if;
 request_sha:=encode(extensions.digest(jsonb_build_object('batch_id',batch.id,'actor_id',actor,
  'manifest_sha256',p_manifest_sha256,'note',p_note)::text,'sha256'),'hex');
 select * into prior from private.rad_source_unpublish_receipts where batch_id=batch.id;
 if prior.id is not null and(prior.actor_id<>actor or prior.request_sha256<>request_sha)then
  raise exception 'source_unpublish_request_conflict'using errcode='PT409';end if;
 if prior.id is null and exists(select 1 from private.rad_source_unpublish_members where batch_id=batch.id)then
  raise exception 'source_unpublish_partial_receipt_state'using errcode='PT409';end if;
 perform 1 from public.visa_article_heads h join public.visa_article_revisions v on v.article_id=h.article_id and v.locale=h.locale
 where v.id in(select(value->>'revision_id')::uuid from jsonb_array_elements(batch.manifest_text::jsonb))
 order by h.article_id,h.locale for update of h;
 perform 1 from private.rad_editorial_catalog c where c.article_id in(
  select revision_row.article_id from public.visa_article_revisions revision_row where revision_row.id in(
   select(value->>'revision_id')::uuid from jsonb_array_elements(batch.manifest_text::jsonb)))
 order by c.article_id for update;
 for entry in select value from jsonb_array_elements(batch.manifest_text::jsonb)order by value->>'revision_id'loop
  if entry->'expected_published_id'is distinct from 'null'::jsonb then
   raise exception 'source_unpublish_prior_pointer_must_be_null'using errcode='PT409';end if;
  entry:=entry||jsonb_build_object('expected_catalog_active',true);
  select * into r from public.visa_article_revisions where id=private.rad_source_editorial_entry(entry);
  select * into head from public.visa_article_heads where article_id=r.article_id and locale=r.locale;
  if head.head_id is distinct from(entry->>'expected_head_id')::uuid then
   raise exception 'source_unpublish_head_conflict'using errcode='PT409';end if;
  if prior.id is not null then
   select * into member from private.rad_source_unpublish_members where batch_id=batch.id and revision_id=r.id;
   select * into event from public.visa_article_revision_events where id=member.unpublish_event_id;
   if member.revision_id is null or head.published_id is not null or private.rad_article_state(r.id)<>'unpublished'
    or member.actor_id<>actor or member.content_hash<>r.content_hash or member.original_author_id<>r.created_by
    or member.expected_head_id<>head.head_id or member.previous_published_id<>r.id
    or event.state<>'unpublished'or event.publication_basis<>'source_faithful'or event.source_batch_id<>batch.id
    or event.revision_id<>r.id or event.actor_id<>actor then
    raise exception 'source_unpublish_retry_conflict'using errcode='PT409';end if;
  else
   if private.rad_article_state(r.id)<>'published'or head.published_id is distinct from r.id
    or not exists(select 1 from public.visa_article_revision_events e where e.revision_id=r.id
     and e.state='published'and e.publication_basis='source_faithful'and e.source_batch_id=batch.id and e.actor_id=actor)then
    raise exception 'source_publication_state_changed'using errcode='PT409';end if;
   insert into public.visa_article_revision_events(revision_id,state,actor_id,note,publication_basis,source_batch_id)
    values(r.id,'unpublished',actor,p_note,'source_faithful',batch.id)returning * into event;
   insert into private.rad_source_unpublish_members(batch_id,revision_id,article_id,locale,expected_head_id,
    previous_published_id,content_hash,original_author_id,unpublish_event_id,actor_id)
    values(batch.id,r.id,r.article_id,r.locale,head.head_id,r.id,r.content_hash,r.created_by,event.id,actor);
   update public.visa_article_heads set published_id=null where article_id=r.article_id and locale=r.locale
    and head_id=head.head_id and published_id=r.id;
   get diagnostics ct=row_count;
   if ct<>1 then raise exception 'source_publication_state_changed'using errcode='PT409';end if;
  end if;
  n:=n+1;
  receipts:=receipts||jsonb_build_array(jsonb_build_object('article_id',r.article_id,'locale',r.locale,
   'revision_id',r.id,'content_hash',r.content_hash,'unpublish_event_id',event.id,'actor_id',event.actor_id,
   'unpublished_at',event.created_at,'published_id',null));
 end loop;
 select encode(extensions.digest(jsonb_agg(to_jsonb(m)order by m.revision_id)::text,'sha256'),'hex'),count(*)
 into members_sha,ct from private.rad_source_unpublish_members m where m.batch_id=batch.id;
 if ct<>n then raise exception 'source_unpublish_member_set_conflict'using errcode='PT409';end if;
 if prior.id is not null then
  if prior.reversed_count<>n or prior.members_sha256 is distinct from members_sha then
   raise exception 'source_unpublish_receipt_conflict'using errcode='PT409';end if;
  rid:=prior.id;
 else
  insert into private.rad_source_unpublish_receipts(batch_id,actor_id,operation,manifest_sha256,request_sha256,members_sha256,note,reversed_count)
   values(batch.id,actor,'unpublish_source_editorial_batch',p_manifest_sha256,request_sha,members_sha,p_note,n)returning id into rid;
 end if;
 return private.rad_envelope(jsonb_build_object('batch_id',batch.id,'manifest_sha256',batch.manifest_sha256,
  'receipt_id',rid,'receipts',receipts,'unpublished_count',n,'factual_verification_changed',false,'feed_publications',0));
end $$;
revoke all on function public.unpublish_source_editorial_batch(uuid,text,text)from public,anon,authenticated,service_role;
grant execute on function public.unpublish_source_editorial_batch(uuid,text,text)to authenticated;

notify pgrst,'reload schema';
commit;
