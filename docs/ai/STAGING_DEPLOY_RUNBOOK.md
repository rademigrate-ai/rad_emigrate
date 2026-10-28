# Staging AI Deploy Runbook (Grok)

**Branch:** `feat/grok-ai-assistant-complete-20261028`  
**Production:** READ-ONLY without separate authorization  
**Known Staging:** `epolbumcfbohtmgvomki`

## 0. Preflight (required)
1. Confirm no concurrent Codex migration apply on the same project.
2. Snapshot / note current `supabase_migrations.schema_migrations` ledger count.
3. Confirm Edge Function list and current `ai-orchestrator` version.
4. Confirm secrets plan (search keys optional; OCR optional).

## 1. Migrations (additive only)
Apply **only after** owner authorization:

1. `20261028190000_ai_catalogue_sync_eight_hour.sql`
   - Creates `private.ai_catalogue_sync_runs`
   - Schedules `rad-ai-catalogue-sync-8h` at `0 0,8,16 * * *` **if** `pg_cron` exists
   - **Note:** schedule tick ≠ full discovery; Edge `action=sync_catalogues` performs HTTP discovery
2. `20261028200000_user_ai_profile_checklist_reports.sql`
   - `user_ai_profiles`, `user_ai_checklists`, `user_ai_reports` + owner RLS
   - `upsert_user_ai_profile`

Local preflight scripts (disposable DB only):
- `supabase/tests/ai_catalogue_sync_cron_preflight.sql`
- `supabase/tests/user_ai_profile_rls_isolation.sql`

## 2. Edge deploy
Deploy `ai-orchestrator` (and existing `document-intelligence` if unchanged) from this branch HEAD.

### Secrets
| Name | Required | Purpose |
|------|----------|---------|
| Platform Supabase URL/keys | yes | runtime |
| `BRAVE_SEARCH_API_KEY` | recommended | full web search |
| `SERPER_API_KEY` | alternative | full web search |
| Document processor runtime via RPC | for OCR | live document analysis |

Without Brave/Serper: DuckDuckGo Instant Answer only — **not** full web search.

## 3. Post-deploy verification
1. **General chat:** answer without official evidence; `evidence_state=not_applicable`.
2. **Immigration:** no claims → uncertain / insufficient; no invented rules.
3. **web_search=on:** honest `web_search_status`; citations HTTPS-only.
4. **onboard_provider:** Staging Base URL + key; rejects localhost/metadata/credentials-in-URL.
5. **sync_catalogues:** super_admin or service role.
6. **Profile RLS:** user A cannot read user B rows.
7. **Documents:** without OCR config → `no_ocr_provider_configured` (honest).
8. **Cron:** if pg_cron present, `cron.job` has at most one `rad-ai-catalogue-sync-8h`.

## 4. Rollback
- Redeploy previous `ai-orchestrator` version.
- Leave additive tables in place unless empty and authorized to drop.
- Unschedule cron job only if it was newly added and must be reversed.

## 5. Explicit non-actions
- No Production migration apply from this runbook alone.
- No migration-history repair.
- No merge to main without review.
