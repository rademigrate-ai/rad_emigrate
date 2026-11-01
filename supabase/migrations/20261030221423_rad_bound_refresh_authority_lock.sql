begin;
-- The worker must not commit evidence using a root revoked while it waited for
-- the article head. Shared proof locks linearize capture against revocation.
create or replace function private.rad_lock_bound_refresh_authority(binding private.rad_official_refresh_bindings,source_url text) returns void
language plpgsql set search_path='' set lock_timeout='5s' as $$
begin
 -- Shared locks retain the exact successful source/proof context until commit.
 -- The query is repeated before final target completion to check wall-clock
 -- expiry too. Conflicting Admin writes time out or retry; partial evidence rolls back.
 perform proof.id from public.research_sources src
 join public.source_documents doc on doc.id=binding.document_id
 join public.visa_articles article on article.id=binding.article_id
 join private.authority_entities authority on authority.id=binding.authority_id
 join private.authority_domains domain on domain.authority_id=authority.id
 join private.authority_proofs proof on proof.domain_id=domain.id
 join private.authority_trust_roots root on root.id=proof.root_id
 where src.id=binding.source_id and src.enabled and src.runtime_scope in('admin','both')
 and src.base_url=doc.canonical_url and src.country_code=article.country_code and src.topic=article.pathway_slug
 and doc.validation_status='validated' and doc.removed_at is null and doc.source_authority<>'rad_official'
 and src.allowed_host=domain.host and private.is_safe_public_https_url(source_url)
 and private.rad_bound_path_allowed(source_url,src.allowed_host,domain.path_prefix)
 and authority.state='verified' and authority.country_code=article.country_code and authority.jurisdiction=article.country_code
 and article.pathway_slug=any(authority.competence_topics) and authority.expires_at>clock_timestamp()
 and domain.state='verified' and domain.expires_at>clock_timestamp() and proof.domain_revision=domain.revision
 and proof.scope_topic=article.pathway_slug and proof.jurisdiction=article.country_code and proof.profession='*'
 and proof.revoked_at is null and proof.expires_at>clock_timestamp() and root.active and root.expires_at>clock_timestamp()
 order by proof.id
 for share of src,doc,article,authority,domain,proof,root;
 if not found then raise exception 'official_binding_evidence_required' using errcode='PT422';end if;
end $$;
revoke all on function private.rad_lock_bound_refresh_authority(private.rad_official_refresh_bindings,text) from public,anon,authenticated,service_role;

create or replace function public.ingest_bound_official_refresh(p_job_id uuid,p_lease_token uuid,p_binding_id uuid,p_expected_revision_id uuid,p_expected_snapshot_id uuid,
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
 -- Lock proof ownership only after the article head is acquired. A revocation
 -- that committed while that head was locked must be observed before evidence.
 perform private.rad_lock_bound_refresh_authority(b,p_final_url);
 if target.source_url is distinct from (select canonical_url from public.source_documents where id=b.document_id) then
  raise exception 'frozen_target_conflict' using errcode='PT409';end if;
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

create or replace function private.rad_complete_bound_target(p_job_id uuid,p_lease_token uuid,p_binding_id uuid,p_snapshot_id uuid,p_result jsonb,p_raw bytea,p_final_url text) returns void
language plpgsql set search_path='' as $$
declare source uuid;progress integer;binding private.rad_official_refresh_bindings;begin
 select * into binding from private.rad_official_refresh_bindings where id=p_binding_id;
 perform private.rad_lock_bound_refresh_authority(binding,p_final_url);
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

commit;
