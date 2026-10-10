# Per-site inventory JSONL

Generated Stage 3 closeout inventories (compact keys: u=url, l=lang, c=category, t=terminal_state, f=freshness, p=policy, i=ingestion, s=source).

## Committed (canonical)

- `radmohajer_ir.jsonl` — 740 rows from live sitemap (commit `b98699a`; SHA-256 `7a031c9c3f729be2d177787275b6ed4f7b0d6d61e4e7bd1377b6162ce15b31a9`)

## Historical observations only — per-site files do NOT exist

The following were referenced by the 2026-10-07 closeout documentation but were **never committed and are absent from disk**. Treat their counts as historical observations, not present files:

- `radvisa_com.jsonl` — 296 rows (2026-10-07 Wayback CDX; live unreachable) — **file absent**
- `digivisa_ir.jsonl` — 239 rows (2026-10-07 Wayback CDX; live unreachable) — **file absent**
- `docs/RAD_CONTENT_INVENTORY.jsonl.gz` — 1,275-row bundle — **absent**

## Current archive evidence (committed; NOT canonical per-site inventory)

- `artifacts/stage3_archive_final_v2/radvisa_archive_discovery_v2.jsonl` — 229 rows
- `artifacts/stage3_archive_final_v2/digivisa_archive_discovery_v2.jsonl` — 413 rows

See `docs/STAGE3_INVENTORY_RECONCILIATION.md` for the full reconciliation, delta arithmetic, and the open owner decision on canonical adoption.
Regenerate radmohajer from `https://radmohajer.ir/sitemap.xml` if needed.
