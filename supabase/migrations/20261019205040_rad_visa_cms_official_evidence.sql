begin;
-- G-002's additive fields are also prerequisites here because its retained
-- scaffold timestamp sorts after this CLI-generated migration. Definitions agree.
alter table public.knowledge_claims add column if not exists factual_status text not null default 'unverified';
alter table public.source_documents add column if not exists validation_status text not null default 'candidate';

create table public.visa_articles(
 id uuid primary key, kind text not null check(kind in ('main','related')),
 country_code text not null check(country_code ~ '^[A-Z]{2}$'),
 pathway_slug text not null check(pathway_slug ~ '^[a-z0-9-]{1,100}$'),
 slug text not null check(slug ~ '^[a-z0-9-]{1,160}$'),
 legacy_knowledge_item_id uuid references public.knowledge_items(id),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(country_code,slug)
);
create unique index visa_articles_main_key on public.visa_articles(country_code,pathway_slug) where kind='main';
create index visa_articles_legacy_idx on public.visa_articles(legacy_knowledge_item_id);
create table public.visa_article_revisions(
 id uuid primary key default gen_random_uuid(),article_id uuid not null references public.visa_articles(id),
 locale text not null check(locale in ('fa','en')),revision integer not null check(revision>0),
 title text not null,summary text not null,content_hash text not null,
 body jsonb not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(article_id,locale,revision)
);
create table public.visa_article_heads(
 article_id uuid not null references public.visa_articles(id),locale text not null check(locale in ('fa','en')),
 head_id uuid references public.visa_article_revisions(id),published_id uuid references public.visa_article_revisions(id),
 primary key(article_id,locale)
);
create table public.visa_article_sections(
 revision_id uuid not null references public.visa_article_revisions(id),id uuid not null,
 anchor text not null,heading text not null,position integer not null,blocks jsonb not null,evidence_refs jsonb not null,
 primary key(revision_id,id),unique(revision_id,anchor),unique(revision_id,position)
);
create table public.visa_article_revision_events(
 id uuid primary key default gen_random_uuid(),sequence bigint generated always as identity unique,
 revision_id uuid not null references public.visa_article_revisions(id),
 state text not null check(state in ('draft','review','approved','rejected','published','archived')),
 actor_id uuid not null references auth.users(id),note text not null default '',created_at timestamptz not null default now()
);
create unique index visa_article_publish_once on public.visa_article_revision_events(revision_id) where state='published';
create index visa_article_events_revision_idx on public.visa_article_revision_events(revision_id,sequence desc);
create index visa_article_heads_published_idx on public.visa_article_heads(published_id);
create index visa_article_heads_head_idx on public.visa_article_heads(head_id);

-- Archived source ancestry is server classified, separate from factual trust.
create table private.visa_source_origins(
 snapshot_id uuid primary key references public.source_snapshots(id),
 publisher text not null check(publisher in ('radvisa','digivisa','radmohajer','official_primary','other')),
 parent_snapshot_ids uuid[] not null default '{}',classified_at timestamptz not null default now()
);
create table public.visa_merge_manifests(
 id uuid primary key default gen_random_uuid(),article_id uuid not null references public.visa_articles(id),
 source_snapshot_ids uuid[] not null,fragments jsonb not null,manifest_hash text not null,
 complete boolean not null default false,created_at timestamptz not null default now()
);

