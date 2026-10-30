-- Synthetic fixtures; rollback all test data. No legal verification/publication.
begin;
insert into public.destinations(code,slug) values('ZZ','bound-refresh-synthetic') on conflict(code) do nothing;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('81000000-0000-4000-8000-000000000001','stage71-admin@example.invalid'),
 ('81000000-0000-4000-8000-000000000002','stage71-user@example.invalid');
update public.profiles set role='admin' where id='81000000-0000-4000-8000-000000000001';
insert into public.source_documents(id,canonical_url,source_authority,title,language_code,validation_status)
values('81000000-0000-4000-8000-000000000050','https://bound-refresh.example.org/info','other','SYNTHETIC ONLY','en','candidate');
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status,fetched_at)
values('81000000-0000-4000-8000-000000000052','81000000-0000-4000-8000-000000000050','BEGIN_SOURCE baseline original language END_SOURCE',encode(extensions.digest('BEGIN_SOURCE baseline original language END_SOURCE','sha256'),'hex'),200,now()-interval '1 day');
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status,fetched_at)
values('81000000-0000-4000-8000-000000000053','81000000-0000-4000-8000-000000000050','SYNTHETIC fixture 2.',encode(extensions.digest('SYNTHETIC fixture 2.','sha256'),'hex'),200,now()-interval '1 day');
insert into private.authority_entities(id,name,authority_type,country_code,jurisdiction,state)
values('81000000-0000-4000-8000-000000000060','SYNTHETIC candidate','government','ZZ','ZZ','candidate');
insert into private.authority_domains(authority_id,host,path_prefix,state)
values('81000000-0000-4000-8000-000000000060','bound-refresh.example.org','/info','candidate');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"81000000-0000-4000-8000-000000000001"}',true);
select public.create_visa_article('{"article_id":"81000000-0000-4000-8000-000000000010","kind":"related","country_code":"ZZ","pathway_slug":"synthetic","slug":"bound-refresh-synthetic","request_key":"81000000-0000-4000-8000-000000000100"}');
create temporary table rich_test_state(name text primary key,value jsonb);
do $$declare sections jsonb;body jsonb;r uuid;projection jsonb;source uuid;ctx jsonb;patches jsonb;req jsonb;response jsonb;begin
 sections:='[
 {"id":"81000000-0000-4000-8000-000000000020","heading":"SYNTHETIC unchanged","blocks":[
 {"id":"81000000-0000-4000-8000-000000000030","type":"paragraph","text":"SYNTHETIC original coverage فارسی preserved","original_structure":{"type":"paragraph","text":"SYNTHETIC original coverage فارسی preserved","links":[{"href":"https://example.org/source","text":"Source"}]},"provenance":[{"snapshot_id":"81000000-0000-4000-8000-000000000052","start":0,"end":29}]}]},
 {"id":"81000000-0000-4000-8000-000000000021","heading":"SYNTHETIC changes","blocks":[
 {"id":"81000000-0000-4000-8000-000000000031","type":"table","text":"SYNTHETIC cell stable","original_structure":{"type":"table","caption":"SYNTHETIC table","rows":[[{"text":"SYNTHETIC cell","header":true,"colspan":2,"rowspan":1}],[{"text":"stable","header":false,"colspan":1,"rowspan":1}]]},"provenance":[]},
 {"id":"81000000-0000-4000-8000-000000000032","type":"bullet_list","text":"SYNTHETIC parent child","original_structure":{"type":"bullet_list","items":[{"text":"SYNTHETIC parent","children":[{"ordered":true,"items":[{"text":"SYNTHETIC child","children":[]}]}]}]},"provenance":[]},
 {"id":"81000000-0000-4000-8000-000000000033","type":"paragraph","text":"SYNTHETIC remove","original_structure":{"type":"paragraph","text":"SYNTHETIC remove"},"provenance":[]},
 {"id":"81000000-0000-4000-8000-000000000034","type":"paragraph","text":"SYNTHETIC reject change","original_structure":{"type":"paragraph","text":"SYNTHETIC reject change"},"provenance":[]},
 {"id":"81000000-0000-4000-8000-000000000035","type":"paragraph","text":"SYNTHETIC insertion anchor","original_structure":{"type":"paragraph","text":"SYNTHETIC insertion anchor"},"provenance":[]}
 ]}]';
 body:=jsonb_build_object('article_id','81000000-0000-4000-8000-000000000010','locale','en','expected_revision',0,'title','SYNTHETIC rich page','summary','SYNTHETIC only','related_article_ids','[]'::jsonb,'merge_manifest_id',null,'request_key',gen_random_uuid(),'sections','[]'::jsonb);
 projection:=private.rad_project_rich(sections,'[]',body);
 body:=body||jsonb_build_object('sections',projection->'sections');
 perform public.save_visa_article_draft(body);
 select head_id into r from public.visa_article_heads where article_id='81000000-0000-4000-8000-000000000010' and locale='en';
 insert into private.rad_editorial_rich_revisions values(r,jsonb_build_object('sections',sections,'projection_map',projection->'projection_map','source_ids',jsonb_build_array('synthetic-source')));
 insert into private.rad_editorial_reference_maps(revision_id,input_hash,source_manifest_hash,content) values(r,repeat('1',64),repeat('2',64),jsonb_build_object('capture_status','complete','sources','[]'::jsonb,'links',jsonb_build_array(jsonb_build_object('href','https://example.org/source','target_block_id','81000000-0000-4000-8000-000000000033','target_anchor','removed'))));
 -- Independent locale head must remain untouched.
 perform public.save_visa_article_draft(body||jsonb_build_object('locale','fa','request_key',gen_random_uuid()));
 response:=public.upsert_editorial_research_source(jsonb_build_object('source_id',null,'display_name','SYNTHETIC research source','base_url','https://bound-refresh.example.org/info','source_type','admin_reference','country_code','ZZ','visa_category','synthetic','request_key',gen_random_uuid()));
 source:=(response->'data'->>'source_id')::uuid;
 ctx:=public.get_structured_article_context('81000000-0000-4000-8000-000000000010','en')->'data';

 update public.source_documents set validation_status='validated' where id='81000000-0000-4000-8000-000000000050';
 update public.research_sources set enabled=true,runtime_scope='admin' where id=source;
 update private.authority_entities set state='verified',verified_at=now(),expires_at=now()+interval '1 day',competence_topics=array['synthetic'] where id='81000000-0000-4000-8000-000000000060';
 update private.authority_domains set state='verified',verified_at=now(),expires_at=now()+interval '1 day' where authority_id='81000000-0000-4000-8000-000000000060';
 insert into private.authority_trust_roots(id,policy_version,proof,approved_by,approved_at,expires_at,active)
 values('81000000-0000-4000-8000-000000000061','SYNTHETIC LOCAL ONLY','{}','81000000-0000-4000-8000-000000000001',now(),now()+interval '1 day',true);
 insert into private.authority_proofs(domain_id,root_id,domain_revision,scope_topic,jurisdiction,profession,proof_hash,ownership_snapshot_id,competence_snapshot_id,verified_at,expires_at)
 select id,'81000000-0000-4000-8000-000000000061',revision,'synthetic','ZZ','*',repeat('a',64),'81000000-0000-4000-8000-000000000052','81000000-0000-4000-8000-000000000052',now(),now()+interval '1 day' from private.authority_domains where authority_id='81000000-0000-4000-8000-000000000060';
 response:=public.create_official_refresh_binding('81000000-0000-4000-8000-000000000080',source,'81000000-0000-4000-8000-000000000050','81000000-0000-4000-8000-000000000060',
 '81000000-0000-4000-8000-000000000010','en','81000000-0000-4000-8000-000000000021','81000000-0000-4000-8000-000000000035','BEGIN_SOURCE','END_SOURCE','81000000-0000-4000-8000-000000000052',(ctx->>'revision_id')::uuid);
 insert into rich_test_state values('base',ctx),('sections',sections),('source',to_jsonb(source)),('fa',(select to_jsonb(h) from public.visa_article_heads h where article_id='81000000-0000-4000-8000-000000000010' and locale='fa'));
