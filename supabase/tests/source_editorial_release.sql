-- Disposable synthetic data. No source website or hosted database is contacted.
begin;
set local statement_timeout='60s';
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('a4100000-0000-4000-8000-000000000001','source-release-admin@example.invalid'),
 ('a4100000-0000-4000-8000-000000000002','source-release-user@example.invalid');
insert into public.profiles(id,role) values('a4100000-0000-4000-8000-000000000001','admin'),('a4100000-0000-4000-8000-000000000002','user')
 on conflict(id) do update set role=excluded.role;
create temporary table source_release_fixture(payload jsonb,entry jsonb,manifest text,batch uuid);
create temporary table source_release_feed_before as select count(*) n from public.feed_items;
do $$declare actor uuid:='a4100000-0000-4000-8000-000000000001';article uuid:='a4100000-0000-4000-8000-000000000010';
 old_head uuid:='a4100000-0000-4000-8000-000000000011';candidate uuid:='a4100000-0000-4000-8000-000000000012';
 source_id uuid:='a4100000-0000-4000-8000-000000000020';snapshot uuid:='a4100000-0000-4000-8000-000000000021';
 source_url text:='https://radvisa.com/synthetic-source-release/';source_text text:='Synthetic source paragraph. Not immigration guidance.';
 source_hash text;body jsonb;rich jsonb;payload jsonb;entry jsonb;begin
 source_hash:=encode(extensions.digest(source_text,'sha256'),'hex');
 insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash)
 values(source_id,'Synthetic RAD source','rad_official','Synthetic source',source_url,'en',now(),source_hash);
 insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash,validation_status)
 values(source_id,source_url,source_id,'rad_official','Synthetic source','en','',source_hash,'candidate');
 insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata)
 values(snapshot,source_id,source_hash,source_text,200,now(),jsonb_build_object('raw_html_sha256',repeat('a',64),'factual_verification','not_verified'));
 perform private.rad_classify_snapshot(snapshot);
 insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
 values(article,'related',null,'source-fixture','source-fixture',actor);
 body:=jsonb_build_object('article_id',article,'locale','en','title','Synthetic source article','summary','',
  'expected_revision',0,'merge_manifest_id',null,'related_article_ids','[]'::jsonb,
  'sections',jsonb_build_array(jsonb_build_object('id','a4100000-0000-4000-8000-000000000030','anchor','source-fixture','heading','Synthetic section','order',0,
   'blocks',jsonb_build_array(jsonb_build_object('id','a4100000-0000-4000-8000-000000000031','type','paragraph','text',source_text,'items','[]'::jsonb)),
   'evidence_refs',jsonb_build_array(jsonb_build_object('snapshot_id',snapshot,'claim_id',null,'excerpt',source_text,'locator','synthetic')))));
 insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)
 values(old_head,article,'en',1,'Original preserved head','',repeat('b',64),'{}',actor),
 (candidate,article,'en',2,body->>'title','',encode(extensions.digest((body-'expected_revision')::text,'sha256'),'hex'),body,actor);
 insert into public.visa_article_sections(revision_id,id,anchor,heading,position,blocks,evidence_refs)
 select candidate,(s->>'id')::uuid,s->>'anchor',s->>'heading',(s->>'order')::integer,s->'blocks',s->'evidence_refs' from jsonb_array_elements(body->'sections')s;
 insert into public.visa_article_revision_events(revision_id,state,actor_id) values(old_head,'draft',actor),(candidate,'draft',actor);
 insert into public.visa_article_heads values(article,'en',old_head,null);
 rich:=jsonb_build_object('article_id',article,'locale','en','country_codes',jsonb_build_array('DE','FR'),'source_publishers',jsonb_build_array('radvisa.com'),
  'source_snapshot_ids',jsonb_build_array(snapshot),'composition_policy','RAD_CONTENT_PRECEDENCE_V4.1','sections',body->'sections',
  'segment_ledger',jsonb_build_array(jsonb_build_object('source_id',source_id,'snapshot_id',snapshot,'status','preserved')),
  'conflicts','[]'::jsonb,'source_assets',jsonb_build_array(jsonb_build_object('url','https://radvisa.com/synthetic.jpg','public_render_allowed',false)));
 insert into private.rad_editorial_rich_revisions values(candidate,rich);
 insert into private.rad_editorial_catalog(article_id,content_class,category,country_codes,source_publishers,source_snapshot_ids,composition,active)
 values(article,'editorial','general-guide',array['DE','FR'],array['radvisa.com'],array[snapshot],rich,false);
 payload:=jsonb_build_object('item',rich||jsonb_build_object('draft_request',body||jsonb_build_object('request_key',gen_random_uuid())),
  'sources',jsonb_build_array(jsonb_build_object('source_id',source_id,'snapshot_id',snapshot,'url',source_url,'language','en','raw_html_sha256',repeat('a',64),'body_text',source_text,'body_sha256',source_hash)));
 entry:=jsonb_build_object('revision_id',candidate,'expected_head_id',old_head,'expected_published_id',null,'expected_catalog_active',false,'activate_catalog',true,
  'payload_text',payload::text,'payload_sha256',encode(extensions.digest(payload::text,'sha256'),'hex'));
 insert into source_release_fixture values(payload,entry,jsonb_build_array(entry)::text,'a4100000-0000-4000-8000-000000000040');
 insert into private.rad_production_reconciliation_journal(package_sha256,operation_id,payload_sha256,article_id,locale,revision_id,actor_id)
 values('c9b4d7e84711a3fb478b639d724289a3f2694a298448d662d4637894d0318353',repeat('e',64),entry->>'payload_sha256',article,'en',candidate,actor);
