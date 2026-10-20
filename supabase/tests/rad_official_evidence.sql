-- All authority names, domains, text and users are SYNTHETIC; rollback removes all.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values('a5000000-0000-4000-8000-000000000001','synthetic-evidence-admin@example.invalid');
update public.profiles set role='admin' where id='a5000000-0000-4000-8000-000000000001';
insert into public.destinations(code,slug) values('ZZ','synthetic-official-only');
insert into public.source_documents(id,canonical_url,source_authority,title,language_code,validation_status) values
 ('d5000000-0000-4000-8000-000000000001','https://authority.example.invalid/test/official','government','SYNTHETIC authority document','en','validated');
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status,fetched_at) values
 ('f5000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','SYNTHETIC official marker alpha.',encode(extensions.digest('SYNTHETIC official marker alpha.','sha256'),'hex'),200,now()-interval '1 hour'),
 ('f5000000-0000-4000-8000-000000000002','d5000000-0000-4000-8000-000000000001','SYNTHETIC official marker bravo.',encode(extensions.digest('SYNTHETIC official marker bravo.','sha256'),'hex'),200,now()-interval '1 minute');
insert into public.knowledge_items(id,slug,language_code,title,summary) values('b5000000-0000-4000-8000-000000000001','synthetic-evidence-only','en','SYNTHETIC record','No immigration advice.');
insert into public.knowledge_claims(id,knowledge_item_id,claim_text,locale,claim_key) values('b5000000-0000-4000-8000-000000000002','b5000000-0000-4000-8000-000000000001','SYNTHETIC official marker alpha.','en','synthetic-marker');
insert into public.knowledge_citations(id,claim_id,snapshot_id,excerpt,locator) values('c5000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000002','f5000000-0000-4000-8000-000000000001','SYNTHETIC official marker alpha.','paragraph 1');
do $$ begin
 begin update public.knowledge_claims set factual_status='verified' where id='b5000000-0000-4000-8000-000000000002';raise exception 'no-proof verification admitted';exception when sqlstate 'PT422' then null;end;
end $$;
insert into private.authority_entities(id,name,authority_type,country_code,jurisdiction,competence_topics,state,verified_at,expires_at)
 values('a5000000-0000-4000-8000-000000000010','SYNTHETIC test authority','government','ZZ','ZZ',array['synthetic'],'verified',now()-interval '1 hour',now()+interval '1 day');
insert into private.authority_domains(id,authority_id,host,path_prefix,state,verified_at,expires_at)
 values('a5000000-0000-4000-8000-000000000011','a5000000-0000-4000-8000-000000000010','authority.example.invalid','/test/','verified',now()-interval '1 hour',now()+interval '1 day');
insert into private.authority_trust_roots(id,policy_version,proof,approved_by,approved_at,expires_at,active)
 values('a5000000-0000-4000-8000-000000000012','synthetic-only','{"synthetic":true}','a5000000-0000-4000-8000-000000000001',now()-interval '1 hour',now()+interval '1 day',true);
insert into private.authority_proofs(id,domain_id,root_id,domain_revision,scope_topic,jurisdiction,proof_hash,ownership_snapshot_id,competence_snapshot_id,verified_at,expires_at)
 values('a5000000-0000-4000-8000-000000000013','a5000000-0000-4000-8000-000000000011','a5000000-0000-4000-8000-000000000012',1,'synthetic','ZZ',repeat('a',64),'f5000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000001',now()-interval '1 hour',now()+interval '1 day');
insert into private.claim_official_evidence(claim_id,citation_id,proof_id,topic,jurisdiction,effective_from,fresh_until)
 values('b5000000-0000-4000-8000-000000000002','c5000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000013','synthetic','ZZ',current_date,now()+interval '1 day');
