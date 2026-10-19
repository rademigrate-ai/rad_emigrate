begin;
-- Retain G-002's legacy proposal table but remove its implicit direct write path.
revoke all on public.research_proposals from public,anon,authenticated;
grant select on public.research_proposals to authenticated;

create function public.list_visa_article_revisions(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare items jsonb; version text; off integer; lim integer:=(p_request->>'limit')::integer; total integer;
begin
 perform private.rad_require_admin();perform private.rad_assert_request('list_visa_article_revisions',p_request);
 select head_id::text into version from public.visa_article_heads where article_id=(p_request->>'article_id')::uuid and locale=p_request->>'locale';
 version:=coalesce(version,'empty');off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 select count(*) into total from public.visa_article_revisions where article_id=(p_request->>'article_id')::uuid and locale=p_request->>'locale';
 select coalesce(jsonb_agg(jsonb_build_object('revision_id',r.id,'revision',r.revision,'locale',r.locale,'content_hash',r.content_hash,
  'editorial_state',private.rad_article_state(r.id),'verification_state',private.rad_article_verification(r.id),
  'created_at',to_char(r.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'created_by',r.created_by,
  'reviewed_at',case when e.created_at is null then null else to_char(e.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,
  'reviewed_by',e.actor_id,'reason',e.note) order by r.revision desc),'[]') into items
 from (select * from public.visa_article_revisions where article_id=(p_request->>'article_id')::uuid and locale=p_request->>'locale' order by revision desc offset off limit lim) r
 left join lateral (select * from public.visa_article_revision_events where revision_id=r.id and state in ('approved','rejected') order by sequence desc limit 1) e on true;
 return private.rad_envelope(jsonb_build_object('items',items),p_request->>'locale',private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;

create function private.rad_job_json(j private.rad_research_jobs) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('job_id',j.id,'kind',j.kind,'status',j.status,
 'created_at',to_char(j.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'updated_at',to_char(j.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'safe_error_code',j.safe_error_code);
$$;
create function public.get_rad_job_status(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;
begin
 perform private.rad_require_owner();perform private.rad_assert_request('get_rad_job_status',p_request);
 select * into j from private.rad_research_jobs where id=(p_request->>'job_id')::uuid and (created_by=auth.uid() or private.has_role(array['admin','super_admin']));
 if not found then raise exception 'not_found' using errcode='PT404'; end if;
 return private.rad_envelope(private.rad_job_json(j));
end $$;
create function private.rad_enqueue_research(operation text,body jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare prior jsonb;j private.rad_research_jobs;
begin
 perform private.rad_require_admin();prior:=private.rad_begin_mutation(operation,body);if prior is not null then return prior; end if;
 if operation='enqueue_research_refresh' and exists(select 1 from jsonb_array_elements_text(body->'authority_ids') i where not exists(select 1 from private.authority_entities where id=i::uuid)) then raise exception 'unknown_authority' using errcode='PT422'; end if;
 insert into private.rad_research_jobs(kind,request,created_by,status,safe_error_code)
 values(case operation when 'discover_official_authorities' then 'authority_discovery' else 'research_refresh' end,body-'request_key',auth.uid(),'queued',null) returning * into j;
 return private.rad_finish_mutation(operation,body,private.rad_envelope(private.rad_job_json(j)));
end $$;
create function public.discover_official_authorities(p_request jsonb) returns jsonb language sql security definer set search_path='' as $$ select private.rad_enqueue_research('discover_official_authorities',p_request); $$;
create function public.enqueue_research_refresh(p_request jsonb) returns jsonb language sql security definer set search_path='' as $$ select private.rad_enqueue_research('enqueue_research_refresh',p_request); $$;

create function private.rad_authority_json(a private.authority_entities) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',a.id,'name',a.name,'authority_type',a.authority_type,'country_code',a.country_code,'jurisdiction',a.jurisdiction,
 'competence_topics',to_jsonb(a.competence_topics),'official_domains',(select coalesce(jsonb_agg(distinct host),'[]') from private.authority_domains where authority_id=a.id and state='verified' and expires_at>now()),
 'verification_state',case when a.state='verified' and a.expires_at<=now() then 'expired' else a.state end,'verification_revision',a.revision,
 'verified_at',case when a.verified_at is null then null else to_char(a.verified_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,
 'expires_at',case when a.expires_at is null then null else to_char(a.expires_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end);
$$;
create function public.list_official_authorities(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; off integer;lim integer:=(p_request->>'limit')::integer;version text;total integer;
begin
 perform private.rad_require_admin();perform private.rad_assert_request('list_official_authorities',p_request);
 select md5(coalesce(string_agg(id::text||revision::text||state,',' order by id),'')) into version from private.authority_entities;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 select count(*) into total from private.authority_entities a where (p_request->>'country_code' is null or a.country_code=p_request->>'country_code') and (p_request->>'topic' is null or p_request->>'topic'=any(a.competence_topics)) and (p_request->>'state' is null or a.state=p_request->>'state');
 select coalesce(jsonb_agg(private.rad_authority_json(a) order by a.name,a.id),'[]') into result from (
 select * from private.authority_entities a where (p_request->>'country_code' is null or a.country_code=p_request->>'country_code') and (p_request->>'topic' is null or p_request->>'topic'=any(a.competence_topics)) and (p_request->>'state' is null or a.state=p_request->>'state') order by name,id offset off limit lim) a;
 return private.rad_envelope(jsonb_build_object('items',result),null,private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;

create function private.rad_proposal_json(p public.visa_research_proposals) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',p.id,'revision',p.revision,'target_article_id',p.article_id,'base_revision',p.base_revision,
 'old_snapshot_id',p.old_snapshot_id,'new_snapshot_id',p.new_snapshot_id,'authority_id',p.authority_id,'changes',p.changes,
 'evidence','[]'::jsonb,'verification_state','unverified','editorial_state',p.state,
 'created_at',to_char(p.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'reviewed_at',case when p.reviewed_at is null then null else to_char(p.reviewed_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,'reviewed_by',p.reviewed_by);
$$;
create function public.get_research_proposal(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.visa_research_proposals;
begin
 perform private.rad_require_admin();perform private.rad_assert_request('get_research_proposal',p_request);
 select * into p from public.visa_research_proposals where id=(p_request->>'proposal_id')::uuid;
 if not found then raise exception 'not_found' using errcode='PT404'; end if;
 return private.rad_envelope(private.rad_proposal_json(p),p.locale);
end $$;
create function public.review_research_proposal(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.visa_research_proposals; r public.visa_article_revisions; h public.visa_article_heads; prior jsonb; id uuid; result jsonb;
begin
 perform private.rad_require_admin();prior:=private.rad_begin_mutation('review_research_proposal',p_request);if prior is not null then return prior; end if;
 select * into p from public.visa_research_proposals where visa_research_proposals.id=(p_request->>'proposal_id')::uuid for update;
 if not found then raise exception 'not_found' using errcode='PT404'; end if;
 if p.revision<>(p_request->>'expected_revision')::integer or p.state<>'review' then raise exception 'proposal_conflict' using errcode='PT409'; end if;
 if p_request->>'decision'='reject' then
  if nullif(btrim(p_request->>'note'),'') is null then raise exception 'rejection_note_required' using errcode='PT422'; end if;
  update public.visa_research_proposals set state='rejected',revision=revision+1,reviewed_at=now(),reviewed_by=auth.uid() where visa_research_proposals.id=p.id returning * into p;
  result:=private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),'draft_revision',null),p.locale);
 else
  select * into h from public.visa_article_heads where article_id=p.article_id and locale=p.locale for update;
  select * into r from public.visa_article_revisions where visa_article_revisions.id=h.head_id;
  if r.revision is distinct from p.base_revision then raise exception 'revision_conflict' using errcode='PT409'; end if;
  id:=private.rad_save_article(r.body||jsonb_build_object('sections',p.new_sections,'expected_revision',p.base_revision,'request_key',p_request->'request_key'));
  update public.visa_research_proposals set state='approved',revision=revision+1,reviewed_at=now(),reviewed_by=auth.uid() where visa_research_proposals.id=p.id returning * into p;
  result:=private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),'draft_revision',private.rad_revision_result(id)),p.locale);
 end if;
 return private.rad_finish_mutation('review_research_proposal',p_request,result);
end $$;

create function public.retrieve_verified_official_claims(p_query text,p_locale text,p_country_code text default null,p_topic text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare results jsonb;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 if char_length(p_query) not between 1 and 500 or p_locale not in ('fa','en') then raise exception 'invalid_query' using errcode='PT422'; end if;
 select coalesce(jsonb_agg(row),'[]') into results from (
  select k.id claim_id,k.claim_text,c.id citation_id,c.excerpt,c.locator,s.id snapshot_id,s.content_hash,d.canonical_url url,a.name authority,a.id authority_id,'verified'::text verification_state,
   a.jurisdiction,e.topic,e.fresh_until,e.verified_at
  from public.knowledge_claims k join private.claim_official_evidence e on e.claim_id=k.id
  join public.knowledge_citations c on c.id=e.citation_id join public.source_snapshots s on s.id=c.snapshot_id
  join public.source_documents d on d.id=s.document_id join private.authority_proofs proof on proof.id=e.proof_id
  join private.authority_domains domain on domain.id=proof.domain_id join private.authority_entities a on a.id=domain.authority_id
  where k.factual_status='verified' and k.locale=p_locale and private.rad_claim_eligible(k.id)
   and (p_country_code is null or a.country_code=p_country_code) and (p_topic is null or e.topic=p_topic)
   and to_tsvector('simple',k.claim_text) @@ plainto_tsquery('simple',p_query)
   and exists(select 1 from public.visa_article_heads h join public.visa_article_sections sec on sec.revision_id=h.published_id
    where sec.evidence_refs @> jsonb_build_array(jsonb_build_object('claim_id',k.id)))
  order by k.id,c.id limit 8
 ) row;
 return jsonb_build_object('results',results,'evidence_state',case when jsonb_array_length(results)>0 then 'verified' else 'insufficient' end);
end $$;
revoke all on function public.retrieve_verified_official_claims(text,text,text,text) from public,anon,authenticated;
grant execute on function public.retrieve_verified_official_claims(text,text,text,text) to service_role;

do $$ declare f text; begin
 foreach f in array array['list_visa_article_revisions','get_rad_job_status','discover_official_authorities','enqueue_research_refresh','list_official_authorities','get_research_proposal','review_research_proposal'] loop
  execute format('revoke all on function public.%I(jsonb) from public,anon,service_role',f);
  execute format('grant execute on function public.%I(jsonb) to authenticated',f);
 end loop;
end $$;
notify pgrst,'reload schema';
commit;
