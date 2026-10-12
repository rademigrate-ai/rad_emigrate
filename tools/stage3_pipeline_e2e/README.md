# Stage 3 Pipeline E2E (local, disposable)

Validates the intended architecture end-to-end against a **disposable local
PostgreSQL 16** container, applying the **real committed migrations**
(`supabase/migrations/*.sql`) in dependency order — no copies, no paraphrases.

Chain under test:

```
source_documents -> source_snapshots -> research_findings
  -> content_drafts(review) -> human approval -> publish RPC -> Feed
```

## Files

- `00_prelude.sql` — Supabase-shaped stubs (roles, `auth.uid()`/`auth.jwt()`
  via session GUCs, minimal `public.profiles`) so the real migrations apply
  unmodified on plain PostgreSQL.
- `run_pipeline_e2e.sh` — boots the container, applies migrations, runs the
  scenario matrix, prints PASS/FAIL per scenario, exits non-zero on failure.

## Scenarios

| # | Scenario | Expected |
|---|---|---|
| 1 | `ingest_research_snapshot` (service_role) | snapshot + `new` finding + `review`-status draft created atomically; doc hash updated |
| 2 | duplicate ingest (same hash) | returns NULL, no new snapshot/finding/draft — idempotent by document/hash |
| 3 | retry after ambiguous result (same args again) | identical counts — safe to retry |
| 4 | changed content (new hash) | second snapshot + `changed` finding + second draft |
| 5 | invalid evidence (empty text / bad status) | `22023`, zero rows written |
| 6 | anon calls ingest RPC | `42501` forbidden |
| 7 | direct Feed insert (anon, authenticated, service_role) | trigger `42501` for ALL roles |
| 7b | publish RPC without the actor marker (service_role direct) | trigger `42501` |
| 8 | non-admin calls publish RPC | `42501` forbidden |
| 9 | admin publishes unapproved draft | `22023` explicit approval required |
| 10 | admin approves then publishes | feed item + localization created, draft `published`, audit row; publish is idempotent (same feed id on repeat) |
| 11 | interrupted ingest transaction | rollback leaves zero partial rows; retry succeeds |

## Run

```bash
bash tools/stage3_pipeline_e2e/run_pipeline_e2e.sh
```

Requires Docker. Container is disposable (`rad_pipeline_e2e`) and removed on
exit. No production connectivity of any kind.
