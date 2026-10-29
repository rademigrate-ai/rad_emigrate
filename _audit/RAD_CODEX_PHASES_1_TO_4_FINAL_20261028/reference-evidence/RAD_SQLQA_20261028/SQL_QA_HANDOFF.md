# RAD Emigrate — Independent Local Stage 7 SQL QA
Date: 2026-10-28
Executed via Desktop Commander on the authorized Windows PC.

## VERIFIED PASS
- Docker Desktop / WSL operational; container `supabase_db_rad_emigrate` healthy.
- An **isolated local** PostgreSQL database `rad_chatgpt_stage7_qa_20261028` was created from the existing LOCAL `postgres` database. The original LOCAL database was only read, not migrated.
- Local baseline: 82 `public` tables; baseline migration ledger latest version `20261024140200`.
- Restored matching schema, ownership, key permissions, and local baseline table data into the scratch database. The `pg_cron` extension and cron-specific permissions were excluded because the live container is configured to host pg_cron exclusively in database `postgres`. During **scratch-only** data restore, triggers were disabled/re-enabled for circular foreign keys and human-feed publication guard.
- All 17 repository migrations dated 2026-10-25 through 2026-10-27 were applied **in chronological order to this isolated scratch DB only**, including Stage 7, Stage 7.1 and the Stage 7.2 authority seed.
- Four critical Research RPCs verified present in scratch: `get_structured_article_context`, `propose_structured_research`, `save_research_review`, `save_structured_research_review`.
- `supabase/tests/stage7_research_review.sql`: **PASS, process exit code 0**. Covers synthetic full-page Research review, granular decisions, consistency, idempotency, authorization and publication isolation.
- `supabase/tests/stage71_rich_review.sql`: **PASS, process exit code 0**. Covers rich table/list preservation, lossless edits, rejection, additions/removals, ancestry, evidence, concurrency, locale, authorization and publication.
- The four synthetic Auth fixture user IDs were absent after tests (count **0**), confirming rollback for these fixtures.
- Original local DB still has migration ledger latest `20261024140200` and does not contain the 2 key new Research RPCs. It was not modified by the QA run.
- No hosted Staging writes, no Production access, no main PR merge/push, no repo source edits.

## Evidence
- `stage7_native_sql.log` — PASS and exit code verified.
- `stage71_native_sql.log` — PASS notice and exit code verified.
- `qa_clone.sh` — clone **local** source database to a narrowly named local scratch database. Destructively resets ONLY the named scratch database, never the source.
- `qa_migrations.sh` — applies local repository migration SQL to that scratch database. Do not run against a remote database.

## Scope / important limitations
- This is an **isolated local reconstruction**, NOT an isolated restore of a **hosted Staging backup**.
- This does NOT satisfy the Staging backup/restore safety gate and does NOT authorize hosted imports or migration-history repairs.
- This is native PostgreSQL SQL acceptance with synthetic fixtures. It is NOT the hosted authenticated positive-path Admin Research Assistant E2E.
- Because pg_cron is excluded, this is not proof of every platform-level cron configuration.
- Other agents are working in live Git worktrees; no changes were made to their source files.
- Keep this temporary QA database while other agents may need it. To clean up later ONLY when confirmed unused: `docker exec supabase_db_rad_emigrate dropdb -U postgres rad_chatgpt_stage7_qa_20261028`.

## Immediate handoff
Claude and Antigravity can now retire the **Docker unavailable** blocker for native Stage 7/7.1 SQL validation and cite the logs above. Full-client-demo gates remain pending on hosted Staging backup, authorization to import complete content, and real authenticated Research positive-path E2E after approved writes. Do not conflate these gates.
