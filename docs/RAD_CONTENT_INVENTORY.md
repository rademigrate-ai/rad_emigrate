# RAD Content Inventory (Stage 3 Closeout)

## Canonical artifacts

- **`docs/RAD_CONTENT_INVENTORY.jsonl.gz`** — full machine-readable inventory (gzip JSONL)
- **`docs/inventory/*.jsonl`** — per-site JSONL (compact keys)
- **`docs/RAD_CONTENT_INVENTORY_METRICS.json`** — metrics generated from the inventory

## Terminal states

`FETCHED_AND_CAPTURED` | `DUPLICATE_OF:` | `REDIRECTED_TO:` | `EXCLUDED:` | `FAILED:` | `REVIEW_REQUIRED:` | `UNREACHABLE:`

## Counts

| Site | Rows | Terminal primary |
|------|-----:|------------------|
| radmohajer.ir | 740 | 6 captured, 734 review_required |
| radvisa.com | 296 | 296 unreachable (live) |
| digivisa.ir | 239 | 239 unreachable (live) |
| **Total** | **1275** | |
## Post-closeout status (2026-10-11)

This document describes the 2026-10-07 closeout state. Its counts (740/296/239 = 1,275) are preserved as **historical observations**, not current verified row counts. Current reality differs:

- `docs/inventory/radmohajer_ir.jsonl` (740 rows) is committed and canonical (commit `b98699a`).
- `docs/inventory/radvisa_com.jsonl`, `docs/inventory/digivisa_ir.jsonl` and `docs/RAD_CONTENT_INVENTORY.jsonl.gz` **do not exist** (never committed; lost with the original runner output).
- Committed archive evidence (not canonical per-site inventory): `artifacts/stage3_archive_final_v2/radvisa_archive_discovery_v2.jsonl` (229 rows) and `artifacts/stage3_archive_final_v2/digivisa_archive_discovery_v2.jsonl` (413 rows).
- Full reconciliation, delta arithmetic, and the open owner decision: `docs/STAGE3_INVENTORY_RECONCILIATION.md`.