end $$;
insert into private.rad_research_jobs(id,kind,request,created_by,status,lease_token,lease_until,attempts)
values('81000000-0000-4000-8000-000000000090','research_refresh','{"authority_ids":["81000000-0000-4000-8000-000000000060"]}',
 '81000000-0000-4000-8000-000000000001','running','81000000-0000-4000-8000-000000000091',now()+interval '5 minutes',1);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
create function pg_temp.refresh_text(value text,prior_snapshot uuid default null,revision uuid default null) returns jsonb language plpgsql as $$
declare target jsonb;job_id uuid;token uuid;stored jsonb;begin
 if prior_snapshot is null then
  job_id:=gen_random_uuid();token:=gen_random_uuid();
  insert into private.rad_research_jobs(id,kind,request,created_by,status,lease_token,lease_until,attempts)
  values(job_id,'research_refresh','{"authority_ids":["81000000-0000-4000-8000-000000000060"]}','81000000-0000-4000-8000-000000000001','running',token,clock_timestamp()+interval '5 minutes',1);
  target:=public.get_bound_official_refresh_targets(job_id,token)->0;
  insert into rich_test_state values('last_lease',jsonb_build_object('job_id',job_id,'token',token,'target',target)) on conflict(name) do update set value=excluded.value;
 else
  select state.value into stored from rich_test_state state where name='last_lease';job_id:=(stored->>'job_id')::uuid;token:=(stored->>'token')::uuid;target:=stored->'target';
 end if;
 return public.ingest_bound_official_refresh(job_id,token,'81000000-0000-4000-8000-000000000080',
 coalesce(revision,(target->>'expected_revision_id')::uuid),coalesce(prior_snapshot,(target->>'expected_snapshot_id')::uuid),value,encode(convert_to(value,'UTF8'),'base64'),'https://bound-refresh.example.org/info',200);
