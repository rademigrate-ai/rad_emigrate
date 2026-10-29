-- Synthetic, rollback-only published-pointer/translation regression.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values('f1000000-0000-4000-8000-000000000010','synthetic-slug@example.invalid');
insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
values('f1000000-0000-4000-8000-000000000011','related','ZZ','synthetic-route','synthetic-slug','f1000000-0000-4000-8000-000000000010');
insert into public.visa_article_revisions(article_id,locale,revision,title,summary,content_hash,body,created_by)
values('f1000000-0000-4000-8000-000000000011','en',1,'SYNTHETIC slug fixture','No legal claims',repeat('0',64),'{"sections":[],"related_article_ids":[]}','f1000000-0000-4000-8000-000000000010');
insert into public.visa_article_heads(article_id,locale,head_id,published_id)
select article_id,locale,id,null from public.visa_article_revisions where article_id='f1000000-0000-4000-8000-000000000011';
set local role anon;
do $$begin
 begin perform public.resolve_editorial_article_slug('ZZ','synthetic-slug','en');raise exception 'FAIL slug leaked draft';exception when sqlstate 'PT404' then null;end;
end $$;
reset role;
update public.visa_article_heads set published_id=head_id where article_id='f1000000-0000-4000-8000-000000000011';
set local role anon;
do $$begin
 if public.resolve_editorial_article_slug('zz','synthetic-slug','en')->'data'->>'article_id'<>'f1000000-0000-4000-8000-000000000011' then raise exception 'FAIL slug did not resolve published UUID';end if;
 begin perform public.resolve_editorial_article_slug('ZZ','synthetic-slug','fa');raise exception 'FAIL invented translation';exception when sqlstate 'PT404' then null;end;
 begin perform public.resolve_editorial_article_slug('CA','synthetic-slug','en');raise exception 'FAIL mixed country';exception when sqlstate 'PT404' then null;end;
end $$;
reset role;
update public.visa_article_heads set published_id=null where article_id='f1000000-0000-4000-8000-000000000011';
set local role anon;
do $$begin
 begin perform public.resolve_editorial_article_slug('ZZ','synthetic-slug','en');raise exception 'FAIL unpublish still resolved';exception when sqlstate 'PT404' then null;end;
end $$;
rollback;
