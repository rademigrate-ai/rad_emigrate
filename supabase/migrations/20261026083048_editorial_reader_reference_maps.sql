-- Append-only, revision-bound source-reference metadata. No source body,
-- published pointer, legal approval, or historical migration is rewritten.
begin;
create table if not exists private.rad_editorial_reference_maps(
 revision_id uuid not null references public.visa_article_revisions(id),
 input_hash text not null,source_manifest_hash text not null check(source_manifest_hash~'^[a-f0-9]{64}$'),
 content jsonb not null,active boolean not null default true,created_at timestamptz not null default now(),
 primary key(revision_id,input_hash)
);
create unique index if not exists rad_editorial_reference_map_active on private.rad_editorial_reference_maps(revision_id) where active;
alter table private.rad_editorial_reference_maps enable row level security;
revoke all on private.rad_editorial_reference_maps from public,anon,authenticated,service_role;

create or replace function public.attach_editorial_reference_map(p_article_id uuid,p_locale text,p_expected_revision integer,p_manifest_hash text,p_map jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;prior private.rad_editorial_reference_maps;hash text;s jsonb;link jsonb;begin
 perform private.rad_editorial_require_import();
 perform pg_advisory_xact_lock(hashtextextended('rad-editorial:'||p_article_id::text,0));
 select v.* into r from public.visa_article_heads h join public.visa_article_revisions v on v.id=h.head_id
 where h.article_id=p_article_id and h.locale=p_locale for update of h;
 if r.id is null then raise exception 'not_found' using errcode='PT404';end if;
 hash:=encode(extensions.digest(jsonb_build_array(p_manifest_hash,p_map)::text,'sha256'),'hex');
 select * into prior from private.rad_editorial_reference_maps where revision_id=r.id and active;
 if found and prior.input_hash=hash then
  return private.rad_envelope(jsonb_build_object('revision_id',r.id,'input_hash',hash));
 end if;
 if p_expected_revision is null or r.revision<>p_expected_revision or private.rad_article_state(r.id)<>'draft'
 or exists(select 1 from private.rad_editorial_clearances where revision_id=r.id)
 or exists(select 1 from public.visa_article_heads where published_id=r.id) then
 raise exception 'draft_revision_reconciliation_required' using errcode='PT409';end if;
 if p_manifest_hash is null or p_manifest_hash!~'^[a-f0-9]{64}$' or p_map->>'capture_status' is distinct from 'complete'
 or jsonb_typeof(p_map->'sources') is distinct from 'array' or jsonb_typeof(p_map->'links') is distinct from 'array'
 or jsonb_array_length(p_map->'links')>10000 then raise exception 'invalid_reference_capture' using errcode='PT422';end if;
 for s in select value from jsonb_array_elements(p_map->'sources') loop
  if not exists(select 1 from public.source_snapshots snap where snap.id=(s->>'snapshot_id')::uuid
   and snap.content_hash=s->>'body_sha256' and snap.metadata->>'raw_html_sha256'=s->>'raw_html_sha256'
   and exists(select 1 from private.rad_editorial_rich_revisions rich
   cross join lateral jsonb_array_elements(rich.composition->'sections')sec
   cross join lateral jsonb_array_elements(sec->'blocks')b
   cross join lateral jsonb_array_elements(b->'provenance')ref
   where rich.revision_id=r.id and ref->>'snapshot_id'=s->>'snapshot_id')) then
   raise exception 'reference_source_not_bound_to_revision' using errcode='PT422';end if;
 end loop;
 if exists(select 1 from private.rad_editorial_rich_revisions rich
 cross join lateral jsonb_array_elements(rich.composition->'sections')sec
 cross join lateral jsonb_array_elements(sec->'blocks')b
 cross join lateral jsonb_array_elements(b->'provenance')ref
 where rich.revision_id=r.id and not exists(select 1 from jsonb_array_elements(p_map->'sources')src
 where src->>'snapshot_id'=ref->>'snapshot_id')) then
 raise exception 'incomplete_reference_source_inventory' using errcode='PT422';end if;
 for link in select value from jsonb_array_elements(p_map->'links') loop
  if jsonb_typeof(link->'label') is distinct from 'string' or link->>'url' is null or link->>'url'!~'^https?://[^[:space:]<>]+$' or link->>'url'~'^https?://[^/]*@'
   or not exists(select 1 from jsonb_array_elements(p_map->'sources')source_entry where source_entry->>'snapshot_id'=link->>'source_snapshot_id') then
   raise exception 'unsafe_or_unbound_reference' using errcode='PT422';end if;
  if link->>'target_block_id' is not null and not exists(select 1 from private.rad_editorial_rich_revisions rich
   cross join lateral jsonb_array_elements(rich.composition->'sections')sec
   cross join lateral jsonb_array_elements(sec->'blocks')b
   where rich.revision_id=r.id and b->>'id'=link->>'target_block_id') then
   raise exception 'invalid_reference_block_target' using errcode='PT422';end if;
 end loop;
 update private.rad_editorial_reference_maps set active=false where revision_id=r.id and active;
 insert into private.rad_editorial_reference_maps(revision_id,input_hash,source_manifest_hash,content)
 values(r.id,hash,p_manifest_hash,p_map) on conflict(revision_id,input_hash) do update set active=true;
 return private.rad_envelope(jsonb_build_object('revision_id',r.id,'input_hash',hash));
end $$;

create or replace function public.get_editorial_reference_links(p_article_id uuid,p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare card jsonb;capture private.rad_editorial_reference_maps;begin
 if p_locale is null or p_locale not in('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 card:=private.rad_editorial_card(p_article_id,p_locale,p_preview);
 if card is null then raise exception 'not_found' using errcode='PT404';end if;
 select * into capture from private.rad_editorial_reference_maps where revision_id=(card->>'revision_id')::uuid and active;
 return private.rad_envelope(jsonb_build_object('revision_id',card->'revision_id','links',coalesce(capture.content->'links','[]'),
 'capture_status',case when capture.revision_id is null then 'not_captured' else capture.content->>'capture_status' end,
 'verification_state','not_inferred_from_links'),p_locale);
end $$;

create or replace function private.rad_editorial_carry_reference_map() returns trigger
language plpgsql set search_path='' as $$begin
 if exists(select 1 from private.rad_editorial_rich_revisions where revision_id=new.id) then
 insert into private.rad_editorial_reference_maps(revision_id,input_hash,source_manifest_hash,content)
 select new.id,c.input_hash,c.source_manifest_hash,c.content from public.visa_article_heads h
 join private.rad_editorial_reference_maps c on c.revision_id=h.head_id
 where h.article_id=new.article_id and h.locale=new.locale and c.active on conflict do nothing;
 end if;
 return new;
end $$;
drop trigger if exists rad_editorial_reference_map_copy on public.visa_article_revisions;
create trigger rad_editorial_reference_map_copy after insert on public.visa_article_revisions
 for each row execute function private.rad_editorial_carry_reference_map();

revoke all on function public.attach_editorial_reference_map(uuid,text,integer,text,jsonb),
 public.get_editorial_reference_links(uuid,text,boolean),private.rad_editorial_carry_reference_map()
 from public,anon,authenticated,service_role;
grant execute on function public.attach_editorial_reference_map(uuid,text,integer,text,jsonb) to service_role;
grant execute on function public.get_editorial_reference_links(uuid,text,boolean) to anon,authenticated;
create or replace function public.clear_editorial_revision(p_revision_id uuid,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();r public.visa_article_revisions;begin
 select v.* into r from public.visa_article_revisions v join public.visa_article_heads h
 on h.head_id=v.id join private.rad_editorial_catalog c on c.article_id=v.article_id where v.id=p_revision_id and c.active;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 if length(btrim(coalesce(p_note,'')))<20 or private.rad_article_verification(r.id)<>'verified'
 or not exists(select 1 from private.rad_editorial_reference_maps where revision_id=r.id and active and content->>'capture_status'='complete') then
 raise exception 'official_verification_and_documented_human_resolution_required' using errcode='PT422';end if;
 insert into private.rad_editorial_clearances(revision_id,content_hash,reviewed_by,note)
 values(r.id,r.content_hash,actor,p_note) on conflict(revision_id) do nothing;
 return private.rad_envelope(jsonb_build_object('revision_id',r.id,'cleared',true,'approved',false,'published',false));
end $$;
create or replace function private.rad_editorial_approval_guard() returns trigger
language plpgsql set search_path='' as $$begin
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
revoke all on function public.clear_editorial_revision(uuid,text),private.rad_editorial_approval_guard() from public,anon,authenticated,service_role;
grant execute on function public.clear_editorial_revision(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
