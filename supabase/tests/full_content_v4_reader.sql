-- Rollback-only authorization and complete-body projection checks.
begin;
-- This suite opens every complete corpus reader in one rollback-only query.
-- Per-request timings are recorded separately by the browser/RPC runner.
set local statement_timeout='600s';
create temporary table v4_published_before as select article_id,locale,published_id from public.visa_article_heads;
create temporary table v4_expected_public as select count(*) expected_count from public.visa_article_heads h join private.rad_editorial_catalog c on c.article_id=h.article_id where h.locale='fa' and h.published_id is not null and c.active and c.content_class='editorial';
grant select on v4_expected_public to anon;
do $$begin
 if has_function_privilege('anon','public.import_editorial_draft(uuid,text,uuid,jsonb,jsonb)','execute') then raise exception 'v4_import_public';end if;
 if has_table_privilege('authenticated','private.rad_editorial_catalog','select') then raise exception 'v4_catalog_public';end if;
end $$;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$declare r jsonb;begin
 r:=public.list_editorial_library('fa',false,0,100);
 if jsonb_array_length(r->'data'->'items')<>(select expected_count from v4_expected_public) then raise exception 'v4_public_library_visibility';end if;
 begin perform public.list_editorial_library('fa',true,0,20);raise exception 'v4_anon_preview_allowed';exception when sqlstate 'PT403' then null;end;
 begin perform public.list_editorial_library('fa',null,0,20);raise exception 'v4_null_preview_allowed';exception when sqlstate 'PT422' then null;end;
 begin perform public.list_editorial_library('fa',false,-1,20);raise exception 'v4_invalid_offset';exception when sqlstate 'PT422' then null;end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000000","user_metadata":{"role":"admin"}}',true);
do $$begin
 begin perform public.list_editorial_library('fa',true,0,20);raise exception 'v4_ordinary_user_preview_allowed';exception when sqlstate 'PT403' then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"0166163b-582b-4d2e-82dc-f9942c2f80b5"}',true);
do $$declare r jsonb;entry record;all_items integer:=0;pos integer:=0;begin
 loop
  r:=public.list_editorial_library('fa',true,pos,100);
  all_items:=all_items+jsonb_array_length(r->'data'->'items');
  if exists(select 1 from jsonb_array_elements(r->'data'->'items')x where x->>'content_class'<>'editorial') then raise exception 'v4_noneditorial_in_library';end if;
  exit when not (r->'data'->>'has_more')::boolean;
  pos:=(r->'data'->>'next_cursor')::integer;
 end loop;
 if all_items<>(select count(*) from private.rad_editorial_catalog c join public.visa_article_heads h on h.article_id=c.article_id where c.active and c.content_class='editorial' and h.locale='fa' and h.head_id is not null) then raise exception 'v4_pagination_omits_articles';end if;
 for entry in select h.article_id,h.locale,h.head_id,rr.composition from public.visa_article_heads h join private.rad_editorial_rich_revisions rr on rr.revision_id=h.head_id join private.rad_editorial_catalog c on c.article_id=h.article_id where c.active loop
  r:=public.get_editorial_article(entry.article_id,entry.locale,true);
  if r->'data'->'rich_sections' is distinct from entry.composition->'sections' then raise exception 'v4_reader_truncates_body';end if;
  if r->'data'->'source_assets' is distinct from coalesce(entry.composition->'source_assets','[]'::jsonb) then raise exception 'v4_media_projection_lost';end if;
 end loop;
 if exists(select 1 from v4_published_before b join public.visa_article_heads h using(article_id,locale) where h.published_id is distinct from b.published_id) then raise exception 'v4_publication_changed';end if;
end $$;
select 'PASS V4 library pagination, anonymous preview denial, complete reader and media projection, unchanged publication';
rollback;
