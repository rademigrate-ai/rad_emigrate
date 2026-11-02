-- Published Visa source discovery: country cards include canonical,
-- source-coded published editorials, and independently approved relations.
-- No unapproved relation or unpublished article can be returned.
-- Purely read-only regression. Does not modify source content or heads.
begin;
set local statement_timeout = '20s';
do $tests$
declare
  actual jsonb;
  article jsonb;
  fn oid := to_regprocedure('public.list_visa_content_countries(text,boolean)');
  country_fn oid := to_regprocedure('public.list_country_visa_content(text,text,boolean)');
  txt text;
begin
  if fn is null then raise exception 'FAIL: country discovery RPC missing'; end if;
  if not has_function_privilege('anon', fn, 'EXECUTE')
     or not has_function_privilege('authenticated', fn, 'EXECUTE') then
    raise exception 'FAIL: published country reader not callable';
  end if;

  if country_fn is null then raise exception 'FAIL: country content RPC missing'; end if;
  if not has_function_privilege('anon',country_fn,'EXECUTE') then
    raise exception 'FAIL: published country content not readable';
  end if;
  txt := pg_get_functiondef(fn);
  if position('unnest(c.country_codes)' in txt) = 0
     or position('rad_editorial_card' in txt) = 0
     or position('r.state' in txt) = 0
     or position('approved' in txt) = 0
     or position('rad_require_admin' in txt) = 0 then
    raise exception 'FAIL: published and preview safeguards missing';
  end if;

  txt := pg_get_functiondef(country_fn);
  if position('c.content_class = ''editorial''' in txt) = 0
     or position('p_country_code = any(c.country_codes)' in txt) = 0
     or position('r.state' in txt) = 0
     or position('approved' in txt) = 0
     or position('rad_editorial_card' in txt) = 0
     or position('rad_require_admin' in txt) = 0 then
    raise exception 'FAIL: country articles are not filtered by source evidence, publish and approval';
  end if;
  actual := public.list_country_visa_content('GB','fa',false);
  if jsonb_typeof(actual->'data'->'categories') <> 'array'
     or jsonb_typeof(actual->'data'->'other_titles') <> 'array' then
    raise exception 'FAIL: country articles payload malformed';
  end if;
  actual := public.list_visa_content_countries('fa', false);
  if jsonb_typeof(actual->'data'->'items') is distinct from 'array' then
    raise exception 'FAIL: malformed country discovery JSON';
  end if;
  for article in select value from jsonb_array_elements(actual->'data'->'items')
  loop
    if (article->>'country_code') !~ '^[A-Z]{2}$'
      or (article->>'article_count')::integer < 1
      or (article->>'category_count')::integer < 0
      or (article->>'other_titles_count')::integer < 0 then
      raise exception 'FAIL: bad published country card payload';
    end if;
  end loop;
  begin
    perform public.list_visa_content_countries('xx', false);
    raise exception 'FAIL: invalid locale accepted';
  exception when sqlstate 'PT422' then null;
  end;
end
$tests$;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $tests$
begin
  begin
    perform public.list_visa_content_countries('fa', true);
    raise exception 'FAIL: anonymous preview was permitted';
  exception when sqlstate 'PT403' then null;
  end;
  begin
    perform public.list_country_visa_content('GB','fa',true);
    raise exception 'FAIL: anonymous country article preview was permitted';
  exception when sqlstate 'PT403' then null;
  end;
  if jsonb_typeof(public.list_visa_content_countries('en',false)->'data'->'items') <> 'array' then
    raise exception 'FAIL: public reader invalid response';
  end if;
end
$tests$;
rollback;
select 'PASS visa published country discovery and preview boundaries';
