# STAGE 3 PRODUCTION INGESTION — OPERATOR RUNBOOK

Package: `artifacts/stage3_ingestion_package_20261012/`
(batch marker `stage3-bulk-20261012`)
Prepared: 2026-10-12 | Status: **validated by full local rehearsal; execution
requires owner authorization** | Branch: `handoff/codex-stage1-stage2-20261010`

This runbook ingests **source evidence only** (`source_documents` /
`source_snapshots`). It creates no research findings, no content drafts, no
knowledge rows, no visa rows, no Feed items. Every snapshot is stamped
`regulatory_status: REVIEW_REQUIRED` in metadata; nothing is approved.

---

## 0. Authorization gate

Do not execute Sections 3+ until the owner has explicitly approved this
runbook. Sections 1-2 are read-only and may run at any time.

## 1. Package integrity (local, read-only)

```bash
cd <repo-root>
python - <<'PY'
import hashlib, json, pathlib
m = json.loads(pathlib.Path('artifacts/stage3_ingestion_package_20261012/INGEST_MANIFEST.json').read_text('utf-8'))
bad = [f['file'] for f in m['files']
       if hashlib.sha256((pathlib.Path('artifacts/stage3_ingestion_package_20261012/sql')/f['file']).read_bytes()).hexdigest() != f['sha256']]
print('chunks', len(m['files']), 'hash failures', bad); assert not bad
PY
```

**Stop if any hash fails.**

## 2. Preflight (read-only, against production)

1. Re-capture live state (GET-only) and re-run the simulator:
   ```bash
   # same GET-only capture script used on 2026-10-12 -> LIVE_STATE_SNAPSHOT.json
   python tools/stage3_content_migration/simulate_ingestion.py \
     --dataset artifacts/stage3_canonical_dataset_20261011/CANONICAL_CONTENT_DATASET.jsonl \
     --live artifacts/stage3_ingestion_package_20261012/LIVE_STATE_SNAPSHOT.json \
     --out artifacts/stage3_ingestion_package_20261012
   ```
2. Compare `INGESTION_IMPACT_REPORT.json` counts against the recorded
   expectation:
   `DOC_INSERT=1607  DOC_UPDATE=5  SNAP_INSERT=1618  SKIP=574  BLOCKED=0`
   (simulator and SQL generator cross-check each other — enforced by test).

**STOP CONDITIONS (re-generate the package, do not improvise):**
- production document count is no longer 5 (someone else ingested);
- counts differ from expectation;
- any `BLOCKED > 0` or new production anomaly appears.

3. Optional but recommended: run `sql/00_preflight.sql` in the Supabase SQL
   editor and record the baseline counts (expect `source_documents=5`,
   `source_snapshots=5`, `feed_items=0`, `existing_batch_rows=0`).
   If `existing_batch_rows > 0`, a previous partial run exists — go to
   Section 6 (resume), not Section 4.

## 3. Expected effects (one sentence)

After a successful run: `source_documents = 1,612` (5 pre-existing kept
untouched incl. titles/language, 1,607 created — URL-equivalent variants
percent-encoded/NFC/slash forms collapse to ONE document),
`source_snapshots = 1,623` (1,618 new, stamped with the batch marker),
`feed_items = 0`, no other table touched.

## 4. Execution

Tool: Supabase Dashboard → SQL Editor (runs as `postgres`, shows in the
dashboard history). Alternative: `psql` with the connection string from
Dashboard → Settings → Database.

Run files **in name order**, each as its own execution (135 chunks, F-04
sizing: largest chunk ≈ 618 KB):

```
00_preflight.sql          (already run in Section 2)
10_ingest_0001.sql
10_ingest_0002.sql
...
10_ingest_0135.sql
90_verify.sql
```

In psql form:

```bash
P=artifacts/stage3_ingestion_package_20261012
for f in "$P"/sql/00_preflight.sql "$P"/sql/10_ingest_*.sql "$P"/sql/90_verify.sql; do
  echo "== $f"
  psql "$PGURL" -v ON_ERROR_STOP=1 -f "$f" || { echo "STOPPED at $f"; break; }
done
```

Record progress: tick off each chunk number as it completes. Expected
runtime: a few minutes (21 MB of SQL total across 135 chunks).

## 5. Post-ingestion verification (must ALL pass)

From `90_verify.sql` output + one read-only REST check:

| Check | Expected |
|---|---|
| `batch_snapshots` | **1,618** |
| `source_documents` total | **1,612** (5 pre-existing + 1,607 created) |
| `source_snapshots` total | **1,623** |
| `batch_orphans` | **0** |
| the 5 pre-existing titles | unchanged (e.g. `digivisa.ir`, `تماس با ما`, `Contact us`, …) |
| `feed_items` | **0** |
| spot-check a batch snapshot `metadata.regulatory_status` | `REVIEW_REQUIRED` |

Any mismatch → Section 6 diagnosis; do not proceed to cleanup.

## 6. Interruption / resume / stop conditions

- **Mid-run interruption is safe.** Every chunk is `begin/commit` with
  `ON CONFLICT DO NOTHING`; rerunning from `10_ingest_0001.sql` converges to
  the same state (proven: full double-run in rehearsal left counts unchanged).
