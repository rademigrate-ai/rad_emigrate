begin;
-- Explicit Admin mappings only. No seeded sources, authorities, or publication.
create table private.rad_official_refresh_bindings(
 id uuid primary key,source_id uuid not null references public.research_sources(id),document_id uuid not null references public.source_documents(id),
 authority_id uuid not null references private.authority_entities(id),article_id uuid not null references public.visa_articles(id),
 locale text not null check(locale in('fa','en')),section_id uuid not null,block_id uuid not null,
 start_marker text not null,end_marker text not null,initial_snapshot_id uuid not null references public.source_snapshots(id),
 last_snapshot_id uuid not null references public.source_snapshots(id),created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(document_id,article_id,locale)
);
create table private.rad_bound_refresh_receipts(
 binding_id uuid not null references private.rad_official_refresh_bindings(id),prior_snapshot_id uuid not null references public.source_snapshots(id),
 snapshot_id uuid not null references public.source_snapshots(id),base_revision_id uuid not null references public.visa_article_revisions(id),result jsonb not null,
 primary key(binding_id,prior_snapshot_id,snapshot_id,base_revision_id)
);
create table private.rad_bound_proposal_evidence(
 proposal_id uuid primary key references public.visa_research_proposals(id),binding_id uuid not null references private.rad_official_refresh_bindings(id),evidence jsonb not null
);
-- A job freezes its nonempty binding set once. Committed no-op targets count as
-- progress too; interrupted leases resume only incomplete frozen targets.
create table private.rad_bound_refresh_job_targets(
 job_id uuid not null references private.rad_research_jobs(id),binding_id uuid not null references private.rad_official_refresh_bindings(id),
 expected_revision_id uuid not null references public.visa_article_revisions(id),expected_snapshot_id uuid not null references public.source_snapshots(id),
  verified_path_prefix text not null,source_url text not null,completed_at timestamptz,completed_lease_token uuid,result jsonb,
 primary key(job_id,binding_id),check((completed_at is null)=(result is null))
);
create table private.rad_bound_raw_captures(
 binding_id uuid not null references private.rad_official_refresh_bindings(id),snapshot_id uuid not null references public.source_snapshots(id),
 raw_sha256 text not null,raw_body bytea not null,final_url text not null,observed_at timestamptz not null default clock_timestamp(),
  primary key(binding_id,snapshot_id,raw_sha256,final_url),
 check(octet_length(raw_body) between 1 and 1000000 and raw_sha256=encode(extensions.digest(raw_body,'sha256'),'hex'))
);
alter table private.rad_bound_refresh_job_targets enable row level security;
alter table private.rad_bound_raw_captures enable row level security;
revoke all on private.rad_bound_refresh_job_targets,private.rad_bound_raw_captures from public,anon,authenticated,service_role;
create trigger rad_bound_raw_capture_immutable before update or delete on private.rad_bound_raw_captures for each row execute function private.rad_immutable();
alter table private.rad_official_refresh_bindings enable row level security;
alter table private.rad_bound_refresh_receipts enable row level security;
alter table private.rad_bound_proposal_evidence enable row level security;
revoke all on private.rad_official_refresh_bindings,private.rad_bound_refresh_receipts,private.rad_bound_proposal_evidence from public,anon,authenticated,service_role;
create trigger rad_bound_receipt_immutable before update or delete on private.rad_bound_refresh_receipts for each row execute function private.rad_immutable();
create trigger rad_bound_evidence_immutable before update or delete on private.rad_bound_proposal_evidence for each row execute function private.rad_immutable();

create function private.rad_bound_fragment(value text,start_marker text,end_marker text) returns text
language plpgsql immutable set search_path='' as $$
declare a integer;b integer;fragment text;begin
 if value is null or start_marker is null or end_marker is null or length(btrim(start_marker))=0 or length(btrim(end_marker))=0
 or length(start_marker)>200 or length(end_marker)>200 or start_marker=end_marker then raise exception 'invalid_source_markers' using errcode='PT422';end if;
 a:=strpos(value,start_marker);b:=strpos(value,end_marker);
 if a=0 or b=0 or b<a+length(start_marker) or strpos(substring(value from a+1),start_marker)>0
 or strpos(substring(value from b+1),end_marker)>0 then raise exception 'source_markers_not_unique' using errcode='PT422';end if;
 fragment:=btrim(substring(value from a+length(start_marker) for b-a-length(start_marker)));
 if length(fragment) not between 1 and 4000 then raise exception 'source_fragment_out_of_bounds' using errcode='PT422';end if;
 return fragment;
