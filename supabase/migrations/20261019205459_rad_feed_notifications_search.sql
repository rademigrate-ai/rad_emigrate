begin;
create extension if not exists pg_trgm with schema extensions;
create function private.rad_search_normalize(value text) returns text language sql immutable parallel safe set search_path='' as $$
 select btrim(regexp_replace(regexp_replace(translate(lower(value),
 'يك٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','یک01234567890123456789'),U&'[\064B-\065F\0670]','','g'),U&'[\200C\200D[:space:][:punct:]]+',' ','g'));
$$;
create function private.rad_blocks_text(blocks jsonb) returns text language sql immutable set search_path='' as $$
 select coalesce(string_agg(coalesce(b->>'text','')||' '||coalesce((select string_agg(v,' ') from jsonb_array_elements_text(b->'items') v),''),E'\n'),'') from jsonb_array_elements(blocks) b;
$$;
create table public.visa_article_search_documents(
 article_id uuid not null references public.visa_articles(id),revision_id uuid not null references public.visa_article_revisions(id),
 section_id uuid not null,locale text not null,title text not null,heading text not null,anchor text not null,
 body text not null,normalized text not null,vector tsvector not null,primary key(revision_id,section_id)
);
alter table public.visa_article_search_documents enable row level security;
revoke all on public.visa_article_search_documents from public,anon,authenticated,service_role;
create index visa_search_fts_idx on public.visa_article_search_documents using gin(vector);
create index visa_search_trgm_idx on public.visa_article_search_documents using gin(normalized extensions.gin_trgm_ops);
create index visa_search_article_locale_idx on public.visa_article_search_documents(article_id,locale);
create table private.rad_search_version(id boolean primary key default true check(id),version bigint not null default 1);
insert into private.rad_search_version values(true,1);
alter table private.rad_search_version enable row level security;
revoke all on private.rad_search_version from public,anon,authenticated,service_role;
create function private.rad_index_article() returns trigger language plpgsql security definer set search_path='' as $$
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
   private.rad_search_normalize(r.title||' '||s.heading||' '||private.rad_blocks_text(s.blocks)),
   setweight(to_tsvector('simple',private.rad_search_normalize(r.title)),'A')||setweight(to_tsvector('simple',private.rad_search_normalize(s.heading)),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_blocks_text(s.blocks))),'C')
  from public.visa_article_sections s where s.revision_id=r.id;
 end if;
 update private.rad_search_version set version=version+1;
 return new;
end $$;
create trigger rad_article_publication_search after insert or update of published_id on public.visa_article_heads for each row execute function private.rad_index_article();

-- Match offsets are UTF-16 code units, matching Dart String/TextSpan indexing.
-- Normalized matching never alters the displayed original text.
create function private.rad_snippet(original text,query text) returns jsonb language plpgsql immutable set search_path='' as $$
declare normalized text:='';mapping integer[]:='{}';c text;i integer;j integer;at integer;needle text:=query;
 first integer;last integer;snippet_start integer;snippet text;start16 integer;end16 integer;
begin
 for i in 1..char_length(original) loop
  c:=private.rad_search_normalize(substring(original from i for 1));
  if c='' then
   if substring(original from i for 1) ~ U&'[\064B-\065F\0670]' then continue;end if;c:=' ';
  end if;
  if c=' ' and (normalized='' or right(normalized,1)=' ') then continue;end if;
  normalized:=normalized||c;
  for j in 1..char_length(c) loop mapping:=mapping||i;end loop;
 end loop;
 at:=position(needle in normalized);
 if at=0 then
  select word into needle from regexp_split_to_table(normalized,' ') word where char_length(word)>=4 order by extensions.similarity(word,query) desc,word limit 1;
  if needle is not null and extensions.similarity(needle,query)>=0.4 then at:=position(needle in normalized);end if;
 end if;
 if at=0 or needle is null then return jsonb_build_object('snippet',left(original,180),'match_ranges','[]'::jsonb);end if;
 first:=mapping[at];last:=mapping[at+char_length(needle)-1];snippet_start:=greatest(1,first-60);
 snippet:=substring(original from snippet_start for 180);first:=first-snippet_start+1;last:=least(last-snippet_start+1,char_length(snippet));
 select coalesce(sum(case when ascii(substring(snippet from n for 1))>65535 then 2 else 1 end),0) into start16 from generate_series(1,first-1) n;
 select coalesce(sum(case when ascii(substring(snippet from n for 1))>65535 then 2 else 1 end),0) into end16 from generate_series(1,last) n;
 return jsonb_build_object('snippet',snippet,'match_ranges',jsonb_build_array(jsonb_build_object('start',start16,'end',end16)));
end $$;

create function public.search_visa_articles(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare query text; version text; off integer;lim integer:=(p_request->>'limit')::integer; hits jsonb; total integer;
begin
 perform private.rad_assert_request('search_visa_articles',p_request);
 query:=private.rad_search_normalize(p_request->>'query');
 if query='' or cardinality(string_to_array(query,' '))>8 then raise exception 'invalid_query' using errcode='PT422'; end if;
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
  'match_kind',case p.bucket when 3 then 'exact' when 2 then 'full_text' else 'typo' end,
  'score',round(p.score,8)::text,'verification_state',private.rad_article_verification(p.revision_id),'freshness_state','unknown',
  'target',jsonb_build_object('kind','visa_article','id',p.article_id,'section_id',p.section_id))||private.rad_snippet(p.body,query) order by p.bucket desc,p.score desc,p.article_id,p.section_id),'[]') into total,hits from page p;
 return private.rad_envelope(jsonb_build_object('items',hits,'index_version',version,'query_normalized',query,'evidence_state','unknown'),p_request->>'locale',
  private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
revoke all on function public.search_visa_articles(jsonb) from public;
grant execute on function public.search_visa_articles(jsonb) to anon,authenticated;
commit;
