-- Internal head-delete maintenance regression. No public deletion API is added.
-- Synthetic bodies and pointers exist only in this rollback-only transaction.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('f1000000-0000-4000-8000-000000000010','synthetic-head-delete@example.invalid');
insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
 values('f1000000-0000-4000-8000-000000000011','related','ZZ','synthetic-delete',
 'synthetic-delete','f1000000-0000-4000-8000-000000000010');
insert into public.visa_article_revisions(article_id,locale,revision,title,summary,content_hash,body,created_by)
 select 'f1000000-0000-4000-8000-000000000011',locale,1,'SYNTHETIC head delete',
 'No immigration facts.',repeat('0',64),'{"sections":[],"related_article_ids":[]}',
 'f1000000-0000-4000-8000-000000000010' from unnest(array['fa','en'])locale;
insert into public.visa_article_sections(revision_id,id,anchor,heading,position,blocks,evidence_refs)
 select id,gen_random_uuid(),'overview','SYNTHETIC',0,
 jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'type','paragraph',
 'text','Synthetic deletion regression body.','items','[]'::jsonb)),'[]'
 from public.visa_article_revisions where article_id='f1000000-0000-4000-8000-000000000011';
insert into public.visa_article_heads(article_id,locale,head_id,published_id)
 select article_id,locale,id,id from public.visa_article_revisions
 where article_id='f1000000-0000-4000-8000-000000000011';
do $$declare v bigint;begin
 if (select count(*) from public.visa_article_search_documents
     where article_id='f1000000-0000-4000-8000-000000000011')<>2 then
   raise exception 'both locale search fixtures were not indexed';end if;
 select version into v from private.rad_search_version where id=true;
 delete from public.visa_article_heads
 where article_id='f1000000-0000-4000-8000-000000000011' and locale='en';
 if exists(select 1 from public.visa_article_search_documents
     where article_id='f1000000-0000-4000-8000-000000000011' and locale='en') then
   raise exception 'deleted head retained stale search rows';end if;
 if (select count(*) from public.visa_article_search_documents
     where article_id='f1000000-0000-4000-8000-000000000011' and locale='fa')<>1 then
   raise exception 'deleting en removed the independent fa projection';end if;
 if (select version from private.rad_search_version where id=true)<>v+1 then
   raise exception 'published-head deletion did not invalidate index cursor version';end if;
 -- Unpublish first: deleting an already empty projection must not churn version.
 update public.visa_article_heads set published_id=null
 where article_id='f1000000-0000-4000-8000-000000000011' and locale='fa';
 select version into v from private.rad_search_version where id=true;
 delete from public.visa_article_heads where article_id='f1000000-0000-4000-8000-000000000011';
 if (select version from private.rad_search_version where id=true)<>v then
   raise exception 'unpublished empty-head deletion changed search generation';end if;
 if exists(select 1 from unnest(array['anon','authenticated','service_role']) r
   where has_function_privilege(r,'private.rad_remove_article_search()','EXECUTE')) then
   raise exception 'internal trigger EXECUTE exposed to clients or service';end if;
 if has_table_privilege('authenticated','public.visa_article_heads','DELETE') then
   raise exception 'client head deletion unexpectedly granted';end if;
end $$;
select 'PASS: deletion clears only its locale, invalidates published cursors, preserves unpublished generation and denies direct clients' as result;
rollback;
