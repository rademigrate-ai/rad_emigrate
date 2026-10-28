# Antigravity / Grok AI Contract

Grok branch: `feat/grok-ai-assistant-complete-20261028`  
Antigravity UI: `feat/antigravity-user-ai-ui-complete-20261028`

## Ownership
- Antigravity: Flutter UI worktree `rad_antigravity_user_ai`
- Grok: AI backend worktree `rad_grok_ai_assistant_20261028`

Do not overwrite each other's active worktrees.

## Flutter contract v1
- Header `x-rad-contract-version: 1` routes to `copilot.ts`.
- Body `web_search`: `auto` | `on` | `off`
- Response fields: `reply`, `evidence_state`, `citations`, `web_citations`, `web_search_status`, `intent`, `quota`
- `evidence_state=not_applicable` for general questions
- Immigration remains fail-closed without verified claims

## Admin actions
- `onboard_provider` with `base_url` + `api_key`
- `sync_catalogues`
- `test_provider` / `discover_models`

## Client helpers on this branch
- `AiRequest.webSearchMode`
- `AdminAiConfigRepository.onboardProviderTwoField` / `syncAllCatalogues`
- `UserAiProfileRepository` (requires profile migration applied)

## Security
- API keys never returned to client
- SSRF checks on Base URL
- No voice UI in this release
