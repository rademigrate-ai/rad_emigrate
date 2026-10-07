-- Stage 4 User AI regression (SQL layer)
begin;

do $$
declare
  r jsonb;
  i int;
  k text := 'stage4_sql_test_guest_key_hash_abcdef';
begin
  delete from public.ai_guest_quota where guest_key_hash = k;
  for i in 1..5 loop
    r := public.consume_ai_guest_quota(k, 5);
    assert (r->>'allowed')::boolean = true, format('expected allow on %s', i);
  end loop;
  r := public.consume_ai_guest_quota(k, 5);
  assert (r->>'allowed')::boolean = false, 'expected block on 6th';
  assert (r->>'error') = 'anonymous_quota_exceeded';
  delete from public.ai_guest_quota where guest_key_hash = k;
end $$;

do $$
declare v jsonb;
begin
  v := public.retrieve_knowledge('contact', 'en', null, null, 3);
  assert v ? 'results';
end $$;

do $$
declare c int;
begin
  select count(*) into c from public.feed_items;
  assert c = 0;
end $$;

rollback;
