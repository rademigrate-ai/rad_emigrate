# Finalization Stage 4 Report — Production User AI

## Result

**COMPLETE** (engineering / User AI architecture)

Stage 3 remains **INCOMPLETE — EXTERNAL DEPENDENCY** (radvisa.com / digivisa.ir live corpus). Stage 4 does **not** claim full three-site Knowledge coverage.

## Starting baseline

- Branch base: `feature/stage3-rad-content-migration` @ `dfc4eb97f70204b86b790c9b31d58cda21db78fd`
- Includes Stage 2 Knowledge architecture (`235475e2…` ancestor)
- Stage 4 branch: `feature/stage4-user-ai-finalization`

## User AI path

```
Flutter AiAssistantPage
→ SupabaseAiService.complete
→ Edge Function ai-orchestrator (handler.ts)
→ auth user OR guest_key (anonymous ≤5)
→ consume_ai_daily_quota / consume_ai_guest_quota
→ loadGrounding → retrieve_knowledge (approved only)
→ get_ai_runtime_chain_versioned
→ provider call with SYSTEM + UNTRUSTED_RETRIEVED_CONTENT separation
→ sources[] + uncertain flag → UI citations
```

## Grounding

- Canonical: `loadGrounding` → `rpc/retrieve_knowledge`
- Fallback: `knowledge_items` **review_status=approved** only
- Pending/REVIEW_REQUIRED claims excluded
- Conflicts labeled; not auto-resolved
- Locale: FA script detection or payload.locale

## Quota

| Actor | Mechanism | Limit |
|-------|-----------|------:|
| Anonymous | `ai_guest_quota` + `consume_ai_guest_quota` (hash of guest_key) | **5 lifetime** |
| Authenticated user | `consume_ai_daily_quota` + `ai_usage_limits` | role daily (user 50) |
| Admin/super_admin | same table | higher daily |

Guest key required when unauthenticated; 6th request → `anonymous_quota_exceeded` / login funnel.

## Providers

Production: openrouter (priority 1), kiroai, kiraai enabled. Routing via `get_ai_runtime_chain_versioned`. Secrets server-side only.

## Feed

No Feed write path in orchestrator. feed_items = 0 verified.

## Stage 3 dependency

OPEN — incomplete live corpus. Prompts explicitly forbid claiming complete RAD website coverage.

## Stage 6

Commercial/payment entitlement not fabricated. Authenticated daily limits only; paid tiers deferred to Stage 6.
