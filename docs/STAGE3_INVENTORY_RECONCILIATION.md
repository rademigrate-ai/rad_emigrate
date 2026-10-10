# STAGE 3 Inventory Reconciliation — Decision Record

- Date: 2026-10-11
- Branch: `handoff/codex-stage1-stage2-20261010`
- Delivery commits: `436c9ebb75c150ff4ab7a9da64d9e4241cee697b` (archive evidence v2), `b98699af36cd3fc763f5898098e57af82e8d399c` (radmohajer canonical inventory)
- Official Stage 3 production readiness: **NO-GO** (unchanged; this record changes no production state)
- Companion: `artifacts/STAGE3_FINAL_BLOCKER_CLOSURE_PLAN.md`

## 1. Status per site — precise distinctions

| Site | Historical observation (2026-10-07 closeout) | Current committed state | Classification |
|---|---:|---|---|
| radmohajer.ir | 740 rows (live sitemap, HTTP 200, 740 `<loc>`) | `docs/inventory/radmohajer_ir.jsonl` — 740 metadata rows, SHA-256 `7a031c9c3f729be2d177787275b6ed4f7b0d6d61e4e7bd1377b6162ce15b31a9`, committed at `b98699a` | **Canonical, committed.** Historical observation and current canonical record are the same 740 rows. |
| radvisa.com | 296 rows (Wayback CDX unique at generation time; per-row list never preserved) | `artifacts/stage3_archive_final_v2/radvisa_archive_discovery_v2.jsonl` — **229** archive-evidence rows, committed at `436c9eb` | **Historical observation ≠ current evidence.** 296 remains a historical count record only; 229 is the committed archive-evidence set. No claim of row identity. |
| digivisa.ir | 239 rows (Wayback CDX unique at generation time; per-row list never preserved) | `artifacts/stage3_archive_final_v2/digivisa_archive_discovery_v2.jsonl` — **413** archive-evidence rows, committed at `436c9eb` | **Historical observation ≠ current evidence.** 239 remains a historical count record only; 413 is the committed archive-evidence set. No claim of row identity. |

## 2. Delta arithmetic (evidence-backed, no padding)

**radvisa.com: 296 historical → 229 evidence (−67)**
- −8: CDX re-collection drift (2026-10-10 evidence run recovered 288 unique HTML URLs vs the 2026-10-07 observation; original list lost, difference not reconcilable)
- −46: v1 quality quarantine (11 replacement-character URLs, 35 static-asset URLs)
- −13: v2 non-content endpoint classification (5 NC1 crawler/ad files, 5 NC2 `.well-known/`, 1 NC3 captcha, 1 NC5 asset handler, 1 NC6 feed, 1 NC7 soft-404; rules and per-URL reasons in `artifacts/stage3_archive_final_v2/STAGE3_ARCHIVE_V2_QUARANTINE.json`)

**digivisa.ir: 239 historical → 413 evidence (+174)**
- +196: CDX re-collection drift (435 unique HTML URLs recovered on 2026-10-10 vs the 2026-10-07 observation; the archive index surface grew or filters differed; original list lost)
- −12: v1 quality quarantine (11 replacement-character URLs, 1 static-asset URL)
- −10: v2 non-content endpoint classification (5 NC1, 5 NC2, 1 NC3 admin login, 1 NC4 suspension page, 1 NC7 soft-404)

Every excluded URL is individually traceable with exact reason and original source line in the v2 quarantine record (23 records). The v1 quarantine (58 records) survives only as counts in `artifacts/stage3_manus_reconciliation_20261010/STAGE3_MANUS_SHA256_MANIFEST.json`; its per-URL lists were never persisted.

## 3. Decisions taken (and boundaries respected)

