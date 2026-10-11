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
   `DOC_INSERT=1612  DOC_UPDATE=5  SNAP_INSERT=1618  SKIP=574  BLOCKED=0`.

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

After a successful run: `source_documents = 1,617` (5 pre-existing kept
untouched incl. titles/language, 1,612 created),
`source_snapshots = 1,623` (1,618 new, stamped with the batch marker),
`feed_items = 0`, no other table touched.

## 4. Execution

Tool: Supabase Dashboard → SQL Editor (runs as `postgres`, shows in the
dashboard history). Alternative: `psql` with the connection string from
Dashboard → Settings → Database.

Run files **in name order**, each as its own execution:

```
00_preflight.sql          (already run in Section 2)
10_ingest_0001.sql
10_ingest_0002.sql
...
10_ingest_0054.sql
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
runtime: a few minutes (21 MB of SQL total; largest chunk < 2 MB).

## 5. Post-ingestion verification (must ALL pass)

From `90_verify.sql` output + one read-only REST check:

| Check | Expected |
|---|---|
| `batch_snapshots` | **1,618** |
| `source_documents` total | **1,617** |
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

## 7. Rollback (owner-authorized recovery only)

`sql/91_rollback.sql` deletes ONLY rows carrying the batch marker and
restores the 5 pre-existing documents' prior `last_content_hash` values
(captured in `LIVE_STATE_SNAPSHOT.json`).

Proven behaviors (local rehearsal, PostgreSQL 16):

- If ANY ingested snapshot has been cited by knowledge work, rollback
  **fails by FK constraint** (`knowledge_citations.snapshot_id` is
  `ON DELETE RESTRICT`) — this is intentional: review work is never silently
  destroyed. Resolve citations first, deliberately.
- After citation cleanup, rollback restores exactly `docs=5, snaps=5,
  batch_left=0`, with `last_content_hash` of `https://digivisa.ir/` back to
  `a99199f4…`.
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

## 9. Audit trail to keep

1. This runbook with Section 5 table filled in (date, executor, values).
2. `INGEST_MANIFEST.json`, `INGESTION_IMPACT_REPORT.json`,
   `REHEARSAL_RESULTS.txt`, `RAW_EVIDENCE_VERIFICATION.json`.
3. Dashboard SQL history entries for the 56 executed files.
