-- Published-only compatibility for legacy independent-article bookmarks.
begin;
create or replace function public.resolve_editorial_article_slug(p_country_code text,p_slug text,p_locale text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text;ids uuid[];begin
 if p_locale is null or p_locale not in('fa','en') or p_slug is null or length(p_slug)<1 or length(p_slug)>160
 or p_country_code is null or length(p_country_code)>100 then raise exception 'invalid_slug_selector' using errcode='PT422';end if;
 if p_country_code~'^[A-Za-z]{2}$' then code:=upper(p_country_code);else
 select d.code into code from public.destinations d where d.status='published' and (d.slug=lower(p_country_code) or d.id::text=p_country_code);
 end if;
 select array_agg(a.id order by a.id) into ids from public.visa_articles a
 where a.kind='related' and a.slug=p_slug and (a.country_code=code or exists(select 1 from private.rad_editorial_catalog c
 where c.article_id=a.id and c.active and code=any(c.country_codes)))
 and private.rad_editorial_card(a.id,p_locale,false) is not null;
 if coalesce(cardinality(ids),0)=0 then raise exception 'article_or_translation_not_found' using errcode='PT404';end if;
 if cardinality(ids)>1 then raise exception 'ambiguous_legacy_slug_use_uuid' using errcode='PT409';end if;
 return private.rad_envelope(jsonb_build_object('article_id',ids[1]),p_locale);
end $$;
revoke all on function public.resolve_editorial_article_slug(text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.resolve_editorial_article_slug(text,text,text) to anon,authenticated;
notify pgrst,'reload schema';
commit;