select public.verify_official_claim('b5000000-0000-4000-8000-000000000002');
do $$ begin
 if not private.rad_claim_eligible('b5000000-0000-4000-8000-000000000002') then raise exception 'valid synthetic proof rejected';end if;
 update private.claim_official_evidence set conflicting=true;
 if private.rad_claim_eligible('b5000000-0000-4000-8000-000000000002') then raise exception 'conflicting evidence trusted';end if;
 update private.claim_official_evidence set conflicting=false,fresh_until=now()-interval '1 minute';
 if private.rad_claim_eligible('b5000000-0000-4000-8000-000000000002') then raise exception 'expired evidence trusted';end if;
 update private.claim_official_evidence set fresh_until=now()+interval '1 day';
 update private.authority_domains set revision=2;
 if private.rad_claim_eligible('b5000000-0000-4000-8000-000000000002') then raise exception 'revoked domain revision trusted';end if;
 update private.authority_domains set revision=1;
 update private.authority_trust_roots set active=false;
 if private.rad_claim_eligible('b5000000-0000-4000-8000-000000000002') then raise exception 'inactive root trusted';end if;
 update private.authority_trust_roots set active=true;
 begin update public.source_snapshots set normalized_text='tampered';raise exception 'snapshot mutable';exception when sqlstate 'PT409' then null;end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a5000000-0000-4000-8000-000000000001"}',true);
select public.create_visa_article('{"article_id":"b5000000-0000-4000-8000-000000000003","kind":"related","country_code":"ZZ","pathway_slug":"synthetic","slug":"synthetic-official","request_key":"c5000000-0000-4000-8000-000000000011"}');
do $$ declare request jsonb;draft jsonb;begin
 request:='{"article_id":"b5000000-0000-4000-8000-000000000003","locale":"en","expected_revision":0,"title":"SYNTHETIC official article","summary":"No immigration advice.","sections":[{"id":"e5000000-0000-4000-8000-000000000001","anchor":"test","heading":"Synthetic marker","order":0,"blocks":[{"id":"e5000000-0000-4000-8000-000000000002","type":"paragraph","text":"SYNTHETIC official marker alpha.","items":[]}],"evidence_refs":[{"snapshot_id":"f5000000-0000-4000-8000-000000000001","claim_id":"b5000000-0000-4000-8000-000000000002","excerpt":"SYNTHETIC official marker alpha.","locator":"paragraph 1"}]}],"related_article_ids":[],"merge_manifest_id":null,"request_key":"c5000000-0000-4000-8000-000000000012"}';
 draft:=public.save_visa_article_draft(request)->'data';
 request:=jsonb_build_object('article_id',draft->'article_id','revision_id',draft->'revision_id','expected_revision',draft->'revision','content_hash',draft->'content_hash','note','','request_key',gen_random_uuid());
 perform public.submit_visa_article_review(request);
 perform public.approve_visa_article_revision(request||jsonb_build_object('request_key',gen_random_uuid()));
 perform public.publish_visa_article_revision((request-'expected_revision'-'note')||jsonb_build_object('request_key',gen_random_uuid()));
 draft:=public.get_visa_article('{"selector":{"article_id":"b5000000-0000-4000-8000-000000000003"},"locale":"en"}');
 if draft->'data'->'sections'->0->'evidence'->0->>'authority_id'<>'a5000000-0000-4000-8000-000000000010' then raise exception 'missing exact authority projection';end if;
end $$;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$ declare r jsonb;begin
 r:=public.retrieve_verified_official_claims('marker','en','ZZ','synthetic');
 if jsonb_array_length(r->'results')<>1 then raise exception 'query-relevant official retrieval';end if;
 r:=public.retrieve_verified_official_claims('unrelatedword','en','ZZ','synthetic');
 if jsonb_array_length(r->'results')<>0 then raise exception 'unrelated fallback';end if;
 update private.authority_domains set state='revoked';
 r:=public.retrieve_verified_official_claims('marker','en','ZZ','synthetic');
 if jsonb_array_length(r->'results')<>0 then raise exception 'revoked retrieval leak';end if;
 update private.authority_domains set state='verified';
