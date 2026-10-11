#!/usr/bin/env bash
# Rehearsal v3 — full independent validation of the remediated Stage 3
# ingestion package against a disposable local PostgreSQL 16.
#
# Scenarios:
#   S1  fresh ingest with a simulated mid-chunk interruption + resume
#   S2  double-run idempotency (all chunks twice)
#   S3  rollback refusal while a batch snapshot is cited (FK RESTRICT,
#       whole transaction rolls back atomically)
#   S4  concurrent (non-batch) writes present, then rollback:
#       concurrent docs/snapshots survive; documents retaining ANY
#       snapshot survive; pre-existing docs and hashes restored
#   S5  second rollback is a verified no-op (marker-derived candidates
#       are gone; leftover concurrent state untouched)
#   S6  fresh DB: ingest -> verify -> rollback -> EXACT baseline, then
#       post-rollback re-ingest of sample chunks proves clean restart
set -u

PKG="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PKG/../.."   # repo root: relative dataset paths inside the manifest resolve here
SQL="$PKG/sql"
C=rad_ingest_rehearsal_v3
DB=rad_rehearsal
# MSYS_NO_PATHCONV: keep /pkg/... container paths from being rewritten to
# Windows paths by Git Bash's path mangling.
export MSYS_NO_PATHCONV=1
PSQL="docker exec -i $C psql -U postgres -d $DB -t -A"
OUT="$PKG/rehearsal/REHEARSAL_RESULTS.txt"
BATCH=stage3-bulk-20261012
FAILURES=0

# expected counts from the manifest (single source of truth)
read -r EXP_CREATED EXP_EXISTING EXP_SNAPS EXP_SKIP < <(python -c "
import json
m = json.load(open(r'artifacts/stage3_ingestion_package_20261012/INGEST_MANIFEST.json', encoding='utf-8'))
e = m['expected_counts']
print(e['documents_created'], e['documents_existing_untouched'],
      e['snapshots_inserted'], e['dataset_rows_skipped_exact_duplicate'])")
EXP_DOCS=$((EXP_CREATED + EXP_EXISTING))
EXP_TOTAL_SNAPS=$((EXP_SNAPS + EXP_EXISTING))
EXP_BATCH=$EXP_SNAPS

say() { echo "$1" | tee -a "$OUT"; }
chk() { # name expected actual
  if [ "$2" = "$3" ]; then
    say "PASS $1=$2"
  else
    say "FAIL $1: expected=$2 actual=$3"
    FAILURES=$((FAILURES + 1))
  fi
}
q() { $PSQL -c "$1" 2>&1 | tail -1; }
chk_gt() { # name actual (assert actual > 0)
  if [ "${2:-0}" -gt 0 ] 2>/dev/null; then
    say "PASS $1=$2"
  else
    say "FAIL $1: expected > 0, actual=${2:-empty}"
    FAILURES=$((FAILURES + 1))
  fi
}
run_ingest() { # all chunks, fail loudly
  docker exec $C sh -c 'set -e
  for f in /pkg/sql/10_ingest_*.sql; do
    psql -q -U postgres -d '"$DB"' -v ON_ERROR_STOP=1 -f "$f" >/dev/null
  done' >>"$OUT" 2>&1
}
PRE_URLS="'https://digivisa.ir/','https://radmohajer.ir/en/about-us','https://radmohajer.ir/en/contact-us','https://radmohajer.ir/fa/','https://radmohajer.ir/fa/contacts'"
HASH5="select count(*) from public.source_documents where (canonical_url,last_content_hash) in
  (('https://digivisa.ir/','a99199f438e3d2e4134a8d1be35c78473e4f7f6e60edc51d9760ec5f38b00110'),
   ('https://radmohajer.ir/fa/','643a3c62ef94bc0f5303a69808c4c847d3f87ab73689bb56fc0f506f9c8f8ec9'),
   ('https://radmohajer.ir/fa/contacts','1720f460d8addfd0398371ee93210730785222f4a1ce36c5a8e01f4865eefc87'),
   ('https://radmohajer.ir/en/contact-us','009442bcb63ee35e40eb4d136015083dcc3610f5dc805d5f5be7d4540fa6eeb3'),
   ('https://radmohajer.ir/en/about-us','549c84fa5e3c3734106847d77c071f7bdf2d9582c05210c728a76cc4ca112d59'))"

: > "$OUT"
say "=== REHEARSAL v3 ($(date -u +%Y-%m-%dT%H:%M:%SZ)) dataset_sha=$(python -c "
import json
print(json.load(open(r'artifacts/stage3_ingestion_package_20261012/INGEST_MANIFEST.json', encoding='utf-8'))
      ['generated_from']['dataset_sha256'][:8])") ==="
say "expected: docs=$EXP_DOCS snaps=$EXP_TOTAL_SNAPS batch=$EXP_BATCH created=$EXP_CREATED existing=$EXP_EXISTING skip_exact_dupes=$EXP_SKIP"

# ---------- environment ----------
docker rm -f $C >/dev/null 2>&1
MNT="$(pwd -W 2>/dev/null || pwd)"
docker run -d --name $C \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=$DB \
  -v "$MNT/artifacts/stage3_ingestion_package_20261012:/pkg:ro" \
  postgres:16-alpine >/dev/null || exit 9
for i in $(seq 1 60); do
  docker exec $C pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
docker exec $C pg_isready -U postgres >/dev/null 2>&1 || { say "FAIL postgres never became ready"; exit 9; }

say "--- schema + seed ---"
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/rehearsal/01_schema.sql >>"$OUT" 2>&1 \
  && say "SCHEMA OK" || { say "FAIL schema"; exit 9; }
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/rehearsal/02_seed_production.sql >>"$OUT" 2>&1 \
  && say "SEED OK" || { say "FAIL seed"; exit 9; }
chk seed_docs 5 "$(q 'select count(*) from public.source_documents')"
chk seed_snaps 5 "$(q 'select count(*) from public.source_snapshots')"
chk seed_sources 6 "$(q 'select count(*) from public.content_sources')"

say "--- 00_preflight ---"
docker exec $C psql -q -U postgres -d $DB -f /pkg/sql/00_preflight.sql >>"$OUT" 2>&1
chk preflight_batch_rows 0 "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"

# ---------- S1: ingest with simulated mid-chunk interruption ----------
say "--- S1: chunks 0001-0040, interrupted chunk 0041, resume ---"
docker exec $C sh -c 'set -e
for f in $(ls /pkg/sql/10_ingest_*.sql | head -40); do
  psql -q -U postgres -d '"$DB"' -v ON_ERROR_STOP=1 -f "$f" >/dev/null
done' >>"$OUT" 2>&1 && say "PARTIAL-40 OK" || say "FAIL partial-40"
DOCS_40=$(q 'select count(*) from public.source_documents')
SNAPS_40=$(q 'select count(*) from public.source_snapshots')
say "after 40 chunks: docs=$DOCS_40 snaps=$SNAPS_40 (batch rows present: $(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'"))"

