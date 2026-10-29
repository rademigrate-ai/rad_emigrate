-- Forward-only reader additions. No historical migration is rewritten.
begin;
create or replace function private.rad_editorial_sources(revision uuid) returns jsonb
language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('source_document_id',d.id,'snapshot_id',s.id,'url',d.canonical_url,
 'publisher',d.title,'fetched_at',s.fetched_at,'body_sha256',s.content_hash,'verification_state','unverified') order by d.canonical_url),'[]')
 from public.source_snapshots s join public.source_documents d on d.id=s.document_id
 where s.id in(select distinct (ref->>'snapshot_id')::uuid from private.rad_editorial_rich_revisions r
 cross join lateral jsonb_array_elements(r.composition->'sections')sec
 cross join lateral jsonb_array_elements(sec->'blocks')b
 cross join lateral jsonb_array_elements(b->'provenance')ref where r.revision_id=revision);
$$;
create or replace function private.rad_editorial_other_titles(article uuid,revision uuid,loc text,preview boolean) returns jsonb
language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(item order by priority,ordinality),'[]') from(
 select distinct on(item->>'id') item,priority,ordinality from(
 select item,0 priority,ordinality from jsonb_array_elements(public.list_editorial_relations(article,loc,preview)->'data'->'items') with ordinality x(item,ordinality)
 union all
 select item,1 priority,ordinality from jsonb_array_elements(private.rad_related(revision,loc)) with ordinality x(item,ordinality)
 )all_titles order by item->>'id',priority,ordinality)unique_titles;
$$;
revoke all on function private.rad_editorial_sources(uuid),private.rad_editorial_other_titles(uuid,uuid,text,boolean)
 from public,anon,authenticated,service_role;
create or replace function public.get_editorial_article(p_article_id uuid,p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare card jsonb;sections jsonb;sources jsonb;rid uuid;available jsonb;begin
 if p_locale not in('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
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
 return private.rad_envelope(card||jsonb_build_object('sections',sections,'sources',sources||private.rad_editorial_sources(rid),'available_locales',available,
 'translation_fallback_used',false,'preview',p_preview,
 'content_contract_version','editorial-3',
 'projection_map',(select composition->'projection_map' from private.rad_editorial_rich_revisions where revision_id=rid),
 'rich_sections',(select composition->'sections' from private.rad_editorial_rich_revisions where revision_id=rid),'other_titles',private.rad_editorial_other_titles(p_article_id,rid,p_locale,p_preview)),p_locale);
end $$;

create or replace function public.list_visa_content_countries(p_locale text,p_preview boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare items jsonb;begin
 if p_locale is null or p_locale not in('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
 if p_preview then perform private.rad_require_admin();end if;
 select coalesce(jsonb_agg(jsonb_build_object('country_code',code,'category_count',n) order by code),'[]') into items from(
 select c.country_codes[1] code,count(*) n from private.rad_editorial_catalog c
 cross join lateral(select private.rad_editorial_card(c.article_id,p_locale,p_preview)card)x
 where c.active and c.content_class='canonical' and cardinality(c.country_codes)=1 and card is not null group by c.country_codes[1])countries;
 return private.rad_envelope(jsonb_build_object('items',items,'preview',p_preview),p_locale);
end $$;
revoke all on function public.list_visa_content_countries(text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.list_visa_content_countries(text,boolean) to anon,authenticated;
notify pgrst,'reload schema';
commit;