end $$;
insert into private.rad_research_jobs(id,kind,request,created_by,status,lease_token,lease_until) values
 ('a5000000-0000-4000-8000-000000000020','research_refresh','{"authority_ids":["a5000000-0000-4000-8000-000000000010"]}',
 'a5000000-0000-4000-8000-000000000001','running','a5000000-0000-4000-8000-000000000021',now()+interval '1 minute');
do $$ declare r public.visa_article_revisions;sections jsonb;changes jsonb;result jsonb;proposal uuid;review jsonb;original_published uuid;base jsonb;begin
 select rev.* into r from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id where h.article_id='b5000000-0000-4000-8000-000000000003';
 original_published:=r.id;
 base:=public.get_research_article_base('a5000000-0000-4000-8000-000000000020','a5000000-0000-4000-8000-000000000021',r.article_id,'en');
 if base->>'revision_id'<>r.id::text or jsonb_array_length(base->'section_hashes')<>1 then raise exception 'worker base/hash contract';end if;
 sections:=jsonb_set(r.body->'sections','{0,blocks,0,text}','"SYNTHETIC official marker bravo."');
 sections:=jsonb_set(sections,'{0,evidence_refs}','[{"snapshot_id":"f5000000-0000-4000-8000-000000000002","claim_id":null,"excerpt":"SYNTHETIC official marker bravo.","locator":"paragraph 1"}]');
 changes:=jsonb_build_array(jsonb_build_object('section_id',sections->0->'id','operation','replace','before_hash',base->'section_hashes'->0->'before_hash','replacement',sections->0,'claim_ids','[]'::jsonb));
 result:=public.record_official_source_change('a5000000-0000-4000-8000-000000000020','a5000000-0000-4000-8000-000000000021',r.article_id,'en','f5000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000001',sections,changes);
 if result->>'changed'<>'false' then raise exception 'unchanged source candidate';end if;
 begin perform public.record_official_source_change('a5000000-0000-4000-8000-000000000020',gen_random_uuid(),r.article_id,'en','f5000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000002',sections,changes);raise exception 'stale lease accepted';exception when sqlstate 'PT409' then null;end;
 result:=public.record_official_source_change('a5000000-0000-4000-8000-000000000020','a5000000-0000-4000-8000-000000000021',r.article_id,'en','f5000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000002',sections,changes);
 proposal:=(result->>'proposal_id')::uuid;
 if proposal is null then raise exception 'source change not persisted';end if;
 if public.record_official_source_change('a5000000-0000-4000-8000-000000000020','a5000000-0000-4000-8000-000000000021',r.article_id,'en','f5000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000002',sections,changes)->>'proposal_id'<>proposal::text then raise exception 'duplicate proposal';end if;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a5000000-0000-4000-8000-000000000001"}',true);
 result:=public.get_research_proposal(jsonb_build_object('proposal_id',proposal));
 if jsonb_array_length(result->'data'->'evidence')<>1 or result->'data'->>'verification_state'<>'unverified' then raise exception 'proposal evidence/state';end if;
 result:=public.list_official_authorities('{"country_code":"ZZ","topic":"synthetic","state":"verified","cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>1 then raise exception 'authority listing';end if;
 result:=public.list_research_proposals('{"editorial_state":"review","verification_state":"unverified","article_id":null,"cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>1 then raise exception 'proposal listing';end if;
 result:=public.get_rad_job_status('{"job_id":"a5000000-0000-4000-8000-000000000020"}');
 if result->'data'->>'status'<>'running' then raise exception 'leased job status';end if;
 review:=jsonb_build_object('proposal_id',proposal,'expected_revision',1,'decision','accept','note','Synthetic review only','request_key',gen_random_uuid());
 result:=public.review_research_proposal(review);
 if result->'data'->'draft_revision'->>'editorial_state'<>'draft' then raise exception 'review auto-approved article';end if;
 if (select published_id from public.visa_article_heads where article_id=r.article_id and locale='en')<>original_published then raise exception 'research auto-published';end if;
 begin perform public.review_research_proposal(review||jsonb_build_object('request_key',gen_random_uuid()));raise exception 'stale review accepted';exception when sqlstate 'PT409' then null;end;
end $$;
rollback;
