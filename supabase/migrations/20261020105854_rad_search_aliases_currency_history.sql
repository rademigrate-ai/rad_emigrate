begin;
-- Empty by default. Curated terminology is an editorial decision, not a
-- fabricated immigration fact or an LLM-generated synonym dictionary.
create table private.rad_search_aliases(
 locale text not null check(locale in ('fa','en')),alias text not null,canonical text not null,
 revision integer not null default 1,enabled boolean not null default true,
 approved_by uuid not null references auth.users(id),updated_at timestamptz not null default now(),primary key(locale,alias)
);
alter table private.rad_search_aliases enable row level security;
revoke all on private.rad_search_aliases from public,anon,authenticated,service_role;
create function public.save_visa_search_alias(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();prior jsonb;term text;target text;a private.rad_search_aliases;expected integer;
begin
 prior:=private.rad_begin_mutation('save_visa_search_alias',p_request);if prior is not null then return prior;end if;
 term:=private.rad_search_normalize(p_request->>'alias');target:=private.rad_search_normalize(p_request->>'canonical');
 if length(term)<2 or length(target)<2 or cardinality(string_to_array(target,' '))>8 then raise exception 'invalid_alias' using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('alias:'||(p_request->>'locale')||term,0));
 select * into a from private.rad_search_aliases where locale=p_request->>'locale' and alias=term for update;
 expected:=case when found then a.revision else 0 end;
 if expected<>(p_request->>'expected_revision')::integer then raise exception 'revision_conflict' using errcode='PT409';end if;
 insert into private.rad_search_aliases(locale,alias,canonical,revision,enabled,approved_by)
 values(p_request->>'locale',term,target,expected+1,(p_request->>'enabled')::boolean,actor)
 on conflict(locale,alias) do update set canonical=excluded.canonical,revision=excluded.revision,enabled=excluded.enabled,approved_by=actor,updated_at=now() returning * into a;
 update private.rad_search_version set version=version+1;
 return private.rad_finish_mutation('save_visa_search_alias',p_request,private.rad_envelope(jsonb_build_object('locale',a.locale,'alias',a.alias,'canonical',a.canonical,'revision',a.revision,'enabled',a.enabled)));
end $$;
revoke all on function public.save_visa_search_alias(jsonb) from public,anon,service_role;
grant execute on function public.save_visa_search_alias(jsonb) to authenticated;

create function private.rad_search_metadata(article uuid,locale text) returns text language sql stable set search_path='' as $$
 select a.country_code||' '||a.pathway_slug||' '||a.slug||' '||coalesce(l.name,'')
 from public.visa_articles a left join public.destinations d on d.code=a.country_code and d.status='published'
 left join public.destination_localizations l on l.destination_id=d.id and l.locale=$2 where a.id=$1;
$$;

-- A chart has one provider, with explicit gaps; fallback dates are never
-- silently spliced into a different provider's series.
create or replace function public.get_fx_history(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare items jsonb;off integer;lim integer:=(p_request->>'limit')::integer;version text;total integer;chosen text;gaps jsonb;
begin
 perform private.rad_assert_request('get_fx_history',p_request);
 if (p_request->>'date_to')::date-(p_request->>'date_from')::date not between 0 and 366 then raise exception 'invalid_history_range' using errcode='PT422';end if;
 select provider into chosen from public.fx_observations where base=p_request->>'base' and quote=p_request->>'quote'
 and observation_date between (p_request->>'date_from')::date and (p_request->>'date_to')::date order by case provider when 'frankfurter' then 0 else 1 end limit 1;
 select coalesce(max(fetched_at)::text,'empty')||':'||coalesce(chosen,'none') into version from public.fx_observations where base=p_request->>'base' and quote=p_request->>'quote';
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 with visible as(select * from public.fx_observations where provider=chosen and base=p_request->>'base' and quote=p_request->>'quote'
 and observation_date between (p_request->>'date_from')::date and (p_request->>'date_to')::date),
 page as(select * from visible order by observation_date,id offset off limit lim)
 select (select count(*) from visible),coalesce(jsonb_agg(private.rad_fx_json(p) order by observation_date,id),'[]') into total,items from page p;
 select coalesce(jsonb_agg(day::date::text order by day),'[]') into gaps from generate_series((p_request->>'date_from')::date::timestamp,(p_request->>'date_to')::date::timestamp,interval '1 day') day
 where not exists(select 1 from public.fx_observations where provider=chosen and base=p_request->>'base' and quote=p_request->>'quote' and observation_date=day::date);
 return private.rad_envelope(jsonb_build_object('items',items,'provider',chosen,'missing_dates',gaps),null,private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
create or replace function private.rad_index_article() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;
begin
 if tg_op='INSERT' then
  if new.published_id is null then return new; end if;
 elsif new.published_id is not distinct from old.published_id then return new;
 end if;
 delete from public.visa_article_search_documents where article_id=new.article_id and locale=new.locale;
 select * into r from public.visa_article_revisions where id=new.published_id;
 if found then
  insert into public.visa_article_search_documents
  select r.article_id,r.id,s.id,r.locale,r.title,s.heading,s.anchor,private.rad_blocks_text(s.blocks),
   private.rad_search_normalize(r.title||' '||s.heading||' '||private.rad_blocks_text(s.blocks)||' '||private.rad_search_metadata(r.article_id,r.locale)),
   setweight(to_tsvector('simple',private.rad_search_normalize(r.title)),'A')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_search_metadata(r.article_id,r.locale))),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(s.heading)),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_blocks_text(s.blocks))),'C')
  from public.visa_article_sections s where s.revision_id=r.id;
 end if;
 update private.rad_search_version set version=version+1;
 return new;