create table private.authority_entities(
 id uuid primary key default gen_random_uuid(),name text not null,authority_type text not null,
 country_code text,jurisdiction text not null,competence_topics text[] not null default '{}',
 state text not null default 'candidate' check(state in ('candidate','verifying','verified','rejected','expired','revoked')),
 revision integer not null default 1,verified_at timestamptz,expires_at timestamptz
);
create table private.authority_domains(
 id uuid primary key default gen_random_uuid(),authority_id uuid not null references private.authority_entities(id),
 host text not null check(host ~ '^[a-z0-9][a-z0-9.-]+$'),path_prefix text not null default '/',
 state text not null default 'candidate',revision integer not null default 1,
 proof_hash text,verified_at timestamptz,expires_at timestamptz,unique(authority_id,host,path_prefix)
);
create table private.authority_trust_roots(
 id uuid primary key default gen_random_uuid(),policy_version text not null,proof jsonb not null,
 approved_by uuid not null references auth.users(id),approved_at timestamptz not null,
 expires_at timestamptz not null,active boolean not null default false
);
create table private.authority_proofs(
 id uuid primary key default gen_random_uuid(),domain_id uuid not null references private.authority_domains(id),
 root_id uuid not null references private.authority_trust_roots(id),domain_revision integer not null,
 scope_topic text not null,jurisdiction text not null,profession text not null default '*',
 proof_hash text not null,ownership_snapshot_id uuid not null references public.source_snapshots(id),
 competence_snapshot_id uuid not null references public.source_snapshots(id),
 verified_at timestamptz not null,expires_at timestamptz not null,revoked_at timestamptz
);
create table private.claim_official_evidence(
 claim_id uuid not null references public.knowledge_claims(id),citation_id uuid not null references public.knowledge_citations(id),
 proof_id uuid not null references private.authority_proofs(id),topic text not null,jurisdiction text not null,
 profession text not null default '*',effective_from date not null,effective_until date,
 fresh_until timestamptz not null,conflicting boolean not null default false,
 verified_at timestamptz not null default now(),primary key(claim_id,citation_id)
);
create table private.rad_research_jobs(
 id uuid primary key default gen_random_uuid(),kind text not null,request jsonb not null,
 created_by uuid not null references auth.users(id),status text not null default 'queued',
 safe_error_code text,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.visa_research_proposals(
 id uuid primary key default gen_random_uuid(),article_id uuid not null references public.visa_articles(id),
 locale text not null,base_revision integer not null,revision integer not null default 1,
 authority_id uuid not null references private.authority_entities(id),
 old_snapshot_id uuid references public.source_snapshots(id),new_snapshot_id uuid not null references public.source_snapshots(id),
 changes jsonb not null,new_sections jsonb not null,state text not null default 'review',
 created_at timestamptz not null default now(),reviewed_at timestamptz,reviewed_by uuid references auth.users(id),
 unique(article_id,locale,base_revision,new_snapshot_id)
);

create function private.rad_immutable() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'immutable_history' using errcode='PT409'; end $$;
create trigger visa_revision_immutable before update or delete on public.visa_article_revisions for each row execute function private.rad_immutable();
create trigger visa_section_immutable before update or delete on public.visa_article_sections for each row execute function private.rad_immutable();
create trigger visa_event_immutable before update or delete on public.visa_article_revision_events for each row execute function private.rad_immutable();
create trigger visa_origins_immutable before update or delete on private.visa_source_origins for each row execute function private.rad_immutable();
create trigger visa_manifest_immutable before update or delete on public.visa_merge_manifests for each row execute function private.rad_immutable();
create trigger authority_proof_immutable before update or delete on private.authority_proofs for each row execute function private.rad_immutable();

create function private.rad_claim_eligible(claim uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from private.claim_official_evidence e
  join public.knowledge_claims k on k.id=e.claim_id
  join public.knowledge_citations c on c.id=e.citation_id and c.claim_id=k.id
  join public.source_snapshots s on s.id=c.snapshot_id
  join public.source_documents doc on doc.id=s.document_id
  join private.authority_proofs p on p.id=e.proof_id
  join private.authority_domains d on d.id=p.domain_id
  join private.authority_entities a on a.id=d.authority_id
  join private.authority_trust_roots r on r.id=p.root_id
  where e.claim_id=claim and k.is_current and not e.conflicting
   and p.revoked_at is null and p.domain_revision=d.revision
   and p.expires_at>now() and e.fresh_until>now() and d.expires_at>now() and a.expires_at>now()
   and r.active and r.expires_at>now() and d.state='verified' and a.state='verified'
   and doc.validation_status='validated' and doc.source_authority<>'rad_official'
   and e.topic=p.scope_topic and e.topic=any(a.competence_topics)
   and e.jurisdiction=p.jurisdiction and e.jurisdiction=a.jurisdiction
   and (p.profession='*' or p.profession=e.profession)
   and e.effective_from<=current_date and (e.effective_until is null or e.effective_until>=current_date)
   and doc.canonical_url like 'https://'||d.host||d.path_prefix||'%'
   and doc.removed_at is null and k.claim_text=c.excerpt
   and length(c.excerpt)>0 and position(c.excerpt in s.normalized_text)>0 and nullif(c.locator,'') is not null
 ) and not exists(select 1 from private.claim_official_evidence where claim_id=claim and conflicting);
$$;

create function private.rad_guard_factual_verification() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.factual_status='verified' and not private.rad_claim_eligible(new.id) then
  raise exception 'official_evidence_required' using errcode='PT422';
 end if;
 return new;
end $$;
create trigger rad_claim_verification_gate before insert or update on public.knowledge_claims
for each row execute function private.rad_guard_factual_verification();
-- Human editorial APIs remain; direct client trust/state patches do not.
revoke insert,update,delete on public.source_documents,public.source_snapshots,public.knowledge_claims,public.knowledge_citations from anon,authenticated;

create function private.rad_article_state(revision uuid) returns text language sql stable set search_path='' as $$
 select state from public.visa_article_revision_events where revision_id=revision order by sequence desc limit 1;
$$;
create function private.rad_article_verification(revision uuid) returns text language sql stable security definer set search_path='' as $$
 select case when exists(select 1 from public.visa_article_sections where revision_id=revision)
 and not exists(
   select 1 from public.visa_article_sections s where s.revision_id=revision and (
     jsonb_array_length(s.evidence_refs)=0 or exists(select 1 from jsonb_array_elements(s.evidence_refs) e
       where e->>'claim_id' is null or not private.rad_claim_eligible((e->>'claim_id')::uuid))))
 then 'verified' else 'unverified' end;
$$;
create function private.rad_revision_result(revision uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('article_id',r.article_id,'revision_id',r.id,'revision',r.revision,'content_hash',r.content_hash,
  'editorial_state',private.rad_article_state(r.id),'verification_state',private.rad_article_verification(r.id),
  'updated_at',to_char(r.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
 from public.visa_article_revisions r where r.id=$1;
$$;

create function private.rad_check_ancestry(snapshots uuid[],seen uuid[] default '{}') returns void
language plpgsql stable set search_path='' as $$
declare s uuid; origin private.visa_source_origins;
begin
 if cardinality(seen)>500 then raise exception 'invalid_provenance' using errcode='PT422'; end if;
 foreach s in array snapshots loop
  if s=any(seen) then raise exception 'cyclic_provenance' using errcode='PT422'; end if;
  select * into origin from private.visa_source_origins where snapshot_id=s;
  if not found or origin.publisher not in ('radvisa','digivisa','official_primary') then
   raise exception 'prohibited_main_ancestry' using errcode='PT422';
  end if;
  perform private.rad_check_ancestry(origin.parent_snapshot_ids,seen||s);
 end loop;
end $$;

create function private.rad_save_article(body jsonb) returns uuid language plpgsql set search_path='' as $$
declare r public.visa_article_revisions; h public.visa_article_heads; section jsonb; e jsonb; snapshot public.source_snapshots;
 rel uuid; manifest public.visa_merge_manifests; id uuid;
begin
 insert into public.visa_article_heads(article_id,locale) values((body->>'article_id')::uuid,body->>'locale') on conflict do nothing;
 select * into h from public.visa_article_heads where article_id=(body->>'article_id')::uuid and locale=body->>'locale' for update;
 select * into r from public.visa_article_revisions where visa_article_revisions.id=h.head_id;
 if coalesce(r.revision,0)<>(body->>'expected_revision')::integer then raise exception 'revision_conflict' using errcode='PT409'; end if;
 if body->>'merge_manifest_id' is not null then
  select * into manifest from public.visa_merge_manifests where visa_merge_manifests.id=(body->>'merge_manifest_id')::uuid and article_id=h.article_id;
  if not found then raise exception 'invalid_merge_manifest' using errcode='PT422'; end if;
 end if;
 for section in select * from jsonb_array_elements(body->'sections') loop
  for e in select * from jsonb_array_elements(section->'evidence_refs') loop
   select * into snapshot from public.source_snapshots where source_snapshots.id=(e->>'snapshot_id')::uuid;
   if not found or position(e->>'excerpt' in snapshot.normalized_text)=0 then raise exception 'invalid_evidence_excerpt' using errcode='PT422'; end if;
   if e->>'claim_id' is not null and not exists(select 1 from public.knowledge_citations c where c.claim_id=(e->>'claim_id')::uuid and c.snapshot_id=snapshot.id and c.excerpt=e->>'excerpt') then
    raise exception 'invalid_claim_reference' using errcode='PT422';
   end if;
  end loop;
 end loop;
 for rel in select jsonb_array_elements_text(body->'related_article_ids')::uuid loop
  if rel=h.article_id or not exists(select 1 from public.visa_articles where visa_articles.id=rel and kind='related') then raise exception 'invalid_related_article' using errcode='PT422'; end if;
 end loop;
 insert into public.visa_article_revisions(article_id,locale,revision,title,summary,content_hash,body,created_by)
 values(h.article_id,h.locale,coalesce(r.revision,0)+1,body->>'title',body->>'summary',encode(extensions.digest((body-'request_key'-'expected_revision')::text,'sha256'),'hex'),body-'request_key',auth.uid())
 returning visa_article_revisions.id into id;
 for section in select * from jsonb_array_elements(body->'sections') loop
  insert into public.visa_article_sections values(id,(section->>'id')::uuid,section->>'anchor',section->>'heading',(section->>'order')::integer,section->'blocks',section->'evidence_refs');
 end loop;
 insert into public.visa_article_revision_events(revision_id,state,actor_id) values(id,'draft',auth.uid());
 update public.visa_article_heads set head_id=id where article_id=h.article_id and locale=h.locale;
 return id;
exception when unique_violation then raise exception 'duplicate_section_or_revision' using errcode='PT409';
end $$;

create function private.rad_article_mutate(operation text,body jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior jsonb; result jsonb; r public.visa_article_revisions; h public.visa_article_heads; a public.visa_articles;
 id uuid; state text; new_state text; ev public.visa_article_revision_events; manifest public.visa_merge_manifests;
begin
 perform private.rad_require_admin();
 prior:=private.rad_begin_mutation(operation,body); if prior is not null then return prior; end if;
 if operation='create_visa_article' then
  if not exists(select 1 from public.destinations where code=rad_article_mutate.body->>'country_code') then raise exception 'unknown_country' using errcode='PT422'; end if;
  insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
  values((rad_article_mutate.body->>'article_id')::uuid,rad_article_mutate.body->>'kind',rad_article_mutate.body->>'country_code',rad_article_mutate.body->>'pathway_slug',rad_article_mutate.body->>'slug',auth.uid());
  result:=private.rad_envelope(jsonb_build_object('article_id',rad_article_mutate.body->>'article_id','created',true));
 elsif operation='save_visa_article_draft' then
  id:=private.rad_save_article(body);result:=private.rad_envelope(private.rad_revision_result(id),rad_article_mutate.body->>'locale');
 elsif operation='rollback_visa_article' then
  select * into r from public.visa_article_revisions where visa_article_revisions.id=(rad_article_mutate.body->>'from_revision_id')::uuid and article_id=(rad_article_mutate.body->>'article_id')::uuid and locale=rad_article_mutate.body->>'locale';
  if not found then raise exception 'not_found' using errcode='PT404'; end if;
  id:=private.rad_save_article(r.body||jsonb_build_object('expected_revision',rad_article_mutate.body->'expected_revision','request_key',rad_article_mutate.body->'request_key'));
  result:=private.rad_envelope(private.rad_revision_result(id),rad_article_mutate.body->>'locale');
 else
  select * into r from public.visa_article_revisions where visa_article_revisions.id=(rad_article_mutate.body->>'revision_id')::uuid and article_id=(rad_article_mutate.body->>'article_id')::uuid;
  if not found then raise exception 'not_found' using errcode='PT404'; end if;
  select * into h from public.visa_article_heads where article_id=r.article_id and locale=r.locale for update;
  if h.head_id<>r.id or r.content_hash<>rad_article_mutate.body->>'content_hash' or (body ? 'expected_revision' and r.revision<>(rad_article_mutate.body->>'expected_revision')::integer) then raise exception 'revision_conflict' using errcode='PT409'; end if;
  state:=private.rad_article_state(r.id);
  new_state:=case operation when 'submit_visa_article_review' then 'review' when 'approve_visa_article_revision' then 'approved' when 'reject_visa_article_revision' then 'rejected' when 'publish_visa_article_revision' then 'published' end;
  if new_state is null or not ((state='draft' and new_state='review') or (state='review' and new_state in ('approved','rejected')) or (state='approved' and new_state='published') or (state='published' and new_state='published')) then raise exception 'invalid_editorial_transition' using errcode='PT409'; end if;
  if new_state='rejected' and nullif(btrim(rad_article_mutate.body->>'note'),'') is null then raise exception 'rejection_note_required' using errcode='PT422'; end if;
  if new_state='published' then
   select * into a from public.visa_articles where visa_articles.id=r.article_id;
   if a.kind='main' then
    select * into manifest from public.visa_merge_manifests where visa_merge_manifests.id=(r.body->>'merge_manifest_id')::uuid and article_id=a.id;
    if not found or not manifest.complete or cardinality(manifest.source_snapshot_ids)<2 then raise exception 'complete_merge_required' using errcode='PT422'; end if;
    perform private.rad_check_ancestry(manifest.source_snapshot_ids);
    if not exists(select 1 from private.visa_source_origins where snapshot_id=any(manifest.source_snapshot_ids) and publisher='radvisa')
       or not exists(select 1 from private.visa_source_origins where snapshot_id=any(manifest.source_snapshot_ids) and publisher='digivisa') then raise exception 'both_publishers_required' using errcode='PT422'; end if;
   end if;
   select * into ev from public.visa_article_revision_events where revision_id=r.id and visa_article_revision_events.state='published';
   if not found then
    insert into public.visa_article_revision_events(revision_id,state,actor_id,note) values(r.id,new_state,auth.uid(),coalesce(rad_article_mutate.body->>'note','')) returning * into ev;
   end if;
   update public.visa_article_heads set published_id=r.id where article_id=r.article_id and locale=r.locale;
   result:=private.rad_envelope(jsonb_build_object('resource_id',r.article_id,'revision_id',r.id,'revision',r.revision,'event_id',ev.id,
    'published_at',to_char(ev.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'target',jsonb_build_object('kind','visa_article','id',r.article_id,'section_id',null)),r.locale);
  else
   insert into public.visa_article_revision_events(revision_id,state,actor_id,note) values(r.id,new_state,auth.uid(),coalesce(rad_article_mutate.body->>'note',''));
   result:=private.rad_envelope(private.rad_revision_result(r.id),r.locale);
  end if;
 end if;
 return private.rad_finish_mutation(operation,body,result);
exception when unique_violation then raise exception 'article_conflict' using errcode='PT409';
end $$;

create function private.rad_evidence(ref jsonb,section uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('source_document_id',d.id,'snapshot_id',s.id,'claim_id',ref->'claim_id','section_id',section,
 'url',d.canonical_url,'publisher',d.title,'source_class',coalesce(o.publisher,'other'),'authority_id',null,
 'excerpt',ref->>'excerpt','locator',ref->'locator','fetched_at',to_char(s.fetched_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'verified_at',null,'fresh_until',null,'verification_state',case when private.rad_claim_eligible((ref->>'claim_id')::uuid) then 'verified' else 'unverified' end,'freshness_state','unknown')
 from public.source_snapshots s join public.source_documents d on d.id=s.document_id
 left join private.visa_source_origins o on o.snapshot_id=s.id where s.id=(ref->>'snapshot_id')::uuid;
$$;

create function private.rad_related(revision uuid,locale text) returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'slug',a.slug,'title',r.title,'summary',r.summary,'published_revision',r.revision,
 'target',jsonb_build_object('kind','visa_article','id',a.id,'section_id',null)) order by refs.ordinality),'[]')
 from public.visa_article_revisions source
 cross join lateral jsonb_array_elements_text(source.body->'related_article_ids') with ordinality refs(id,ordinality)
 join public.visa_articles a on a.id=refs.id::uuid and a.kind='related'
 join public.visa_article_heads h on h.article_id=a.id and h.locale=$2
 join public.visa_article_revisions r on r.id=h.published_id
 where source.id=$1;
$$;

create function public.get_visa_article(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions; a public.visa_articles; sections jsonb; published_at timestamptz;
begin
 perform private.rad_assert_request('get_visa_article',p_request);
 select * into a from public.visa_articles where
  (p_request->'selector' ? 'article_id' and id=(p_request->'selector'->>'article_id')::uuid)
  or (not p_request->'selector' ? 'article_id' and country_code=p_request->'selector'->>'country_code' and pathway_slug=p_request->'selector'->>'pathway_slug' and kind='main');
 select rev.* into r from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.published_id where h.article_id=a.id and h.locale=p_request->>'locale';
 if r.id is null then raise exception 'not_found' using errcode='PT404'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'anchor',s.anchor,'heading',s.heading,'order',s.position,'blocks',s.blocks,
 'evidence',(select coalesce(jsonb_agg(private.rad_evidence(e,s.id)),'[]') from jsonb_array_elements(s.evidence_refs) e)) order by s.position,s.id),'[]')
 into sections from public.visa_article_sections s where s.revision_id=r.id;
 select created_at into published_at from public.visa_article_revision_events where revision_id=r.id and state='published';
 return private.rad_envelope(jsonb_build_object('id',a.id,'kind',a.kind,'country_code',a.country_code,'pathway_slug',a.pathway_slug,'slug',a.slug,
  'locale',r.locale,'revision',r.revision,'revision_id',r.id,'content_hash',r.content_hash,'title',r.title,'summary',r.summary,'sections',sections,
  'related_articles',private.rad_related(r.id,r.locale),'editorial_state','published','verification_state',private.rad_article_verification(r.id),'freshness_state','unknown',
  'published_at',to_char(published_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'updated_at',to_char(r.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'target',jsonb_build_object('kind','visa_article','id',a.id,'section_id',null)),r.locale);
end $$;

create function public.list_related_visa_articles(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare article jsonb; items jsonb; pos jsonb; version text; off integer; lim integer:=(p_request->>'limit')::integer; total integer;
begin
 perform private.rad_assert_request('list_related_visa_articles',p_request);
 article:=public.get_visa_article(jsonb_build_object('selector',jsonb_build_object('article_id',p_request->'article_id'),'locale',p_request->'locale'));
 version:=article->'data'->>'revision_id';pos:=private.rad_page_position(p_request,version);off:=coalesce((pos->>'offset')::integer,0);
 total:=jsonb_array_length(article->'data'->'related_articles');
 select coalesce(jsonb_agg(v order by n),'[]') into items from jsonb_array_elements(article->'data'->'related_articles') with ordinality e(v,n) where n>off and n<=off+lim;
 return private.rad_envelope(jsonb_build_object('items',items),p_request->>'locale',private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;

CREATE FUNCTION public.create_visa_article(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('create_visa_article',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.create_visa_article(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.create_visa_article(jsonb) TO authenticated;
CREATE FUNCTION public.save_visa_article_draft(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('save_visa_article_draft',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.save_visa_article_draft(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_visa_article_draft(jsonb) TO authenticated;
CREATE FUNCTION public.submit_visa_article_review(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('submit_visa_article_review',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.submit_visa_article_review(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.submit_visa_article_review(jsonb) TO authenticated;
CREATE FUNCTION public.approve_visa_article_revision(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('approve_visa_article_revision',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.approve_visa_article_revision(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.approve_visa_article_revision(jsonb) TO authenticated;
CREATE FUNCTION public.reject_visa_article_revision(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('reject_visa_article_revision',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.reject_visa_article_revision(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.reject_visa_article_revision(jsonb) TO authenticated;
CREATE FUNCTION public.publish_visa_article_revision(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('publish_visa_article_revision',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.publish_visa_article_revision(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.publish_visa_article_revision(jsonb) TO authenticated;
CREATE FUNCTION public.rollback_visa_article(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_article_mutate('rollback_visa_article',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.rollback_visa_article(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.rollback_visa_article(jsonb) TO authenticated;

-- Workflow tables are reachable only through role-checked functions. A client
-- cannot bypass exact-version review by directly editing JSON or state rows.
do $$ declare name text; begin
 foreach name in array array['visa_articles','visa_article_revisions','visa_article_heads','visa_article_sections','visa_article_revision_events','visa_merge_manifests','visa_research_proposals'] loop
  execute format('alter table public.%I enable row level security',name);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',name);
 end loop;
 foreach name in array array['visa_source_origins','authority_entities','authority_domains','authority_trust_roots','authority_proofs','claim_official_evidence','rad_research_jobs'] loop
  execute format('alter table private.%I enable row level security',name);
  execute format('revoke all on private.%I from public,anon,authenticated,service_role',name);
 end loop;
end $$;
revoke all on function public.get_visa_article(jsonb),public.list_related_visa_articles(jsonb) from public;
grant execute on function public.get_visa_article(jsonb),public.list_related_visa_articles(jsonb) to anon,authenticated;
commit;
