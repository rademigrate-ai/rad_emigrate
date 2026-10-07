# Per-site inventory JSONL

Generated Stage 3 closeout inventories (compact keys: u=url, l=lang, c=category, t=terminal_state, f=freshness, p=policy, i=ingestion, s=source).

- `radmohajer_ir.jsonl` — 740 rows from live sitemap
- `radvisa_com.jsonl` — 296 rows from Wayback CDX (live unreachable)
- `digivisa_ir.jsonl` — 239 rows from Wayback CDX (live unreachable)

Full gzip bundle: `docs/RAD_CONTENT_INVENTORY.jsonl.gz` (when present in branch).
Regenerate radmohajer from `https://radmohajer.ir/sitemap.xml` if needed.
