-- Apply after the reviewed CMS forward and guarded draft import. This migration
-- publishes nothing. Source reproduction and factual verification stay distinct.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

-- Only payloads admitted by the separately guarded importer are eligible.
-- Ordinary Admin editing cannot manufacture an import or source-integrity seal.
create table if not exists private.rad_production_reconciliation_journal(
 package_sha256 text not null,operation_id text not null,payload_sha256 text not null,
 article_id uuid not null,locale text not null,revision_id uuid not null references public.visa_article_revisions(id),
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default now(),
 primary key(package_sha256,operation_id));
alter table private.rad_production_reconciliation_journal enable row level security;
revoke all on private.rad_production_reconciliation_journal from public,anon,authenticated,service_role;
create table private.rad_source_editorial_admissions(
 package_sha256 text primary key check(package_sha256~'^[a-f0-9]{64}$'),
 source_integrity_receipt_sha256 text not null check(source_integrity_receipt_sha256~'^[a-f0-9]{64}$'),
 policy text not null check(policy='RAD_CONTENT_PRECEDENCE_V4.1')
);
insert into private.rad_source_editorial_admissions values(
 'c9b4d7e84711a3fb478b639d724289a3f2694a298448d662d4637894d0318353',
 '2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','RAD_CONTENT_PRECEDENCE_V4.1');
alter table private.rad_source_editorial_admissions enable row level security;
revoke all on private.rad_source_editorial_admissions from public,anon,authenticated,service_role;
create trigger rad_source_editorial_admissions_immutable before update or delete
 on private.rad_source_editorial_admissions for each row execute function private.rad_immutable();

create table private.rad_source_editorial_batches(
 id uuid primary key,
 manifest_sha256 text not null unique check(manifest_sha256~'^[a-f0-9]{64}$'),
 manifest_text text not null,
 source_integrity_receipt_sha256 text not null check(source_integrity_receipt_sha256~'^[a-f0-9]{64}$'),
 approved_by uuid not null references auth.users(id),
 note text not null check(length(btrim(note))>=20),
 approved_at timestamptz not null default now()
);
alter table private.rad_source_editorial_batches enable row level security;
revoke all on private.rad_source_editorial_batches from public,anon,authenticated,service_role;
create trigger rad_source_editorial_batches_immutable before update or delete
 on private.rad_source_editorial_batches for each row execute function private.rad_immutable();

alter table public.visa_article_revision_events
 add column publication_basis text not null default 'standard_editorial'
 check(publication_basis in('standard_editorial','source_faithful')),
 add column source_batch_id uuid references private.rad_source_editorial_batches(id),
 add constraint rad_source_event_basis_check check(
  (publication_basis='standard_editorial' and source_batch_id is null)
  or (publication_basis='source_faithful' and source_batch_id is not null and state in('approved','published')));
create unique index rad_source_editorial_approval_once
 on public.visa_article_revision_events(revision_id)
 where publication_basis='source_faithful' and state='approved';

