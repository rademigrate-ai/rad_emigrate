# FINAL PRE-PRODUCTION READINESS ASSESSMENT — 2026-10-12 (remediated package)

Branch `handoff/codex-stage1-stage2-20261010`, package
`artifacts/stage3_ingestion_package_20261012/`.
Baseline `bc16647` → remediation applied for audit findings F-01 … F-04, F-08.

## Assessment: LOCAL PACKAGE = GO · PRODUCTION EXECUTION = NO-GO (owner gate)

The remediated ingestion package is validated end-to-end, including a full
scenario-matrix rehearsal against a disposable PostgreSQL 16 (0 failures).
Executing against production requires the owner's explicit authorization
(Section 0 of the runbook); no production write has been made.

## What changed in this remediation pass (audit findings)

| Finding | Severity | Fix | Proof |
|---|---|---|---|
| **F-01 rollback safety** | HIGH | `91_rollback.sql` rewritten: strictly batch-scoped, set-based. Candidates derived from batch snapshot **markers** captured in a temp table **before** any deletion (no URL list, no timestamps); 5 pre-ingest URLs hard-excluded; existence check carries **no metadata predicate** (NULL-trap eliminated — concurrent/seed snapshots always protect their document); FK RESTRICT preserved. | Rehearsal v3 S3 (refuses while cited, atomic), S4 (concurrent writes survive; protected batch doc survives; hashes restored), S5 (second rollback = no-op), S6 (exact baseline restored) + unit tests |
| **F-02 hash anomaly** | — | Investigated with evidence only; no algorithm invented. 2/5 seed snapshots conform to `sha256(normalized_text)`; 3/5 undetermined; `radmohajer.ir/fa/` `last_content_hash=643a3c62…` exists on **no** stored snapshot (orphaned doc-only write, `last_seen_at` 2026-10-11T03:27Z). Historical values preserved verbatim; rollback restores them exactly. | `F-02_HASH_ANOMALY_INVESTIGATION.md`; rehearsal S4/S6 hash-restoration checks (5/5) |
| **F-03 URL normalization** | MED | Shared `url_equivalence.py` `url_key()`: whitespace trim, percent-decode, NFC Unicode normalization, empty-path `/` form; ZWNJ vs space deliberately **not** unified (distinct bytes on the source sites). Dataset rows resolve to the **existing production canonical URL** where equivalent — production URLs never overwritten. | 15 regression tests incl. real collision pairs; rehearsal: `digivisa.ir` equivalence merge holds, no duplicate documents (1,612 docs exactly) |
| **F-04 chunk sizing** | MED | 12 rows/chunk → 135 chunks, largest ≈ 618 KB (was ~2.5 MB). Data and transactional semantics identical; chunk count asserted dynamically by test. Manifests and all checksums regenerated. | `INGEST_MANIFEST.json` (135 chunks, 0 hash mismatches), `PACKAGE_MANIFEST.json` (157 entries, 0 mismatches) |
| **F-08 raw-evidence backup** | MED | 1,627/1,627 files verified (0 missing / 0 mismatch / 0 extra). Local bundle **built and verified**: `backups/rad-raw-evidence-20261012.tar.gz` (28.7 MB) + `.sha256`; full restore drill (extract → re-hash all 1,627 files → 0 failures). | `RAW_EVIDENCE_BACKUP_PROCEDURE.md` status table |

## Requirement-by-requirement evidence

