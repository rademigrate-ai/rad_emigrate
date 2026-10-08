# Knowledge Ingestion Contract

## RPC: `promote_knowledge_from_evidence`

**Callers:** `service_role`, `admin`, `super_admin` (and migration superuser).

**Required:**

| Arg | Meaning |
|-----|---------|
| `p_slug` | Stable item identity |
| `p_language_code` | `fa` \| `en` |
| `p_title` / `p_summary` | Item metadata |
| `p_claim_text` | Atomic factual proposition (≥8 chars) |
| `p_snapshot_id` | Existing evidence snapshot UUID |

**Optional:** excerpt, topic, jurisdiction, destination_code, program_slug, confidence, `p_approve`.

**Behavior:**

1. Validates snapshot exists.
2. Upserts `knowledge_items` by slug; versions on material change.
3. Upserts current claim by `claim_key = md5(lower(trim(claim_text)))`.
4. Upserts citation `(claim_id, snapshot_id)`.
5. Returns JSON ids + created flags.
6. Idempotent on repeat with same slug+claim_key+snapshot.
7. Does **not** write Feed.

## Research path

`ingest_research_snapshot` creates snapshots + findings + review drafts only. Promotion to knowledge is a separate admin/service step.
