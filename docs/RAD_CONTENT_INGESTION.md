# RAD Content Ingestion (Stage 3)

## Pipeline

1. Discover (sitemap, robots, nav)
2. Normalize URL (`tools/stage3_content_migration/url_normalize.py`)
3. Classify + freshness + promotion_policy
4. Fetch via SSRF-safe path (`research-sync` / manual Stage 3 runner)
5. Snapshot into `source_documents` + `source_snapshots` (unique on canonical_url and document_id+content_hash)
6. Promote via `promote_knowledge_from_evidence` only under trust policy
7. Never write `feed_items`

## Idempotency

- Documents: unique `canonical_url`
- Snapshots: unique `(document_id, content_hash)`
- Knowledge: claim_key + slug idempotency from Stage 2

## Re-fetch

When digivisa.ir / radvisa.com are reachable, run discovery + fetch and merge into inventory; do not delete prior snapshots.
