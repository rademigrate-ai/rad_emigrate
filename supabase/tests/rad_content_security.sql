-- Synthetic, transaction-rolled-back role and content integration regression.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('a0000000-0000-4000-8000-000000000001','rad-admin@example.invalid'),
 ('a0000000-0000-4000-8000-000000000002','rad-user@example.invalid'),
 ('a0000000-0000-4000-8000-000000000003','rad-other@example.invalid');
update public.profiles set role='admin' where id='a0000000-0000-4000-8000-000000000001';
insert into public.destinations(code,slug) values('ZZ','synthetic-test-only');

set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000002","user_metadata":{"role":"super_admin"}}',true);
do $$ begin
 begin
  update public.profiles set role='super_admin' where id=auth.uid();
  raise exception 'SECURITY FAILURE: UPDATE escalation admitted';
 exception when insufficient_privilege then null; end;
 begin
  perform public.create_visa_article('{"article_id":"b0000000-0000-4000-8000-000000000001","kind":"related","country_code":"ZZ","pathway_slug":"test","slug":"test","request_key":"c0000000-0000-4000-8000-000000000001"}');
  raise exception 'SECURITY FAILURE: forged metadata admin admitted';
 exception when sqlstate 'PT403' then null; end;
 begin perform public.list_cms_articles('{"locale":"en","cursor":null,"limit":50}'); raise exception 'CMS admin guard bypass'; exception when sqlstate 'PT403' then null; end;
 begin perform public.get_cms_article_draft('{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en"}'); raise exception 'CMS draft leaked'; exception when sqlstate 'PT403' then null; end;
 begin
  perform * from public.visa_article_revisions;
  raise exception 'SECURITY FAILURE: direct draft access';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000001"}',true);
