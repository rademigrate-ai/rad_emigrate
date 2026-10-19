begin;
create table private.visa_source_inventories(
 article_id uuid not null references public.visa_articles(id),revision integer not null,
 snapshot_ids uuid[] not null,inventory_hash text not null,approved_by uuid not null references auth.users(id),
 approved_at timestamptz not null default now(),primary key(article_id,revision)
);
alter table private.visa_source_inventories enable row level security;
revoke all on private.visa_source_inventories from public,anon,authenticated,service_role;
create trigger visa_source_inventory_immutable before update or delete on private.visa_source_inventories for each row execute function private.rad_immutable();

create function private.rad_classify_snapshot(snapshot uuid) returns text language plpgsql set search_path='' as $$
declare url text;publisher text;parent_ids uuid[];stored private.visa_source_origins;
begin
 select d.canonical_url,array(select jsonb_array_elements_text(coalesce(s.metadata->'parent_snapshot_ids','[]'))::uuid)
 into url,parent_ids from public.source_snapshots s join public.source_documents d on d.id=s.document_id where s.id=snapshot;
 if not found then raise exception 'snapshot_not_found' using errcode='PT422'; end if;
 publisher:=case when url ~ '^https://(www[.])?radvisa[.]com/' then 'radvisa'
  when url ~ '^https://(www[.])?digivisa[.]ir/' then 'digivisa'
  when url ~ '^https://(www[.])?radmohajer[.]ir/' then 'radmohajer' else 'other' end;
 select * into stored from private.visa_source_origins where snapshot_id=snapshot;
 if found then
  if stored.publisher<>publisher or stored.parent_snapshot_ids<>parent_ids then raise exception 'provenance_changed' using errcode='PT409'; end if;
 else
  insert into private.visa_source_origins(snapshot_id,publisher,parent_snapshot_ids) values(snapshot,publisher,parent_ids);
 end if;
 return publisher;
end $$;

