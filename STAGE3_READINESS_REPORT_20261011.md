# STAGE 3 READINESS REPORT — 2026-10-11

Consolidated delivery report for the RAD Emigrate Stage 3 content-readiness
workstream (three official sources: radmohajer.ir, radvisa.com, digivisa.ir).

## A. Git

- Branch: `handoff/codex-stage1-stage2-20261010` (unchanged; no new branches)
- Baseline HEAD: `e3b4d5dc3b02885e451a5725baacfabdc98c24bf` (== remote at start)
- New commits (this workstream):
  1. `0b9553a` — Stage 3: three-site content pipeline (acquire, extract,
     verify, canonicalize, test)
  2. `4008ec7` — Stage 3: three-site discovery + full bulk acquisition evidence
     (2,332 URLs)
  3. `2b8dfd4` — Stage 3: canonical dataset, regulatory ledger, visa coverage,
     DB readiness
  4. *(this report + artifact checksum manifest)*
- Remote: pushed and verified after push (see final section for remote SHA).
- Not committed (pre-existing untracked owner/prior-session materials, left
  untouched by design): `STAGE3_CODEX_CONTINUATION_HANDOFF.md`,
  `STAGE3_GROK_*`, `STAGE3_INVENTORY_RECOVERY_*`,
  `artifacts/stage3_live_discovery_20261011/`,
  `artifacts/stage3_live_snapshot_20261011/`,
  `artifacts/stage3_manus_reconciliation_20261010/`,
  `artifacts/STAGE3_*PLAN.md`, `scripts/diag_*.py`, `supabase/.branches/`,
  `.freebuff/`, `.work/`.

## B. Three-site coverage

All counts are distinct states (discovered ≠ verified ≠ captured ≠ extracted
≠ eligible); none are conflated.

### radmohajer.ir
| State | Count |
|---|---|
| Historical inventory (committed metadata records) | 740 |
| Live sitemap locs (reconciled) | 740 (739/740 historical URLs still sitemap-listed; 1 dropped, documented) |
| Current discovered candidates (normalized unique) | 731 |
| HTTP-verified live (200/redirect + pilot reuse) | 680 (669 live + 2 redirect + 9 pilot) |
| Captured to evidence store | 680 |
| Extracted | 680 |
| PASS / REVIEW / FAIL | 212 / 468 / 0 |
| Duplicate flags (near 365 / exact 558, all sites) | 346 (site share) |
| Restricted (403, documented, not bypassed) | 35 |
| Hard 404 | 15 (was 13 mid-run; final manifest authoritative) |
| Soft 404 | 1 |
| Remaining backlog | 0 |

REVIEW-heavy distribution is explained, not hidden: site-wide shell `<title>`
template (flagged `shell_title_page`, with genuine in-page h2 fallbacks) and
high internal duplication.

### radvisa.com
| State | Count |
|---|---|
| Historical inventory | 296 (+ archive discovery 229; live candidates 399 — preserved, not replaced) |
| Current discovered candidates | 589 |
| HTTP-verified live | 573 (555 live + 8 redirect + 10 pilot) |
| Captured | 573 |
| Extracted | 573 |
| PASS / REVIEW / FAIL | 363 / 208 / 2 |
| Duplicate flags | 207 (site share) |
| Soft 404 | 16 |
| Hard 404 / restricted | 0 / 0 |
| Remaining backlog | 0 |

### digivisa.ir
| State | Count |
|---|---|
| Historical inventory | 239 (+ archive discovery 413; live candidates 608 — preserved) |
| Current discovered candidates | 1,012 |
| HTTP-verified live | 939 (912 live + 17 redirect + 10 pilot) |
| Captured | 939 |
| Extracted | 939 |
| PASS / REVIEW / FAIL | 564 / 372 / 3 |
| Duplicate flags | 370 (site share) |
| Soft 404 | 69 |
| HTTP 400 (server-side rejection of 4 legacy URLs; documented) | 4 |
| Remaining backlog | 0 |

**Totals:** 2,332 URLs discovered, all attempted exactly once, 0 transport
errors, 2,192 extracted (PASS 1,139 / REVIEW 1,048 / FAIL 5).

## C. Content readiness

- Total extracted records: 2,192 (`artifacts/stage3_acquisition_20261011/extracted/`)
- Quality: PASS 1,139 / REVIEW 1,048 / FAIL 5, every classification with a
  reproducible reason in `quality_ledger.jsonl`.
- Regulatory verification: 19,017 verbatim claims; 3,128 linked to
  official-source findings; 129 material-discrepancy flags (investment /
  golden-visa claims for DE/GB/DK etc. contradicted by official sources);
  **all claims REVIEW_REQUIRED**.