end $$;

-- Two original-language revisions share one catalog row and release atomically.
do $$declare f record;body jsonb;rich jsonb;payload jsonb;entry_fa jsonb;source_hash text;
 source_text text:='متن آزمایشی منبع؛ راهنمای مهاجرت نیست.';source_url text:='https://radvisa.com/synthetic-source-release-fa/';
 source_id uuid:='a4100000-0000-4000-8000-000000000022';snapshot uuid:='a4100000-0000-4000-8000-000000000023';
 candidate uuid:='a4100000-0000-4000-8000-000000000015';old_head uuid:='a4100000-0000-4000-8000-000000000014';begin
 select * into f from source_release_fixture;
 source_hash:=encode(extensions.digest(source_text,'sha256'),'hex');
 insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash)
 values(source_id,'Synthetic RAD source','rad_official','Synthetic Persian source',source_url,'fa',now(),source_hash);
 insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash,validation_status)
 values(source_id,source_url,source_id,'rad_official','Synthetic Persian source','fa','',source_hash,'candidate');
 insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata)
 values(snapshot,source_id,source_hash,source_text,200,now(),jsonb_build_object('raw_html_sha256',repeat('a',64),'factual_verification','not_verified'));
 perform private.rad_classify_snapshot(snapshot);
 body:=(f.payload->'item'->'draft_request')-'request_key';
 body:=body||jsonb_build_object('locale','fa','title','مطلب آزمایشی');
 body:=jsonb_set(body,'{sections,0,blocks,0,text}',to_jsonb(source_text));
 body:=jsonb_set(body,'{sections,0,evidence_refs}',jsonb_build_array(jsonb_build_object('snapshot_id',snapshot,'claim_id',null,'excerpt',source_text,'locator','synthetic')));
 insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)
 values(old_head,(body->>'article_id')::uuid,'fa',1,'Original preserved Persian head','',repeat('b',64),'{}','a4100000-0000-4000-8000-000000000001'),
 (candidate,(body->>'article_id')::uuid,'fa',2,body->>'title','',encode(extensions.digest((body-'expected_revision')::text,'sha256'),'hex'),body,'a4100000-0000-4000-8000-000000000001');
 insert into public.visa_article_sections(revision_id,id,anchor,heading,position,blocks,evidence_refs)
 select candidate,(s->>'id')::uuid,s->>'anchor',s->>'heading',(s->>'order')::integer,s->'blocks',s->'evidence_refs' from jsonb_array_elements(body->'sections')s;
 insert into public.visa_article_revision_events(revision_id,state,actor_id) values
 (old_head,'draft','a4100000-0000-4000-8000-000000000001'),(candidate,'draft','a4100000-0000-4000-8000-000000000001');
 insert into public.visa_article_heads values((body->>'article_id')::uuid,'fa',old_head,null);
 rich:=((f.payload->'item')-'draft_request')||jsonb_build_object('locale','fa','sections',body->'sections','source_snapshot_ids',jsonb_build_array(snapshot),'source_assets','[]'::jsonb,
 'segment_ledger',jsonb_build_array(jsonb_build_object('source_id',source_id,'snapshot_id',snapshot,'status','preserved')));
 insert into private.rad_editorial_rich_revisions values(candidate,rich);
 payload:=jsonb_build_object('item',rich||jsonb_build_object('draft_request',body||jsonb_build_object('request_key',gen_random_uuid())),
  'sources',jsonb_build_array(jsonb_build_object('source_id',source_id,'snapshot_id',snapshot,'url',source_url,'language','fa','raw_html_sha256',repeat('a',64),'body_text',source_text,'body_sha256',source_hash)));
 entry_fa:=jsonb_build_object('revision_id',candidate,'expected_head_id',old_head,'expected_published_id',null,'expected_catalog_active',false,'activate_catalog',true,
  'payload_text',payload::text,'payload_sha256',encode(extensions.digest(payload::text,'sha256'),'hex'));
 update source_release_fixture set manifest=jsonb_build_array(f.entry,entry_fa)::text;
 insert into private.rad_production_reconciliation_journal(package_sha256,operation_id,payload_sha256,article_id,locale,revision_id,actor_id)
 values('c9b4d7e84711a3fb478b639d724289a3f2694a298448d662d4637894d0318353',repeat('f',64),entry_fa->>'payload_sha256',(body->>'article_id')::uuid,'fa',candidate,'a4100000-0000-4000-8000-000000000001');
