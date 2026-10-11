# Stage 3 — Database & Pipeline Readiness Report (Phase G)

Date: 2026-10-11 (read-only inspection; no hosted access, no writes, no migrations)

## 1. Confirmed schema contract (from committed migrations)

| Canonical dataset field | Target column | Constraint verified in migration |
|---|---|---|
| `canonical_url` | `public.source_documents.canonical_url` | UNIQUE document key |
| `extracted_title` | `source_documents.title` | 1 row with missing title flagged (`would_fail_missing_title: 1`) |
| `language` (normalized fa/en/NULL) | `source_documents.language_code` | `check (language_code in ('fa','en'))` (`20261003210302…visa_catalog.sql:46`); **nullable** in `source_documents` (`20261003214031…document_intelligence.sql:35`) |
| `body` | `source_snapshots.normalized_text` | snapshot text store |
| `body_sha256` | `source_snapshots.content_hash` | UNIQUE `(document_id, content_hash)` idempotency |
| `raw_snapshot_sha256`, quality, extraction version | `source_snapshots.metadata` | jsonb metadata |
| `provenance.http_status / capture_timestamp` | `source_snapshots.http_status / fetched_at` | audit fields |

Language normalization was added to the builder because raw HTML yields BCP-47
tags (`fa-ir`, `en-gb`) and 572 pages with no language evidence; after
normalization the dry-run reports **0 check-constraint failures**.

## 2. Ingestion dry-run result (no network, no DB)

From `artifacts/stage3_canonical_dataset_20261011/INGESTION_DRYRUN_RESULT.json`:

- rows_total: 2,192
- would_insert_documents: 1,617 | would_skip_existing_documents: 575 (same canonical_url)
- would_insert_snapshots: 1,618 | would_skip_existing_snapshots: 574 (same content_hash)
- would_fail_language_check: 0 | would_fail_missing_title: 1

The dry-run simulates the two uniqueness rules only. A production ingest must
run in a transaction and remains an operator action requiring explicit owner
authorization.

Tables explicitly NOT touched: `knowledge_items`, `knowledge_claims`,
`research_findings`, `content_drafts`, `feed_items`, `destinations`, `visa_*`.

## 3. research_findings → content_drafts investigation

The previously recorded concern was investigated against current code:

- `20261007080002_research_atomic_review_candidate.sql` replaces the
  trigger-based path with an atomic `create_research_review_candidate` RPC.
- Serialization is enforced with an advisory lock; per-finding idempotency keys
  prevent duplicate drafts on re-delivery.
- Regression SQL for the concern ships inside the migration.
- `supabase/functions/research-sync/handler.ts` calls only the atomic RPC.

**Conclusion: the concern was already remediated in Stage 5 migrations. No
remaining local code defect found; no correction needed.**

## 4. Feed publication safety

- Nothing in the Stage 3 pipeline writes `feed_items`.
- Promotion remains a separate admin step
  (`promote_knowledge_from_evidence`, `docs/KNOWLEDGE_INGESTION_CONTRACT.md`).
- The canonical dataset marks every row
  `regulatory_verification_status: REVIEW_REQUIRED`, `review_status: unreviewed`,
  and the dataset manifest reports `feed_eligible: 0`.
- CI keyword scan (`.github/workflows/ci.yml`) plus these invariants keep
  research from auto-publishing.

## 5. Operator procedure for eventual (authorized) ingestion

1. Owner authorizes a production ingest explicitly.
2. Run `build_canonical_dataset.py` → `CANONICAL_CONTENT_DATASET.jsonl`.
3. In a transaction: upsert `source_documents` keyed by `canonical_url`;
   insert `source_snapshots` keyed by `(document_id, sha256(body))`;
   `ON CONFLICT DO NOTHING` guarantees idempotent re-runs.
4. Verify counts against `INGESTION_DRYRUN_RESULT.json`.
5. Keep all rows in review workflows; no promotion to knowledge, no Feed writes
   as part of this ingest.

## 6. Readiness verdict

Schema compatibility: **confirmed**. Dry-run: **clean**. Research→draft:
**already hardened**. Feed safety: **enforced by design**.
Hosted ingestion remains gated on owner authorization (Stage 3 production
NO-GO until then, plus human review of regulatory content).
