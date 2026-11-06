-- Aggregate real, *published* Visa country content from both canonical
-- categories and approved country-title relations. A draft is never public.
-- This file is additive: no data writes, head movement or approval changes.
begin;

create or replace function public.list_visa_content_countries(
  p_locale text,
  p_preview boolean default false
) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  items jsonb;
begin
  if p_locale is null or p_locale not in ('fa', 'en') then
    raise exception 'invalid_locale' using errcode = 'PT422';
  end if;

  -- The caller's preview flag is not itself authorization.
  if p_preview then
    perform private.rad_require_admin();
  end if;

  with candidates as (
    select c.country_codes[1] as country_code,
           c.article_id,
           true as is_category
    from private.rad_editorial_catalog c
    where c.active
      and c.content_class = 'canonical'
      and cardinality(c.country_codes) = 1

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
    select distinct c.country_code, c.article_id, c.is_category
    from candidates c
    where c.country_code ~ '^[A-Z]{2}$'
      and private.rad_editorial_card(
        c.article_id, p_locale, p_preview
      ) is not null
  ),
  counts as (
    select country_code,
           count(distinct article_id) as article_count,
           count(distinct article_id) filter (where is_category) as category_count,
           count(distinct article_id) filter (where not is_category) as other_titles_count
    from visible
    group by country_code
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'country_code', country_code,
        'category_count', category_count,
        'other_titles_count', other_titles_count,
        'article_count', article_count
      ) order by country_code
    ), '[]'::jsonb
  ) into items
  from counts;

  return private.rad_envelope(
    jsonb_build_object('items', items, 'preview', p_preview),
    p_locale
  );
end $$;

revoke all on function public.list_visa_content_countries(text, boolean)
  from public, anon, authenticated, service_role;
grant execute on function public.list_visa_content_countries(text, boolean)
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
