begin;
create or replace function public.get_editorial_link_review(p_article_id uuid,p_locale text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare categories jsonb;countries jsonb;begin
 perform private.rad_require_admin();
 if p_locale is null or p_locale not in('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
 if private.rad_editorial_card(p_article_id,p_locale,true) is null then raise exception 'not_found' using errcode='PT404';end if;
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('title',card->>'title','review_kind','category') order by r.rank,r.related_id),'[]') into categories
 from private.rad_editorial_relations r cross join lateral(select private.rad_editorial_card(r.related_id,p_locale,true)card)x
 where r.parent_id=p_article_id and card is not null;
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('review_kind','country') order by r.country_code),'[]') into countries
 from private.rad_editorial_country_titles r where r.article_id=p_article_id;
 return private.rad_envelope(jsonb_build_object('category_links',categories,'country_links',countries),p_locale);
end $$;
revoke all on function public.get_editorial_link_review(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.get_editorial_link_review(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