-- Inventory approval is an explicit human statement about corpus coverage,
-- never official factual verification. No live corpus is seeded by migrations.
create function public.approve_visa_source_inventory(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();prior jsonb;ids uuid[];id uuid;rev integer;hash text;publisher text;publishers text[]:='{}';
begin
 prior:=private.rad_begin_mutation('approve_visa_source_inventory',p_request);if prior is not null then return prior; end if;
 perform pg_advisory_xact_lock(hashtextextended('visa-inventory:'||(p_request->>'article_id'),0));
 select coalesce(max(revision),0) into rev from private.visa_source_inventories where article_id=(p_request->>'article_id')::uuid;
 if rev<>(p_request->>'expected_inventory_revision')::integer then raise exception 'inventory_conflict' using errcode='PT409'; end if;
 ids:=array(select distinct value::uuid from jsonb_array_elements_text(p_request->'source_snapshot_ids') value order by value::uuid);
 if cardinality(ids)<2 then raise exception 'both_publishers_required' using errcode='PT422'; end if;
 foreach id in array ids loop
  publisher:=private.rad_classify_snapshot(id);publishers:=publishers||publisher;
  perform private.rad_check_ancestry(array[id]);
 end loop;
 if not ('radvisa'=any(publishers) and 'digivisa'=any(publishers)) then raise exception 'both_publishers_required' using errcode='PT422'; end if;
 select encode(extensions.digest(string_agg(s.id::text||':'||s.content_hash,',' order by s.id),'sha256'),'hex') into hash from public.source_snapshots s where s.id=any(ids);
 insert into private.visa_source_inventories(article_id,revision,snapshot_ids,inventory_hash,approved_by) values((p_request->>'article_id')::uuid,rev+1,ids,hash,actor);
 return private.rad_finish_mutation('approve_visa_source_inventory',p_request,private.rad_envelope(jsonb_build_object('inventory_revision',rev+1,'inventory_hash',hash,'source_snapshot_ids',to_jsonb(ids))));
end $$;
revoke all on function public.approve_visa_source_inventory(jsonb) from public,anon,service_role;
grant execute on function public.approve_visa_source_inventory(jsonb) to authenticated;

create function public.ingest_visa_snapshots(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare a public.visa_articles;inventory private.visa_source_inventories;h public.visa_article_heads;r public.visa_article_revisions;
 s record;ids uuid[];fragments jsonb:='[]';sections jsonb:='[]';blocks jsonb;known jsonb:='{}';fragment jsonb;piece text;hash text;fragment_id uuid;section_id uuid;target_section uuid;
 idx integer;v_offset integer;locale text;manifest uuid;draft uuid;body jsonb;prior private.rad_idempotency;result jsonb;retained integer:=0;deduplicated integer:=0;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 perform private.rad_assert_request('visa-content-ingest',p_request);
 select * into a from public.visa_articles where id=(p_request->>'article_id')::uuid;
 if not found or a.kind<>'main' then raise exception 'main_article_required' using errcode='PT422'; end if;
 select * into inventory from private.visa_source_inventories where article_id=a.id order by revision desc limit 1;
 ids:=array(select distinct value::uuid from jsonb_array_elements_text(p_request->'source_snapshot_ids') value order by value::uuid);
 if not found or ids<>inventory.snapshot_ids then raise exception 'approved_complete_inventory_required' using errcode='PT422'; end if;
 perform pg_advisory_xact_lock(hashtextextended('visa-ingest:'||a.id::text,0));
 select * into prior from private.rad_idempotency where actor_id=inventory.approved_by and operation='visa-content-ingest' and request_key=(p_request->>'request_key')::uuid;
 if found then
  if prior.body_hash<>md5(p_request::text) then raise exception 'idempotency_conflict' using errcode='PT409'; end if;return prior.result;
 end if;
 if (select sum(octet_length(normalized_text)) from public.source_snapshots where id=any(ids))>1800000 or cardinality(ids)>100 then raise exception 'corpus_batch_too_large' using errcode='PT422'; end if;
 select min(d.language_code) into locale from public.source_snapshots ss join public.source_documents d on d.id=ss.document_id where ss.id=any(ids);
 if locale not in ('fa','en') or exists(select 1 from public.source_snapshots ss join public.source_documents d on d.id=ss.document_id where ss.id=any(ids) and d.language_code<>locale) then raise exception 'mixed_source_locales' using errcode='PT422'; end if;
 insert into public.visa_article_heads(article_id,locale) values(a.id,locale) on conflict do nothing;
 select * into h from public.visa_article_heads where article_id=a.id and visa_article_heads.locale=locale for update;
 select * into r from public.visa_article_revisions where id=h.head_id;
 if coalesce(r.revision,0)<>(p_request->>'expected_revision')::integer then raise exception 'revision_conflict' using errcode='PT409'; end if;
 idx:=0;
 for s in select ss.*,d.title,d.canonical_url,d.id document_id from public.source_snapshots ss join public.source_documents d on d.id=ss.document_id where ss.id=any(ids) order by ss.id loop
  perform private.rad_classify_snapshot(s.id);perform private.rad_check_ancestry(array[s.id]);
  if s.content_hash<>encode(extensions.digest(s.normalized_text,'sha256'),'hex') or nullif(btrim(s.normalized_text),'') is null then raise exception 'snapshot_checksum_or_content_invalid' using errcode='PT422'; end if;
  section_id:=extensions.uuid_generate_v5(a.id,s.document_id::text||':'||locale);blocks:='[]';v_offset:=0;
  while v_offset<char_length(s.normalized_text) loop
   piece:=substring(s.normalized_text from v_offset+1 for 12000);hash:=encode(extensions.digest(piece,'sha256'),'hex');fragment_id:=gen_random_uuid();
   target_section:=case when known ? hash then (known->hash->>'section_id')::uuid else section_id end;
   fragment:=jsonb_build_object('id',fragment_id,'snapshot_id',s.id,'publisher',(select publisher from private.visa_source_origins where snapshot_id=s.id),'source_hash',s.content_hash,
    'locator','characters:'||v_offset||'-'||(v_offset+char_length(piece)),'start_offset',v_offset,'end_offset',v_offset+char_length(piece),
    'disposition',case when known ? hash then 'duplicate' else 'retained' end,'target_section_id',target_section,
    'duplicate_of_fragment_id',case when known ? hash then known->hash->'fragment_id' else 'null'::jsonb end,'reason',case when known ? hash then 'Exact text duplicate' else '' end);
   fragments:=fragments||jsonb_build_array(fragment);
   if known ? hash then deduplicated:=deduplicated+1;
   else
    retained:=retained+1;known:=known||jsonb_build_object(hash,jsonb_build_object('fragment_id',fragment_id,'section_id',section_id));
    blocks:=blocks||jsonb_build_array(jsonb_build_object('id',extensions.uuid_generate_v5(section_id,v_offset::text),'type','paragraph','text',piece,'items','[]'::jsonb));
   end if;
   v_offset:=v_offset+char_length(piece);
  end loop;
  sections:=sections||jsonb_build_array(jsonb_build_object('id',section_id,'anchor','source-'||s.document_id,'heading',left(coalesce(nullif(s.title,''),a.slug),200),'order',idx,'blocks',blocks,'evidence_refs','[]'::jsonb));idx:=idx+1;
 end loop;
 insert into public.visa_merge_manifests(article_id,source_snapshot_ids,fragments,manifest_hash,complete)
 values(a.id,ids,fragments,encode(extensions.digest(fragments::text,'sha256'),'hex'),true) returning id into manifest;
 body:=jsonb_build_object('article_id',a.id,'locale',locale,'expected_revision',coalesce(r.revision,0),'title',coalesce(r.title,a.slug),'summary',coalesce(r.summary,''),'sections',sections,
 'related_article_ids',coalesce(r.body->'related_article_ids','[]'),'merge_manifest_id',manifest);
 if not private.rad_schema_valid((select schema from private.rad_contract_schemas where name='save_visa_article_draft_request'),body||jsonb_build_object('request_key',p_request->'request_key')) then raise exception 'content_contract_limit' using errcode='PT422'; end if;
 insert into public.visa_article_revisions(article_id,locale,revision,title,summary,content_hash,body,created_by)
 values(a.id,locale,coalesce(r.revision,0)+1,body->>'title',body->>'summary',encode(extensions.digest(body::text,'sha256'),'hex'),body,inventory.approved_by) returning id into draft;
 for fragment in select * from jsonb_array_elements(sections) loop
  insert into public.visa_article_sections values(draft,(fragment->>'id')::uuid,fragment->>'anchor',fragment->>'heading',(fragment->>'order')::integer,fragment->'blocks',fragment->'evidence_refs');
 end loop;
 insert into public.visa_article_revision_events(revision_id,state,actor_id,note) values(draft,'draft',inventory.approved_by,'Worker ingestion; no human review or factual verification');
 update public.visa_article_heads set head_id=draft where article_id=a.id and visa_article_heads.locale=locale;
 result:=private.rad_envelope(jsonb_build_object('draft',private.rad_revision_result(draft),'manifest_id',manifest),locale);
 insert into private.rad_idempotency(actor_id,operation,request_key,body_hash,result) values(inventory.approved_by,'visa-content-ingest',(p_request->>'request_key')::uuid,md5(p_request::text),result);
 return result;
end $$;
revoke all on function public.ingest_visa_snapshots(jsonb) from public,anon,authenticated;
grant execute on function public.ingest_visa_snapshots(jsonb) to service_role;

-- Publication rechecks exact fragment preservation after all editorial edits.
create function private.rad_check_main_publication() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;m public.visa_merge_manifests;f jsonb;source text;target text;inventory private.visa_source_inventories;
begin
 if new.published_id is null or new.published_id is not distinct from old.published_id then return new; end if;
 if not exists(select 1 from public.visa_articles where id=new.article_id and kind='main') then return new; end if;
 select * into r from public.visa_article_revisions where id=new.published_id;
 select * into m from public.visa_merge_manifests where id=(r.body->>'merge_manifest_id')::uuid and article_id=new.article_id;
 select * into inventory from private.visa_source_inventories where article_id=new.article_id order by revision desc limit 1;
 if m.id is null or not m.complete or inventory.snapshot_ids is distinct from m.source_snapshot_ids then raise exception 'complete_inventory_required' using errcode='PT422'; end if;
 perform private.rad_check_ancestry(m.source_snapshot_ids);
 for f in select * from jsonb_array_elements(m.fragments) loop
  select substring(normalized_text from (f->>'start_offset')::integer+1 for (f->>'end_offset')::integer-(f->>'start_offset')::integer) into source from public.source_snapshots where id=(f->>'snapshot_id')::uuid;
  select private.rad_blocks_text(blocks) into target from public.visa_article_sections where revision_id=r.id and id=(f->>'target_section_id')::uuid;
  if nullif(source,'') is null or target is null or position(source in target)=0 then raise exception 'unique_fragment_lost' using errcode='PT422'; end if;
 end loop;
 return new;
end $$;
create trigger rad_main_publication_manifest before update of published_id on public.visa_article_heads for each row execute function private.rad_check_main_publication();

alter table private.rad_research_jobs add column lease_token uuid,add column lease_until timestamptz,add column attempts integer not null default 0;
create function public.claim_official_research_job() returns jsonb language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 select * into j from private.rad_research_jobs where attempts<3 and (status='queued' or (status='running' and lease_until<now())) order by created_at,id for update skip locked limit 1;
 if not found then return null; end if;
 update private.rad_research_jobs set status='running',attempts=attempts+1,lease_token=gen_random_uuid(),lease_until=now()+interval '60 seconds',updated_at=now() where id=j.id returning * into j;
 return jsonb_build_object('job_id',j.id,'lease_token',j.lease_token,'kind',j.kind,'request',j.request);
end $$;
create function public.get_official_research_job(p_job_id uuid,p_lease_token uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 select * into j from private.rad_research_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>now() and status='running';
 if not found then raise exception 'lease_invalid' using errcode='PT409'; end if;
 return jsonb_build_object('job_id',j.id,'kind',j.kind,'request',j.request);
end $$;
create function public.finish_official_research_job(p_job_id uuid,p_lease_token uuid,p_candidates jsonb,p_safe_code text default null) returns boolean language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;c jsonb;id uuid;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 select * into j from private.rad_research_jobs where rad_research_jobs.id=p_job_id and lease_token=p_lease_token and lease_until>now() and status='running' for update;
 if not found then raise exception 'lease_invalid' using errcode='PT409'; end if;
 if p_safe_code is not null and p_safe_code not in ('discovery_unavailable','protected_egress_unavailable','authority_verification_required','source_unavailable','worker_failed') then raise exception 'invalid_error' using errcode='PT422'; end if;
 if jsonb_typeof(p_candidates)<>'array' or jsonb_array_length(p_candidates)>20 or (j.kind<>'authority_discovery' and jsonb_array_length(p_candidates)>0) then raise exception 'invalid_candidates' using errcode='PT422'; end if;
 for c in select * from jsonb_array_elements(p_candidates) loop
  if nullif(c->>'name','') is null or char_length(c->>'name')>300 or c->>'host' !~ '^[a-z0-9][a-z0-9.-]{1,252}$' or c ? 'verification_state' or c ? 'verified' then raise exception 'invalid_candidate' using errcode='PT422'; end if;
  insert into private.authority_entities(name,authority_type,country_code,jurisdiction,competence_topics)
  values(c->>'name','other_competent_body',j.request->>'country_code',j.request->>'country_code',array[j.request->>'topic']) returning authority_entities.id into id;
  insert into private.authority_domains(authority_id,host) values(id,c->>'host');
 end loop;
 update private.rad_research_jobs set status=case when p_safe_code is null then 'succeeded' else 'failed' end,safe_error_code=p_safe_code,lease_token=null,lease_until=null,updated_at=now() where rad_research_jobs.id=p_job_id;
 return true;
end $$;
revoke all on function public.claim_official_research_job(),public.get_official_research_job(uuid,uuid),public.finish_official_research_job(uuid,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.claim_official_research_job(),public.get_official_research_job(uuid,uuid),public.finish_official_research_job(uuid,uuid,jsonb,text) to service_role;
commit;