end $$;

do $$declare result jsonb;retry jsonb;prior uuid;snapshots integer;begin
 select count(*) into snapshots from public.source_snapshots;
 result:=pg_temp.refresh_text('NAV CHANGED BEGIN_SOURCE baseline original language END_SOURCE FOOTER');
 assert (result->>'changed')::boolean=false and result->>'proposal_id' is null,'page navigation must not create legal-change noise';
 assert (select count(*) from public.source_snapshots)=snapshots+1,'complete changed normalized snapshot must be retained';
 prior:=(result->>'snapshot_id')::uuid;
 result:=pg_temp.refresh_text('NAV CHANGED BEGIN_SOURCE exact new source wording END_SOURCE FOOTER');
 assert (result->>'changed')::boolean and result->>'proposal_id' is not null,'bound changed source fragment must create review proposal';
 retry:=pg_temp.refresh_text('NAV CHANGED BEGIN_SOURCE exact new source wording END_SOURCE FOOTER',prior);
 assert retry=result,'ambiguous network-result exact retry must return same proposal';
 assert (select count(*) from public.visa_research_proposals)=1,'retry cannot duplicate proposal';
 insert into rich_test_state values('proposal',result),('prior',to_jsonb(prior));
 begin perform pg_temp.refresh_text('BEGIN_SOURCE ambiguous BEGIN_SOURCE second END_SOURCE');raise exception 'FAIL ambiguous markers';exception when sqlstate 'PT422' then null;end;
 begin perform pg_temp.refresh_text('missing source markers');raise exception 'FAIL missing markers';exception when sqlstate 'PT422' then null;end;
 begin perform pg_temp.refresh_text('BEGIN_SOURCE oversized '||repeat('x',4000)||' END_SOURCE');raise exception 'FAIL truncated oversized fragment';exception when sqlstate 'PT422' then null;end;
 begin perform pg_temp.refresh_text('BEGIN_SOURCE stale observation END_SOURCE',prior);raise exception 'FAIL stale source snapshot';exception when sqlstate 'PT409' then null;end;
 begin perform pg_temp.refresh_text('BEGIN_SOURCE wrong head END_SOURCE',null,gen_random_uuid());raise exception 'FAIL stale article head';exception when sqlstate 'PT409' then null;end;
 assert not has_function_privilege('service_role','public.save_structured_research_review(jsonb)','EXECUTE'),'worker may not approve or create drafts';
 assert not has_function_privilege('service_role','public.propose_structured_research(jsonb)','EXECUTE'),'do not relax Admin-only proposal API';
 assert not has_function_privilege('service_role','public.create_official_refresh_binding(uuid,uuid,uuid,uuid,uuid,text,uuid,uuid,text,text,uuid,uuid)','EXECUTE'),'worker may not invent source bindings';
 assert not has_function_privilege('authenticated','public.ingest_bound_official_refresh(uuid,uuid,uuid,uuid,uuid,text,text,text,integer)','EXECUTE'),'clients may not ingest protected evidence';