end $$;
create or replace function public.search_visa_articles(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare query text;normalized_query text; version text; off integer;lim integer:=(p_request->>'limit')::integer; hits jsonb; total integer;
begin
 perform private.rad_assert_request('search_visa_articles',p_request);
 query:=private.rad_search_normalize(p_request->>'query');
 if query='' or cardinality(string_to_array(query,' '))>8 then raise exception 'invalid_query' using errcode='PT422'; end if;
 normalized_query:=query;
 select coalesce((select canonical from private.rad_search_aliases where locale=p_request->>'locale' and alias=query and enabled),query) into query;
 select rad_search_version.version::text into version from private.rad_search_version;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 with matches as (
  select d.*,r.revision,a.kind,
   case when position(query in private.rad_search_normalize(d.title||' '||d.heading))>0 then 3
    when d.vector @@ plainto_tsquery('simple',query) then 2 else 1 end bucket,
   ts_rank_cd(d.vector,plainto_tsquery('simple',query))::numeric+extensions.similarity(d.normalized,query)::numeric score
  from public.visa_article_search_documents d join public.visa_article_heads h on h.published_id=d.revision_id and h.article_id=d.article_id and h.locale=d.locale
  join public.visa_article_revisions r on r.id=d.revision_id join public.visa_articles a on a.id=d.article_id
  where (d.locale=p_request->>'locale' or (p_request->>'allow_locale_fallback')::boolean)
   and (jsonb_array_length(p_request->'country_codes')=0 or p_request->'country_codes' ? a.country_code)
   and (jsonb_array_length(p_request->'pathway_slugs')=0 or p_request->'pathway_slugs' ? a.pathway_slug)
   and (p_request->>'article_kind' is null or a.kind=p_request->>'article_kind')
   and (d.vector @@ plainto_tsquery('simple',query) or position(query in d.normalized)>0
    or (length(query)>=4 and d.normalized operator(extensions.%>) query))
 ), page as (select * from matches order by bucket desc,score desc,article_id,section_id offset off limit lim)
 select (select count(*) from matches),coalesce(jsonb_agg(jsonb_build_object(
  'article_id',p.article_id,'revision_id',p.revision_id,'revision',p.revision,'article_kind',p.kind,'title',p.title,
  'section_id',p.section_id,'section_anchor',p.anchor,'snippet',left(p.body,180),'match_locale',p.locale,
  'match_kind',case when query<>normalized_query then 'synonym' else case p.bucket when 3 then 'exact' when 2 then 'full_text' else 'typo' end end,
  'score',round(p.score,8)::text,'verification_state',private.rad_article_verification(p.revision_id),'freshness_state','unknown',
  'target',jsonb_build_object('kind','visa_article','id',p.article_id,'section_id',p.section_id))||private.rad_snippet(p.body,query) order by p.bucket desc,p.score desc,p.article_id,p.section_id),'[]') into total,hits from page p;
 return private.rad_envelope(jsonb_build_object('items',hits,'index_version',version,'query_normalized',normalized_query,'evidence_state','unknown'),p_request->>'locale',
  private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;

update public.visa_article_search_documents d set
 normalized=private.rad_search_normalize(d.title||' '||d.heading||' '||d.body||' '||private.rad_search_metadata(d.article_id,d.locale)),
 vector=setweight(to_tsvector('simple',private.rad_search_normalize(d.title)),'A')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_search_metadata(d.article_id,d.locale))),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(d.heading)),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(d.body)),'C');
update private.rad_search_version set version=version+1;

notify pgrst,'reload schema';
commit;