| # | Requirement | Evidence | Status |
|---|---|---|---|
| 1 | Verify HEAD/dataset/checksums/raw | Baseline `bc16647`; ingest manifest 138/138 SQL hashes OK; package manifest 157/157 OK; raw 1,627/1,627 verified (`RAW_EVIDENCE_VERIFICATION.json`) | PASS |
| 2 | Current production schema/state, read-only | REST probes (GET-only): 5 documents, 5 snapshots, 6 content_sources, feed_items 0; DDL+RLS+triggers read from committed migrations; **no `alter publication` statement exists in any migration** — nothing publication-gated | PASS |
| 3 | Real ingestion simulation, exact counts | `INGESTION_IMPACT_REPORT.json`: DOC_INSERT 1,607 · DOC_UPDATE 5 · SNAP_INSERT 1,618 · SKIP 574 · BLOCKED 0; generator ≡ simulator (test-enforced); impact report now includes `triggers_and_publication_gates` inspection | PASS |
| 4 | IDs, dup groups, provenance, snapshots, RLS compatibility | Deterministic text IDs in snapshot metadata only (DB PK = server uuid); per-row provenance + batch marker; write path = postgres/service_role (grants+policies verified); URL-equivalence prevents duplicates (15 tests) | PASS |
| 5 | research→draft workflow + Feed proof | Feed tables revoked from API roles; `trg_guard_human_feed_item_mutation` blocks even service_role direct writes; bulk package never calls `ingest_research_snapshot`; rehearsal used a **local hard guard** raising on any feed mutation — 0 violations across all scenarios; live feed_items=0 | PASS |
| 6 | Deterministic, resumable, idempotent procedure + rollback | 135 chunks; **rehearsal v3 (PostgreSQL 16, 0 failures)**: mid-chunk interruption applies 0 rows (transactional) and resume converges; full double-run idempotent; verify script clean; rollback refuses-while-cited (FK RESTRICT, atomic), survives concurrent writes, second rollback is a no-op, restores exact baseline (`docs=5 snaps=5 batch=0`, all 5 hashes original) | PASS |
| 7 | Editorial review packages | `stage3_review_queues_20261012/`: 19,017 claims prioritized (P0 3,128 incl. all 129 discrepancies), 165 visa drafts; every row `REVIEW_REQUIRED`, `auto_approved=false` (tested) | PASS |
| 8 | Raw evidence completeness + backup | Verified complete; **backup bundle built + restore-verified locally**; external/independent copy NOT yet made (no owner-authorized destination) — see Owner decisions | PASS (local) / OPEN (independent copy) |
| 9 | Tests + security | **77/77 tests pass** (incl. new F-01 rollback-safety, F-03 URL-equivalence, F-04 dynamic-chunk-count regression tests); security scan `stage3_security_scan_20261012.json`: **0 BLOCK**, 4 review (public institutional contacts, previously dispositioned) | PASS |
| 10 | Operator runbook | `OPERATOR_RUNBOOK.md` updated: 135-chunk order, preflight gates, expected effects (1,612/1,623/0), stop conditions, interruption/resume, §7 rollback with rehearsal-v3-proven behaviors, §8a triggers & publication-gate findings, audit trail (137 executed files) | PASS |

## Known limitations (stated honestly)

- The 5 seed rows' original `content_hash` algorithm remains undetermined
  (3/5 snapshots non-conforming; documented in `F-02_HASH_ANOMALY_INVESTIGATION.md`).
  New rows use `sha256(normalized_text)`; uniqueness is unaffected.
- 35 restricted (403) radmohajer URLs and 4 HTTP-400 digivisa URLs remain
  uncaptured, documented, not bypassed.
- Rehearsal ran on PostgreSQL 16 with production-faithful DDL (auth FKs
  omitted; a stricter local feed guard). It does not exercise Supabase
  RLS/GUC runtime behavior — covered by migration analysis + the read-only
  production probes.
- The backup bundle is on the **same disk** as the originals until the owner
  copies it off-machine (checksum file ready).

## Owner decisions required

1. **Authorize execution** of `OPERATOR_RUNBOOK.md` (production write).
2. Assign reviewers for the P0 queues (3,128 claims incl. 129 discrepancies;
   14 visa drafts).
3. Choose a backup destination and copy `backups/rad-raw-evidence-20261012.tar.gz`
   (+ `.sha256`) off this machine — closes the last F-08 item.
4. Decide on the 35 restricted URLs (leave excluded vs owner-mediated access).