# inject a runtime error just before commit: the whole chunk must roll back
# PYTHONUTF8 so Windows python (cp1252 default stdout) can emit the UTF-8
# Persian URLs; cygpath so docker cp gets a real Windows path.
PYTHONUTF8=1 python - <<'EOF' > /tmp/chunk_fail.sql
src = open(r'artifacts/stage3_ingestion_package_20261012/sql/10_ingest_0041.sql', encoding='utf-8').read().replace('\r\n', '\n')
i = src.rstrip().rfind('commit;')
print(src[:i] + 'select 1/0; -- simulated mid-chunk interruption\ncommit;')
EOF
docker cp "$(cygpath -w /tmp/chunk_fail.sql)" $C:/tmp/chunk_fail.sql >/dev/null
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /tmp/chunk_fail.sql >>"$OUT" 2>&1
chk interrupted_chunk_exitcode 3 "$?"
chk docs_unchanged_after_interruption "$DOCS_40" "$(q 'select count(*) from public.source_documents')"
chk snaps_unchanged_after_interruption "$SNAPS_40" "$(q 'select count(*) from public.source_snapshots')"
say "interruption atomicity verified: failed chunk applied 0 rows"

docker exec $C sh -c 'set -e
for f in $(ls /pkg/sql/10_ingest_*.sql | tail -n +41); do
  psql -q -U postgres -d '"$DB"' -v ON_ERROR_STOP=1 -f "$f" >/dev/null
done' >>"$OUT" 2>&1 && say "RESUME OK" || say "FAIL resume"
chk docs_after_ingest "$EXP_DOCS" "$(q 'select count(*) from public.source_documents')"
chk snaps_after_ingest "$EXP_TOTAL_SNAPS" "$(q 'select count(*) from public.source_snapshots')"
chk batch_after_ingest "$EXP_BATCH" "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"
chk feed_after_ingest 0 "$(q 'select count(*) from public.feed_items')"
chk batch_orphans 0 "$(q "select count(*) from public.source_snapshots s left join public.source_documents d on d.id=s.document_id where s.metadata->>'ingest_batch'='$BATCH' and (d.id is null or d.last_content_hash is null)")"
chk preexisting_titles_intact 5 "$(q "select count(*) from public.source_documents where canonical_url in ($PRE_URLS) and title is not null and title <> ''")"

