-- Synthetic fixtures; rollback all test data. No legal verification/publication.
begin;
insert into public.destinations(code,slug) values('ZZ','stage71-synthetic') on conflict(code) do nothing;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('71000000-0000-4000-8000-000000000001','stage71-admin@example.invalid'),
 ('71000000-0000-4000-8000-000000000002','stage71-user@example.invalid');
update public.profiles set role='admin' where id='71000000-0000-4000-8000-000000000001';
insert into public.source_documents(id,canonical_url,source_authority,title,language_code,validation_status)
values('71000000-0000-4000-8000-000000000050','https://stage71.example.org/info','other','SYNTHETIC ONLY','en','candidate');
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status,fetched_at)
values('71000000-0000-4000-8000-000000000052','71000000-0000-4000-8000-000000000050','SYNTHETIC fixture evidence only.',encode(extensions.digest('SYNTHETIC fixture evidence only.','sha256'),'hex'),200,now());
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status,fetched_at)
values('71000000-0000-4000-8000-000000000053','71000000-0000-4000-8000-000000000050','SYNTHETIC fixture 2.',encode(extensions.digest('SYNTHETIC fixture 2.','sha256'),'hex'),200,now());
insert into private.authority_entities(id,name,authority_type,country_code,jurisdiction,state)
values('71000000-0000-4000-8000-000000000060','SYNTHETIC candidate','government','ZZ','ZZ','candidate');
insert into private.authority_domains(authority_id,host,path_prefix,state)
values('71000000-0000-4000-8000-000000000060','stage71.example.org','/info','candidate');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"71000000-0000-4000-8000-000000000001"}',true);
select public.create_visa_article('{"article_id":"71000000-0000-4000-8000-000000000010","kind":"related","country_code":"ZZ","pathway_slug":"synthetic","slug":"stage71-synthetic","request_key":"71000000-0000-4000-8000-000000000100"}');
create temporary table rich_test_state(name text primary key,value jsonb);
do $$declare sections jsonb;body jsonb;r uuid;projection jsonb;source uuid;ctx jsonb;patches jsonb;req jsonb;response jsonb;begin
 sections:='[
 {"id":"71000000-0000-4000-8000-000000000020","heading":"SYNTHETIC unchanged","blocks":[
 {"id":"71000000-0000-4000-8000-000000000030","type":"paragraph","text":"SYNTHETIC original coverage فارسی preserved","original_structure":{"type":"paragraph","text":"SYNTHETIC original coverage فارسی preserved","links":[{"href":"https://example.org/source","text":"Source"}]},"provenance":[{"snapshot_id":"71000000-0000-4000-8000-000000000052","start":0,"end":29}]}]},
 {"id":"71000000-0000-4000-8000-000000000021","heading":"SYNTHETIC changes","blocks":[
 {"id":"71000000-0000-4000-8000-000000000031","type":"table","text":"SYNTHETIC cell stable","original_structure":{"type":"table","caption":"SYNTHETIC table","rows":[[{"text":"SYNTHETIC cell","header":true,"colspan":2,"rowspan":1}],[{"text":"stable","header":false,"colspan":1,"rowspan":1}]]},"provenance":[]},
 {"id":"71000000-0000-4000-8000-000000000032","type":"bullet_list","text":"SYNTHETIC parent child","original_structure":{"type":"bullet_list","items":[{"text":"SYNTHETIC parent","children":[{"ordered":true,"items":[{"text":"SYNTHETIC child","children":[]}]}]}]},"provenance":[]},
 {"id":"71000000-0000-4000-8000-000000000033","type":"paragraph","text":"SYNTHETIC remove","original_structure":{"type":"paragraph","text":"SYNTHETIC remove"},"provenance":[]},
 {"id":"71000000-0000-4000-8000-000000000034","type":"paragraph","text":"SYNTHETIC reject change","original_structure":{"type":"paragraph","text":"SYNTHETIC reject change"},"provenance":[]},
 {"id":"71000000-0000-4000-8000-000000000035","type":"paragraph","text":"SYNTHETIC insertion anchor","original_structure":{"type":"paragraph","text":"SYNTHETIC insertion anchor"},"provenance":[]}
 ]}]';
 body:=jsonb_build_object('article_id','71000000-0000-4000-8000-000000000010','locale','en','expected_revision',0,'title','SYNTHETIC rich page','summary','SYNTHETIC only','related_article_ids','[]'::jsonb,'merge_manifest_id',null,'request_key',gen_random_uuid(),'sections','[]'::jsonb);
 projection:=private.rad_project_rich(sections,'[]',body);
 body:=body||jsonb_build_object('sections',projection->'sections');
 perform public.save_visa_article_draft(body);
 select head_id into r from public.visa_article_heads where article_id='71000000-0000-4000-8000-000000000010' and locale='en';
 insert into private.rad_editorial_rich_revisions values(r,jsonb_build_object('sections',sections,'projection_map',projection->'projection_map','source_ids',jsonb_build_array('synthetic-source')));
 insert into private.rad_editorial_reference_maps(revision_id,input_hash,source_manifest_hash,content) values(r,repeat('1',64),repeat('2',64),jsonb_build_object('capture_status','complete','sources','[]'::jsonb,'links',jsonb_build_array(jsonb_build_object('href','https://example.org/source','target_block_id','71000000-0000-4000-8000-000000000033','target_anchor','removed'))));
 -- Independent locale head must remain untouched.
 perform public.save_visa_article_draft(body||jsonb_build_object('locale','fa','request_key',gen_random_uuid()));
 response:=public.upsert_editorial_research_source(jsonb_build_object('source_id',null,'display_name','SYNTHETIC research source','base_url','https://stage71.example.org/info','source_type','admin_reference','country_code','ZZ','visa_category','synthetic','request_key',gen_random_uuid()));
 source:=(response->'data'->>'source_id')::uuid;
 ctx:=public.get_structured_article_context('71000000-0000-4000-8000-000000000010','en')->'data';
 patches:='[]';
 for req in select x from jsonb_array_elements('[
 {"id":"71000000-0000-4000-8000-000000000071","block_id":"71000000-0000-4000-8000-000000000031","operation":"replace_text","path":["rows","0","0","text"],"text":"SYNTHETIC proposed cell","new_block_id":null},
 {"id":"71000000-0000-4000-8000-000000000072","block_id":"71000000-0000-4000-8000-000000000032","operation":"replace_text","path":["items","0","children","0","items","0","text"],"text":"SYNTHETIC new nested child","new_block_id":null},
 {"id":"71000000-0000-4000-8000-000000000073","block_id":"71000000-0000-4000-8000-000000000033","operation":"remove","path":[],"text":null,"new_block_id":null},
 {"id":"71000000-0000-4000-8000-000000000074","block_id":"71000000-0000-4000-8000-000000000034","operation":"replace_text","path":["text"],"text":"SYNTHETIC rejected wording","new_block_id":null},
 {"id":"71000000-0000-4000-8000-000000000075","block_id":"71000000-0000-4000-8000-000000000035","operation":"add_after","path":[],"text":"SYNTHETIC added paragraph","new_block_id":"71000000-0000-4000-8000-000000000036"}
 ]'::jsonb)x loop
 patches:=patches||jsonb_build_array(req||jsonb_build_object('section_id','71000000-0000-4000-8000-000000000021','before_hash',ctx->'block_hashes'->(req->>'block_id'),'evidence',jsonb_build_object('snapshot_id','71000000-0000-4000-8000-000000000052','excerpt','SYNTHETIC fixture evidence only.','locator','SYNTHETIC test')));
 end loop;
 req:=jsonb_build_object('article_id',ctx->'article_id','locale','en','base_revision_id',ctx->'revision_id','base_content_hash',ctx->'content_hash','base_rich_hash',ctx->'rich_hash','source_id',source,'authority_id','71000000-0000-4000-8000-000000000060','snapshot_id','71000000-0000-4000-8000-000000000052','patches',patches,'request_key',gen_random_uuid());
 response:=public.propose_structured_research(req);
 begin perform public.propose_structured_research(req||jsonb_build_object('base_rich_hash',repeat('0',64),'request_key',gen_random_uuid()));raise exception 'FAIL stale rich baseline';exception when sqlstate 'PT409' then null;end;
 begin perform public.propose_structured_research(jsonb_set(req,'{patches,0,before_hash}',to_jsonb(repeat('0',64)))||jsonb_build_object('request_key',gen_random_uuid()));raise exception 'FAIL stale block';exception when sqlstate 'PT409' then null;end;
 begin perform public.propose_structured_research(jsonb_set(req,'{patches,0,evidence,excerpt}','"not present in snapshot"')||jsonb_build_object('request_key',gen_random_uuid()));raise exception 'FAIL invented evidence';exception when sqlstate 'PT422' then null;end;
 begin perform public.propose_structured_research(jsonb_set(req,'{patches,0,path}','["rows","0","0","colspan"]')||jsonb_build_object('request_key',gen_random_uuid()));raise exception 'FAIL structural mutation';exception when sqlstate 'PT422' then null;end;
 begin perform public.propose_structured_research(req||jsonb_build_object('authority_id',gen_random_uuid(),'request_key',gen_random_uuid()));raise exception 'FAIL unrelated authority';exception when sqlstate 'PT422' then null;end;
 if public.propose_structured_research(req)->'data'<>response->'data' then raise exception 'FAIL proposal retry';end if;
 insert into rich_test_state values('base',ctx),('sections',sections),('proposal',response->'data'),('request',req),('fa',(select to_jsonb(h) from public.visa_article_heads h where article_id='71000000-0000-4000-8000-000000000010' and locale='fa'));
