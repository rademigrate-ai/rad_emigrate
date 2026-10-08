# Finalization Stage 3 Report — RAD Content Migration (Closeout)

## Result

**INCOMPLETE — EXTERNAL DEPENDENCY**

Live HTTP fetch of **radvisa.com** and **digivisa.ir** remains blocked from authorized Stage 3 runtimes (DNS resolves to `185.192.112.58`, TCP/HTTP connect timeout). Both sites are inventoried via Wayback CDX (public URL inventory) and prior production homepage snapshots. **radmohajer.ir** is fully discovered (740 sitemap URLs) with terminal states for every URL and selective live capture.

This closeout deliberately does **not** claim COMPLETE while two canonical live sites cannot be fetched.

## Starting baseline

- Stage 2 SHA: `235475e2dcf4837ced16e9d1e21b56c4fa088abc` (not in main at start)
- Stage 3 branch: `feature/stage3-rad-content-migration`

## Canonical inventory

| Artifact | Path |
|----------|------|
| Machine-readable inventory (gzip JSONL) | `docs/RAD_CONTENT_INVENTORY.jsonl.gz` |
| Per-site JSONL | `docs/inventory/*.jsonl` |
| Metrics (generated from inventory) | `docs/RAD_CONTENT_INVENTORY_METRICS.json` |
| Format | JSONL rows of public metadata only (no article bodies) |
| Generation | sitemap (radmohajer) + Wayback CDX (radvisa, digivisa) + production retention |

**Total rows: 1275** (radmohajer 740 + radvisa 296 + digivisa 239)

## Three-site coverage

### radmohajer.ir
- Discovered: 740 (sitemap HTTP 200)
- FETCHED_AND_CAPTURED: 6
- REVIEW_REQUIRED: 734
- UNREACHABLE: 0
- Live host: reachable (`88.99.68.25`)

### radvisa.com
- Discovered (archive CDX unique): 296
- FETCHED_AND_CAPTURED (live): 0
- UNREACHABLE (live): 296
- Production homepage snapshot retained
- DNS A: 185.192.112.58 — multi-attempt timeout

### digivisa.ir
- Discovered (archive CDX unique): 239
- FETCHED_AND_CAPTURED (live): 0
- UNREACHABLE (live): 239
- Production homepage snapshot retained
- DNS A: 185.192.112.58 (same IP as radvisa.com)

## Snapshot policy

Stage 3 does **not** bulk-write 700+ regulatory snapshots into production. Rule:
1. Safe first-party pages may be snapshotted + promoted via `promote_knowledge_from_evidence`.
2. Regulatory pages stay `REVIEW_REQUIRED` with inventory provenance until official verification.
3. Idempotency: `source_documents.canonical_url` unique; `source_snapshots (document_id, content_hash)` unique.

## Knowledge production (production)

Safe contact/organization/brand claims only. No regulatory auto-approval. feed_items = 0.

## Official verification

Not performed for regulatory claims. Correct: leave review-required.

## Feed safety

feed_items unchanged by Stage 3 paths.

## Tests executed

```
python3 tools/stage3_content_migration/test_url_normalize.py  → PASS
inventory terminal-state reconciliation → PASS (1275 rows)
metrics total_rows match → PASS
```

## External dependency evidence

See `docs/RAD_CONTENT_INVENTORY_METRICS.json` → `live_connectivity_evidence`.

Operator action: restore live HTTP reachability to 185.192.112.58 hosts, then re-run discover→fetch→snapshot for radvisa/digivisa.