1. **`docs/RAD_CONTENT_INVENTORY_METRICS.json` and `docs/RAD_CONTENT_INVENTORY_SUMMARY.json` are preserved unchanged as historical observations.** Their 740/296/239 (=1,275) counts describe the 2026-10-07 closeout state; they are not current verified row counts for radvisa/digivisa and must not be reinterpreted as such.
2. **No rows were invented, padded, or dropped to force 296/239** (per the CDX recovery order: do not pad the missing radvisa rows; do not drop digivisa rows solely to force 239).
3. **The 229/413 archive-evidence sets are NOT declared canonical replacements for 296/239.** That requires an owner decision (below). They are committed, SHA-pinned evidence under `artifacts/`.
4. `docs/inventory/radmohajer_ir.jsonl` is the only committed per-site canonical inventory file. The `radvisa_com.jsonl` / `digivisa_ir.jsonl` files referenced by pre-2026-10-10 documentation **never existed in git and are absent from disk**; the 1,275-row `docs/RAD_CONTENT_INVENTORY.jsonl.gz` bundle is likewise absent. Documentation claiming otherwise has been corrected by this change.

## 4. OWNER DECISION — RESOLVED: **Option B selected** (2026-10-11)

Options considered:
- **Option A** — accept 229/413 as the new canonical archive-evidence counts, with this record as the documented supersession of the 296/239 observations (METRICS stays historical).
- **Option B** — keep METRICS 296/239 as the authoritative historical count source with explicit GAP annotation (status quo of this record; per-site row lists remain unavailable).
- **Option C** — if the owner possesses the original 2026-10-07 CDX row lists on any machine, restore them per the recovery-package local-restore procedure, then re-reconcile.

### Decision (owner-selected, 2026-10-11)

**Option B is adopted.** Recorded terms:

1. Historical observations are preserved unchanged: radmohajer 740, radvisa 296, digivisa 239 (total 1,275) — in `docs/RAD_CONTENT_INVENTORY_METRICS.json` and the closeout documentation.
2. `docs/inventory/radmohajer_ir.jsonl` remains the committed canonical metadata inventory (740 records).
3. The radvisa 229 / digivisa 413 archive-discovery records remain **evidence only**; archive evidence is **not** promoted into canonical inventory, and no per-site `radvisa_com.jsonl` / `digivisa_ir.jsonl` canonical files are created.
4. The radvisa **−67** and digivisa **+174** differences are recorded as **unresolved historical row-set GAPs** (original 2026-10-07 row lists were never preserved; deltas are documented in §2).
5. This decision resolves only the canonical-adoption question. It does **not** mark the underlying data reconciliation, live website verification, or content migration complete.
6. Official Stage 3 production readiness remains **NO-GO** (see §5 blockers; §6 boundaries remain in force).

Options A and C are closed without prejudice; they may be revisited only by a new explicit owner decision.

## 5. Remaining external blockers and acceptance criteria

| Blocker | Acceptance criterion | Class |
|---|---|---|
| Live HTTP reachability to `radvisa.com` / `digivisa.ir` (`185.192.112.58`) | HTTP(S) 200 on both roots from an authorized non-production environment | External; blocks Stage 3 COMPLETE |
| Authorization for a bounded discover→fetch→snapshot delta | Explicit owner approval for network fetch in a non-production environment, merged per `docs/RAD_CONTENT_INGESTION.md` re-fetch rules | Owner decision |
| Capture-claim provenance for the 6 radmohajer `FETCHED_AND_CAPTURED` URLs | Read-only export of `source_documents` / `source_snapshots` rows matching those URLs, or documented downgrade to REVIEW_REQUIRED | Hosted evidence |
| Official-source verification of 731 radmohajer regulatory rows | Official evidence attached per editorial policy before any promotion | Deferred by design |
| Grok Stage 3 blueprint | Owner provides it or declares it not required | Owner decision |

## 6. What this record does NOT change

No inventory JSONL, archived evidence, metrics or summary JSON, database, code, migration, or production state was modified. feed_items remain untouched. Regulatory rows remain `REVIEW_REQUIRED`. Official Stage 3 production readiness remains **NO-GO**.