end $$;

create function private.rad_bound_path_allowed(source_url text,allowed_host text,path_prefix text) returns boolean
language plpgsql immutable set search_path='' as $$
declare path text;origin text;prefix text:=rtrim(path_prefix,'/');begin
 if source_url is null or length(source_url)>2048 or allowed_host is null or path_prefix is null or not starts_with(path_prefix,'/')
 or source_url ~ '[[:cntrl:][:space:]]' or position(chr(92) in source_url)>0 or position('#' in source_url)>0 then return false;end if;
 origin:=substring(source_url from '^https://([^/?#]+)');
 if origin is null or origin not in(allowed_host,allowed_host||':443') then return false;end if;
 path:=coalesce(nullif(substring(source_url from '^https://[^/?#]+([^?#]*)'),''),'/');
 -- Do not let clients/origins decode an apparent permitted prefix into another
 -- resource. Encoded UTF-8 remains allowed; encoded delimiters/dots/percent and
 -- control bytes, raw dot segments and backslashes fail closed.
 if path ~ '(^|/)\.{1,2}(/|$)' or path ~* '%(2e|2f|5c|25|0[0-9a-f]|1[0-9a-f]|20|7f)' or path ~ '%(?![0-9a-fA-F]{2})'
 or path_prefix ~ '(^|/)\.{1,2}(/|$)' or path_prefix ~* '%(2e|2f|5c|25|0[0-9a-f]|1[0-9a-f]|20|7f)'
 or path_prefix ~ '[?#[:cntrl:][:space:]]' or position(chr(92) in path_prefix)>0 then return false;end if;
 return prefix='' or path=prefix or starts_with(path,prefix||'/');
end $$;

create function private.rad_bound_verified_prefixes(binding private.rad_official_refresh_bindings) returns text[]
language sql stable set search_path='' as $$
 select coalesce(array_agg(distinct domain.path_prefix),'{}'::text[]) from public.research_sources src join public.source_documents doc on doc.id=binding.document_id
 join public.visa_articles article on article.id=binding.article_id
 join private.authority_entities authority on authority.id=binding.authority_id
 join private.authority_domains domain on domain.authority_id=authority.id
 join private.authority_proofs proof on proof.domain_id=domain.id
 join private.authority_trust_roots root on root.id=proof.root_id
 where src.id=binding.source_id and src.enabled and src.runtime_scope in('admin','both')
 and src.base_url=doc.canonical_url and src.country_code=article.country_code and src.topic=article.pathway_slug
 and doc.validation_status='validated' and doc.removed_at is null and doc.source_authority<>'rad_official'
 and src.allowed_host=domain.host
 and authority.state='verified' and authority.country_code=article.country_code and authority.jurisdiction=article.country_code
 and article.pathway_slug=any(authority.competence_topics) and authority.expires_at>now()
 and domain.state='verified' and domain.expires_at>now() and proof.domain_revision=domain.revision
 and proof.scope_topic=article.pathway_slug and proof.jurisdiction=article.country_code and proof.profession='*'
 and proof.revoked_at is null and proof.expires_at>now() and root.active and root.expires_at>now();
$$;
create function private.rad_bound_authorized(binding private.rad_official_refresh_bindings,source_url text) returns boolean
language sql stable set search_path='' as $$
 select private.is_safe_public_https_url(source_url) and exists(select 1
 from unnest(private.rad_bound_verified_prefixes(binding))prefix
 where private.rad_bound_path_allowed(source_url,(select allowed_host from public.research_sources where id=binding.source_id),prefix));
$$;