end $$;
update private.authority_trust_roots set active=false where id='81000000-0000-4000-8000-000000000061';
do $$begin
 begin perform pg_temp.refresh_text('BEGIN_SOURCE untrusted END_SOURCE');raise exception 'FAIL revoked trust root';exception when sqlstate 'PT422' then null;end;
end $$;
update private.authority_trust_roots set active=true where id='81000000-0000-4000-8000-000000000061';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"81000000-0000-4000-8000-000000000001"}',true);
do $$declare context jsonb;request jsonb;response jsonb;pid uuid;patch_id uuid;draft uuid;original jsonb;rich jsonb;begin
 pid:=((select value from rich_test_state where name='proposal')->>'proposal_id')::uuid;
 context:=public.get_research_review_context_v2(pid)->'data';
 assert context->'bound_source_change'->>'source_language'='en' and context->'bound_source_change'->>'article_locale'='en','source and article language must be explicit';
 assert context->'bound_source_change'->>'old_fragment'='baseline original language','old exact source fragment';
 assert context->'bound_source_change'->>'new_fragment'='exact new source wording','new exact source fragment';
 assert context->'bound_source_change'->>'source_url'='https://bound-refresh.example.org/info','canonical citation URL';
 assert length(context->'bound_source_change'->>'new_content_hash')=64,'snapshot content hash shown';
 patch_id:=(context->'structured_patches'->0->>'id')::uuid;
 request:=jsonb_build_object('proposal_id',pid,'expected_proposal_revision',1,'expected_review_revision',0,'base_revision_id',context->'base'->'revision_id','base_content_hash',context->'base'->'content_hash',
 'mode','create_draft','decisions',jsonb_build_array(jsonb_build_object('section_id',patch_id,'decision','accept','edited_text',null)),'note','SYNTHETIC human accept only','request_key',gen_random_uuid());
 response:=public.save_structured_research_review(request);
 assert public.save_structured_research_review(request)=response,'exact human draft retry';
 select head_id into draft from public.visa_article_heads where article_id='81000000-0000-4000-8000-000000000010' and locale='en';
 select value into original from rich_test_state where name='sections';
 select composition->'sections' into rich from private.rad_editorial_rich_revisions where revision_id=draft;
 assert rich->0=original->0,'unrelated source section unchanged';
 assert rich#>'{1,blocks,0}'=original#>'{1,blocks,0}','original rich table preserved';
 assert rich#>'{1,blocks,1}'=original#>'{1,blocks,1}','original nested list preserved';
 assert rich#>>'{1,blocks,5,current_text}'='exact new source wording','accepted change adds exact quote after bound anchor';
 assert private.rad_article_state(draft)='draft' and response->'data'->>'published'='false','human acceptance creates unverified draft only';
 assert (select to_jsonb(h) from public.visa_article_heads h where article_id='81000000-0000-4000-8000-000000000010' and locale='fa')=(select value from rich_test_state where name='fa'),'locale isolation';
 assert not exists(select 1 from public.visa_article_heads where article_id='81000000-0000-4000-8000-000000000010' and published_id is not null),'no automatic publication';
 begin perform public.publish_visa_article_revision(jsonb_build_object('article_id','81000000-0000-4000-8000-000000000010','locale','en','expected_revision',2,'request_key',gen_random_uuid()));raise exception 'FAIL publish unapproved draft';exception when sqlstate 'PT409' or sqlstate 'PT422' then null;end;
