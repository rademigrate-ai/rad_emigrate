-- Additive editorial metadata around existing Visa revisions and human workflow.
-- No import target is enabled here. A separate authorized staging setup must
-- insert its exact project marker. Real content is never approved/published here.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
alter table public.visa_articles alter column country_code drop not null;

create table if not exists private.rad_editorial_import_target(
 project_ref text primary key check(project_ref='epolbumcfbohtmgvomki'),
 enabled boolean not null default false
);
create table if not exists private.rad_editorial_catalog(
 article_id uuid primary key references public.visa_articles(id),
 content_class text not null check(content_class in('canonical','editorial')),
 category text not null check(category in('university','living-costs','qualifications','education','culture-living','migration','general-guide')),
 country_codes text[] not null default '{}',
 source_publishers text[] not null,
 source_snapshot_ids uuid[] not null,
 composition jsonb not null,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create index if not exists rad_editorial_country_idx on private.rad_editorial_catalog using gin(country_codes);
create table if not exists private.rad_editorial_import_batches(
 id uuid primary key,manifest_hash text not null check(manifest_hash~'^[a-f0-9]{64}$'),
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default now(),
 rolled_back_at timestamptz
);
create table if not exists private.rad_editorial_import_journal(
 article_id uuid not null references public.visa_articles(id),locale text not null check(locale in('fa','en')),
 batch_id uuid not null references private.rad_editorial_import_batches(id),
 input_hash text not null,revision_id uuid not null references public.visa_article_revisions(id),
 receipt jsonb not null,rolled_back_at timestamptz,primary key(article_id,locale)
);
create table if not exists private.rad_editorial_relations(
 parent_id uuid not null references public.visa_articles(id),related_id uuid not null references public.visa_articles(id),
 justification jsonb not null,rank integer not null check(rank>=0),
 state text not null default 'proposed' check(state in('proposed','approved','rejected')),
 revision integer not null default 1,reviewed_by uuid references auth.users(id),reviewed_at timestamptz,
 primary key(parent_id,related_id),check(parent_id<>related_id)
);
create table if not exists private.rad_editorial_review_receipts(
 actor_id uuid not null references auth.users(id),request_key uuid not null,
 input_hash text not null,receipt jsonb not null,primary key(actor_id,request_key)
);
create table if not exists private.rad_editorial_rich_revisions(
 revision_id uuid primary key references public.visa_article_revisions(id),composition jsonb not null
);
create table if not exists private.rad_editorial_clearances(
 revision_id uuid primary key references public.visa_article_revisions(id),
 content_hash text not null,reviewed_by uuid not null references auth.users(id),
 note text not null check(length(btrim(note))>=20),created_at timestamptz not null default now()
);
create table if not exists private.rad_editorial_country_titles(
 country_code text not null check(country_code~'^[A-Z]{2}$'),
 article_id uuid not null references public.visa_articles(id),
 state text not null default 'proposed' check(state in('proposed','approved','rejected')),
 rank integer not null default 0 check(rank>=0),revision integer not null default 1,
 reviewed_by uuid references auth.users(id),reviewed_at timestamptz,
 primary key(country_code,article_id)
);
create unique index if not exists rad_editorial_country_category_unique
 on private.rad_editorial_catalog((country_codes[1]),(composition->>'visa_category'))
 where content_class='canonical' and active;

do $$declare n text;begin
 foreach n in array array['rad_editorial_import_target','rad_editorial_catalog','rad_editorial_import_batches',
 'rad_editorial_import_journal','rad_editorial_relations','rad_editorial_review_receipts','rad_editorial_rich_revisions','rad_editorial_clearances','rad_editorial_country_titles'] loop
  execute format('alter table private.%I enable row level security',n);
  execute format('revoke all on private.%I from public,anon,authenticated,service_role',n);
 end loop;
end $$;

create or replace function private.rad_editorial_require_import() returns void
language plpgsql stable set search_path='' as $$begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' or not exists(
 select 1 from private.rad_editorial_import_target where project_ref='epolbumcfbohtmgvomki' and enabled) then
 raise exception 'staging_import_disabled_or_forbidden' using errcode='PT403';end if;
