-- Stage 2 Knowledge regression tests
begin;
do $$ begin
  assert (select count(*) from information_schema.tables where table_schema='public' and table_name in ('knowledge_items','knowledge_claims','knowledge_citations','knowledge_conflicts','knowledge_versions')) = 5;
end $$;
do $$ begin
  assert exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='retrieve_knowledge');
  assert exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='promote_knowledge_from_evidence');
end $$;
do $$ declare v_orphans int; begin
  select count(*) into v_orphans from public.knowledge_claims kc where kc.review_status = 'approved' and not exists (select 1 from public.knowledge_citations c where c.claim_id = kc.id);
  assert v_orphans = 0;
end $$;
do $$ declare v jsonb; begin
  v := public.retrieve_knowledge('تماس راد', 'fa', null, null, 5);
  assert (v->>'count')::int >= 0;
end $$;
do $$ declare v_before int; v_after int; v_snap uuid; begin
  select count(*) into v_before from public.feed_items;
  select ss.id into v_snap from public.source_snapshots ss limit 1;
  if v_snap is not null then
    perform public.promote_knowledge_from_evidence('stage2-feed-safety', 'en', 'Feed safety', 'Summary', 'Feed safety claim must not publish', v_snap, null, 'test', null, null, null, 'low', true);
  end if;
  select count(*) into v_after from public.feed_items;
  assert v_before = v_after;
end $$;
rollback;
