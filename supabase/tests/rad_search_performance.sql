-- Synthetic 10,000-section load test; no immigration facts and no retained data.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values('a6000000-0000-4000-8000-000000000001','synthetic-search@example.invalid');
update public.profiles set role='admin' where id='a6000000-0000-4000-8000-000000000001';
insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
select gen_random_uuid(),'related','ZZ','synthetic-load','synthetic-load-'||n,'a6000000-0000-4000-8000-000000000001' from generate_series(1,100) n;
insert into public.visa_article_revisions(article_id,locale,revision,title,summary,content_hash,body,created_by)
select id,'en',1,'SYNTHETIC benchmark article','No immigration facts.',repeat('0',64),'{"sections":[],"related_article_ids":[]}','a6000000-0000-4000-8000-000000000001' from public.visa_articles where pathway_slug='synthetic-load';
insert into public.visa_article_sections(revision_id,id,anchor,heading,position,blocks,evidence_refs)
select r.id,gen_random_uuid(),'section-'||n,'SYNTHETIC section '||n,n,
jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'type','paragraph','text','SYNTHETIC benchmark marker searchable body section '||n||' 😀 کتاب فارسی sample.','items','[]'::jsonb)),'[]'
from public.visa_article_revisions r join public.visa_articles a on a.id=r.article_id cross join generate_series(1,100) n where a.pathway_slug='synthetic-load';
-- Set published pointers only inside this rollback-only index fixture.
insert into public.visa_article_heads(article_id,locale,head_id,published_id)
select r.article_id,'en',r.id,r.id from public.visa_article_revisions r join public.visa_articles a on a.id=r.article_id where a.pathway_slug='synthetic-load';
analyze public.visa_article_search_documents;
do $$ declare request jsonb;first jsonb;second jsonb;cursor text;version text;start_at timestamptz;elapsed numeric;timings numeric[]:='{}';p95 numeric;i integer;begin
 if (select count(*) from public.visa_article_search_documents where body like 'SYNTHETIC benchmark%')<>10000 then raise exception 'load fixture incomplete';end if;
 request:='{"query":"searchable","locale":"en","country_codes":["ZZ"],"pathway_slugs":["synthetic-load"],"article_kind":"related","allow_locale_fallback":false,"cursor":null,"limit":20}';
 for i in 1..20 loop
  start_at:=clock_timestamp();first:=public.search_visa_articles(request);elapsed:=extract(epoch from clock_timestamp()-start_at)*1000;timings:=timings||elapsed;
 end loop;
 select percentile_cont(0.95) within group(order by x) into p95 from unnest(timings) x;
 raise notice 'SYNTHETIC search 10000 sections, 20 warm broad-query samples, p95_ms=%',round(p95,3);
 cursor:=first->'page'->>'next_cursor';
 if cursor is null or jsonb_array_length(first->'data'->'items')<>20 then raise exception 'load pagination first page';end if;
 second:=public.search_visa_articles(request||jsonb_build_object('cursor',cursor));
 if exists(select 1 from jsonb_array_elements(first->'data'->'items') a join jsonb_array_elements(second->'data'->'items') b on a->>'section_id'=b->>'section_id') then raise exception 'duplicate search page';end if;
 -- Revocation must invalidate both visibility and an outstanding cursor.
 update public.visa_article_heads set published_id=null where article_id=(first->'data'->'items'->0->>'article_id')::uuid;
 begin perform public.search_visa_articles(request||jsonb_build_object('cursor',cursor));raise exception 'publication revoke cursor replay';exception when sqlstate 'PT409' then null;end;
 second:=public.search_visa_articles(request);
 if exists(select 1 from jsonb_array_elements(second->'data'->'items') a where a->>'article_id'=first->'data'->'items'->0->>'article_id') then raise exception 'unpublished search leak';end if;
end $$;
rollback;