end $$;

-- Sources and draft are committed together. A failure creates neither half.
create or replace function public.import_editorial_draft(p_batch_id uuid,p_manifest_hash text,p_actor_id uuid,p_item jsonb,p_sources jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid:=(p_item->>'article_id')::uuid;loc text:=p_item->>'locale';hash text;
 prior private.rad_editorial_import_journal;s jsonb;doc uuid;snap uuid;cs uuid;
 supplied uuid[]:='{}';publishers text[]:='{}';country text;body jsonb;rev uuid;receipt jsonb;
begin
 perform private.rad_editorial_require_import();
 if p_batch_id is null or p_manifest_hash is null or p_manifest_hash!~'^[a-f0-9]{64}$'
 or not exists(select 1 from public.profiles where id=p_actor_id and role in('admin','super_admin')) then
 raise exception 'invalid_import_identity' using errcode='PT422';end if;
 if jsonb_typeof(p_item) is distinct from 'object' or jsonb_typeof(p_sources) is distinct from 'array'
 or jsonb_array_length(p_sources)<1 or jsonb_array_length(p_sources)>500 or loc not in('fa','en')
 or p_item->>'editorial_state' is distinct from 'draft' or p_item->>'verification_state' is distinct from 'unverified'
 or p_item->'publication_allowed' is distinct from 'false'::jsonb or p_item->'published' is distinct from 'false'::jsonb
 or p_item->>'reviewer_id' is not null or p_item->>'category' not in('university','living-costs','qualifications','education','culture-living','migration','general-guide')
 or p_item->>'content_class' not in('canonical','editorial') then
 raise exception 'invalid_draft_only_import' using errcode='PT422';end if;
 if p_item->>'content_class'='canonical' and (jsonb_array_length(p_item->'country_codes')<>1
 or p_item->>'visa_category' is null or p_item->>'visa_category' not in('study','work','investment','tourist','family')) then
 raise exception 'explicit_single_country_category_required' using errcode='PT422';end if;
 hash:=encode(extensions.digest(jsonb_build_array(p_item,p_sources)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('rad-editorial:'||a::text,0));
 insert into private.rad_editorial_import_batches(id,manifest_hash,actor_id)
 values(p_batch_id,p_manifest_hash,p_actor_id) on conflict do nothing;
 if not exists(select 1 from private.rad_editorial_import_batches where id=p_batch_id and manifest_hash=p_manifest_hash
 and actor_id=p_actor_id and rolled_back_at is null) then raise exception 'batch_conflict' using errcode='PT409';end if;
 select * into prior from private.rad_editorial_import_journal where article_id=a and locale=loc;
 if found then
  if prior.input_hash<>hash then raise exception 'import_input_conflict' using errcode='PT409';end if;
  if prior.rolled_back_at is not null then raise exception 'import_was_rolled_back' using errcode='PT409';end if;
  -- Never restore an old imported head over human edits or a publication.
  return prior.receipt;
 end if;
 if exists(select 1 from public.visa_articles where id=a) and not exists(select 1 from private.rad_editorial_catalog c where c.article_id=a and c.content_class=p_item->>'content_class' and c.country_codes=array(select jsonb_array_elements_text(p_item->'country_codes')) and c.composition->>'visa_category' is not distinct from p_item->>'visa_category' and exists(select 1 from private.rad_editorial_import_journal j where j.article_id=a and j.locale<>loc and j.rolled_back_at is null)) then
 raise exception 'existing_article_requires_manual_reconciliation' using errcode='PT409';end if;
 for s in select value from jsonb_array_elements(p_sources) loop
  if s->>'url'!~'^https://(radvisa[.]com|digivisa[.]ir|radmohajer[.]ir)/'
  or s->>'body_sha256' is distinct from encode(extensions.digest(s->>'body_text','sha256'),'hex')
  or s->>'language' is distinct from loc or s->>'retrieved_at' is null
  or (s->>'retrieved_at')::timestamptz>now()+interval '5 minutes' then
   raise exception 'source_hash_url_language_or_date' using errcode='PT422';end if;
  -- Descriptive RAD origin is never government legal verification.
  cs:=(s->>'content_source_id')::uuid;
  insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash)
  select cs,'RAD first-party editorial source, not legal verification','rad_official',s->>'title',s->>'url',loc,
  (s->>'retrieved_at')::timestamptz,s->>'body_sha256'
  where not exists(select 1 from public.content_sources where url=s->>'url');
  select id into cs from public.content_sources where url=s->>'url' order by created_at,id limit 1;
  doc:=(s->>'source_id')::uuid;
  if exists(select 1 from public.source_documents where canonical_url=s->>'url' and id<>doc)
  or exists(select 1 from public.source_documents where id=doc and canonical_url<>s->>'url') then
   raise exception 'source_identity_conflict' using errcode='PT409';end if;
  insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash)
  values(doc,s->>'url',cs,'rad_official',s->>'title',loc,'',s->>'body_sha256') on conflict(id) do nothing;
  snap:=(s->>'snapshot_id')::uuid;
  if exists(select 1 from public.source_snapshots where (id=snap and (document_id<>doc or content_hash<>s->>'body_sha256'))
   or (document_id=doc and content_hash=s->>'body_sha256' and id<>snap)) then
   raise exception 'snapshot_identity_conflict' using errcode='PT409';end if;
  insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata)
  values(snap,doc,s->>'body_sha256',s->>'body_text',200,(s->>'retrieved_at')::timestamptz,
   jsonb_build_object('import_batch',p_batch_id,'raw_html_sha256',s->'raw_html_sha256','parser_version','h1-owned-body-v2','factual_verification','not_verified'))
  on conflict(id) do nothing;
  perform private.rad_classify_snapshot(snap);
  supplied:=array_append(supplied,snap);
  select array_append(publishers,publisher) into publishers from private.visa_source_origins where snapshot_id=snap;
 end loop;
 if p_item->>'content_class'='canonical' and (cardinality(publishers)=0 or exists(select 1 from unnest(publishers)x where x not in('radvisa','digivisa'))) then
  raise exception 'canonical_requires_primary_publishers_only' using errcode='PT422';end if;
 if 'radmohajer'=any(publishers) and exists(select 1 from unnest(publishers)x where x<>'radmohajer') then
  raise exception 'supplementary_body_must_remain_standalone' using errcode='PT422';end if;
 country:=case when jsonb_array_length(p_item->'country_codes')=1 then p_item->'country_codes'->>0 else null end;
 if exists(select 1 from jsonb_array_elements_text(p_item->'country_codes')x where x!~'^[A-Z]{2}$') then
  raise exception 'invalid_country_tag' using errcode='PT422';end if;
 insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
 values(a,case when p_item->>'content_class'='canonical' then 'main' else 'related' end,country,
 case when p_item->>'content_class'='canonical' then p_item->>'visa_category' else 'topic-'||replace(a::text,'-','') end,'editorial-'||a::text,p_actor_id) on conflict(id) do nothing;
 body:=p_item->'draft_request';
 if body->>'article_id' is distinct from a::text or body->>'locale' is distinct from loc
 or body->>'expected_revision' is distinct from '0' or body->>'merge_manifest_id' is not null
 or jsonb_array_length(body->'related_article_ids')<>0 then raise exception 'initial_draft_only' using errcode='PT422';end if;
 perform private.rad_assert_request('save_visa_article_draft',body);
 if exists(select 1 from jsonb_array_elements(body->'sections')sec
  cross join lateral jsonb_array_elements(sec->'evidence_refs')e
  where e->>'claim_id' is not null or not (e->>'snapshot_id')::uuid=any(supplied)) then
  raise exception 'import_cannot_invent_official_claim_or_source' using errcode='PT422';end if;
 -- The original invoker save helper stamps created_by using auth.uid(). Only
 -- service-only import can enter here; transaction-local identity is restored.
 declare original_claims text:=current_setting('request.jwt.claims',true);begin
  perform set_config('request.jwt.claims',jsonb_build_object('role','service_role','sub',p_actor_id)::text,true);
  rev:=private.rad_save_article(body);
  perform set_config('request.jwt.claims',coalesce(original_claims,''),true);
 end;
 receipt:=private.rad_envelope(private.rad_revision_result(rev),loc);
 insert into private.rad_editorial_catalog(article_id,content_class,category,country_codes,source_publishers,source_snapshot_ids,composition)
 values(a,p_item->>'content_class',p_item->>'category',array(select jsonb_array_elements_text(p_item->'country_codes')),
  array(select distinct unnest(publishers)),supplied,p_item-'draft_request') on conflict(article_id) do nothing;
 insert into private.rad_editorial_rich_revisions(revision_id,composition) values(rev,p_item-'draft_request');
 if p_item->>'content_class'='editorial' then
 insert into private.rad_editorial_country_titles(country_code,article_id)
 select x,a from jsonb_array_elements_text(p_item->'country_codes')x on conflict do nothing;
 end if;
 insert into private.rad_editorial_import_journal(article_id,locale,batch_id,input_hash,revision_id,receipt)
 values(a,loc,p_batch_id,hash,rev,receipt);
 return receipt;