say "--- 90_verify.sql (S1) ---"
docker exec $C psql -q -U postgres -d $DB -f /pkg/sql/90_verify.sql >>"$OUT" 2>&1
say "verify rc=$?"

# ---------- S2: double-run idempotency ----------
say "--- S2: rerun ALL chunks (idempotency) ---"
run_ingest && say "DOUBLE-RUN OK" || say "FAIL double-run"
chk docs_double_run "$EXP_DOCS" "$(q 'select count(*) from public.source_documents')"
chk snaps_double_run "$EXP_TOTAL_SNAPS" "$(q 'select count(*) from public.source_snapshots')"
chk batch_double_run "$EXP_BATCH" "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"

# ---------- S3: rollback refusal while cited ----------
say "--- S3: cited-snapshot rollback refusal ---"
docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1 <<EOF
begin;
insert into public.knowledge_items (slug, language_code, title, summary)
values ('rehearsal-item', 'fa', 'rehearsal', 'rehearsal citation target');
insert into public.knowledge_claims (knowledge_item_id, claim_text)
select id, 'rehearsal claim' from public.knowledge_items where slug='rehearsal-item';
insert into public.knowledge_citations (claim_id, snapshot_id, excerpt)
select c.id, s.id, 'rehearsal excerpt'
  from public.knowledge_claims c, public.source_snapshots s
 where c.claim_text='rehearsal claim'
   and s.metadata->>'ingest_batch'='$BATCH' limit 1;
commit;
EOF
chk citation_inserted 1 "$(q 'select count(*) from public.knowledge_citations')"
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/sql/91_rollback.sql >>"$OUT" 2>&1
chk cited_rollback_exitcode 3 "$?"
chk batch_survived_refusal "$EXP_BATCH" "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"
chk docs_survived_refusal "$EXP_DOCS" "$(q 'select count(*) from public.source_documents')"
chk snaps_survived_refusal "$EXP_TOTAL_SNAPS" "$(q 'select count(*) from public.source_snapshots')"
say "REFUSED-WHILE-CITED: whole rollback transaction rolled back atomically, nothing lost"

# resolve the citation (runbook step: resolve citations before rollback)
docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1 <<EOF
begin;
delete from public.knowledge_items where slug='rehearsal-item'; -- cascades claims+citations
commit;
EOF
chk citation_resolved 0 "$(q 'select count(*) from public.knowledge_citations')"

# ---------- S4: concurrent writes + rollback ----------
say "--- S4: concurrent (non-batch) writes, then rollback ---"
docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1 <<EOF
begin;
-- concurrent writer A: brand-new document + snapshot, no batch marker
insert into public.source_documents (id, canonical_url, source_authority, title, language_code)
values ('00000000-0000-4000-8000-000000000001', 'https://concurrent.example/new-doc',
        'other', 'concurrent doc', 'en');
insert into public.source_snapshots (document_id, content_hash, normalized_text, metadata)
values ('00000000-0000-4000-8000-000000000001', 'concurrent-hash-1', 'concurrent text', '{}'::jsonb);
-- concurrent writer B: extra snapshot on a batch-created document
insert into public.source_snapshots (document_id, content_hash, normalized_text, metadata)
select d.id, 'concurrent-extra-hash', 'concurrent extra', '{}'::jsonb
  from public.source_documents d
  join public.source_snapshots s on s.document_id = d.id
 where s.metadata->>'ingest_batch'='$BATCH'
   and d.canonical_url not in ($PRE_URLS)
 limit 1;
commit;
EOF
B_CITED=$(q "select document_id from public.source_snapshots where content_hash='concurrent-extra-hash'")
say "batch document protected by concurrent snapshot: $B_CITED"

docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/sql/91_rollback.sql >>"$OUT" 2>&1
chk s4_rollback_rc 0 "$?"
chk s4_batch_snapshots_deleted 0 "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"
chk s4_concurrent_doc_kept 1 "$(q "select count(*) from public.source_documents where id='00000000-0000-4000-8000-000000000001'")"
chk s4_concurrent_snapshot_kept 1 "$(q "select count(*) from public.source_snapshots where content_hash='concurrent-hash-1'")"
chk s4_protected_batch_doc_kept 1 "$(q "select count(*) from public.source_documents where id='$B_CITED'")"
chk s4_concurrent_extra_snapshot_kept 1 "$(q "select count(*) from public.source_snapshots where content_hash='concurrent-extra-hash'")"
chk s4_preexisting_docs_kept 5 "$(q "select count(*) from public.source_documents where canonical_url in ($PRE_URLS)")"
chk s4_all_5_hashes_restored 5 "$(q "$HASH5")"
# every remaining batch-candidate document must still carry its snapshot
chk s4_no_orphaned_candidates 0 "$(q "select count(*) from public.source_documents d
  where d.id='$B_CITED' and not exists (select 1 from public.source_snapshots s where s.document_id=d.id)")"
