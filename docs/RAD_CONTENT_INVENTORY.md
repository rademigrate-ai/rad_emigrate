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
