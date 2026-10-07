# Finalization Stage 4 Report — Production User AI

## STAGE 4 CLOSEOUT RESULT

**INCOMPLETE** — production Edge version 7 has a proven routing defect; fix is on branch and **requires redeploy**.

## FINAL BRANCH / HEAD

- Branch: `feature/stage4-user-ai-finalization`
- Fix HEAD: `589cf63a4c6ca3e4e284336c366ac3cd463d41b5`
- Prior deploy SHA (v7): `8a2897a3c2d137bd9a0c947ec521d476405006b3`

## Production acceptance (Edge v7)

| # | Test | Result |
|---|------|--------|
| 1 | Authenticated EN | BLOCKED (routing_unavailable) |
| 2 | Authenticated FA | BLOCKED |
| 3 | Approved Knowledge grounding | BLOCKED |
| 4 | Citations | BLOCKED |
| 5 | No-Knowledge uncertainty | BLOCKED |
| 6 | Multi-turn | BLOCKED |
| 7 | Guest Q1–Q5 | BLOCKED after quota path |
| 8 | Guest Q6 login funnel | BLOCKED |
| 9 | Real provider inference | FAIL |
| 10 | Provider fallback | BLOCKED |
| 11 | Served by version 7 | PASS (ACTIVE v7 confirmed) |
| 12 | feed_items unchanged | PASS (0) |

## Defect

Wrong RPC parameter names for `get_ai_runtime_chain_versioned` (see `docs/USER_AI_PRODUCTION_EVIDENCE.md`).

## Redeploy required

```bash
supabase functions deploy ai-orchestrator --project-ref inshddthftkhcdosoqcn
```

From HEAD `589cf63` or later.

## Stage 3

OPEN / INCOMPLETE.

## Stage 5

Not started.