end $$;
-- Authenticated non-Admin (including forged user metadata) cannot call new APIs.
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"71000000-0000-4000-8000-000000000002","user_metadata":{"role":"admin"}}',true);
do $$begin
 begin perform public.get_structured_article_context('71000000-0000-4000-8000-000000000010','en');raise exception 'FAIL private context';exception when sqlstate 'PT403' then null;end;
 begin perform public.propose_structured_research('{}');raise exception 'FAIL proposal authorization';exception when sqlstate 'PT403' then null;end;
 begin perform public.save_structured_research_review('{}');raise exception 'FAIL review authorization';exception when sqlstate 'PT403' then null;end;
 begin perform public.get_editorial_article('71000000-0000-4000-8000-000000000010','en',true);raise exception 'FAIL preview authorization';exception when sqlstate 'PT403' then null;end;
 begin perform public.get_editorial_article('71000000-0000-4000-8000-000000000010','en',false);raise exception 'FAIL draft public visibility';exception when sqlstate 'PT404' then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"71000000-0000-4000-8000-000000000001"}',true);
do $$declare ctx jsonb;original jsonb;req jsonb;response jsonb;draft uuid;pid uuid;rich jsonb;oldrich jsonb;begin
 select value into original from rich_test_state where name='sections';
 select (value->>'proposal_id')::uuid into pid from rich_test_state where name='proposal';
 ctx:=public.get_research_review_context_v2(pid)->'data';
 if jsonb_array_length(ctx->'structured_patches')<>5 then raise exception 'FAIL full context';end if;
 req:=jsonb_build_object('proposal_id',pid,'expected_proposal_revision',1,'expected_review_revision',0,'base_revision_id',ctx->'base'->'revision_id','base_content_hash',ctx->'base'->'content_hash','mode','save_review','decisions','[
 {"section_id":"71000000-0000-4000-8000-000000000071","decision":"edit","edited_text":"SYNTHETIC manual cell"},
 {"section_id":"71000000-0000-4000-8000-000000000072","decision":"accept","edited_text":null},
 {"section_id":"71000000-0000-4000-8000-000000000073","decision":"accept","edited_text":null},
 {"section_id":"71000000-0000-4000-8000-000000000074","decision":"reject","edited_text":null},
 {"section_id":"71000000-0000-4000-8000-000000000075","decision":"accept","edited_text":null}]'::jsonb,'note','SYNTHETIC review','request_key',gen_random_uuid());
 response:=public.save_structured_research_review(req);
 if public.save_structured_research_review(req)->'data'<>response->'data' then raise exception 'FAIL review retry';end if;
 if public.get_research_review_context_v2(pid)->'data'->'decisions'<>req->'decisions' then raise exception 'FAIL decision persistence';end if;
 begin perform public.save_structured_research_review(req||jsonb_build_object('request_key',gen_random_uuid()));raise exception 'FAIL stale review';exception when sqlstate 'PT409' then null;end;
 req:=req||jsonb_build_object('expected_review_revision',1,'mode','create_draft','request_key',gen_random_uuid());
 begin perform public.save_structured_research_review(req||jsonb_build_object('decisions',(select jsonb_agg(x||jsonb_build_object('decision','reject','edited_text',null)) from jsonb_array_elements(req->'decisions')x),'request_key',gen_random_uuid()));raise exception 'FAIL all-rejected manufactured draft';exception when sqlstate 'PT422' then null;end;
 begin perform public.save_structured_research_review(req||jsonb_build_object('decisions','[]'::jsonb,'request_key',gen_random_uuid()));raise exception 'FAIL missing decisions';exception when sqlstate 'PT422' then null;end;
 begin update public.visa_research_proposals set state='approved' where id=pid;raise exception 'FAIL legacy approval bypass';exception when sqlstate 'PT409' then null;end;
 begin perform public.review_research_proposal(jsonb_build_object('proposal_id',pid,'expected_revision',1,'decision','accept','note','','request_key',gen_random_uuid()));raise exception 'FAIL legacy review_research_proposal bypass';exception when sqlstate 'PT422' or sqlstate 'PT409' then null;end;
 declare p_leg uuid;begin
  insert into public.visa_research_proposals(article_id,locale,base_revision,authority_id,new_snapshot_id,changes,new_sections)
  values('71000000-0000-4000-8000-000000000010','en',1,'71000000-0000-4000-8000-000000000060','71000000-0000-4000-8000-000000000053','[]','[]') returning id into p_leg;
  begin
   perform public.review_research_proposal(jsonb_build_object('proposal_id',p_leg,'expected_revision',1,'decision','accept','note','','request_key',gen_random_uuid()));
   raise exception 'FAIL legacy unstructured approval bypass on rich article';
  exception when sqlstate 'PT422' then null;end;
 end;
 response:=public.save_structured_research_review(req);
 select head_id into draft from public.visa_article_heads where article_id='71000000-0000-4000-8000-000000000010' and locale='en';
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=draft;
 select composition into oldrich from private.rad_editorial_rich_revisions where revision_id=(ctx->'base'->>'revision_id')::uuid;
 if oldrich->'sections'<>original then raise exception 'FAIL historical body changed';end if;
 if rich->'sections'->0<>original->0 then raise exception 'FAIL untouched full section hash';end if;
 if rich#>'{sections,1,blocks,0,original_structure}'<>original#>'{1,blocks,0,original_structure}' then raise exception 'FAIL original table lost';end if;
 if rich#>>'{sections,1,blocks,0,current_structure,rows,0,0,text}'<>'SYNTHETIC manual cell' or rich#>>'{sections,1,blocks,0,current_structure,rows,0,0,colspan}'<>'2' then raise exception 'FAIL table patch';end if;
 if rich#>>'{sections,1,blocks,1,current_structure,items,0,children,0,items,0,text}'<>'SYNTHETIC new nested child' then raise exception 'FAIL nested list';end if;
 if rich#>'{sections,1,blocks,2}'<>original#>'{1,blocks,3}' then raise exception 'FAIL rejected block/order';end if;
 if rich#>>'{sections,1,blocks,4,current_text}'<>'SYNTHETIC added paragraph' then raise exception 'FAIL added paragraph/order';end if;
 if not exists(select 1 from private.rad_structured_revision_ancestry where revision_id=draft and parent_revision_id=(ctx->'base'->>'revision_id')::uuid) then raise exception 'FAIL ancestry';end if;
 if exists(select 1 from public.visa_article_heads where article_id='71000000-0000-4000-8000-000000000010' and published_id is not null) then raise exception 'FAIL autopublish';end if;
 if (select to_jsonb(h) from public.visa_article_heads h where article_id='71000000-0000-4000-8000-000000000010' and locale='fa')<>(select value from rich_test_state where name='fa') then raise exception 'FAIL locale isolation';end if;
 if (select content#>>'{links,0,href}' from private.rad_editorial_reference_maps where revision_id=draft)<>'https://example.org/source' then raise exception 'FAIL link lost';end if;
 if (select body::text from public.visa_article_revisions where id=draft) not like '%SYNTHETIC manual cell%' then raise exception 'FAIL search projection';end if;
 if private.rad_article_state(draft)<>'draft' or response->'data'->>'published'<>'false' then raise exception 'FAIL lifecycle';end if;
 if public.save_structured_research_review(req)->'data'<>response->'data' then raise exception 'FAIL draft retry';end if;
 raise notice 'PASS rich table/list/manual/add/remove/reject/full-page/ancestry/locale/links/evidence/concurrency/auth/publication boundaries';
end $$;
do $$begin
 if has_function_privilege('anon','public.propose_structured_research(jsonb)','EXECUTE') or has_function_privilege('service_role','public.save_structured_research_review(jsonb)','EXECUTE') then raise exception 'FAIL privileged RPC exposure';end if;
 if has_table_privilege('authenticated','private.rad_structured_proposals','SELECT') then raise exception 'FAIL private patches exposure';end if;
end $$;
rollback;
