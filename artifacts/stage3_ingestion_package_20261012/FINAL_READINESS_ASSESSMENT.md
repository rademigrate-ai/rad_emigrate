# FINAL PRE-PRODUCTION READINESS ASSESSMENT — 2026-10-12

Branch `handoff/codex-stage1-stage2-20261010`, package
`artifacts/stage3_ingestion_package_20261012/`.

## Assessment: LOCAL PACKAGE = GO · PRODUCTION EXECUTION = NO-GO (owner gate)

The ingestion package is validated end-to-end and ready to execute. Executing
it against production requires the owner's explicit authorization (Section 0
of the runbook); no production write has been made.

## Requirement-by-requirement evidence

| # | Requirement | Evidence | Status |
|---|---|---|---|
| 1 | Verify HEAD/dataset/checksums/raw | HEAD `ebbe568` verified; artifact manifest 22/22 hashes OK; raw 1,627/1,627 files verified (`RAW_EVIDENCE_VERIFICATION.json`: complete, 0 missing, 0 mismatch, 0 extra) | PASS |
| 2 | Current production schema/state, read-only | REST probes: 5 documents, 5 snapshots, 6 content_sources, 10 programs/22 destinations published, feed_items 0; `research_findings`/`content_drafts` anon-SELECT denied (401/42501); DDL+RLS read from committed migrations | PASS |
| 3 | Real ingestion simulation, exact counts | `INGESTION_IMPACT_REPORT.json`: **INSERT docs 1,612 · UPDATE 5 · SKIP 574 · BLOCKED 0 · snapshots 1,618**, 2 URL-equivalence matches, 1 production anomaly documented; counts match `INGEST_MANIFEST.json` (enforced by test) | PASS |
| 4 | IDs, dup groups, provenance, snapshots, RLS compatibility | Deterministic text IDs carried in snapshot metadata (DB PK is server uuid — documented in impact report); 662 dup groups resolved upstream; per-row provenance + batch marker in metadata; write path = service_role/admin only (grants+policies verified); URL-equivalence prevents duplicate documents (regression-tested) | PASS |
| 5 | research→draft workflow + Feed proof | Drafts enter as `status='review'`; `publish_content_draft` requires admin + `status='approved'`; feed tables revoked from all API roles; `trg_guard_human_feed_item_mutation` blocks even service_role writes unless the RPC sets the transaction-local human-actor marker; bulk package never calls `ingest_research_snapshot`; rehearsal `feed_items=0` throughout; live feed_items=0 | PASS |
| 6 | Deterministic, resumable, idempotent procedure + rollback | 54 ordered chunks, `ON CONFLICT` idempotency proven by full double-run (counts unchanged); interruption-safe resume documented in `OPERATOR_RUNBOOK.md` §6; `91_rollback.sql` scope-tested: refuses while cited (FK RESTRICT), restores exact baseline incl. prior `last_content_hash`; non-lossless caveats documented (§7) | PASS |
| 7 | Editorial review packages, 129 + 165 | `stage3_review_queues_20261012/`: 19,017 claims prioritized (P0 3,128 incl. **all 129 discrepancies** / P1 15,889), 165 visa drafts prioritized (P0 14 / P1 117 / P2 34); every row `REVIEW_REQUIRED`, `auto_approved=false` (tested) | PASS |
| 8 | Raw evidence completeness + backup procedure | Full hash verification complete; `RAW_EVIDENCE_BACKUP_PROCEDURE.md` prepared (offline/second-machine/encrypted-cloud options, restore drill incl. deterministic rebuild) — **not executed, upload not authorized** | PASS (procedure) |
| 9 | Tests + security | **67/67 tests pass** (43 prior + 24 new package/queue/contract regression tests); security scan `stage3_security_scan_20261012.json`: **0 BLOCK**, 4 review (public institutional contacts already dispositioned) | PASS |
| 10 | Operator runbook | `OPERATOR_RUNBOOK.md`: exact file order, preflight gates, expected-effects table, stop conditions, interruption/resume, rollback with rehearsal-proven behaviors, audit trail | PASS |

## Defects found and fixed in this pass (root causes, all regression-tested)

1. **`language_code` NOT NULL mis-modeled** — dry-run claimed nullable; 572
   rows would have failed. Fixed with deterministic script/site detection
   (fa 2,185 / en 7, violations 0).
2. **Missing title vs NOT NULL** — hostname fallback with explicit
   `title_source=url_fallback` flag (matches existing production seed
   practice); violations 0.
3. **Home content-type false positives** — titles ending in `/` matched the
   URL rule; rule now URL-only with slash-insensitive home patterns.
4. **URL-equivalence in SQL** — `ON CONFLICT` is exact-match; dataset
   `https://digivisa.ir` vs production `https://digivisa.ir/` would have
   created a duplicate document and silently dropped its snapshot. Fixed by
   resolving to the production canonical form (proven in rehearsal).
5. **Simulator key bug** — whole-URL lowercasing and empty-path trailing
   slash; both fixed, host-only case folding verified by tests.
6. **Near-dup length cutoff** — `break`→`continue` correctness fix (prior
   pass), kept covered by builder determinism test.

## Known limitations (not blockers for the package, stated honestly)

- Production `content_hash` algorithm of the 5 seed rows remains
  undetermined (not reproducible from stored data); documented — new rows use
  the package's defined `sha256(normalized_text)`, uniqueness is unaffected.
- 1 production anomaly (`radmohajer.ir/fa/` `last_content_hash` not among its
  snapshot hashes) predates this work; the ingest's UPDATE heals it, and
  rollback restores the prior value.
- 35 restricted (403) radmohajer URLs and 4 HTTP-400 digivisa URLs remain
  uncaptured, documented, not bypassed.
- Local rehearsal ran on PostgreSQL 16.15 with production-faithful DDL
  (auth FKs omitted); it does not exercise Supabase RLS/GUC behavior — those
  are addressed by the write-path analysis and the untouched production
  probes.

## Owner decisions required

1. **Authorize execution** of `OPERATOR_RUNBOOK.md` (production write).
2. Assign reviewers for the P0 queues (3,128 claims incl. 129 discrepancies;
   14 visa drafts).
3. Choose and authorize a raw-evidence backup destination (procedure ready,
   nothing uploaded).
4. Decide on the 35 restricted URLs (leave excluded vs owner-mediated
   access).