end $$;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000002"}',true);
do $$declare f record;begin
 select * into f from source_release_fixture;
 begin perform public.approve_source_editorial_batch(f.batch,f.manifest,encode(extensions.digest(f.manifest,'sha256'),'hex'),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
  raise exception 'FAIL non-Admin approval';exception when sqlstate 'PT403' then null;end;
 if has_function_privilege('anon','public.approve_source_editorial_batch(uuid,text,text,text,text)','EXECUTE')
 or has_function_privilege('service_role','public.publish_source_editorial_batch(uuid,text)','EXECUTE')
 or has_table_privilege('authenticated','private.rad_source_editorial_batches','SELECT') then raise exception 'FAIL client ACL';end if;
 begin perform public.publish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'));
  raise exception 'FAIL non-Admin publication';exception when sqlstate 'PT403' then null;end;
end $$;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000001"}',true);
do $$declare f record;bad jsonb;body jsonb;begin
 select * into f from source_release_fixture;
 begin perform public.clear_editorial_revision((f.entry->>'revision_id')::uuid,'This source is not officially verified.');
  raise exception 'FAIL official clearance weakened';exception when sqlstate 'PT422' or sqlstate 'PT404' then null;end;
 begin insert into public.visa_article_revision_events(revision_id,state,actor_id)
  values((f.entry->>'revision_id')::uuid,'approved','a4100000-0000-4000-8000-000000000001');
  raise exception 'FAIL standard verification guard weakened';exception when sqlstate 'PT422' then null;end;
 begin perform public.approve_source_editorial_batch(f.batch,f.manifest,repeat('0',64),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
  raise exception 'FAIL changed manifest hash';exception when sqlstate 'PT422' then null;end;
 begin
  bad:=jsonb_set(f.entry,'{expected_head_id}','"a4100000-0000-4000-8000-000000000099"');
  body:=jsonb_build_array(bad);
  perform public.approve_source_editorial_batch(f.batch,body::text,encode(extensions.digest(body::text,'sha256'),'hex'),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
  raise exception 'FAIL stale head';exception when sqlstate 'PT409' then null;end;
 begin
  bad:=jsonb_set(f.payload,'{item,conflicts}', '[{"values":[10,20],"resolution":"unresolved"}]');
  update private.rad_editorial_rich_revisions set composition=(bad->'item')-'draft_request' where revision_id=(f.entry->>'revision_id')::uuid;
  update private.rad_production_reconciliation_journal set payload_sha256=encode(extensions.digest(bad::text,'sha256'),'hex') where revision_id=(f.entry->>'revision_id')::uuid;
  body:=jsonb_build_array(f.entry||jsonb_build_object('payload_text',bad::text,'payload_sha256',encode(extensions.digest(bad::text,'sha256'),'hex')));
  perform public.approve_source_editorial_batch(f.batch,body::text,encode(extensions.digest(body::text,'sha256'),'hex'),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
  raise exception 'FAIL unresolved numeric conflict';exception when sqlstate 'PT422' then
   if sqlerrm<>'faithful_body_conflict_or_media_gate' then raise;end if;end;
 begin
  bad:=jsonb_set(f.payload,'{item,source_assets,0,public_render_allowed}','true');
  update private.rad_editorial_rich_revisions set composition=(bad->'item')-'draft_request' where revision_id=(f.entry->>'revision_id')::uuid;
  update private.rad_production_reconciliation_journal set payload_sha256=encode(extensions.digest(bad::text,'sha256'),'hex') where revision_id=(f.entry->>'revision_id')::uuid;
  body:=jsonb_build_array(f.entry||jsonb_build_object('payload_text',bad::text,'payload_sha256',encode(extensions.digest(bad::text,'sha256'),'hex')));
  perform public.approve_source_editorial_batch(f.batch,body::text,encode(extensions.digest(body::text,'sha256'),'hex'),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
  raise exception 'FAIL unapproved media';exception when sqlstate 'PT422' then
   if sqlerrm<>'faithful_body_conflict_or_media_gate' then raise;end if;end;
 body:=public.approve_source_editorial_batch(f.batch,f.manifest,encode(extensions.digest(f.manifest,'sha256'),'hex'),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
 if body->'data'->>'approved_by'<>'a4100000-0000-4000-8000-000000000001' or body->'data'->>'approved_at' is null then raise exception 'FAIL approval actor/time receipt';end if;
 perform public.approve_source_editorial_batch(f.batch,f.manifest,encode(extensions.digest(f.manifest,'sha256'),'hex'),'2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic source integrity reviewed.');
 if (select count(*) from public.visa_article_revision_events where source_batch_id=f.batch and state='approved')<>2 then raise exception 'FAIL approval retry';end if;
 if private.rad_article_verification((f.entry->>'revision_id')::uuid)<>'unverified' then raise exception 'FAIL verification altered';end if;
 begin update public.visa_article_heads set published_id=(f.entry->>'revision_id')::uuid where article_id='a4100000-0000-4000-8000-000000000010';
  raise exception 'FAIL direct source pointer bypass';exception when sqlstate 'PT422' then null;end;
 begin perform public.get_editorial_article('a4100000-0000-4000-8000-000000000010','en',false);raise exception 'FAIL approved draft exposed';exception when sqlstate 'PT404' then null;end;
end $$;

do $$declare f record;receipt jsonb;card jsonb;begin
 select * into f from source_release_fixture;
 receipt:=public.publish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'));
 if receipt->'data'->>'published_count'<>'2' then raise exception 'FAIL missing publication receipt';end if;
 perform public.publish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'));
 if (select count(*) from public.visa_article_revision_events where source_batch_id=f.batch and state='published')<>2 then raise exception 'FAIL publication retry';end if;
 if not exists(select 1 from public.visa_article_heads where article_id='a4100000-0000-4000-8000-000000000010'
  and head_id='a4100000-0000-4000-8000-000000000011' and published_id=(f.entry->>'revision_id')::uuid) then raise exception 'FAIL existing head overwritten';end if;
 card:=public.get_editorial_article('a4100000-0000-4000-8000-000000000010','en',false)->'data';
 if card->>'publication_basis'<>'source_faithful' or card->>'verification_state'<>'unverified'
 or card->'rich_sections' is distinct from f.payload->'item'->'sections'
 or card->'source_assets'->0->'public_render_allowed' is distinct from 'false'::jsonb then raise exception 'FAIL truthful complete public projection';end if;
 if (select count(*) from public.feed_items)<>(select n from source_release_feed_before) then raise exception 'FAIL automatic Feed publication';end if;
end $$;
select set_config('request.jwt.claims','{"role":"anon"}',true);
set local role anon;
do $$declare result jsonb;begin
 result:=public.get_editorial_article('a4100000-0000-4000-8000-000000000010','en',false)->'data';
 if result->>'publication_basis'<>'source_faithful' or result->>'verification_state'<>'unverified' then raise exception 'FAIL anonymous public reader';end if;
 result:=public.get_editorial_article('a4100000-0000-4000-8000-000000000010','fa',false)->'data';
 if result->>'publication_basis'<>'source_faithful' or result->>'locale'<>'fa' then raise exception 'FAIL shared-catalog Persian source reader';end if;
 begin perform public.get_editorial_article('a4100000-0000-4000-8000-000000000010','en',true);raise exception 'FAIL anonymous preview';exception when sqlstate 'PT403' then null;end;
end $$;
reset role;
\if :{?rad_keep_source_fixture}
-- The caller owns this same transaction and must roll it back.
\else
rollback;
\endif
