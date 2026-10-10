# Stage 4 Orchestrator Layout

Canonical modules on branch:

- `handler.ts` — chat, guest/auth quota, admin test_provider/discover_models,
  grounding orchestration
- `handler_providers.ts` — OpenAI-compatible/OpenRouter, Anthropic, Gemini
  adapters, discover, health
- `knowledge_grounding.ts` — approved-only retrieve_knowledge grounding
- `index.ts` — Deno.serve entry

Do not use local artifacts as source of truth.
