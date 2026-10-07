# Stage 4 Handler Restore

Remote `handler.ts` imports `./handler_providers.ts`.

**Self-contained full handler (Stage 2 adapters + Stage 4 guest quota):**
project artifacts path:
`artifacts/ai-orchestrator-handler-stage4.ts`

**Providers module:**
`artifacts/handler_providers.ts`

Owner actions:
1. Copy self-contained handler to `supabase/functions/ai-orchestrator/handler.ts` OR add `handler_providers.ts` from artifact.
2. `supabase functions deploy ai-orchestrator --project-ref inshddthftkhcdosoqcn`

Verified markers in artifact handler:
- test_provider, discover_models
- openai_compatible, anthropic, gemini
- consume_ai_guest_quota, consume_ai_daily_quota
- loadGrounding + hasApprovedEvidence
