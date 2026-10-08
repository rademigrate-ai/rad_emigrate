-- Stage 3 content migration regression checks
begin;

do $$ begin
  assert exists (select 1 from public.source_documents where canonical_url = 'https://radmohajer.ir/fa/contacts');
  assert exists (select 1 from public.source_documents where canonical_url = 'https://radmohajer.ir/en/contact-us');
  assert exists (select 1 from public.source_documents where canonical_url = 'https://radmohajer.ir/en/about-us');
end $$;

do $$ declare v int; begin
  select count(*) into v from public.knowledge_claims kc
  where kc.review_status = 'approved'
    and not exists (select 1 from public.knowledge_citations c where c.claim_id = kc.id);
  assert v = 0;
end $$;

do $$ declare v jsonb; begin
  v := public.retrieve_knowledge('تماس', 'fa', null, null, 5);
  assert v ? 'results';
end $$;

do $$ declare v_before int; v_after int; begin
  select count(*) into v_before from public.feed_items;
  select count(*) into v_after from public.feed_items;
  assert v_before = v_after;
end $$;

rollback;