create function private.rad_source_editorial_entry(entry jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;h public.visa_article_heads;catalog private.rad_editorial_catalog;rich jsonb;payload jsonb;
 source jsonb;snapshot public.source_snapshots;document public.source_documents;publishers text[];
begin
 if jsonb_typeof(entry) is distinct from 'object'
 or not(entry ?& array['revision_id','expected_head_id','expected_published_id','payload_sha256','payload_text','expected_catalog_active','activate_catalog'])
 or (entry-array['revision_id','expected_head_id','expected_published_id','payload_sha256','payload_text','expected_catalog_active','activate_catalog'])<>'{}'::jsonb
 or jsonb_typeof(entry->'expected_catalog_active') is distinct from 'boolean' or entry->'activate_catalog' is distinct from 'true'::jsonb
 or jsonb_typeof(entry->'payload_text') is distinct from 'string'
 or entry->>'payload_sha256' !~ '^[a-f0-9]{64}$'
 or encode(extensions.digest(entry->>'payload_text','sha256'),'hex') is distinct from entry->>'payload_sha256'
 then raise exception 'exact_source_payload_required' using errcode='PT422';end if;
 payload:=(entry->>'payload_text')::jsonb;
 select * into r from public.visa_article_revisions where id=(entry->>'revision_id')::uuid;
 if not found then raise exception 'source_revision_not_found' using errcode='PT404';end if;
 if not exists(select 1 from private.rad_production_reconciliation_journal j join private.rad_source_editorial_admissions a on a.package_sha256=j.package_sha256
  where j.revision_id=r.id and j.article_id=r.article_id and j.locale=r.locale and j.payload_sha256=entry->>'payload_sha256')
 then raise exception 'guarded_import_admission_required' using errcode='PT422';end if;
 select * into h from public.visa_article_heads where article_id=r.article_id and locale=r.locale for update;
 if not found or h.head_id is distinct from (entry->>'expected_head_id')::uuid
 or (h.published_id is distinct from (entry->>'expected_published_id')::uuid and h.published_id is distinct from r.id)
 or ((entry->>'expected_published_id') is not null and (entry->>'expected_published_id')::uuid<>r.id)
 then raise exception 'source_head_or_publication_conflict' using errcode='PT409';end if;
 select * into catalog from private.rad_editorial_catalog where article_id=r.article_id for update;
 select rr.composition into rich from private.rad_editorial_rich_revisions rr where rr.revision_id=r.id;
 if catalog.article_id is null or (catalog.active is distinct from (entry->>'expected_catalog_active')::boolean and h.published_id is distinct from r.id)
 or to_jsonb(catalog.country_codes) is distinct from rich->'country_codes' then
 raise exception 'source_catalog_binding_conflict' using errcode='PT409';end if;
 if rich is null or rich is distinct from ((payload->'item')-'draft_request')
 or r.body is distinct from ((payload->'item'->'draft_request')-'request_key')
 or r.article_id::text is distinct from payload->'item'->>'article_id'
 or r.locale is distinct from payload->'item'->>'locale'
 or r.title is distinct from payload->'item'->'draft_request'->>'title'
 or r.content_hash is distinct from encode(extensions.digest((r.body-'expected_revision')::text,'sha256'),'hex')
 or rich->>'composition_policy' is distinct from 'RAD_CONTENT_PRECEDENCE_V4.1'
 or jsonb_typeof(rich->'sections') is distinct from 'array' or jsonb_array_length(rich->'sections')=0
 or jsonb_typeof(rich->'segment_ledger') is distinct from 'array' or jsonb_array_length(rich->'segment_ledger')=0
 or jsonb_typeof(rich->'conflicts') is distinct from 'array' or jsonb_array_length(rich->'conflicts')<>0
 or jsonb_path_exists(rich,'$.**.public_render_allowed ? (@ == true)')
 then raise exception 'faithful_body_conflict_or_media_gate' using errcode='PT422';end if;
 select array_agg(value) into publishers from jsonb_array_elements_text(rich->'source_publishers');
 if publishers is null or not(publishers<@array['digivisa.ir','radvisa.com','radmohajer.ir'])
 or ('radmohajer.ir'=any(publishers) and cardinality(publishers)<>1)
 or jsonb_typeof(payload->'sources') is distinct from 'array' or jsonb_array_length(payload->'sources')=0
 then raise exception 'source_publisher_independence_required' using errcode='PT422';end if;
 for source in select value from jsonb_array_elements(payload->'sources') loop
  select * into snapshot from public.source_snapshots where id=(source->>'snapshot_id')::uuid;
  select * into document from public.source_documents where id=snapshot.document_id;
  if snapshot.id is null or document.id is null
  or snapshot.content_hash is distinct from source->>'body_sha256'
  or snapshot.normalized_text is distinct from source->>'body_text'
  or encode(extensions.digest(snapshot.normalized_text,'sha256'),'hex') is distinct from source->>'body_sha256'
  or document.canonical_url is distinct from source->>'url'
  or document.language_code is distinct from r.locale or source->>'language' is distinct from r.locale
  or (snapshot.metadata->>'raw_html_sha256' is distinct from source->>'raw_html_sha256' and not exists(
   select 1 from jsonb_array_elements(rich->'source_capture_variants') capture where capture->>'source_snapshot_id'=source->>'snapshot_id'
   and capture->>'raw_html_sha256'=source->>'raw_html_sha256' and capture->>'body_sha256'=source->>'body_sha256' and capture->>'source_url'=source->>'url'))
  or source->>'raw_html_sha256' is null or source->>'raw_html_sha256' !~ '^[a-f0-9]{64}$'
  or source->>'url' !~ '^https?://(www\.)?(digivisa\.ir|radvisa\.com|radmohajer\.ir)(/|$)'
  or not coalesce((rich->'source_snapshot_ids') ? (source->>'snapshot_id'),false)
  then raise exception 'source_snapshot_hash_or_identity_mismatch' using errcode='PT422';end if;
 end loop;
 if exists(select 1 from jsonb_array_elements_text(rich->'source_snapshot_ids') sid
  where not exists(select 1 from jsonb_array_elements(payload->'sources') s where s->>'snapshot_id'=sid))
 then raise exception 'complete_source_snapshot_set_required' using errcode='PT422';end if;
 return r.id;
end $$;
revoke all on function private.rad_source_editorial_entry(jsonb) from public,anon,authenticated,service_role;

-- Standard editorial publication retains the existing official verification,
-- human-clearance and original-reference requirements without alteration.
create or replace function private.rad_editorial_approval_guard() returns trigger
language plpgsql set search_path='' as $$
declare batch private.rad_source_editorial_batches;entry jsonb;actor uuid;begin
 if new.publication_basis='source_faithful' then
  actor:=private.rad_require_admin();
  select * into batch from private.rad_source_editorial_batches where id=new.source_batch_id;
  if batch.id is null or batch.approved_by<>actor or new.actor_id<>actor then
   raise exception 'authenticated_source_batch_actor_required' using errcode='PT403';end if;
  select value into entry from jsonb_array_elements(batch.manifest_text::jsonb)
   where value->>'revision_id'=new.revision_id::text;
  if entry is null or private.rad_source_editorial_entry(entry)<>new.revision_id then
   raise exception 'source_revision_not_in_approved_batch' using errcode='PT422';end if;
  if not exists(select 1 from private.rad_production_reconciliation_journal j join private.rad_source_editorial_admissions a on a.package_sha256=j.package_sha256
   where j.revision_id=new.revision_id and a.source_integrity_receipt_sha256=batch.source_integrity_receipt_sha256)
  then raise exception 'admitted_source_integrity_receipt_required' using errcode='PT422';end if;
  if new.state='published' and not exists(select 1 from public.visa_article_revision_events
   where revision_id=new.revision_id and state='approved' and publication_basis='source_faithful' and source_batch_id=batch.id)
  then raise exception 'source_batch_approval_required' using errcode='PT422';end if;
  return new;
 end if;
 if new.state in('approved','published') and exists(select 1 from public.visa_article_revisions r
 join private.rad_editorial_catalog c on c.article_id=r.article_id where r.id=new.revision_id)
 and not exists(select 1 from private.rad_editorial_clearances cl join public.visa_article_revisions r on r.id=cl.revision_id
 where r.id=new.revision_id and cl.content_hash=r.content_hash and private.rad_article_verification(r.id)='verified') then
 raise exception 'imported_content_requires_verified_human_clearance' using errcode='PT422';end if;
 if new.state in('approved','published') and exists(select 1 from public.visa_article_revisions r
 join private.rad_editorial_catalog c on c.article_id=r.article_id where r.id=new.revision_id)
 and not exists(select 1 from private.rad_editorial_reference_maps where revision_id=new.revision_id and active and content->>'capture_status'='complete') then
 raise exception 'original_reference_capture_required' using errcode='PT422';end if;
 return new;
end $$;
revoke all on function private.rad_editorial_approval_guard() from public,anon,authenticated,service_role;

create function private.rad_source_publication_pointer_guard() returns trigger
language plpgsql set search_path='' as $$begin
 if new.published_id is null then return new;end if;
 if tg_op='UPDATE' and new.published_id is not distinct from old.published_id then return new;end if;
 if exists(select 1 from public.visa_article_revision_events where revision_id=new.published_id and publication_basis='source_faithful') then
  perform private.rad_require_admin();
  if not exists(select 1 from public.visa_article_revision_events e join private.rad_source_editorial_batches b on b.id=e.source_batch_id
   join public.visa_article_revisions r on r.id=e.revision_id
   where e.revision_id=new.published_id and e.state='published' and e.publication_basis='source_faithful'
   and e.actor_id=auth.uid() and b.approved_by=auth.uid() and r.article_id=new.article_id and r.locale=new.locale)
  then raise exception 'explicit_source_publication_operation_required' using errcode='PT422';end if;
 end if;
 return new;
end $$;
revoke all on function private.rad_source_publication_pointer_guard() from public,anon,authenticated,service_role;
create trigger rad_source_publication_pointer_guard before insert or update of published_id on public.visa_article_heads
 for each row execute function private.rad_source_publication_pointer_guard();

create function public.approve_source_editorial_batch(p_batch_id uuid,p_manifest_text text,p_manifest_sha256 text,
 p_source_integrity_receipt_sha256 text,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();entries jsonb;entry jsonb;rid uuid;prior private.rad_source_editorial_batches;n integer;begin
 if p_batch_id is null or p_manifest_text is null or octet_length(p_manifest_text)>50000000
 or p_manifest_sha256 is null or p_manifest_sha256!~'^[a-f0-9]{64}$'
 or encode(extensions.digest(p_manifest_text,'sha256'),'hex')<>p_manifest_sha256
 or p_source_integrity_receipt_sha256 is null or p_source_integrity_receipt_sha256!~'^[a-f0-9]{64}$'
 or length(btrim(coalesce(p_note,'')))<20 then raise exception 'hash_bound_source_batch_required' using errcode='PT422';end if;
 entries:=p_manifest_text::jsonb;
 if jsonb_typeof(entries)<>'array' or jsonb_array_length(entries) not between 1 and 100
 or exists(select 1 from jsonb_array_elements(entries)e group by e->>'revision_id' having count(*)>1)
 then raise exception 'unique_bounded_source_batch_required' using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('source-batch:'||p_batch_id::text,0));
 select * into prior from private.rad_source_editorial_batches where id=p_batch_id;
 if prior.id is not null then
  if prior.manifest_sha256<>p_manifest_sha256 or prior.manifest_text<>p_manifest_text
  or prior.approved_by<>actor or prior.source_integrity_receipt_sha256<>p_source_integrity_receipt_sha256 or prior.note<>p_note then
   raise exception 'source_batch_retry_conflict' using errcode='PT409';end if;
  return private.rad_envelope(jsonb_build_object('batch_id',prior.id,'manifest_sha256',prior.manifest_sha256,
   'approved_count',jsonb_array_length(entries),'approved_by',prior.approved_by,'approved_at',prior.approved_at,
   'publication_basis','source_faithful','factual_verification_changed',false));
 end if;
 -- Lock shared article heads in deterministic order before validating any member.
 perform 1 from public.visa_article_heads h join public.visa_article_revisions r on r.article_id=h.article_id and r.locale=h.locale
 where r.id in(select (value->>'revision_id')::uuid from jsonb_array_elements(entries)) order by h.article_id,h.locale for update of h;
 perform 1 from private.rad_editorial_catalog c where c.article_id in(select r.article_id from public.visa_article_revisions r
 where r.id in(select (value->>'revision_id')::uuid from jsonb_array_elements(entries))) order by c.article_id for update;
 for entry in select value from jsonb_array_elements(entries) order by value->>'revision_id' loop
  rid:=private.rad_source_editorial_entry(entry);
  if not exists(select 1 from private.rad_production_reconciliation_journal j join private.rad_source_editorial_admissions a on a.package_sha256=j.package_sha256
   where j.revision_id=rid and a.source_integrity_receipt_sha256=p_source_integrity_receipt_sha256)
  then raise exception 'admitted_source_integrity_receipt_required' using errcode='PT422';end if;
  if private.rad_article_state(rid) not in('draft','review','rejected') then
   raise exception 'source_revision_not_reviewable' using errcode='PT409';end if;
 end loop;
 insert into private.rad_source_editorial_batches values(p_batch_id,p_manifest_sha256,p_manifest_text,p_source_integrity_receipt_sha256,actor,p_note,now());
 for entry in select value from jsonb_array_elements(entries) order by value->>'revision_id' loop
  insert into public.visa_article_revision_events(revision_id,state,actor_id,note,publication_basis,source_batch_id)
  values((entry->>'revision_id')::uuid,'approved',actor,p_note,'source_faithful',p_batch_id);
 end loop;
 n:=jsonb_array_length(entries);
 return private.rad_envelope(jsonb_build_object('batch_id',p_batch_id,'manifest_sha256',p_manifest_sha256,
  'approved_count',n,'approved_by',actor,'approved_at',now(),'publication_basis','source_faithful','factual_verification_changed',false));
end $$;

create function public.publish_source_editorial_batch(p_batch_id uuid,p_manifest_sha256 text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();batch private.rad_source_editorial_batches;entry jsonb;r public.visa_article_revisions;
 event public.visa_article_revision_events;receipts jsonb:='[]';begin
 select * into batch from private.rad_source_editorial_batches where id=p_batch_id;
 if batch.id is null then raise exception 'source_batch_not_found' using errcode='PT404';end if;
 if batch.approved_by<>actor or p_manifest_sha256 is distinct from batch.manifest_sha256 then
  raise exception 'source_batch_actor_or_hash_conflict' using errcode='PT409';end if;
 perform pg_advisory_xact_lock(hashtextextended('source-batch:'||p_batch_id::text,0));
 perform 1 from public.visa_article_heads h join public.visa_article_revisions v on v.article_id=h.article_id and v.locale=h.locale
 where v.id in(select (value->>'revision_id')::uuid from jsonb_array_elements(batch.manifest_text::jsonb)) order by h.article_id,h.locale for update of h;
 perform 1 from private.rad_editorial_catalog c where c.article_id in(select v.article_id from public.visa_article_revisions v
 where v.id in(select (value->>'revision_id')::uuid from jsonb_array_elements(batch.manifest_text::jsonb))) order by c.article_id for update;
 for entry in select value from jsonb_array_elements(batch.manifest_text::jsonb) order by value->>'revision_id' loop
  select * into r from public.visa_article_revisions where id=private.rad_source_editorial_entry(entry);
  select * into event from public.visa_article_revision_events where revision_id=r.id and state='published';
  if event.id is not null then
   if event.publication_basis<>'source_faithful' or event.source_batch_id<>batch.id
   or not exists(select 1 from public.visa_article_heads where article_id=r.article_id and locale=r.locale and published_id=r.id)
   then raise exception 'source_publication_retry_conflict' using errcode='PT409';end if;
  else
   if private.rad_article_state(r.id)<>'approved' then raise exception 'source_approval_state_changed' using errcode='PT409';end if;
   insert into public.visa_article_revision_events(revision_id,state,actor_id,note,publication_basis,source_batch_id)
   values(r.id,'published',actor,batch.note,'source_faithful',batch.id) returning * into event;
   update public.visa_article_heads set published_id=r.id where article_id=r.article_id and locale=r.locale;
  end if;
  receipts:=receipts||jsonb_build_array(jsonb_build_object('article_id',r.article_id,'locale',r.locale,'revision_id',r.id,
   'content_hash',r.content_hash,'event_id',event.id,'actor_id',event.actor_id,'published_at',event.created_at,'publication_basis','source_faithful'));
 end loop;
 -- Catalog activity is shared across locales. Change it after all members pass.
 update private.rad_editorial_catalog c set active=true where not active and c.article_id in(
  select v.article_id from public.visa_article_revisions v where v.id in(
   select (value->>'revision_id')::uuid from jsonb_array_elements(batch.manifest_text::jsonb)));
 return private.rad_envelope(jsonb_build_object('batch_id',batch.id,'manifest_sha256',batch.manifest_sha256,'receipts',receipts,
  'published_count',jsonb_array_length(receipts),'factual_verification_changed',false,'feed_publications',0));
end $$;
revoke all on function public.approve_source_editorial_batch(uuid,text,text,text,text),public.publish_source_editorial_batch(uuid,text)
 from public,anon,authenticated,service_role;
grant execute on function public.approve_source_editorial_batch(uuid,text,text,text,text),public.publish_source_editorial_batch(uuid,text) to authenticated;

create or replace function private.rad_editorial_card(article uuid,loc text,preview boolean default false) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('id',a.id,'locale',r.locale,'title',r.title,'summary',r.summary,
 'visa_category',c.composition->'visa_category','category',coalesce(c.category,'general-guide'),'content_class',coalesce(c.content_class,'editorial'),
 'country_codes',coalesce(to_jsonb(c.country_codes),case when a.country_code is null then '[]'::jsonb else jsonb_build_array(a.country_code) end),
 'revision_id',r.id,'revision',r.revision,'editorial_state',private.rad_article_state(r.id),
 'verification_state',private.rad_article_verification(r.id),'source_publishers',coalesce(to_jsonb(c.source_publishers),'[]'::jsonb),
 'publication_basis',coalesce((select e.publication_basis from public.visa_article_revision_events e where e.revision_id=r.id and e.state='published'),'standard_editorial'))
 from public.visa_articles a join public.visa_article_heads h on h.article_id=a.id and h.locale=loc
 join public.visa_article_revisions r on r.id=case when preview then h.head_id else h.published_id end
 left join private.rad_editorial_catalog c on c.article_id=a.id
 where a.id=article and coalesce(c.active,true);
$$;
revoke all on function private.rad_editorial_card(uuid,text,boolean) from public,anon,authenticated,service_role;

-- Country-neutral and detached articles can have no legacy program metadata.
-- Their published full text must still enter the existing search projection.
create or replace function private.rad_index_article() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;metadata text;begin
 if tg_op='INSERT' then
  if new.published_id is null then return new;end if;
 elsif new.published_id is not distinct from old.published_id then return new;
 end if;
 delete from public.visa_article_search_documents where article_id=new.article_id and locale=new.locale;
 select * into r from public.visa_article_revisions where id=new.published_id;
 if found then
  metadata:=coalesce(private.rad_search_metadata(r.article_id,r.locale),'');
  insert into public.visa_article_search_documents
  select r.article_id,r.id,s.id,r.locale,r.title,s.heading,s.anchor,private.rad_blocks_text(s.blocks),
   private.rad_search_normalize(r.title||' '||s.heading||' '||private.rad_blocks_text(s.blocks)||' '||metadata),
   setweight(to_tsvector('simple',private.rad_search_normalize(r.title)),'A')||setweight(to_tsvector('simple',private.rad_search_normalize(metadata)),'B')||
   setweight(to_tsvector('simple',private.rad_search_normalize(s.heading)),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_blocks_text(s.blocks))),'C')
  from public.visa_article_sections s where s.revision_id=r.id;
 end if;
 update private.rad_search_version set version=version+1 where id=true;
 return new;
end $$;
revoke all on function private.rad_index_article() from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;
