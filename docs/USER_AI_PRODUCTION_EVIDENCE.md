# User AI Production Evidence — Stage 4 Closeout

## Deployed baseline (pre-fix)

- Edge Function: `ai-orchestrator`
- Status: ACTIVE
- Version: **7**
- Source SHA at deploy: `8a2897a3c2d137bd9a0c947ec521d476405006b3`
- Project: `inshddthftkhcdosoqcn`

## Production defect found during post-deploy smoke

### Symptom
Anonymous and authenticated chat requests returned:

```json
{"error":"routing_unavailable","request_id":null}
HTTP 503
```

Guest quota path was reached (not `guest_quota_unavailable`), then routing failed.

### Root cause
Handler called `get_ai_runtime_chain_versioned` with incorrect parameter names:

| Handler (v7 / SHA 8a2897a) | Production RPC |
|----------------------------|----------------|
| `p_require_structured_output` | `p_require_structured` |
| `p_min_context_window` | `p_min_context` |

PostgREST rejects the RPC call → handler catch → `routing_unavailable`.

### Fix committed

- Commit: `589cf63a4c6ca3e4e284336c366ac3cd463d41b5`
- Change: align RPC body to `p_require_structured` + `p_min_context`
- Branch: `feature/stage4-user-ai-finalization`

### Required action

**Redeploy** `ai-orchestrator` from HEAD ≥ `589cf63` to become Edge version 8+.
Do not treat version 7 as production-complete.

## Smoke results against version 7 (before fix deploy)

| Test | Result |
|------|--------|
| Edge ACTIVE version 7 | PASS |
| Anonymous request reaches function | PASS |
| Guest quota consumed before routing | PASS |
| Provider routing / inference | FAIL — routing_unavailable |
| English/Persian answers | BLOCKED |
| Citations | BLOCKED |
| No-knowledge path | BLOCKED |
| Multi-turn | BLOCKED |
| Q1–Q5 / Q6 | BLOCKED (routing) |
| feed_items after smoke | 0 (unchanged) |

## Knowledge corpus (supporting)

- `knowledge_items` with `review_status=approved`: 7
- Stage 3 inventory is not used for grounding

## Stage 3

Remains OPEN / INCOMPLETE — external dependency.
