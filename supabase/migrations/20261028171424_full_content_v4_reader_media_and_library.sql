-- Additive V4 reader projections. Publication pointers and review gates stay
-- controlled by the existing publication API. No historical migration replay.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

create or replace function public.get_editorial_article(p_article_id uuid,p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare card jsonb;sections jsonb;sources jsonb;rid uuid;available jsonb;rich jsonb;begin
 if p_locale is null or p_locale not in('fa','en') or p_preview is null then raise exception 'invalid_locale_or_preview' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 card:=private.rad_editorial_card(p_article_id,p_locale,p_preview);
 if card is null then raise exception 'article_or_translation_not_found' using errcode='PT404';end if;
 rid:=(card->>'revision_id')::uuid;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'anchor',s.anchor,'heading',s.heading,'order',s.position,'blocks',s.blocks,
 'evidence',(select coalesce(jsonb_agg(private.rad_evidence(e,s.id)),'[]') from jsonb_array_elements(s.evidence_refs)e)) order by s.position),'[]') into sections
 from public.visa_article_sections s where s.revision_id=rid;
 select coalesce(jsonb_agg(source order by source->>'url'),'[]') into sources from(
 select distinct private.rad_evidence(e,s.id)-'section_id'-'excerpt'-'locator'-'claim_id' source
 from public.visa_article_sections s cross join lateral jsonb_array_elements(s.evidence_refs)e where s.revision_id=rid)x;
 select coalesce(jsonb_agg(locale order by locale),'[]') into available from public.visa_article_heads
 where article_id=p_article_id and case when p_preview then head_id else published_id end is not null;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=rid;
 return private.rad_envelope(card||jsonb_build_object('sections',sections,'sources',sources||private.rad_editorial_sources(rid),'available_locales',available,
 'translation_fallback_used',false,'preview',p_preview,
 'content_contract_version','editorial-4',
 'projection_map',rich->'projection_map','rich_sections',rich->'sections',
 'source_assets',coalesce(rich->'source_assets','[]'::jsonb),
 'source_links',coalesce(rich->'source_links','[]'::jsonb),
 'composition_policy',rich->'composition_policy',
 'other_titles',private.rad_editorial_other_titles(p_article_id,rid,p_locale,p_preview)),p_locale);
end $$;
revoke all on function public.get_editorial_article(uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.get_editorial_article(uuid,text,boolean) to anon,authenticated;

create or replace function public.list_editorial_library(p_locale text,p_preview boolean default false,p_offset integer default 0,p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
declare items jsonb;more boolean;begin
 if p_locale is null or p_locale not in('fa','en') or p_preview is null or p_offset is null or p_offset<0 or p_offset>1000000 or p_limit is null or p_limit<1 or p_limit>100 then raise exception 'invalid_library_page' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 -- Bound candidates BEFORE calculating verification/evidence on each card.
 -- A filter on the card function itself evaluates the entire catalog for every
 -- page and made the admin library unusably slow on the complete corpus.
 with candidates as materialized(
 select c.article_id from private.rad_editorial_catalog c
 join public.visa_article_heads h on h.article_id=c.article_id and h.locale=p_locale
 join public.visa_article_revisions r on r.id=case when p_preview then h.head_id else h.published_id end
 where c.active and c.content_class='editorial'
 order by c.article_id offset p_offset limit p_limit+1)
 select coalesce(jsonb_agg(private.rad_editorial_card(article_id,p_locale,p_preview) order by article_id),'[]'::jsonb) into items from candidates;
 more:=jsonb_array_length(items)>p_limit;
 if more then items:=items-p_limit;end if;
 return private.rad_envelope(jsonb_build_object('items',items,'has_more',more,
 'next_cursor',case when more then (p_offset+p_limit)::text else null end,'preview',p_preview),p_locale);
end $$;
revoke all on function public.list_editorial_library(text,boolean,integer,integer) from public,anon,authenticated,service_role;
grant execute on function public.list_editorial_library(text,boolean,integer,integer) to anon,authenticated;
notify pgrst,'reload schema';
commit;
