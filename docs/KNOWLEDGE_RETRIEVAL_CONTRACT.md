# Knowledge Retrieval Contract (Stage 4 interface)

## RPC: `retrieve_knowledge(p_query, p_locale, p_destination_code, p_program_slug, p_limit)`

**Grants:** `anon`, `authenticated`, `service_role` (read-only approved knowledge).

### Input

- `p_query` text — free-text topic
- `p_locale` `fa`|`en` (default `en`)
- `p_destination_code` optional
- `p_program_slug` optional
- `p_limit` 1–20 (default 8)

### Output JSON

Citation-ready ranked results with claims, citations, source authority, open_conflicts, rank_score, retrieved_at.

Ranking: FTS relevance + locale match + destination/program + inverse authority_priority + approved status.

## Orchestrator integration

`ai-orchestrator` `loadGrounding` calls `rpc/retrieve_knowledge` first; falls back to approved `knowledge_items` select only if the RPC fails.
