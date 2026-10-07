# User AI Production Evidence — Stage 4 Closeout

## Deployed production

| Field | Value |
|-------|--------|
| Edge Function | `ai-orchestrator` |
| Status | ACTIVE |
| Version | **8** |
| Branch HEAD at deploy | `3a36e59f62040d495566ab0853f6bba86b7c2f32` |
| Project | `inshddthftkhcdosoqcn` |
| verify_jwt | true |

## Prior defect (v7) — resolved

Wrong RPC params (`p_require_structured_output` / `p_min_context_window`) caused `routing_unavailable`.
Fixed in `589cf63` and live in version 8.

## Additional production fix (SQL, applied live)

`get_ai_runtime_chain` returned 200+ models with decrypted secrets → oversized payload / empty effective chain.
Applied `LIMIT 8` on ranked results (migration `20261007212000_stage4_limit_ai_runtime_chain.sql`).
Also cleared stale `credential_rejected` / offline health so routing could attempt providers.

## Production acceptance against version 8

| # | Test | Result | Evidence |
|---|------|--------|----------|
| 1 | English AI | **PASS** | HTTP 200, reply_len 695, locale=en |
| 2 | Persian AI | **PASS** | HTTP 200, fa_chars 590, locale=fa |
| 3 | Approved-Knowledge grounding | **PASS** | `has_approved_evidence=true` |
| 4 | Citations | **PASS** | sources_n=5 |
| 5 | No-Knowledge / no fabrication | **PASS** | CRS cutoff refused; points to official sources |
| 6 | Multi-turn | **PASS** | history + follow-up HTTP 200 |
| 7 | Guest Q1–Q5 | **PASS** | five successful chats same guest_key |
| 8 | Guest Q6 → login funnel | **PASS** | HTTP 401 `anonymous_quota_exceeded` count=5 limit=5 |
| 9 | Real provider inference | **PASS** | provider=`kiroai`, models include `cohere/command-a` |
| 10 | Provider fallback | **PARTIAL** | chain ranked; single-provider success (failover=false); multi-fail path not forced |
| 11 | Version 8 | **PASS** | list_edge_functions version=8 ACTIVE |
| 12 | feed_items | **PASS** | 0 before and after smoke |

### Auth note

Full user JWT signup was rate-limited / email-policy blocked in this session. English and Persian production inference were exercised via the **anonymous guest** path, which shares the same chat → grounding → runtime chain → `callProvider` pipeline as authenticated users after identity resolution. Authenticated-only daily quota RPC is present in handler code and was previously unit-tested in SQL.

## Feed safety

`feed_items` count remained **0** after all smoke calls.

## Stage 3

Remains **OPEN / INCOMPLETE**.
