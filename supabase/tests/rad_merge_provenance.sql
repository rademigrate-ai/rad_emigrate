begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values('a3000000-0000-4000-8000-000000000001','rad-merge-admin@example.invalid');
update public.profiles set role='admin' where id='a3000000-0000-4000-8000-000000000001';
insert into public.destinations(code,slug) values('ZZ','synthetic-merge-only');
insert into public.source_documents(id,canonical_url,source_authority,title,language_code) values
 ('d3000000-0000-4000-8000-000000000001','https://radvisa.com/synthetic-test-only','rad_official','Synthetic alpha','en'),
 ('d3000000-0000-4000-8000-000000000002','https://digivisa.ir/synthetic-test-only','rad_official','Synthetic bravo','en'),
 ('d3000000-0000-4000-8000-000000000003','https://radmohajer.ir/synthetic-test-only','rad_official','Synthetic excluded','en');
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status) values
 ('f3000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Synthetic unique alpha material.',encode(extensions.digest('Synthetic unique alpha material.','sha256'),'hex'),200),
 ('f3000000-0000-4000-8000-000000000002','d3000000-0000-4000-8000-000000000002','Synthetic unique bravo material.',encode(extensions.digest('Synthetic unique bravo material.','sha256'),'hex'),200),
 ('f3000000-0000-4000-8000-000000000003','d3000000-0000-4000-8000-000000000003','Synthetic prohibited ancestry.',encode(extensions.digest('Synthetic prohibited ancestry.','sha256'),'hex'),200);
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a3000000-0000-4000-8000-000000000001"}',true);
select public.create_visa_article('{"article_id":"b3000000-0000-4000-8000-000000000001","kind":"main","country_code":"ZZ","pathway_slug":"synthetic","slug":"synthetic","request_key":"c3000000-0000-4000-8000-000000000001"}');
do $$ begin
 begin perform public.approve_visa_source_inventory('{"article_id":"b3000000-0000-4000-8000-000000000001","source_snapshot_ids":["f3000000-0000-4000-8000-000000000001","f3000000-0000-4000-8000-000000000003"],"expected_inventory_revision":0,"request_key":"c3000000-0000-4000-8000-000000000002"}');raise exception 'RadMohajer main ancestry admitted';exception when sqlstate 'PT422' then null;end;
 perform public.approve_visa_source_inventory('{"article_id":"b3000000-0000-4000-8000-000000000001","source_snapshot_ids":["f3000000-0000-4000-8000-000000000001","f3000000-0000-4000-8000-000000000002"],"expected_inventory_revision":0,"request_key":"c3000000-0000-4000-8000-000000000003"}');
end $$;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$ declare result jsonb; begin
 result:=public.ingest_visa_snapshots('{"article_id":"b3000000-0000-4000-8000-000000000001","source_snapshot_ids":["f3000000-0000-4000-8000-000000000001","f3000000-0000-4000-8000-000000000002"],"expected_revision":0,"request_key":"c3000000-0000-4000-8000-000000000004"}');
 if result->'data'->'draft'->>'editorial_state'<>'draft' then raise exception 'worker auto-approved'; end if;
 if result->'data'->'draft'->>'verification_state'<>'unverified' then raise exception 'worker fabricated factual verification'; end if;
 begin perform public.publish_visa_article_revision(jsonb_build_object('article_id',result->'data'->'draft'->'article_id','revision_id',result->'data'->'draft'->'revision_id','content_hash',result->'data'->'draft'->'content_hash','request_key','c3000000-0000-4000-8000-000000000005'));raise exception 'worker published';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a3000000-0000-4000-8000-000000000001"}',true);
do $$ declare r public.visa_article_revisions;request jsonb;article jsonb;changed jsonb; begin
 select * into r from public.visa_article_revisions where article_id='b3000000-0000-4000-8000-000000000001';
 request:=jsonb_build_object('article_id',r.article_id,'revision_id',r.id,'expected_revision',r.revision,'content_hash',r.content_hash,'note','','request_key','c3000000-0000-4000-8000-000000000006');
 perform public.submit_visa_article_review(request);perform public.approve_visa_article_revision(request||'{"request_key":"c3000000-0000-4000-8000-000000000007"}');
 perform public.publish_visa_article_revision((request-'expected_revision'-'note')||'{"request_key":"c3000000-0000-4000-8000-000000000008"}');
 article:=public.get_visa_article('{"selector":{"country_code":"ZZ","pathway_slug":"synthetic","kind":"main"},"locale":"en"}');
 if jsonb_array_length(article->'data'->'sections')<>2 then raise exception 'merge lost independent source section'; end if;
 changed:=r.body||jsonb_build_object('sections',jsonb_set(r.body->'sections','{0,blocks}','[]'),'expected_revision',1,'request_key','c3000000-0000-4000-8000-000000000009');
 request:=public.save_visa_article_draft(changed)->'data';
 request:=jsonb_build_object('article_id',request->'article_id','revision_id',request->'revision_id','expected_revision',request->'revision','content_hash',request->'content_hash','note','','request_key','c3000000-0000-4000-8000-000000000010');
 perform public.submit_visa_article_review(request);perform public.approve_visa_article_revision(request||'{"request_key":"c3000000-0000-4000-8000-000000000011"}');
 begin perform public.publish_visa_article_revision((request-'expected_revision'-'note')||'{"request_key":"c3000000-0000-4000-8000-000000000012"}');raise exception 'unique source content loss published';exception when sqlstate 'PT422' then null; end;
end $$;
rollback;
