-- Stage 3 bulk ingestion — ROLLBACK (owner-authorized recovery only)
-- F-01 strategy: strictly batch-scoped and set-based.
--   * candidate documents are derived from batch snapshot MARKERS captured
--     BEFORE any deletion — never from a URL list, never from timestamps;
--   * the 5 pre-ingest production documents are
--     hard-excluded by explicit URL guard (generated from the live-state
--     capture), so they can never be deleted;
--   * a document survives whenever ANY snapshot remains after batch
--     deletion (concurrent writers, seed rows, post-ingest work) — the
--     existence check carries NO metadata predicate, so rows without an
--     ingest_batch key (NULL) protect their document rather than being
--     silently skipped;
--   * knowledge_citations.snapshot_id is ON DELETE RESTRICT: if any batch
--     snapshot is cited by reviewed knowledge, step 2 FAILS the whole
--     transaction by design. Resolve citations first.
begin;

-- 1) batch-created document candidates (set-based, marker-derived)
create temp table _rb_batch_docs on commit drop as
select distinct d.id
  from public.source_documents d
  join public.source_snapshots s on s.document_id = d.id
 where s.metadata->>'ingest_batch' = 'stage3-bulk-20261012';

-- 2) FK RESTRICT safety net: refuses this transaction while cited
delete from public.source_snapshots
 where metadata->>'ingest_batch' = 'stage3-bulk-20261012';

-- 3) delete ONLY batch-created documents that now have zero snapshots
delete from public.source_documents d
 where d.id in (select id from _rb_batch_docs)
   and d.canonical_url not in (
      'https://digivisa.ir/',
      'https://radmohajer.ir/en/about-us',
      'https://radmohajer.ir/en/contact-us',
      'https://radmohajer.ir/fa/',
      'https://radmohajer.ir/fa/contacts'
   )
   and not exists (
     select 1 from public.source_snapshots s where s.document_id = d.id);

-- 4) restore pre-existing documents' prior last_content_hash (recorded in
--    the pre-ingest live-state capture; last_seen_at is intentionally left
--    bumped — it is an audit timestamp, not content).
update public.source_documents sd
set last_content_hash = v.h
from (values
  ('https://digivisa.ir/', 'a99199f438e3d2e4134a8d1be35c78473e4f7f6e60edc51d9760ec5f38b00110'),
  ('https://radmohajer.ir/fa/', '643a3c62ef94bc0f5303a69808c4c847d3f87ab73689bb56fc0f506f9c8f8ec9'),
  ('https://radmohajer.ir/fa/contacts', '1720f460d8addfd0398371ee93210730785222f4a1ce36c5a8e01f4865eefc87'),
  ('https://radmohajer.ir/en/contact-us', '009442bcb63ee35e40eb4d136015083dcc3610f5dc805d5f5be7d4540fa6eeb3'),
  ('https://radmohajer.ir/en/about-us', '549c84fa5e3c3734106847d77c071f7bdf2d9582c05210c728a76cc4ca112d59')
) as v(url, h)
where sd.canonical_url = v.url;

-- 5) audit report: batch-candidate documents kept because snapshots remain
select d.canonical_url as kept_candidate_with_remaining_snapshots,
       (select count(*) from public.source_snapshots s
         where s.document_id = d.id) as remaining_snapshots
  from public.source_documents d
 where d.id in (select id from _rb_batch_docs)
 order by 1;

commit;
