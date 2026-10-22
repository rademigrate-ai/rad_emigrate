begin;
alter function public.consume_ai_guest_quota(text,integer) set search_path='';
-- Exact reviewed R03 effect; no historical migration replay.
create or replace function public.create_user_notification(p_user_id uuid,p_type text,p_title text,p_body text,p_action_path text default null,p_source_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare id uuid;kind text:=coalesce(nullif(btrim(p_type),''),'system');
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' and not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
 if p_user_id is null or nullif(btrim(p_title),'') is null or nullif(btrim(p_body),'') is null or char_length(p_title)>200 or char_length(p_body)>4000
 or kind not in ('feed','application','document','system') or (p_action_path is not null and (p_action_path not like '/%' or p_action_path like '//%' or position(chr(92) in p_action_path)>0 or p_action_path ~ '[[:cntrl:]]' or char_length(p_action_path)>1000)) then raise exception 'invalid_notification' using errcode='22023'; end if;
 insert into public.notifications(user_id,type,title,body,action_path,source_id) values(p_user_id,kind,btrim(p_title),p_body,p_action_path,p_source_id) returning notifications.id into id;
 return id;
end $$;
revoke all on function public.create_user_notification(uuid,text,text,text,text,uuid) from public,anon;
grant execute on function public.create_user_notification(uuid,text,text,text,text,uuid) to authenticated,service_role;
create index if not exists knowledge_claims_superseded_by_idx on public.knowledge_claims(superseded_by);
create index if not exists consultation_requests_assigned_to_idx on public.consultation_requests(assigned_to);
create index if not exists consultation_requests_related_application_id_idx on public.consultation_requests(related_application_id);

create table private.rad_capabilities(name text primary key,enabled boolean not null default false);
insert into private.rad_capabilities(name) values('content'),('research'),('currency'),('feed'),('search'),('copilot');
alter table private.rad_capabilities enable row level security;
revoke all on private.rad_capabilities from public,anon,authenticated,service_role;
create function public.get_backend_contract_status(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare flags jsonb;
begin
 perform private.rad_assert_request('get_backend_contract_status',p_request);
 select jsonb_object_agg(name,enabled) into flags from private.rad_capabilities;
 return private.rad_envelope(flags||jsonb_build_object('contract_versions',jsonb_build_array('1'),'minimum_client_contract','1'));
end $$;
revoke all on function public.get_backend_contract_status(jsonb) from public;
grant execute on function public.get_backend_contract_status(jsonb) to anon,authenticated;

create or replace function private.rad_job_json(j private.rad_research_jobs) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('job_id',j.id,'status',j.status,'deduplicated',false);
$$;

create function public.get_visa_merge_manifest(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.visa_merge_manifests;revision integer;documents jsonb;retained integer;deduplicated integer;
begin
 perform private.rad_require_admin();perform private.rad_assert_request('get_visa_merge_manifest',p_request);
 select * into m from public.visa_merge_manifests where id=(p_request->>'manifest_id')::uuid;
 if not found then raise exception 'not_found' using errcode='PT404'; end if;
 select min(r.revision) into revision from public.visa_article_revisions r where r.body->>'merge_manifest_id'=m.id::text;
 select jsonb_agg(distinct document_id) into documents from public.source_snapshots where id=any(m.source_snapshot_ids);
 select count(*) filter(where f->>'disposition'='retained'),count(*) filter(where f->>'disposition'='duplicate') into retained,deduplicated from jsonb_array_elements(m.fragments) f;
 return private.rad_envelope(jsonb_build_object('id',m.id,'article_id',m.article_id,'revision',coalesce(revision,1),'source_document_ids',documents,'snapshot_ids',to_jsonb(m.source_snapshot_ids),
 'fragment_count',jsonb_array_length(m.fragments),'retained_count',retained,'deduplicated_count',deduplicated,'unresolved_count',0,'manifest_hash',m.manifest_hash,'complete',m.complete,'fragments',m.fragments));
end $$;
revoke all on function public.get_visa_merge_manifest(jsonb) from public,anon,service_role;
grant execute on function public.get_visa_merge_manifest(jsonb) to authenticated;

create function public.list_research_proposals(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;version text;off integer;lim integer:=(p_request->>'limit')::integer;total integer;
begin
 perform private.rad_require_admin();perform private.rad_assert_request('list_research_proposals',p_request);
 select md5(coalesce(string_agg(id::text||revision::text,',' order by id),'')) into version from public.visa_research_proposals;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 with visible as(select * from public.visa_research_proposals p where (p_request->>'article_id' is null or p.article_id=(p_request->>'article_id')::uuid)
 and (p_request->>'editorial_state' is null or p.state=p_request->>'editorial_state') and (p_request->>'verification_state' is null or p_request->>'verification_state'='unverified')),
 page as(select * from visible order by created_at desc,id desc offset off limit lim)
 select (select count(*) from visible),coalesce(jsonb_agg(private.rad_proposal_json(p) order by p.created_at desc,p.id desc),'[]') into total,result from page p;
 return private.rad_envelope(jsonb_build_object('items',result),null,private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
revoke all on function public.list_research_proposals(jsonb) from public,anon,service_role;
grant execute on function public.list_research_proposals(jsonb) to authenticated;

alter table public.currency_alerts add column deleted_at timestamptz;
create function public.list_currency_alerts(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=private.rad_require_owner();result jsonb;version text;off integer;lim integer:=(p_request->>'limit')::integer;total integer;
begin
 perform private.rad_assert_request('list_currency_alerts',p_request);
 select md5(coalesce(string_agg(id::text||revision::text,',' order by id),'')) into version from public.currency_alerts where user_id=owner and deleted_at is null;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 select count(*) into total from public.currency_alerts where user_id=owner and deleted_at is null;
 select coalesce(jsonb_agg(private.rad_alert_json(a) order by a.created_at,a.id),'[]') into result from (
 select * from public.currency_alerts where user_id=owner and deleted_at is null order by created_at,id offset off limit lim) a;
 return private.rad_envelope(jsonb_build_object('items',result),null,private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
revoke all on function public.list_currency_alerts(jsonb) from public,anon,service_role;
grant execute on function public.list_currency_alerts(jsonb) to authenticated;

-- Revised aggregation preserves the six factual states and expires trust at read time.
create or replace function private.rad_article_verification(revision uuid) returns text language sql stable security definer set search_path='' as $$
 with refs as(select e->>'claim_id' claim_id from public.visa_article_sections s cross join lateral jsonb_array_elements(s.evidence_refs) e where s.revision_id=$1),
 states as(select case
  when k.factual_status='verified' and private.rad_claim_eligible(k.id) then 'verified'
  when exists(select 1 from private.claim_official_evidence where claim_id=k.id and conflicting) then 'conflicting'
  when k.factual_status='verified' and exists(select 1 from private.claim_official_evidence where claim_id=k.id and fresh_until<=now()) then 'outdated'
  when k.factual_status in ('incorrect','incomplete','outdated','conflicting') then k.factual_status else 'unverified' end state
  from refs left join public.knowledge_claims k on k.id=refs.claim_id::uuid
  union all select 'unverified' from public.visa_article_sections where revision_id=$1 and jsonb_array_length(evidence_refs)=0)
 select coalesce((select state from states order by case state when 'conflicting' then 0 when 'incorrect' then 1 when 'outdated' then 2 when 'incomplete' then 3 when 'unverified' then 4 else 5 end limit 1),'unverified');
$$;

create function public.verify_official_claim(p_claim_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare state text;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 if not exists(select 1 from public.knowledge_claims where id=p_claim_id) then raise exception 'not_found' using errcode='PT404'; end if;
 state:=case when private.rad_claim_eligible(p_claim_id) then 'verified'
  when exists(select 1 from private.claim_official_evidence where claim_id=p_claim_id and conflicting) then 'conflicting'
  when exists(select 1 from private.claim_official_evidence where claim_id=p_claim_id and fresh_until<=now()) then 'outdated' else 'unverified' end;
 update public.knowledge_claims set factual_status=state where id=p_claim_id;
 return jsonb_build_object('claim_id',p_claim_id,'verification_state',state);
end $$;
revoke all on function public.verify_official_claim(uuid) from public,anon,authenticated;
grant execute on function public.verify_official_claim(uuid) to service_role;
notify pgrst,'reload schema';
commit;