create function public.create_official_refresh_binding(p_binding_id uuid,p_source_id uuid,p_document_id uuid,p_authority_id uuid,
 p_article_id uuid,p_locale text,p_section_id uuid,p_block_id uuid,p_start_marker text,p_end_marker text,p_snapshot_id uuid,p_expected_revision_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();binding private.rad_official_refresh_bindings;head uuid;rich jsonb;snapshot public.source_snapshots;stored private.rad_official_refresh_bindings;begin
 select head_id into head from public.visa_article_heads where article_id=p_article_id and locale=p_locale for share;
 if head is null or head is distinct from p_expected_revision_id then raise exception 'baseline_conflict' using errcode='PT409';end if;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=head;
 if not exists(select 1 from jsonb_array_elements(rich->'sections')s cross join lateral jsonb_array_elements(s->'blocks')b where s->>'id'=p_section_id::text and b->>'id'=p_block_id::text)
 then raise exception 'binding_target_missing' using errcode='PT422';end if;
 select * into snapshot from public.source_snapshots where id=p_snapshot_id;
 if snapshot.document_id is distinct from p_document_id or snapshot.http_status is distinct from 200 or snapshot.fetched_at>now()
 or snapshot.content_hash is distinct from encode(extensions.digest(snapshot.normalized_text,'sha256'),'hex') then raise exception 'binding_snapshot_invalid' using errcode='PT422';end if;
 binding:=row(p_binding_id,p_source_id,p_document_id,p_authority_id,p_article_id,p_locale,p_section_id,p_block_id,p_start_marker,p_end_marker,p_snapshot_id,p_snapshot_id,actor,now())::private.rad_official_refresh_bindings;
 if not private.rad_bound_authorized(binding,(select canonical_url from public.source_documents where id=p_document_id)) then raise exception 'official_binding_evidence_required' using errcode='PT422';end if;
 perform private.rad_bound_fragment(snapshot.normalized_text,p_start_marker,p_end_marker);
 select * into stored from private.rad_official_refresh_bindings where id=p_binding_id;
 if found then
  if to_jsonb(stored)-array['last_snapshot_id','created_at'] is distinct from to_jsonb(binding)-array['last_snapshot_id','created_at'] then raise exception 'binding_conflict' using errcode='PT409';end if;
 else insert into private.rad_official_refresh_bindings select binding.*;end if;
 return jsonb_build_object('binding_id',p_binding_id,'published',false);
end $$;

create function public.get_bound_official_refresh_targets(p_job_id uuid,p_lease_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job private.rad_research_jobs;b private.rad_official_refresh_bindings;result jsonb:='[]';head uuid;prefix text;begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403';end if;
 select * into job from private.rad_research_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>clock_timestamp() and status='running' and kind='research_refresh' for update;
 if not found then raise exception 'lease_invalid' using errcode='PT409';end if;
 if not exists(select 1 from private.rad_bound_refresh_job_targets where job_id=p_job_id) then
 for b in select * from private.rad_official_refresh_bindings where (job.request->'authority_ids') ? authority_id::text order by id loop
  if not private.rad_bound_authorized(b,(select canonical_url from public.source_documents where id=b.document_id)) then raise exception 'official_binding_evidence_required' using errcode='PT422';end if;
  select h.head_id into head from public.visa_article_heads h join private.rad_editorial_rich_revisions r on r.revision_id=h.head_id where h.article_id=b.article_id and h.locale=b.locale;
  if head is null then raise exception 'baseline_unavailable' using errcode='PT409';end if;
  select candidate into prefix from unnest(private.rad_bound_verified_prefixes(b))candidate
  where private.rad_bound_path_allowed((select canonical_url from public.source_documents where id=b.document_id),
   (select allowed_host from public.research_sources where id=b.source_id),candidate) order by length(candidate) desc,candidate limit 1;
  if prefix is null then raise exception 'official_binding_evidence_required' using errcode='PT422';end if;
  insert into private.rad_bound_refresh_job_targets(job_id,binding_id,expected_revision_id,expected_snapshot_id,verified_path_prefix,source_url)
  values(p_job_id,b.id,head,b.last_snapshot_id,prefix,(select canonical_url from public.source_documents where id=b.document_id));
 end loop;
 if (select count(*) from private.rad_bound_refresh_job_targets where job_id=p_job_id) not between 1 and 20 or exists(select 1 from jsonb_array_elements_text(job.request->'authority_ids') as requested(authority_id_text)
  where not exists(select 1 from private.rad_official_refresh_bindings binding where binding.authority_id=requested.authority_id_text::uuid)) then raise exception 'explicit_source_bindings_required' using errcode='PT422';end if;
 end if;
 -- Completed rows deliberately remain in the manifest. Empty now means an
 -- existing nonempty manifest is complete, never an unconfigured source set.
 if exists(select 1 from private.rad_bound_refresh_job_targets t join private.rad_official_refresh_bindings binding on binding.id=t.binding_id
 where t.job_id=p_job_id and t.completed_at is null and not private.rad_bound_authorized(binding,t.source_url))
 then raise exception 'official_binding_evidence_required' using errcode='PT422';end if;
 if exists(select 1 from private.rad_bound_refresh_job_targets t join private.rad_official_refresh_bindings binding on binding.id=t.binding_id
 join public.source_documents doc on doc.id=binding.document_id left join public.visa_article_heads h on h.article_id=binding.article_id and h.locale=binding.locale
 where t.job_id=p_job_id and t.completed_at is null and (doc.canonical_url is distinct from t.source_url or binding.last_snapshot_id is distinct from t.expected_snapshot_id or h.head_id is distinct from t.expected_revision_id))
 then raise exception 'frozen_target_conflict' using errcode='PT409';end if;
 select coalesce(jsonb_agg(jsonb_build_object('binding_id',t.binding_id,'url',t.source_url,'verified_path_prefix',t.verified_path_prefix,
  'expected_revision_id',t.expected_revision_id,'expected_snapshot_id',t.expected_snapshot_id) order by t.binding_id),'[]'::jsonb) into result
 from private.rad_bound_refresh_job_targets t join private.rad_official_refresh_bindings binding on binding.id=t.binding_id
 join public.source_documents d on d.id=binding.document_id where t.job_id=p_job_id and t.completed_at is null;
 return result;
end $$;

create function public.renew_bound_official_refresh_lease(p_job_id uuid,p_lease_token uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403';end if;
 update private.rad_research_jobs set lease_until=clock_timestamp()+interval '60 seconds',updated_at=clock_timestamp()
 where id=p_job_id and lease_token=p_lease_token and lease_until>clock_timestamp() and status='running' and kind='research_refresh';
 if not found then raise exception 'lease_invalid' using errcode='PT409';end if;return true;
end $$;

create function public.yield_bound_official_refresh(p_job_id uuid,p_lease_token uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare job private.rad_research_jobs;begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403';end if;
 select * into job from private.rad_research_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>clock_timestamp()
 and status='running' and kind='research_refresh' for update;
 if not found then raise exception 'lease_invalid' using errcode='PT409';end if;
 if not exists(select 1 from private.rad_bound_refresh_job_targets where job_id=p_job_id and completed_lease_token=p_lease_token)
 or not exists(select 1 from private.rad_bound_refresh_job_targets where job_id=p_job_id and completed_at is null)
 then raise exception 'refresh_yield_requires_progress' using errcode='PT409';end if;
 update private.rad_research_jobs set status='queued',attempts=0,lease_token=null,lease_until=null,updated_at=clock_timestamp() where id=p_job_id;
 return true;
end $$;

create function private.rad_complete_bound_target(p_job_id uuid,p_lease_token uuid,p_binding_id uuid,p_snapshot_id uuid,p_result jsonb,p_raw bytea,p_final_url text) returns void
language plpgsql set search_path='' as $$
declare source uuid;progress integer;begin
 insert into private.rad_bound_raw_captures(binding_id,snapshot_id,raw_sha256,raw_body,final_url)
 values(p_binding_id,p_snapshot_id,encode(extensions.digest(p_raw,'sha256'),'hex'),p_raw,p_final_url) on conflict do nothing;
 update private.rad_bound_refresh_job_targets set completed_at=clock_timestamp(),completed_lease_token=p_lease_token,result=p_result
 where job_id=p_job_id and binding_id=p_binding_id and completed_at is null;
 get diagnostics progress=row_count;
 update private.rad_research_jobs set attempts=case when progress>0 then 0 else attempts end,updated_at=clock_timestamp()
 where id=p_job_id and lease_token=p_lease_token and lease_until>clock_timestamp() and status='running' and kind='research_refresh';
 if not found then raise exception 'lease_invalid' using errcode='PT409';end if;
 select source_id into source from private.rad_official_refresh_bindings where id=p_binding_id;
 update public.source_documents set last_seen_at=clock_timestamp(),last_content_hash=(select content_hash from public.source_snapshots where id=p_snapshot_id)
 where id=(select document_id from private.rad_official_refresh_bindings where id=p_binding_id);
 update public.research_sources set last_attempt_at=clock_timestamp(),last_success_at=clock_timestamp(),last_error_code=null where id=source;
end $$;

create function public.ingest_bound_official_refresh(p_job_id uuid,p_lease_token uuid,p_binding_id uuid,p_expected_revision_id uuid,p_expected_snapshot_id uuid,
 p_normalized_text text,p_raw_base64 text,p_final_url text,p_http_status integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job private.rad_research_jobs;b private.rad_official_refresh_bindings;r public.visa_article_revisions;rich jsonb;block jsonb;target private.rad_bound_refresh_job_targets;
 old_snapshot public.source_snapshots;new_snapshot public.source_snapshots;new_hash text;old_fragment text;new_fragment text;raw bytea;
 patch jsonb;patches jsonb;proposal uuid;result jsonb;prior jsonb;evidence jsonb;source_language text;begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403';end if;
 select * into job from private.rad_research_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>clock_timestamp() and status='running' and kind='research_refresh' for update;
 if not found then raise exception 'lease_invalid' using errcode='PT409';end if;
 if p_http_status is distinct from 200 or p_normalized_text is null or length(p_normalized_text) not between 1 and 100000
 or p_raw_base64 is null or length(p_raw_base64)>1333336 then raise exception 'invalid_source_snapshot' using errcode='PT422';end if;
 begin raw:=decode(p_raw_base64,'base64');exception when others then raise exception 'invalid_source_snapshot' using errcode='PT422';end;
 if octet_length(raw) not between 1 and 1000000 then raise exception 'invalid_source_snapshot' using errcode='PT422';end if;
 select * into b from private.rad_official_refresh_bindings where id=p_binding_id for update;
 if b.id is null or not ((job.request->'authority_ids') ? b.authority_id::text) or not private.rad_bound_authorized(b,p_final_url)
 then raise exception 'official_binding_evidence_required' using errcode='PT422';end if;
 select * into target from private.rad_bound_refresh_job_targets where job_id=p_job_id and binding_id=p_binding_id for update;
 if target.job_id is null or target.expected_revision_id is distinct from p_expected_revision_id or target.expected_snapshot_id is distinct from p_expected_snapshot_id
 or target.source_url is distinct from (select canonical_url from public.source_documents where id=b.document_id)
 or not private.rad_bound_path_allowed(p_final_url,(select allowed_host from public.research_sources where id=b.source_id),target.verified_path_prefix)
 then raise exception 'frozen_target_conflict' using errcode='PT409';end if;
 select rev.* into r from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id where h.article_id=b.article_id and h.locale=b.locale for update of h;
 if r.id is distinct from p_expected_revision_id then raise exception 'baseline_conflict' using errcode='PT409';end if;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=r.id;
 select k into block from jsonb_array_elements(rich->'sections')s cross join lateral jsonb_array_elements(s->'blocks')k where s->>'id'=b.section_id::text and k->>'id'=b.block_id::text;
 if block is null then raise exception 'binding_target_missing' using errcode='PT409';end if;
 select * into old_snapshot from public.source_snapshots where id=p_expected_snapshot_id and document_id=b.document_id;
 if old_snapshot.id is null then raise exception 'snapshot_conflict' using errcode='PT409';end if;
 new_hash:=encode(extensions.digest(p_normalized_text,'sha256'),'hex');
 select * into new_snapshot from public.source_snapshots where document_id=b.document_id and content_hash=new_hash;
 if b.last_snapshot_id is distinct from p_expected_snapshot_id then
  if new_snapshot.id is distinct from b.last_snapshot_id then raise exception 'snapshot_conflict' using errcode='PT409';end if;
  select receipt.result into prior from private.rad_bound_refresh_receipts receipt where binding_id=b.id and prior_snapshot_id=p_expected_snapshot_id and snapshot_id=new_snapshot.id and base_revision_id=r.id;
  if prior is null then raise exception 'snapshot_conflict' using errcode='PT409';end if;
  perform private.rad_complete_bound_target(p_job_id,p_lease_token,b.id,new_snapshot.id,prior,raw,p_final_url);
  return prior;
 end if;
 if new_snapshot.id=old_snapshot.id then
  result:=jsonb_build_object('changed',false,'snapshot_id',old_snapshot.id,'proposal_id',null,'published',false);
  perform private.rad_complete_bound_target(p_job_id,p_lease_token,b.id,old_snapshot.id,result,raw,p_final_url);
  return result;
 end if;
 if new_snapshot.id is not null and new_snapshot.fetched_at<=old_snapshot.fetched_at then raise exception 'snapshot_reversion_requires_review' using errcode='PT409';end if;
 old_fragment:=private.rad_bound_fragment(old_snapshot.normalized_text,b.start_marker,b.end_marker);
 new_fragment:=private.rad_bound_fragment(p_normalized_text,b.start_marker,b.end_marker);
 if new_snapshot.id is null then
  insert into public.source_snapshots(document_id,content_hash,normalized_text,http_status,metadata)
  values(b.document_id,new_hash,p_normalized_text,200,jsonb_build_object('final_url',p_final_url,'raw_body_base64',p_raw_base64,'raw_sha256',encode(extensions.digest(raw,'sha256'),'hex'),'raw_byte_length',octet_length(raw),'transport','dns_pinned_public_egress'))
  on conflict(document_id,content_hash) do nothing returning * into new_snapshot;
  if new_snapshot.id is null then select * into new_snapshot from public.source_snapshots where document_id=b.document_id and content_hash=new_hash;end if;
 end if;
 if new_fragment is distinct from old_fragment then
  patch:=jsonb_build_object('id',gen_random_uuid(),'section_id',b.section_id,'block_id',b.block_id,'before_hash',encode(extensions.digest(block::text,'sha256'),'hex'),
   'operation','add_after','path','[]'::jsonb,'text',new_fragment,'new_block_id',gen_random_uuid(),
   'evidence',jsonb_build_object('snapshot_id',new_snapshot.id,'excerpt',new_fragment,'locator','Admin-bound exact source markers; original source language; not a translation'));
  patches:=jsonb_build_array(patch);
  perform private.rad_apply_rich_patches(rich->'sections',patches,'[]',false);
  insert into public.visa_research_proposals(article_id,locale,base_revision,authority_id,old_snapshot_id,new_snapshot_id,changes,new_sections)
  values(r.article_id,r.locale,r.revision,b.authority_id,old_snapshot.id,new_snapshot.id,'[]',r.body->'sections') returning id into proposal;
  insert into private.rad_structured_proposals values(proposal,r.id,encode(extensions.digest(rich::text,'sha256'),'hex'),b.source_id,patches);
  select language_code into source_language from public.source_documents where id=b.document_id;
  evidence:=jsonb_build_object('source_url',(select canonical_url from public.source_documents where id=b.document_id),'source_language',source_language,'article_locale',r.locale,
   'old_snapshot_id',old_snapshot.id,'new_snapshot_id',new_snapshot.id,'old_content_hash',old_snapshot.content_hash,'new_content_hash',new_snapshot.content_hash,
   'old_fragment',old_fragment,'new_fragment',new_fragment,'interpretation','verbatim source evidence only; no translation or legal interpretation');
  insert into private.rad_bound_proposal_evidence values(proposal,b.id,evidence);
 end if;
 update private.rad_official_refresh_bindings set last_snapshot_id=new_snapshot.id where id=b.id;
 update public.source_documents set last_seen_at=now(),last_content_hash=new_hash where id=b.document_id;
 update public.research_sources set last_attempt_at=now(),last_success_at=now(),last_error_code=null where id=b.source_id;
 result:=jsonb_build_object('changed',proposal is not null,'snapshot_id',new_snapshot.id,'proposal_id',proposal,'published',false);
 insert into private.rad_bound_refresh_receipts values(b.id,old_snapshot.id,new_snapshot.id,r.id,result);
 perform private.rad_complete_bound_target(p_job_id,p_lease_token,b.id,new_snapshot.id,result,raw,p_final_url);
 return result;
end $$;

create or replace function public.get_research_review_context_v2(p_proposal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;structured private.rad_structured_proposals;bound jsonb;begin
 result:=public.get_research_review_context(p_proposal_id);
 select * into structured from private.rad_structured_proposals where proposal_id=p_proposal_id;
 if found then result:=jsonb_set(result,'{data}',result->'data'||jsonb_build_object('structured_patches',structured.patches,'base_rich_hash',structured.base_rich_hash));end if;
 select evidence into bound from private.rad_bound_proposal_evidence where proposal_id=p_proposal_id;
 if found then result:=jsonb_set(result,'{data}',result->'data'||jsonb_build_object('bound_source_change',bound));end if;
 return result;
end $$;
revoke all on function private.rad_bound_fragment(text,text,text),private.rad_bound_authorized(private.rad_official_refresh_bindings,text) from public,anon,authenticated,service_role;
revoke all on function private.rad_bound_path_allowed(text,text,text),private.rad_bound_verified_prefixes(private.rad_official_refresh_bindings),private.rad_complete_bound_target(uuid,uuid,uuid,uuid,jsonb,bytea,text) from public,anon,authenticated,service_role;
revoke all on function public.renew_bound_official_refresh_lease(uuid,uuid),public.yield_bound_official_refresh(uuid,uuid) from public,anon,authenticated;
grant execute on function public.renew_bound_official_refresh_lease(uuid,uuid),public.yield_bound_official_refresh(uuid,uuid) to service_role;
revoke all on function public.create_official_refresh_binding(uuid,uuid,uuid,uuid,uuid,text,uuid,uuid,text,text,uuid,uuid) from public,anon,service_role;
grant execute on function public.create_official_refresh_binding(uuid,uuid,uuid,uuid,uuid,text,uuid,uuid,text,text,uuid,uuid) to authenticated;
revoke all on function public.get_bound_official_refresh_targets(uuid,uuid),public.ingest_bound_official_refresh(uuid,uuid,uuid,uuid,uuid,text,text,text,integer) from public,anon,authenticated;
grant execute on function public.get_bound_official_refresh_targets(uuid,uuid),public.ingest_bound_official_refresh(uuid,uuid,uuid,uuid,uuid,text,text,text,integer) to service_role;
create or replace function public.finish_official_research_job(p_job_id uuid,p_lease_token uuid,p_candidates jsonb,p_safe_code text default null) returns boolean language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;c jsonb;id uuid;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 select * into j from private.rad_research_jobs where rad_research_jobs.id=p_job_id and lease_token=p_lease_token and lease_until>clock_timestamp() and status='running' for update;
 if not found then raise exception 'lease_invalid' using errcode='PT409'; end if;
 if p_safe_code is not null and p_safe_code not in ('discovery_unavailable','protected_egress_unavailable','authority_verification_required','source_unavailable','worker_failed') then raise exception 'invalid_error' using errcode='PT422'; end if;
 if jsonb_typeof(p_candidates)<>'array' or jsonb_array_length(p_candidates)>20 or (j.kind<>'authority_discovery' and jsonb_array_length(p_candidates)>0) then raise exception 'invalid_candidates' using errcode='PT422'; end if;
 for c in select * from jsonb_array_elements(p_candidates) loop
  if nullif(c->>'name','') is null or char_length(c->>'name')>300 or c->>'host' !~ '^[a-z0-9][a-z0-9.-]{1,252}$' or c ? 'verification_state' or c ? 'verified' then raise exception 'invalid_candidate' using errcode='PT422'; end if;
  insert into private.authority_entities(name,authority_type,country_code,jurisdiction,competence_topics)
  values(c->>'name','other_competent_body',j.request->>'country_code',j.request->>'country_code',array[j.request->>'topic']) returning authority_entities.id into id;
  insert into private.authority_domains(authority_id,host) values(id,c->>'host');
 end loop;
 if j.kind='research_refresh' and p_safe_code is null and
 (not exists(select 1 from private.rad_bound_refresh_job_targets where job_id=p_job_id)
 or exists(select 1 from private.rad_bound_refresh_job_targets where job_id=p_job_id and completed_at is null))
 then raise exception 'refresh_targets_incomplete' using errcode='PT409';end if;
 update private.rad_research_jobs set status=case when p_safe_code is null then 'succeeded' else 'failed' end,safe_error_code=p_safe_code,lease_token=null,lease_until=null,updated_at=now() where rad_research_jobs.id=p_job_id;
 return true;
end $$;

commit;