do $$
declare created jsonb; draft jsonb; result jsonb; request jsonb; publication jsonb;
begin
 request:='{"article_id":"b0000000-0000-4000-8000-000000000001","kind":"related","country_code":"ZZ","pathway_slug":"test","slug":"test","request_key":"c0000000-0000-4000-8000-000000000001"}';
 created:=public.create_visa_article(request);
 if created<>public.create_visa_article(request) then raise exception 'idempotent create differs'; end if;
 begin perform public.create_visa_article(request||'{"slug":"different"}');raise exception 'changed-key replay admitted';exception when sqlstate 'PT409' then null;end;
 request:='{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en","expected_revision":0,"title":"Synthetic source-neutral article","summary":"Test content, no immigration rules.","sections":[{"id":"d0000000-0000-4000-8000-000000000001","anchor":"overview","heading":"Synthetic overview","order":0,"blocks":[{"id":"e0000000-0000-4000-8000-000000000001","type":"paragraph","text":"This synthetic paragraph contains a searchable full body marker alphabravo.","items":[]}],"evidence_refs":[]}],"related_article_ids":[],"merge_manifest_id":null,"request_key":"c0000000-0000-4000-8000-000000000002"}';
 draft:=public.save_visa_article_draft(request)->'data';
 if draft->>'verification_state'<>'unverified' then raise exception 'draft acquired factual trust'; end if;
 result:=public.get_cms_article_draft('{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en"}');
 if result->'meta'->>'contract_version'<>'1' then raise exception 'CMS head contract';end if;
 if result->'data'->'content'->>'article_id'<>draft->>'article_id' or result->'data'->'content'->>'expected_revision'<>'1' or result->'data'->'content'->'sections'<>request->'sections' then raise exception 'CMS head loss/identity';end if;
 result:=public.list_cms_articles('{"locale":"en","cursor":null,"limit":50}');
 if result->'meta'->>'contract_version'<>'1' or jsonb_array_length(result->'data'->'items')<>1 then raise exception 'CMS list contract';end if;
 begin perform public.get_cms_article_draft('{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"fa"}');raise exception 'CMS silently changed locale';exception when sqlstate 'PT404' then null;end;

 begin perform public.save_visa_article_draft(request||'{"expected_revision":99,"request_key":"c0000000-0000-4000-8000-000000000099"}');raise exception 'stale revision admitted';exception when sqlstate 'PT409' then null;end;
 begin perform public.get_visa_article('{"selector":{"article_id":"b0000000-0000-4000-8000-000000000001"},"locale":"en"}');raise exception 'draft leaked';exception when sqlstate 'PT404' then null;end;
 request:=jsonb_build_object('article_id',draft->'article_id','revision_id',draft->'revision_id','expected_revision',draft->'revision','content_hash',draft->'content_hash','note','','request_key','c0000000-0000-4000-8000-000000000003');
 perform public.submit_visa_article_review(request);
 result:=public.approve_visa_article_revision(request||'{"request_key":"c0000000-0000-4000-8000-000000000004"}');
 if result->'data'->>'verification_state'<>'unverified' then raise exception 'editorial approval acquired factual trust'; end if;
 publication:=public.publish_visa_article_revision((request-'expected_revision'-'note')||'{"request_key":"c0000000-0000-4000-8000-000000000005"}');
 result:=public.get_visa_article('{"selector":{"article_id":"b0000000-0000-4000-8000-000000000001"},"locale":"en"}');
 if result->'data'->>'editorial_state'<>'published' or result->'data'->>'verification_state'<>'unverified' then raise exception 'publication state mismatch'; end if;
 result:=public.search_visa_articles('{"query":"alphabravo","locale":"en","country_codes":["ZZ"],"pathway_slugs":[],"article_kind":null,"allow_locale_fallback":false,"cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>1 then raise exception 'full body search failed'; end if;
 perform public.save_visa_search_alias(jsonb_build_object('locale','en','alias','synthetic approved alias','canonical','alphabravo','enabled',true,'expected_revision',0,'request_key',gen_random_uuid()));
 result:=public.search_visa_articles('{"query":"synthetic approved alias","locale":"en","country_codes":["ZZ"],"pathway_slugs":[],"article_kind":null,"allow_locale_fallback":false,"cursor":null,"limit":20}');
 if result->'data'->'items'->0->>'match_kind'<>'synonym' then raise exception 'approved alias search';end if;
 result:=public.search_visa_articles('{"query":"alphabrvo","locale":"en","country_codes":["ZZ"],"pathway_slugs":[],"article_kind":null,"allow_locale_fallback":false,"cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>1 then raise exception 'typo fallback';end if;
 result:=public.search_visa_articles('{"query":"alphabravo","locale":"fa","country_codes":["ZZ"],"pathway_slugs":[],"article_kind":null,"allow_locale_fallback":false,"cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>0 then raise exception 'locale filter';end if;
 result:=public.search_visa_articles('{"query":"ZZ test","locale":"en","country_codes":["ZZ"],"pathway_slugs":["test"],"article_kind":"related","allow_locale_fallback":false,"cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>1 then raise exception 'country/pathway metadata search';end if;
end $$;

reset role;
do $$ begin
 if (select count(*) from public.visa_article_revision_events where state='published')<>1 then raise exception 'duplicate publish event'; end if;
 if has_column_privilege('authenticated','public.profiles','role','INSERT') then raise exception 'role INSERT grant retained'; end if;
 if has_function_privilege('anon','public.list_cms_articles(jsonb)','EXECUTE') or has_function_privilege('service_role','public.list_cms_articles(jsonb)','EXECUTE') or has_function_privilege('anon','public.get_cms_article_draft(jsonb)','EXECUTE') or has_function_privilege('service_role','public.get_cms_article_draft(jsonb)','EXECUTE') then raise exception 'CMS read RPC grant bypass';end if;

 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) then raise exception 'RLS disabled table'; end if;
end $$;

reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000002"}',true);
do $$ declare r jsonb;request jsonb;begin
 request:='{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en","section_id":"d0000000-0000-4000-8000-000000000001","saved":true,"expected_revision":0,"request_key":"c0000000-0000-4000-8000-000000000088"}';
 r:=public.save_visa_reading_state(request);
 if r->'data'->>'revision'<>'1' then raise exception 'reading revision';end if;
 r:=public.get_visa_reading_state('{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en"}');
 if r->'data'->>'saved'<>'true' or r->'data'->>'section_id'<>'d0000000-0000-4000-8000-000000000001' then raise exception 'resume pointer';end if;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000003"}',true);
 r:=public.get_visa_reading_state('{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en"}');
 if r->'data'->>'saved'<>'false' or r->'data'->>'revision'<>'0' then raise exception 'cross-user reading leak';end if;
end $$;

-- Stage 8B: real opaque pagination, cursor fencing and head-only locale reads.
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000001"}',true);
do $$
declare request jsonb; page_request jsonb; result jsonb; cursor text; seen uuid[]:='{}'; article uuid; i integer;
begin
 for i in 2..3 loop
  article:=format('b1000000-0000-4000-8000-%s',lpad(i::text,12,'0'))::uuid;
  perform public.create_visa_article(jsonb_build_object('article_id',article,'kind','related','country_code','ZZ','pathway_slug','synthetic','slug','stage8b-'||i,'request_key',gen_random_uuid()));
  request:=jsonb_build_object('article_id',article,'locale','en','expected_revision',0,'title','Synthetic pagination '||i,'summary','','sections','[]'::jsonb,'related_article_ids','[]'::jsonb,'merge_manifest_id',null,'request_key',gen_random_uuid());
  perform public.save_visa_article_draft(request);
 end loop;
 page_request:='{"locale":"en","cursor":null,"limit":1}';
 for i in 1..3 loop
  result:=public.list_cms_articles(page_request);
  assert jsonb_array_length(result->'data'->'items')=1,'bounded CMS page';
  article:=(result->'data'->'items'->0->>'id')::uuid;
  assert not article=any(seen),'CMS duplicate article across pages';
  seen:=array_append(seen,article);
  assert result->'data'->'items'->0->>'locale'='en','CMS wrong locale';
  cursor:=result->'page'->>'next_cursor';
  assert (result->'page'->>'has_more')::boolean=(i<3),'CMS last page flag';
  if i<3 then assert cursor is not null,'CMS missing cursor'; end if;
  page_request:=page_request||jsonb_build_object('cursor',cursor);
 end loop;
 result:=public.list_cms_articles('{"locale":"fa","cursor":null,"limit":1}');
 assert result->'data'->'items'='[]'::jsonb,'CMS invented untranslated heads';
 result:=public.list_cms_articles('{"locale":"en","cursor":null,"limit":1}');
 cursor:=result->'page'->>'next_cursor';
 -- Advance the selected head; an old cursor must not silently skip/repeat rows.
 request:=request||jsonb_build_object('expected_revision',1,'title','Synthetic updated head','request_key',gen_random_uuid());
 perform public.save_visa_article_draft(request);
 begin
  perform public.list_cms_articles(jsonb_build_object('locale','en','cursor',cursor,'limit',1));
  raise exception 'CMS accepted stale head-set cursor';
 exception when sqlstate 'PT409' then null; end;
 result:=public.get_cms_article_draft(jsonb_build_object('article_id',request->'article_id','locale','en'));
 assert result->'data'->>'revision'='2','CMS did not resolve actual head';
 assert result->'data'->'content'->>'expected_revision'='2','CMS stale save fence';
 assert result->'data'->'content'->>'title'='Synthetic updated head','CMS stale body';
 assert result->'data'->>'editorial_state'='draft','CMS auto-published saved revision';
end $$;
rollback;
