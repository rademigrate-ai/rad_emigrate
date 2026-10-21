-- Confirmed CMS editor defect: no approved head/draft read interface existed.
-- Additive, read-only RPCs; no direct table grants. Hosted application prohibited.
begin;
insert into private.rad_contract_schemas(name,schema) values ('CmsDraftContent','{"type":"object","properties":{"article_id":{"$ref":"#/$defs/UUID"},"locale":{"$ref":"#/$defs/Locale"},"expected_revision":{"type":"integer","minimum":0,"maximum":2147483647},"title":{"type":"string","minLength":1,"maxLength":300},"summary":{"type":"string","minLength":0,"maxLength":1500},"sections":{"type":"array","items":{"$ref":"#/$defs/ArticleSectionInput"},"maxItems":100},"related_article_ids":{"type":"array","items":{"$ref":"#/$defs/UUID"},"maxItems":100},"merge_manifest_id":{"anyOf":[{"$ref":"#/$defs/UUID"},{"type":"null"}]}},"required":["article_id","locale","expected_revision","title","summary","sections","related_article_ids","merge_manifest_id"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values ('CmsArticleListItem','{"type":"object","properties":{"id":{"$ref":"#/$defs/UUID"},"slug":{"type":"string"},"country_code":{"type":"string"},"kind":{"enum":["main","related"]},"locale":{"$ref":"#/$defs/Locale"},"title":{"type":"string"},"revision":{"type":"integer","minimum":1},"editorial_state":{"$ref":"#/$defs/EditorialState"},"verification_state":{"$ref":"#/$defs/ClaimVerificationState"},"updated_at":{"$ref":"#/$defs/Timestamp"}},"required":["id","slug","country_code","kind","locale","title","revision","editorial_state","verification_state","updated_at"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values ('list_cms_articles_request','{"type":"object","properties":{"locale":{"$ref":"#/$defs/Locale"},"cursor":{"anyOf":[{"type":"string","minLength":1,"maxLength":2048},{"type":"null"}]},"limit":{"type":"integer","minimum":1,"maximum":50}},"required":["locale","cursor","limit"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values ('list_cms_articles_response','{"type":"object","properties":{"data":{"type":"object","properties":{"items":{"type":"array","items":{"$ref":"#/$defs/CmsArticleListItem"},"maxItems":50}},"required":["items"],"additionalProperties":false},"meta":{"$ref":"#/$defs/Meta"},"page":{"$ref":"#/$defs/Page"}},"required":["data","meta","page"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values ('get_cms_article_draft_request','{"type":"object","properties":{"article_id":{"$ref":"#/$defs/UUID"},"locale":{"$ref":"#/$defs/Locale"}},"required":["article_id","locale"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values ('get_cms_article_draft_response','{"type":"object","properties":{"data":{"type":"object","properties":{"revision_id":{"$ref":"#/$defs/UUID"},"revision":{"type":"integer","minimum":1},"editorial_state":{"$ref":"#/$defs/EditorialState"},"verification_state":{"$ref":"#/$defs/ClaimVerificationState"},"updated_at":{"$ref":"#/$defs/Timestamp"},"content":{"$ref":"#/$defs/CmsDraftContent"}},"required":["revision_id","revision","editorial_state","verification_state","updated_at","content"],"additionalProperties":false},"meta":{"$ref":"#/$defs/Meta"}},"required":["data","meta"],"additionalProperties":false}'::jsonb);

create function public.list_cms_articles(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare items jsonb; version text; off integer; lim integer; total integer;
begin
 perform private.rad_require_admin(); perform private.rad_assert_request('list_cms_articles',p_request);
 lim:=(p_request->>'limit')::integer;
 select md5(coalesce(string_agg(head_id::text,',' order by article_id),'')) into version
 from public.visa_article_heads where locale=p_request->>'locale';
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 select count(*) into total from public.visa_article_heads where locale=p_request->>'locale' and head_id is not null;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'slug',a.slug,'country_code',a.country_code,'kind',a.kind,
  'locale',r.locale,'title',r.title,'revision',r.revision,'editorial_state',private.rad_article_state(r.id),
  'verification_state',private.rad_article_verification(r.id),
  'updated_at',to_char(r.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) order by a.id),'[]') into items
 from (select * from public.visa_article_heads where locale=p_request->>'locale' and head_id is not null order by article_id offset off limit lim) h
 join public.visa_articles a on a.id=h.article_id join public.visa_article_revisions r on r.id=h.head_id;
 return private.rad_envelope(jsonb_build_object('items',items),p_request->>'locale',
  private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
create function public.get_cms_article_draft(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;
begin
 perform private.rad_require_admin(); perform private.rad_assert_request('get_cms_article_draft',p_request);
 select rev.* into r from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id
 where h.article_id=(p_request->>'article_id')::uuid and h.locale=p_request->>'locale';
 if not found then raise exception 'not_found' using errcode='PT404'; end if;
 return private.rad_envelope(jsonb_build_object('revision_id',r.id,'revision',r.revision,
  'editorial_state',private.rad_article_state(r.id),'verification_state',private.rad_article_verification(r.id),
  'updated_at',to_char(r.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'content',(r.body-'request_key')||jsonb_build_object('expected_revision',r.revision)),r.locale);
end $$;
revoke all on function public.list_cms_articles(jsonb),public.get_cms_article_draft(jsonb) from public,anon,service_role;
grant execute on function public.list_cms_articles(jsonb),public.get_cms_article_draft(jsonb) to authenticated;
commit;