- Resume by re-running from the first chunk you are not sure completed.
- **Stop the run and call the owner** if: SQL editor errors with anything
  other than a clean statement completion; `feed_items` becomes non-zero
  (impossible via this package — would indicate a different session's
  activity); counts exceed expectations (another writer is active); or the
  dashboard reports replication/health issues.
- Do NOT improvise corrective SQL; re-derive the package instead.

## 7. Rollback (owner-authorized recovery only) — F-01 strategy

`sql/91_rollback.sql` is **strictly batch-scoped and set-based**:

1. candidate documents are derived from batch snapshot **markers** in a
   temp table captured **before** any deletion — never from a URL list,
   never from timestamps;
2. the 5 pre-ingest production URLs are **hard-excluded** by an explicit
   guard (generated from the live-state capture) — they cannot be deleted;
3. any snapshot remaining after batch deletion (concurrent writer, seed,
   post-ingest work) protects its document — the existence check carries
   **no metadata predicate**, so rows without an `ingest_batch` key cannot
   be silently skipped (the NULL-evaluation trap is gone);
4. `last_content_hash` of the 5 pre-existing documents is restored to the
   captured pre-ingest values (including the F-02 historical `643a3c62…`
   value for `radmohajer.ir/fa/` — preserved verbatim);
5. a final SELECT reports every batch candidate that was KEPT because
   snapshots remain.

Proven behaviors (local rehearsal v3, PostgreSQL 16, 2026-10-12 — full
scenario matrix, 0 failures):

- **Interruption mid-chunk**: a chunk that dies before `commit;` applies
  ZERO rows (transactional); resume continues cleanly from that chunk.
- **Double-run idempotency**: all 135 chunks run twice → counts unchanged.
- If ANY ingested snapshot has been cited by knowledge work, rollback
  **fails by FK constraint** (`knowledge_citations.snapshot_id` is
  `ON DELETE RESTRICT`) — this is intentional: review work is never silently
  destroyed. Resolve citations first, deliberately. The whole rollback
  transaction rolls back atomically (nothing partially deleted).
- **Concurrent-writer safety**: with a concurrent writer's rows present
  (a new document+snapshot, and an extra snapshot on a batch-created
  document), rollback deletes only batch markers/snapshots; the concurrent
  document, its snapshots, and the batch document that still carries a
  snapshot all SURVIVE, and the 5 pre-existing hashes are restored.
- After citation cleanup, rollback restores exactly `docs=5, snaps=5,
  batch_left=0`, with `last_content_hash` of `https://digivisa.ir/` back to
  `a99199f4…` and `https://radmohajer.ir/fa/` back to `643a3c62…`.
  A second rollback run is a verified no-op.
- Full cycle re-proven on a fresh database: ingest → verify → rollback →
  exact baseline → re-ingest applies cleanly.
- `last_seen_at` on pre-existing documents is intentionally NOT reverted
  (audit timestamp, not content).
- **Rollback is not assumed lossless for anything created AFTER the ingest**
  (e.g. knowledge citations, versions, drafts referencing these snapshots).
  Inventory those first; the FK constraint will refuse destruction, but rows
  created without FK links (manual notes, exports) cannot be restored by
  this script.

## 8. What this runbook deliberately does NOT do

- Does not call `ingest_research_snapshot()` — that interface creates
  research findings + review drafts (correct for scheduled delta sync,
  wrong for bulk: it would create ~1,618 unreviewed findings).
- Does not touch `knowledge_*`, `research_findings`, `content_drafts`,
  `destinations`, `visa_*`, `feed_items`.
- Does not approve, promote, or publish anything.
- Does not modify migrations or migration history.

## 8a. Source-table triggers & publication gates (inspected 2026-10-12)

Verified against the committed migrations (`supabase/migrations/`):

- `source_documents` / `source_snapshots`: **no triggers at all** (no
  `updated_at`, no audit, no gate) and **no Realtime publication membership**
  (no `alter publication` statement exists in any migration). The only
  runtime gates during ingest are the two unique indexes (which give
  idempotency) and the `knowledge_citations.snapshot_id` FK RESTRICT
  (which gives rollback safety).
- `content_sources` has an `updated_at` trigger and an AFTER audit trigger
  writing to `admin_audit_logs` — this package performs **zero**
  `content_sources` writes, so neither fires.
- `feed_items` / `feed_item_localizations` carry the Stage 1 human-publication
  guard trigger (blocks all direct mutations, even service_role). The package
  writes zero feed rows; the rehearsal additionally enforced this with a
  local hard guard (any feed mutation raises) — 0 violations.
- Full findings recorded in `INGESTION_IMPACT_REPORT.json` →
  `triggers_and_publication_gates`.

## 9. Audit trail to keep

1. This runbook with Section 5 table filled in (date, executor, values).
2. `INGEST_MANIFEST.json`, `INGESTION_IMPACT_REPORT.json`,
   `REHEARSAL_RESULTS.txt` (v3), `RAW_EVIDENCE_VERIFICATION.json`,
   `F-02_HASH_ANOMALY_INVESTIGATION.md`, `FINAL_READINESS_ASSESSMENT.md`.
3. Dashboard SQL history entries for the 137 executed files
   (1 preflight + 135 chunks + 1 verify).