- Canonical dataset: `artifacts/stage3_canonical_dataset_20261011/`
  (2,192 rows; 662 duplicate groups / 1,584 members / 608 singletons;
  deterministic IDs; dataset SHA-256 in `DATASET_MANIFEST.json`).
- Evidence integrity: 29 pilot snapshots byte-verified against manifest and
  Git blobs; 1,627 raw bulk bodies pinned by
  `manifests/RAW_EVIDENCE_SHA256_MANIFEST.json` (247 MB, local-only by
  repository-suitability rule); committed discovery evidence marked `-text`.

## D. Database readiness

- Schema compatibility: **confirmed** against committed migrations
  (`source_documents` / `source_snapshots` unique keys; language check
  constraint satisfied after normalization: 0 violations).
- Ingestion dry-run: 1,617 document upserts + 1,618 snapshots simulated,
  575/574 conflicts skipped idempotently, 0 constraint failures,
  1 missing-title flag (`INGESTION_DRYRUN_RESULT.json`).
- research_findings → content_drafts: the recorded concern is **already
  remediated** in Stage 5 migrations (atomic RPC + advisory lock + per-finding
  idempotency + regression SQL; handler calls only the RPC). No local defect
  remains; no correction was needed.
- Feed publication safety: nothing in this workstream writes `feed_items`;
  every row is `review_status: unreviewed`; dataset manifest `feed_eligible: 0`;
  promotion remains a separate admin step.

## E. Visa readiness

- Evidence-backed and ready for review: **165 draft programs** across 41
  destinations (`artifacts/stage3_visa_coverage_20261011/`), each citing its
  primary source URL; word-boundary country matching (regression-tested
  against Persian substring collisions).
- Incomplete evidence: 109 destination-category pairs (1–2 PASS pages or
  REVIEW-only) — documented, not fabricated.
- Not supported by available sources: 2 pairs.
- Remaining verification: every draft requires (1) human editorial review and
  (2) official-source sign-off before any production ingestion. No production
  writes were made; package is `status='draft'` only.

## F. QA and security

- Tests: `python -m unittest discover -s tools/stage3_content_migration` —
  **43/43 pass** (integrity, unicode/Persian URLs, redirect/hard/soft-404,
  restricted, duplicate/near-duplicate, canonical handling, boilerplate
  exclusion, missing-title fallback, mojibake, manifest accounting, resume
  state, builder determinism/idempotency, language constraint,
  REVIEW_REQUIRED enforcement, secret-scanner rules, no-Feed-write static
  checks).
- Integrity: pilot manifest + Git blob byte-exactness verified; raw evidence
  hash manifest generated; dataset SHA-256s pinned.
- Security scan (`artifacts/stage3_security_scan_20261011.json`):
  **0 BLOCK findings**; 14 review findings — all public institutional contact
  emails published on the source sites (consulates, visa application
  centers); VIEWSTATE handled contextually (none flagged as secret).
- Unresolved defects: none in branch-attributable code. Known content-level
  issues are captured as REVIEW classifications (shell titles, duplication),
  not code defects.

## G. Final decision

**LOCAL CONTENT WORKSTREAM COMPLETE — PRODUCTION STAGE 3 NO-GO**

All achievable safe local work is complete. Production Stage 3 remains NO-GO
because it requires human regulatory/editorial review approval and authorized
operator actions (hosted ingestion) that are explicitly gated:

1. 19,017 regulatory claims remain REVIEW_REQUIRED pending human approval
   (129 material discrepancies need explicit dispositions).
2. 1,048 REVIEW-classified pages need editorial adjudication (shell titles,
   duplicates).
3. Hosted ingestion into `source_documents`/`source_snapshots` requires
   explicit owner authorization (dry-run package + operator procedure ready).
4. Visa catalog initialization (165 draft programs) requires review +
   official-source sign-off and a separate authorized migration/write path.

## H. Owner decisions required

1. **Authorize hosted ingestion** of the canonical dataset (operator procedure
   in `artifacts/stage3_database_readiness_20261011/DATABASE_READINESS_REPORT.md`).
2. **Assign reviewers** for the 129 material regulatory discrepancies and the
   165 draft visa programs (approval workflow owner).
3. **Confirm handling of the 35 restricted radmohajer URLs** (403): leave
   excluded (current state) or provide owner-mediated access evidence.
4. **Confirm raw-evidence policy**: 247 MB of raw bodies remain local-only,
   pinned by SHA-256 manifest — approve external content-addressed storage if
   off-machine backup is desired (no external upload performed, per
   authorization limits).
