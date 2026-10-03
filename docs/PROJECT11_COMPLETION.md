# Project 11 — Multi-provider AI and safe key management

Project 11 replaces any client-side provider dependency with the authenticated `ai-orchestrator` Edge Function. Provider credentials are written to Supabase Vault only through a Super Admin RPC; clients can never select or retrieve a key.

The runtime orders enabled providers by priority, skips cooldown entries, caps fallback at three providers, gives each call a 25-second timeout, records safe request/health metadata without prompts or responses, and returns an explicit `ai_temporarily_unavailable` response when no real provider is configured. It never fabricates an answer.

Supported adapters are OpenAI-compatible, Anthropic, and Gemini. Models, capabilities, limits, health and usage are data-driven. Paid credentials remain an owner choice in `EXTERNAL_ACTIONS.md`; the application remains operational with an honest unavailable state until one is configured.

Validation includes rollback migration execution, clean-schema/Auth/RLS/Storage CI, function deployment, unauthorized/no-provider checks, and Supabase advisors. Final evidence is added after merge.

## Production verification

- Merged SHA: `e612b5103d49e798184d6047448bfe4b882f2a08`; CI run 55 passed every repository, clean-schema, Flutter, web, Android and signing gate.
- Live migration applied and `ai-orchestrator` version 1 deployed with JWT verification.
- Production checks confirm 0 enabled providers, 3 role limits, runtime RPC denied to anon/authenticated and granted only to service role.
- No paid credential, fake answer, prompt body, or response body was introduced.
- Security Advisor retains the documented non-relocatable `pg_net` warning and flags the intentional Super-Admin-only SECURITY DEFINER configuration RPC; that RPC performs its own role check, has an empty search path, and never returns the secret.
