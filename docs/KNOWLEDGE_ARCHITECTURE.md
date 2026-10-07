# Knowledge Architecture (Stage 2)

## Pipeline

```
research_sources (allowlist)
  → source_documents (canonical URL, authority, locale)
    → source_snapshots (immutable content_hash + normalized_text)
      → research_findings (untrusted, review required)
        → content_drafts (human review / Feed candidates ONLY via publish_content_draft)
      → promote_knowledge_from_evidence (admin/service)
        → knowledge_items (versioned subjects)
          → knowledge_claims (atomic propositions + claim_key)
            → knowledge_citations (claim → snapshot evidence)
          → knowledge_versions (history)
          → knowledge_conflicts (explicit open disagreements)
        → retrieve_knowledge (citation-ready ranking for User AI)
```

## Trust boundary

- Research findings and drafts are **not** trusted knowledge.
- Trusted/retrievable knowledge requires `review_status = approved` on the item and claims with citations.
- `promote_knowledge_from_evidence` requires a real `source_snapshots` row; it cannot invent evidence.
- Approved claims without citations are rejected by trigger.
- Knowledge promotion **never** inserts into `feed_items`. Feed remains exclusive to `publish_content_draft`.

## Source authority

`source_documents.source_authority`: `rad_official` | `government` | `embassy` | `institution` | `other`

Ranking prefers lower `authority_priority` (government=10 … other=50) while still applying relevance, locale, and destination filters.

## Versioning

- `knowledge_items.version` increments on material title/summary change.
- `knowledge_versions` stores JSON snapshots of material changes.
- Claims use `is_current` / `superseded_by` for claim-level history.

## Conflicts

`register_knowledge_conflict` records open conflicts. Retrieval surfaces `open_conflicts` and marks claims `conflicting`. No automatic resolution.

## Freshness

- Snapshot `fetched_at`, item `freshness_checked_at`, `effective_date`.
- Newest timestamp does not always win; authority is ranked explicitly.