end $$;
-- Reject and edit follow the same existing Stage7 structured human-review RPC.
do $$declare mode text;result jsonb;context jsonb;request jsonb;before_head uuid;after_head uuid;begin
 foreach mode in array array['reject_proposal','create_draft'] loop
  select head_id into before_head from public.visa_article_heads where article_id='81000000-0000-4000-8000-000000000010' and locale='en';
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  result:=pg_temp.refresh_text('BEGIN_SOURCE next verbatim source '||mode||' END_SOURCE');
  perform set_config('request.jwt.claims','{"role":"authenticated","sub":"81000000-0000-4000-8000-000000000001"}',true);
  context:=public.get_research_review_context_v2((result->>'proposal_id')::uuid)->'data';
  request:=jsonb_build_object('proposal_id',result->'proposal_id','expected_proposal_revision',1,'expected_review_revision',0,'base_revision_id',context->'base'->'revision_id','base_content_hash',context->'base'->'content_hash','mode',mode,
   'decisions',case when mode='reject_proposal' then '[]'::jsonb else jsonb_build_array(jsonb_build_object('section_id',context->'structured_patches'->0->'id','decision','edit','edited_text','SYNTHETIC explicitly human edited quote')) end,'note','SYNTHETIC explicit human decision','request_key',gen_random_uuid());
  perform public.save_structured_research_review(request);
  select head_id into after_head from public.visa_article_heads where article_id='81000000-0000-4000-8000-000000000010' and locale='en';
  if mode='reject_proposal' then assert after_head=before_head,'rejection cannot modify article';
  else assert after_head<>before_head and private.rad_article_state(after_head)='draft','human edit creates draft';end if;
 end loop;
end $$;

-- Verified scope is checked before fetch and again at atomic ingestion.
do $$begin
 assert private.rad_bound_path_allowed('https://bound-refresh.example.org/info/page','bound-refresh.example.org','/info');
 assert not private.rad_bound_path_allowed('https://bound-refresh.example.org/information','bound-refresh.example.org','/info');
 assert not private.rad_bound_path_allowed('https://bound-refresh.example.org/info/../private','bound-refresh.example.org','/info');
 assert not private.rad_bound_path_allowed('https://bound-refresh.example.org/info/%2e%2e/private','bound-refresh.example.org','/info');
 assert not private.rad_bound_path_allowed('https://bound-refresh.example.org/info/%2E%2E%2fprivate','bound-refresh.example.org','/info');
 assert not private.rad_bound_path_allowed('https://bound-refresh.example.org/info/%252e/private','bound-refresh.example.org','/info');
 assert not private.rad_bound_path_allowed('https://evil.example.org/info','bound-refresh.example.org','/info');
