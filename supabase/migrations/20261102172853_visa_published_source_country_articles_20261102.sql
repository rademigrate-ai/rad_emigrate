-- Route published, provenance-tagged editorial articles to their real Visa
-- country cards. Country codes originate from the sealed source corpus.
-- No content is approved, published, adopted or changed by this migration.
begin;

create or replace function public.list_country_visa_content(
  p_country_code text, p_locale text, p_preview boolean default false
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  categories jsonb;
  other_titles jsonb;
begin
  if p_country_code is null or p_country_code !~ '^[A-Z]{2}$'
     or p_locale is null or p_locale not in ('fa','en') then
    raise exception 'invalid_country_or_locale' using errcode = 'PT422';
  end if;
  if p_preview then perform private.rad_require_admin(); end if;

  select coalesce(jsonb_agg(card order by card->>'visa_category'),'[]'::jsonb)
    into categories
  from private.rad_editorial_catalog c
  cross join lateral (
    select private.rad_editorial_card(c.article_id,p_locale,p_preview) card
  ) x
  where c.active and c.content_class = 'canonical'
    and c.country_codes = array[p_country_code]
    and card is not null;

  -- An editorial item's own captured country codes are intrinsic metadata,
  -- not an invented relationship. Separately approved country-title links
  -- remain supported, including cross-country references. Deduplicate both.
  with candidates as (
    select c.article_id, 2147483647::integer as rank
    from private.rad_editorial_catalog c
    where c.active and c.content_class = 'editorial'
      and p_country_code = any(c.country_codes)

    union all

    select r.article_id, r.rank
    from private.rad_editorial_country_titles r
    join private.rad_editorial_catalog c
      on c.article_id = r.article_id and c.active
    where r.country_code = p_country_code
      and (p_preview or r.state = 'approved')
  ),
  deduplicated as (
    select article_id, min(rank) as rank
    from candidates
    group by article_id
  )
  select coalesce(
    jsonb_agg(card order by d.rank, card->>'title', d.article_id),
    '[]'::jsonb
  ) into other_titles
  from deduplicated d
  cross join lateral (
    select private.rad_editorial_card(d.article_id,p_locale,p_preview) card
  ) x
  where card is not null;

  return private.rad_envelope(
    jsonb_build_object(
      'country_code',p_country_code,'categories',categories,
      'other_titles',other_titles,'preview',p_preview
    ),p_locale
  );
end $$;

create or replace function public.list_visa_content_countries(
  p_locale text, p_preview boolean default false
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare items jsonb;
begin
  if p_locale is null or p_locale not in ('fa','en') then
    raise exception 'invalid_locale' using errcode = 'PT422';
  end if;
  if p_preview then perform private.rad_require_admin(); end if;

  with candidates as (
    select c.country_codes[1] as country_code,
           c.article_id,
           true as is_category
    from private.rad_editorial_catalog c
    where c.active and c.content_class = 'canonical'
      and cardinality(c.country_codes) = 1

    union all

    -- Source-supported one- or multi-country editorial articles.
    select code.country_code,
           c.article_id,
           false as is_category
    from private.rad_editorial_catalog c
    cross join lateral unnest(c.country_codes) code(country_code)
    where c.active and c.content_class = 'editorial'

    union all

    select r.country_code,
           r.article_id,
           false as is_category
    from private.rad_editorial_country_titles r
    join private.rad_editorial_catalog c
      on c.article_id = r.article_id and c.active
    where p_preview or r.state = 'approved'
  ),
  visible as (
    select distinct c.country_code,c.article_id,c.is_category
    from candidates c
    where c.country_code ~ '^[A-Z]{2}$'
      and private.rad_editorial_card(
        c.article_id,p_locale,p_preview
      ) is not null
  ),
  counts as (
    select country_code,
           count(distinct article_id) as article_count,
           count(distinct article_id) filter (where is_category) as category_count,
           count(distinct article_id) filter (where not is_category) as other_titles_count
    from visible group by country_code
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'country_code',country_code,
      'category_count',category_count,
      'other_titles_count',other_titles_count,
      'article_count',article_count
    ) order by country_code
  ),'[]'::jsonb) into items
  from counts;

  return private.rad_envelope(
    jsonb_build_object('items',items,'preview',p_preview),p_locale
  );
end $$;

revoke all on function public.list_country_visa_content(text,text,boolean),
  public.list_visa_content_countries(text,boolean)
  from public,anon,authenticated,service_role;
grant execute on function public.list_country_visa_content(text,text,boolean),
  public.list_visa_content_countries(text,boolean)
  to anon,authenticated;

notify pgrst,'reload schema';
commit;
