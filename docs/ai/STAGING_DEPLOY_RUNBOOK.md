# Staging AI Deploy Runbook

Branch: `feat/grok-ai-assistant-complete-20261028`  
Production: READ-ONLY without separate authorization

## Migrations (after ledger verification)
1. `20261028190000_ai_catalogue_sync_eight_hour.sql`
2. `20261028200000_user_ai_profile_checklist_reports.sql`

A migration file is not a live cron job. Eight-hour sync requires `pg_cron` plus Edge `sync_catalogues` invocation.

## Edge
Deploy `ai-orchestrator` from this branch HEAD.

Optional secrets:
- `BRAVE_SEARCH_API_KEY` (recommended)
- `SERPER_API_KEY` (alternative)

Without those keys, DuckDuckGo Instant Answer is used and is **not** full web search.

Document OCR requires configured `get_document_processor_runtime`.

## Verify
1. General chat answers without official evidence
2. Immigration insufficient when no claims
3. `web_search` modes return honest status
4. `onboard_provider` on Staging only
5. Profile RLS isolation user A vs B