end $$;

create or replace function public.rollback_editorial_import(p_batch_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.rad_editorial_import_journal;removed integer:=0;preserved integer:=0;begin
 perform private.rad_editorial_require_import();
 for j in select * from private.rad_editorial_import_journal where batch_id=p_batch_id for update loop
  perform pg_advisory_xact_lock(hashtextextended('rad-editorial:'||j.article_id::text||':'||j.locale,0));
  if j.rolled_back_at is not null then continue;end if;
  perform 1 from public.visa_article_heads where article_id=j.article_id and locale=j.locale for update;
  if exists(select 1 from public.visa_article_heads where article_id=j.article_id and locale=j.locale
   and head_id=j.revision_id and published_id is null) and private.rad_article_state(j.revision_id)='draft' then
   update public.visa_article_heads set head_id=null where article_id=j.article_id and locale=j.locale;
   update private.rad_editorial_catalog set active=false where article_id=j.article_id;
   update private.rad_editorial_import_journal set rolled_back_at=now() where article_id=j.article_id and locale=j.locale;
   removed:=removed+1;
  else preserved:=preserved+1;end if;
 end loop;
 update private.rad_editorial_import_batches set rolled_back_at=now() where id=p_batch_id;
 return jsonb_build_object('detached_unmodified_drafts',removed,'preserved_edited_or_approved_or_published',preserved,
 'deleted_sources_or_revisions',0);
end $$;

create or replace function public.propose_editorial_relations(p_relations jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare r jsonb;n integer:=0;begin
 perform private.rad_editorial_require_import();
 if jsonb_typeof(p_relations) is distinct from 'array' or jsonb_array_length(p_relations)>1000 then
 raise exception 'invalid_relations' using errcode='PT422';end if;
 for r in select value from jsonb_array_elements(p_relations) loop
  if r->>'state' is distinct from 'proposed' or r->>'reviewer_id' is not null
   or not exists(select 1 from private.rad_editorial_catalog p join private.rad_editorial_catalog c
   on p.country_codes && c.country_codes where p.article_id=(r->>'parent_id')::uuid and p.content_class='canonical'
   and c.article_id=(r->>'related_id')::uuid and c.content_class='editorial' and p.active and c.active) then
   raise exception 'human_relation_review_required' using errcode='PT422';end if;
  if exists(select 1 from private.rad_editorial_relations where parent_id=(r->>'parent_id')::uuid
   and related_id=(r->>'related_id')::uuid and justification<>r) then raise exception 'relation_input_conflict' using errcode='PT409';end if;
  insert into private.rad_editorial_relations(parent_id,related_id,justification,rank)
  values((r->>'parent_id')::uuid,(r->>'related_id')::uuid,r,(r->>'rank')::integer) on conflict do nothing;
  n:=n+1;
 end loop;return n;
end $$;

create or replace function public.review_editorial_relation(p_parent_id uuid,p_related_id uuid,p_expected_revision integer,
 p_decision text,p_rank integer,p_request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();hash text;prior private.rad_editorial_review_receipts;r private.rad_editorial_relations;result jsonb;begin
 if p_request_key is null or p_decision is null or p_decision not in('approved','rejected') or p_rank is null or p_rank<0 or p_rank>10000 then
 raise exception 'invalid_relation_review' using errcode='PT422';end if;
 hash:=encode(extensions.digest(jsonb_build_array(p_parent_id,p_related_id,p_expected_revision,p_decision,p_rank)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':editorial-relation:'||p_request_key::text,0));
 select * into prior from private.rad_editorial_review_receipts where actor_id=actor and request_key=p_request_key;
 if found then if prior.input_hash<>hash then raise exception 'idempotency_conflict' using errcode='PT409';end if;return prior.receipt;end if;
 select * into r from private.rad_editorial_relations where parent_id=p_parent_id and related_id=p_related_id for update;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 if p_expected_revision is null or r.revision<>p_expected_revision then raise exception 'revision_conflict' using errcode='PT409';end if;
 update private.rad_editorial_relations set state=p_decision,rank=p_rank,revision=revision+1,reviewed_by=actor,reviewed_at=now()
 where parent_id=p_parent_id and related_id=p_related_id returning * into r;
 result:=private.rad_envelope(to_jsonb(r));
 insert into private.rad_editorial_review_receipts values(actor,p_request_key,hash,result);
 return result;
end $$;

create or replace function private.rad_editorial_card(article uuid,loc text,preview boolean default false) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('id',a.id,'locale',r.locale,'title',r.title,'summary',r.summary,
 'visa_category',c.composition->'visa_category','category',coalesce(c.category,'general-guide'),'content_class',coalesce(c.content_class,'editorial'),
 'country_codes',coalesce(to_jsonb(c.country_codes),case when a.country_code is null then '[]'::jsonb else jsonb_build_array(a.country_code) end),
 'revision_id',r.id,'revision',r.revision,'editorial_state',private.rad_article_state(r.id),
 'verification_state',private.rad_article_verification(r.id),'source_publishers',coalesce(to_jsonb(c.source_publishers),'[]'::jsonb))
 from public.visa_articles a join public.visa_article_heads h on h.article_id=a.id and h.locale=loc
 join public.visa_article_revisions r on r.id=case when preview then h.head_id else h.published_id end
 left join private.rad_editorial_catalog c on c.article_id=a.id
 where a.id=article and coalesce(c.active,true);
$$;

create or replace function public.list_editorial_relations(p_article_id uuid,p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare items jsonb;begin
 if p_locale not in('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 if private.rad_editorial_card(p_article_id,p_locale,p_preview) is null then raise exception 'not_found' using errcode='PT404';end if;
 select coalesce(jsonb_agg(card||jsonb_build_object('relation_state',r.state,'rank',r.rank,'relation_revision',r.revision) order by r.rank,r.related_id),'[]') into items
 from private.rad_editorial_relations r
 cross join lateral(select private.rad_editorial_card(r.related_id,p_locale,p_preview) card)x
 where r.parent_id=p_article_id and (p_preview or r.state='approved') and card is not null;
 return private.rad_envelope(jsonb_build_object('items',items),p_locale);
end $$;

create or replace function public.get_editorial_article(p_article_id uuid,p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare card jsonb;sections jsonb;sources jsonb;rid uuid;available jsonb;begin
 if p_locale not in('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 card:=private.rad_editorial_card(p_article_id,p_locale,p_preview);
 if card is null then raise exception 'article_or_translation_not_found' using errcode='PT404';end if;
 rid:=(card->>'revision_id')::uuid;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'anchor',s.anchor,'heading',s.heading,'order',s.position,'blocks',s.blocks,
 'evidence',(select coalesce(jsonb_agg(private.rad_evidence(e,s.id)),'[]') from jsonb_array_elements(s.evidence_refs)e)) order by s.position),'[]') into sections
 from public.visa_article_sections s where s.revision_id=rid;
 select coalesce(jsonb_agg(source order by source->>'url'),'[]') into sources from(
 select distinct private.rad_evidence(e,s.id)-'section_id'-'excerpt'-'locator'-'claim_id' source
 from public.visa_article_sections s cross join lateral jsonb_array_elements(s.evidence_refs)e where s.revision_id=rid)x;
 select coalesce(jsonb_agg(locale order by locale),'[]') into available from public.visa_article_heads
 where article_id=p_article_id and case when p_preview then head_id else published_id end is not null;
 return private.rad_envelope(card||jsonb_build_object('sections',sections,'sources',sources,'available_locales',available,
 'translation_fallback_used',false,'preview',p_preview,
 'rich_sections',(select composition->'sections' from private.rad_editorial_rich_revisions where revision_id=rid),'other_titles',public.list_editorial_relations(p_article_id,p_locale,p_preview)->'data'->'items'),p_locale);
end $$;

create or replace function public.list_editorial_articles(p_locale text,p_category text default null,p_country_code text default null,
 p_query text default null,p_cursor text default null,p_limit integer default 20,p_content_class text default 'editorial') returns jsonb
language plpgsql security definer set search_path='' as $$
declare request jsonb;version text;off integer;items jsonb;total integer;begin
 if p_locale not in('fa','en') or p_limit not between 1 and 50 or length(coalesce(p_query,''))>200
 or (p_country_code is not null and p_country_code!~'^[A-Z]{2}$')
 or (p_content_class is not null and p_content_class not in('canonical','editorial')) then raise exception 'invalid_filters' using errcode='PT422';end if;
 request:=jsonb_build_object('locale',p_locale,'category',p_category,'country',p_country_code,'query',p_query,'cursor',p_cursor,'limit',p_limit,'class',p_content_class);
 select v.version::text into version from private.rad_search_version v where id=true;
 off:=coalesce((private.rad_page_position(request,version)->>'offset')::integer,0);
 with matches as(select c.article_id,private.rad_editorial_card(c.article_id,p_locale) card
 from private.rad_editorial_catalog c where c.active and (p_category is null or c.category=p_category)
 and (p_country_code is null or p_country_code=any(c.country_codes)) and (p_content_class is null or c.content_class=p_content_class)),
 filtered as(select * from matches m where card is not null and (nullif(btrim(p_query),'') is null
 or position(private.rad_search_normalize(p_query) in private.rad_search_normalize((card->>'title')||' '||(card->>'summary')))>0
 or exists(select 1 from public.visa_article_search_documents d where d.revision_id=(card->>'revision_id')::uuid
 and position(private.rad_search_normalize(p_query) in d.normalized)>0))),
 page as(select * from filtered order by card->>'title',article_id offset off limit p_limit)
 select (select count(*) from filtered),coalesce(jsonb_agg(card order by card->>'title',article_id),'[]') into total,items from page;
 return private.rad_envelope(jsonb_build_object('items',items),p_locale,
 private.rad_page(request,version,jsonb_build_object('offset',off+p_limit),total>off+p_limit));
end $$;

create or replace function public.list_editorial_review_queue(p_locale text,p_offset integer default 0,p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
declare items jsonb;begin
 perform private.rad_require_admin();
 if p_locale not in('fa','en') or p_offset<0 or p_limit not between 1 and 50 then raise exception 'invalid_page' using errcode='PT422';end if;
 select coalesce(jsonb_agg(card||jsonb_build_object('composition',composition,'composition_stale',composition is null)),'[]') into items from(
 select private.rad_editorial_card(c.article_id,p_locale,true) card,rr.composition
 from private.rad_editorial_catalog c join public.visa_article_heads h on h.article_id=c.article_id and h.locale=p_locale
 left join private.rad_editorial_rich_revisions rr on rr.revision_id=h.head_id
 where c.active and h.head_id is not null order by c.created_at,c.article_id offset p_offset limit p_limit)x;
 return private.rad_envelope(jsonb_build_object('items',items),p_locale);
end $$;

-- Keep rich structure on evidence-only editorial revisions. A change to any
-- projected body/heading/order invalidates the rich rendering, so stale source
-- text can never override a later human edit. Original evidence stays in history.
create or replace function private.rad_editorial_carry_rich_revision() returns trigger
language plpgsql set search_path='' as $$
declare previous public.visa_article_revisions;rich jsonb;old_sections jsonb;new_sections jsonb;begin
 select r.* into previous from public.visa_article_heads h
 join public.visa_article_revisions r on r.id=h.head_id
 join private.rad_editorial_rich_revisions rr on rr.revision_id=r.id
 where h.article_id=new.article_id and h.locale=new.locale;
 if previous.id is null then return new;end if;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=previous.id;
 select jsonb_agg(value-'evidence_refs' order by ordinality) into old_sections
 from jsonb_array_elements(previous.body->'sections') with ordinality;
 select jsonb_agg(value-'evidence_refs' order by ordinality) into new_sections
 from jsonb_array_elements(new.body->'sections') with ordinality;
 if old_sections=new_sections then
 insert into private.rad_editorial_rich_revisions values(new.id,rich) on conflict do nothing;
 end if;
 return new;
end $$;
drop trigger if exists rad_editorial_carry_rich_revision on public.visa_article_revisions;
create trigger rad_editorial_carry_rich_revision after insert on public.visa_article_revisions
 for each row execute function private.rad_editorial_carry_rich_revision();
revoke all on function private.rad_editorial_carry_rich_revision() from public,anon,authenticated,service_role;

-- Clearance never approves/publishes. Those remain separate existing Admin
-- operations. Any later draft/revision invalidates clearance by identity/hash.
create or replace function public.clear_editorial_revision(p_revision_id uuid,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();r public.visa_article_revisions;begin
 select v.* into r from public.visa_article_revisions v join public.visa_article_heads h
 on h.head_id=v.id join private.rad_editorial_catalog c on c.article_id=v.article_id where v.id=p_revision_id and c.active;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 if length(btrim(coalesce(p_note,'')))<20 or private.rad_article_verification(r.id)<>'verified' then
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
 return new;
end $$;
drop trigger if exists rad_editorial_approval_guard on public.visa_article_revision_events;
create trigger rad_editorial_approval_guard before insert on public.visa_article_revision_events
 for each row execute function private.rad_editorial_approval_guard();
revoke all on function private.rad_editorial_approval_guard(),public.clear_editorial_revision(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.clear_editorial_revision(uuid,text) to authenticated;

create or replace function public.review_country_other_title(p_country_code text,p_article_id uuid,p_expected_revision integer,
 p_decision text,p_rank integer,p_request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();hash text;prior private.rad_editorial_review_receipts;r private.rad_editorial_country_titles;result jsonb;begin
 if p_country_code is null or p_country_code!~'^[A-Z]{2}$' or p_request_key is null or p_decision is null
 or p_decision not in('approved','rejected') or p_rank is null or p_rank not between 0 and 10000 then
 raise exception 'invalid_country_relation_review' using errcode='PT422';end if;
 hash:=encode(extensions.digest(jsonb_build_array('country-other-title',p_country_code,p_article_id,p_expected_revision,p_decision,p_rank)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':editorial-relation:'||p_request_key::text,0));
 select * into prior from private.rad_editorial_review_receipts where actor_id=actor and request_key=p_request_key;
 if found then if prior.input_hash<>hash then raise exception 'idempotency_conflict' using errcode='PT409';end if;return prior.receipt;end if;
 select * into r from private.rad_editorial_country_titles where country_code=p_country_code and article_id=p_article_id for update;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 if p_expected_revision is null or r.revision<>p_expected_revision then raise exception 'revision_conflict' using errcode='PT409';end if;
 update private.rad_editorial_country_titles set state=p_decision,rank=p_rank,revision=revision+1,reviewed_by=actor,reviewed_at=now()
 where country_code=p_country_code and article_id=p_article_id returning * into r;
 result:=private.rad_envelope(to_jsonb(r));
 insert into private.rad_editorial_review_receipts values(actor,p_request_key,hash,result);
 return result;
end $$;

create or replace function public.list_country_visa_content(p_country_code text,p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare categories jsonb;other_titles jsonb;begin
 if p_country_code is null or p_country_code!~'^[A-Z]{2}$' or p_locale is null or p_locale not in('fa','en') then
 raise exception 'invalid_country_or_locale' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 select coalesce(jsonb_agg(card order by card->>'visa_category'),'[]') into categories
 from private.rad_editorial_catalog c cross join lateral(select private.rad_editorial_card(c.article_id,p_locale,p_preview)card)x
 where c.active and c.content_class='canonical' and c.country_codes=array[p_country_code] and card is not null;
 select coalesce(jsonb_agg(card order by r.rank,r.article_id),'[]') into other_titles
 from private.rad_editorial_country_titles r cross join lateral(select private.rad_editorial_card(r.article_id,p_locale,p_preview)card)x
 where r.country_code=p_country_code and (p_preview or r.state='approved') and card is not null;
 return private.rad_envelope(jsonb_build_object('country_code',p_country_code,'categories',categories,'other_titles',other_titles,'preview',p_preview),p_locale);
end $$;
revoke all on function public.review_country_other_title(text,uuid,integer,text,integer,uuid),
 public.list_country_visa_content(text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.review_country_other_title(text,uuid,integer,text,integer,uuid) to authenticated;
grant execute on function public.list_country_visa_content(text,text,boolean) to anon,authenticated;

-- NULL country associations are intentional for general/multicountry content.
-- Preserve legacy v1 schemas: typed Visa requests are unchanged and global
-- articles use the additive editorial detail endpoint. CMS lists use empty
-- display text rather than inventing a country.
do $$begin if to_regprocedure('private.rad_legacy_get_visa_article(jsonb)') is null then
 alter function public.get_visa_article(jsonb) set schema private;
 alter function private.get_visa_article(jsonb) rename to rad_legacy_get_visa_article;
end if;end $$;
revoke all on function private.rad_legacy_get_visa_article(jsonb) from public,anon,authenticated,service_role;
create or replace function public.get_visa_article(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$declare r jsonb;begin
 r:=private.rad_legacy_get_visa_article(p_request);
 if r->'data'->>'country_code' is null then raise exception 'editorial_route_required' using errcode='PT404';end if;
 return r;
end $$;
do $$begin if to_regprocedure('private.rad_legacy_list_cms_articles(jsonb)') is null then
 alter function public.list_cms_articles(jsonb) set schema private;
 alter function private.list_cms_articles(jsonb) rename to rad_legacy_list_cms_articles;
end if;end $$;
revoke all on function private.rad_legacy_list_cms_articles(jsonb) from public,anon,authenticated,service_role;
create or replace function public.list_cms_articles(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$declare r jsonb;items jsonb;begin
 r:=private.rad_legacy_list_cms_articles(p_request);
 select coalesce(jsonb_agg(jsonb_set(value,'{country_code}',to_jsonb(coalesce(value->>'country_code','')))),'[]') into items
 from jsonb_array_elements(r->'data'->'items');
 return jsonb_set(r,'{data,items}',items);
end $$;

revoke all on function private.rad_editorial_require_import(),private.rad_editorial_card(uuid,text,boolean)
 from public,anon,authenticated,service_role;
revoke all on function public.import_editorial_draft(uuid,text,uuid,jsonb,jsonb),public.rollback_editorial_import(uuid),
 public.propose_editorial_relations(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.import_editorial_draft(uuid,text,uuid,jsonb,jsonb),public.rollback_editorial_import(uuid),
 public.propose_editorial_relations(jsonb) to service_role;
revoke all on function public.get_editorial_article(uuid,text,boolean),public.list_editorial_relations(uuid,text,boolean),
 public.list_editorial_articles(text,text,text,text,text,integer,text),public.list_editorial_review_queue(text,integer,integer),
 public.review_editorial_relation(uuid,uuid,integer,text,integer,uuid),public.get_visa_article(jsonb),public.list_cms_articles(jsonb)
 from public,anon,authenticated,service_role;
grant execute on function public.get_editorial_article(uuid,text,boolean),public.list_editorial_relations(uuid,text,boolean),
 public.list_editorial_articles(text,text,text,text,text,integer,text),public.get_visa_article(jsonb) to anon,authenticated;
grant execute on function public.list_editorial_review_queue(text,integer,integer),
 public.review_editorial_relation(uuid,uuid,integer,text,integer,uuid),public.list_cms_articles(jsonb) to authenticated;
commit;
