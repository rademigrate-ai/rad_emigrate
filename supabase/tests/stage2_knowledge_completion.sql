-- Stage 2 Knowledge regression tests
begin;

do $$ begin
  assert (select count(*) from information_schema.tables
    where table_schema='public' and table_name in
    ('knowledge_items','knowledge_claims','knowledge_citations','knowledge_conflicts','knowledge_versions')) = 5;
end $$;

do $$ begin
  assert exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='retrieve_knowledge');
  assert exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='promote_knowledge_from_evidence');
  assert exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='register_knowledge_conflict');
end $$;

do $$ declare v_orphans int; begin
  select count(*) into v_orphans from public.knowledge_claims kc
  where kc.review_status = 'approved'
    and not exists (select 1 from public.knowledge_citations c where c.claim_id = kc.id);
  assert v_orphans = 0, 'approved claims without citations';
end $$;

do $$ declare v jsonb; begin
  v := public.retrieve_knowledge('تماس راد', 'fa', null, null, 5);
  assert v ? 'results';
  assert v ? 'retrieved_at';
end $$;

do $$ declare v jsonb; begin
  v := public.retrieve_knowledge('RAD contact', 'en', null, null, 5);
  assert v ? 'results';
end $$;

do $$
declare
  v_snap uuid; r1 jsonb; r2 jsonb; c1 int; c2 int;
begin
  select ss.id into v_snap from public.source_snapshots ss limit 1;
  if v_snap is null then raise notice 'skip idempotency: no snapshots'; return; end if;
  r1 := public.promote_knowledge_from_evidence(
    'stage2-idempotency-test', 'en', 'Idempotency fixture', 'Summary',
    'Stage 2 idempotency claim text unique key', v_snap, 'excerpt', 'test',
    null, null, null, 'low', true);
  select count(*) into c1 from public.knowledge_claims
  where knowledge_item_id = (r1->>'knowledge_item_id')::uuid;
  r2 := public.promote_knowledge_from_evidence(
    'stage2-idempotency-test', 'en', 'Idempotency fixture', 'Summary',
    'Stage 2 idempotency claim text unique key', v_snap, 'excerpt', 'test',
    null, null, null, 'low', true);
  select count(*) into c2 from public.knowledge_claims
  where knowledge_item_id = (r2->>'knowledge_item_id')::uuid;
  assert c1 = c2, 'duplicate claims created';
  assert (r1->>'claim_id') = (r2->>'claim_id');
end $$;

do $$
declare v_before int; v_after int; v_snap uuid;
begin
  select count(*) into v_before from public.feed_items;
  select ss.id into v_snap from public.source_snapshots ss limit 1;
  if v_snap is not null then
    perform public.promote_knowledge_from_evidence(
      'stage2-feed-safety', 'en', 'Feed safety', 'Summary',
      'Feed safety claim must not publish', v_snap, null, 'test',
      null, null, null, 'low', true);
  end if;
  select count(*) into v_after from public.feed_items;
  assert v_before = v_after, 'promote wrote feed_items';
end $$;

do $$
declare v_item uuid; v_claim uuid; v_failed boolean := false;
begin
  insert into public.knowledge_items (slug, language_code, title, summary, review_status)
  values ('stage2-integrity-orphan', 'en', 'Orphan test', 'x', 'draft')
  returning id into v_item;
  insert into public.knowledge_claims (knowledge_item_id, claim_text, claim_key, review_status)
  values (v_item, 'orphan claim without citation', md5('orphan claim without citation'), 'unreviewed')
  returning id into v_claim;
  begin
    update public.knowledge_claims set review_status = 'approved' where id = v_claim;
  exception when others then
    v_failed := true;
  end;
  assert v_failed, 'approved without citation should fail';
  delete from public.knowledge_items where id = v_item;
end $$;

rollback;