say "S4 result: batch snapshots all deleted; docs kept = 5 pre-existing + 1 protected batch doc + 1 concurrent doc"
say "kept-candidate audit report:"
docker exec $C psql -U postgres -d $DB -c "select d.canonical_url, (select count(*) from public.source_snapshots s where s.document_id=d.id) as remaining from public.source_documents d where d.id='$B_CITED'" >>"$OUT" 2>&1

# ---------- S5: second rollback is a verified no-op ----------
say "--- S5: second rollback (no markers left -> no candidates -> no-op) ---"
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/sql/91_rollback.sql >>"$OUT" 2>&1
chk s5_second_rollback_rc 0 "$?"
# after S4: 5 pre-existing + 1 protected batch doc + 1 concurrent doc = 7
chk s5_docs_unchanged 7 "$(q 'select count(*) from public.source_documents')"
chk s5_snaps_unchanged 7 "$(q 'select count(*) from public.source_snapshots')"
chk s5_concurrent_state_intact 2 "$(q "select count(*) from public.source_snapshots where content_hash in ('concurrent-hash-1','concurrent-extra-hash')")"
chk s5_hashes_still_restored 5 "$(q "$HASH5")"
say "S5: rollback is idempotent; leftover concurrent state untouched"

# ---------- S6: fresh DB — full cycle ingest -> verify -> rollback -> baseline ----------
say "--- S6: fresh schema+seed, full ingest, verify, rollback to exact baseline ---"
docker exec $C psql -q -U postgres -d $DB -c "drop schema public cascade; create schema public;" >>"$OUT" 2>&1
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/rehearsal/01_schema.sql >>"$OUT" 2>&1
docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/rehearsal/02_seed_production.sql >>"$OUT" 2>&1
run_ingest && say "S6 INGEST OK" || say "FAIL S6 ingest"
chk s6_docs "$EXP_DOCS" "$(q 'select count(*) from public.source_documents')"
chk s6_snaps "$EXP_TOTAL_SNAPS" "$(q 'select count(*) from public.source_snapshots')"
chk s6_batch "$EXP_BATCH" "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"
docker exec $C psql -q -U postgres -d $DB -f /pkg/sql/90_verify.sql >>"$OUT" 2>&1
say "S6 verify rc=$?"

docker exec $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 -f /pkg/sql/91_rollback.sql >>"$OUT" 2>&1
chk s6_rollback_rc 0 "$?"
chk s6_final_docs 5 "$(q 'select count(*) from public.source_documents')"
chk s6_final_snaps 5 "$(q 'select count(*) from public.source_snapshots')"
chk s6_final_batch 0 "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"
chk s6_final_hashes_restored 5 "$(q "$HASH5")"
chk s6_final_feed 0 "$(q 'select count(*) from public.feed_items')"
say "exact pre-ingest baseline restored: docs=5 snaps=5 batch=0 hashes=original"

# post-rollback re-ingest: chunks must apply cleanly on the restored baseline
docker exec $C sh -c 'set -e
for f in $(ls /pkg/sql/10_ingest_*.sql | head -3); do
  psql -q -U postgres -d '"$DB"' -v ON_ERROR_STOP=1 -f "$f" >/dev/null
done' >>"$OUT" 2>&1 && say "POST-ROLLBACK RE-INGEST OK" || say "FAIL post-rollback re-ingest"
# exact per-chunk doc arithmetic is URL-equivalence dependent; assert the
# meaningful invariants: new batch rows landed and seed docs remain untouched
chk_gt s6_reingest_batch_rows_gt_0 "$(q "select count(*) from public.source_snapshots where metadata->>'ingest_batch'='$BATCH'")"
chk s6_reingest_seed_intact 5 "$(q "select count(*) from public.source_documents where canonical_url in ($PRE_URLS)")"

# ---------- pre-existing documents: titles/languages never overwritten ----------
say "--- pre-existing document identity (title/lang must be the original production values) ---"
docker exec $C psql -U postgres -d $DB -c "select canonical_url, title, language_code from public.source_documents where canonical_url in ($PRE_URLS) order by canonical_url" >>"$OUT" 2>&1

say ""
say "=== REHEARSAL v3 SUMMARY: $FAILURES failures ==="
docker rm -f $C >/dev/null 2>&1
[ "$FAILURES" -eq 0 ]
