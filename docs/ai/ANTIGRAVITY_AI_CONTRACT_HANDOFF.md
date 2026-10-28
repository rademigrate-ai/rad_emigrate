# Antigravity ↔ Grok AI Integration Contract

**Grok branch / HEAD target:** `feat/grok-ai-assistant-complete-20261028`  
**Antigravity UI worktree (read-only inspected):** `rad_antigravity_user_ai` @ `feat/antigravity-user-ai-ui-complete-20261028`

## Ownership
| Area | Owner | Path |
|------|-------|------|
| Flutter UI (chat, history, profile sheet, citations widgets) | Antigravity | `rad_antigravity_user_ai` |
| AI orchestrator, search, routing, admin onboard, SQL | Grok | `rad_grok_ai_assistant_20261028` |

Do **not** overwrite the other agent's worktree or uncommitted files.

## Observed Antigravity UI (uncommitted at inspection time)
- `AiImmigrationProfile` — device SharedPreferences (`ai_profile_<userId>_…`)
- Widgets: history drawer, immigration profile sheet, document chip, adviser handoff, interactive report, markdown view, search progress, message actions
- Profile is **device-local** today; server sync is optional after Staging migration

## Profile field mapping

| Antigravity (device) | Server `user_ai_profiles` | AI context key |
|----------------------|---------------------------|----------------|
| `education` | `education` | `education` |
| `workExperienceYears` | `work_experience` (`"N years"`) | `experience_years` / `work_experience` |
| `languageScore` | `language_level` | `language` / `language_level` |
| `targetCountry` | `preferred_destinations[0]` | `target_country` |
| `estimatedBudget` | `budget_range` | `budget` / `budget_range` |
| `enableAiPersonalization` | `consent_at` set when true | omit context if false |

Grok helper: `lib/features/ai_assistant/domain/ai_profile_contract.dart`

## Chat contract (v1)
Headers: `x-rad-contract-version: 1`, `x-rad-request-key`, `Authorization`

Body extras Grok accepts:
- `web_search`: `auto` | `on` | `off`

Response `data`:
- `reply`, `evidence_state`, `uncertain`, `citations`
- `web_search_status`, `web_citations`, `intent` (when present)
- `quota`

Immigration: fail-closed without verified claims.  
General: `evidence_state=not_applicable`.

## Admin
- `onboard_provider`: Base URL + API Key only
- `sync_catalogues`, `test_provider`, `discover_models`

## Security notes for UI
- Never display or log provider API keys
- Render official `citations` and `web_citations` separately; never invent links
- No voice UI in this release