end $$;
-- More than three chunks must finish without failure-attempt starvation.
do $$declare i integer;doc uuid;source uuid;snapshot uuid;head uuid;ctx jsonb;job uuid:=gen_random_uuid();token uuid:=gen_random_uuid();targets jsonb;target jsonb;claimed jsonb;result jsonb;normalized text;raw text;captures integer;before_heads jsonb;article uuid;body jsonb;rich jsonb;projection jsonb;begin
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"81000000-0000-4000-8000-000000000001"}',true);
 select head_id into head from public.visa_article_heads where article_id='81000000-0000-4000-8000-000000000010' and locale='en';
 select (value#>>'{}')::uuid into source from rich_test_state where name='source';
 doc:='81000000-0000-4000-8000-000000000050';
 select last_snapshot_id into snapshot from private.rad_official_refresh_bindings where id='81000000-0000-4000-8000-000000000080';
 select rev.body,rr.composition into body,rich from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id
 join private.rad_editorial_rich_revisions rr on rr.revision_id=rev.id where h.article_id='81000000-0000-4000-8000-000000000010' and h.locale='en';
 for i in 1..4 loop
  article:=gen_random_uuid();
  perform public.create_visa_article(jsonb_build_object('article_id',article,'kind','related','country_code','ZZ','pathway_slug','synthetic','slug','bound-chunk-'||i,'request_key',gen_random_uuid()));
  projection:=private.rad_project_rich(rich->'sections','[]',body||jsonb_build_object('article_id',article));
  perform public.save_visa_article_draft(body||jsonb_build_object('article_id',article,'expected_revision',0,'request_key',gen_random_uuid(),'sections',projection->'sections'));
  select head_id into head from public.visa_article_heads where article_id=article and locale='en';
  insert into private.rad_editorial_rich_revisions values(head,rich||jsonb_build_object('projection_map',projection->'projection_map'));
  perform public.create_official_refresh_binding(gen_random_uuid(),source,doc,'81000000-0000-4000-8000-000000000060',article,'en',
   '81000000-0000-4000-8000-000000000021','81000000-0000-4000-8000-000000000035','BEGIN_SOURCE','END_SOURCE',snapshot,head);
 end loop;
 update public.research_sources set last_attempt_at=now()-interval '1 day',last_success_at=now()-interval '1 day' where id=source;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 insert into private.rad_research_jobs(id,kind,request,created_by,status,lease_token,lease_until,attempts)
 values(job,'research_refresh','{"authority_ids":["81000000-0000-4000-8000-000000000060"]}','81000000-0000-4000-8000-000000000001','running',token,clock_timestamp()+interval '1 minute',1);
 targets:=public.get_bound_official_refresh_targets(job,token);assert jsonb_array_length(targets)=5,'freeze complete explicit binding set';
 update private.authority_trust_roots set active=false where id='81000000-0000-4000-8000-000000000061';
 begin perform public.get_bound_official_refresh_targets(job,token);raise exception 'FAIL revoked proof in frozen manifest';exception when sqlstate 'PT422' then null;end;
 update private.authority_trust_roots set active=true where id='81000000-0000-4000-8000-000000000061';
 begin perform public.finish_official_research_job(job,token,'[]',null);raise exception 'FAIL premature success';exception when sqlstate 'PT409' then null;end;
 begin perform public.yield_bound_official_refresh(job,token);raise exception 'FAIL yield without progress';exception when sqlstate 'PT409' then null;end;
 select coalesce(jsonb_agg(to_jsonb(h)),'[]') into before_heads from public.visa_article_heads h where article_id='81000000-0000-4000-8000-000000000010';
 for i in 1..5 loop
  targets:=public.get_bound_official_refresh_targets(job,token);assert jsonb_array_length(targets)=6-i,'completed targets must not repeat';target:=targets->0;
  perform public.renew_bound_official_refresh_lease(job,token);
  select normalized_text into normalized from public.source_snapshots where id=(target->>'expected_snapshot_id')::uuid;
  raw:='<p>'||normalized||'</p>';select count(*) into captures from private.rad_bound_raw_captures;
  result:=public.ingest_bound_official_refresh(job,token,(target->>'binding_id')::uuid,(target->>'expected_revision_id')::uuid,(target->>'expected_snapshot_id')::uuid,
   normalized,encode(convert_to(raw,'UTF8'),'base64'),target->>'url',200);
  assert not (result->>'changed')::boolean,'unchanged fragment must not generate proposal';
  assert (select count(*) from private.rad_bound_raw_captures)=captures+1,'preserve distinct raw response even when normalized hash unchanged';
  select source_id into source from private.rad_official_refresh_bindings where id=(target->>'binding_id')::uuid;
  assert (select last_success_at>clock_timestamp()-interval '1 minute' and last_attempt_at>clock_timestamp()-interval '1 minute' from public.research_sources where id=source),'unchanged observation updates real telemetry';
  assert (select attempts=0 from private.rad_research_jobs where id=job),'committed progress resets failure attempts';
  if i<5 then
   perform public.yield_bound_official_refresh(job,token);claimed:=public.claim_official_research_job();assert claimed->>'job_id'=job::text,'resume same bounded job';token:=(claimed->>'lease_token')::uuid;
  end if;
 end loop;
 assert public.get_bound_official_refresh_targets(job,token)='[]','completed manifest can finish without network';
 perform public.finish_official_research_job(job,token,'[]',null);
 assert (select status='succeeded' from private.rad_research_jobs where id=job),'complete job success only after all five chunks';
 assert (select coalesce(jsonb_agg(to_jsonb(h)),'[]') from public.visa_article_heads h where article_id='81000000-0000-4000-8000-000000000010')=before_heads,'source monitoring never mutates article heads';
 assert not has_function_privilege('authenticated','public.renew_bound_official_refresh_lease(uuid,uuid)','EXECUTE');
 assert not has_function_privilege('authenticated','public.yield_bound_official_refresh(uuid,uuid)','EXECUTE');
 assert not has_table_privilege('service_role','private.rad_bound_raw_captures','SELECT');
end $$;
rollback;
