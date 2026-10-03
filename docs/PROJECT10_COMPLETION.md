# Project 10 — RAD Knowledge Base and Research Ingestion

Project 10 introduces a review-first knowledge model with immutable source snapshots, claims, citations, conflicts, drafts, version history, bounded research jobs, and three allowlisted RAD sources.

The `research-sync` Edge Function processes one queued job at a time, fetches no more than the configured source limit, hashes normalized content, deduplicates unchanged snapshots, and creates admin-review findings. It never publishes findings automatically. A daily Postgres Cron job enqueues an idempotent RAD sync independently of browsers.

Security is enforced with RLS and trusted roles. Public clients can read only approved knowledge and its cited evidence. Worker configuration and invocation tokens are service-only. No document body, provider key, or user PII is logged.

Validation includes rollback execution against PostgreSQL 17, clean schema replay in CI, RLS checks, Edge Function deployment, and Security Advisor review. Final SHA and CI are recorded in `MASTER_COMPLETION_STATUS.md`.

## Production verification

- Merged implementation SHA: `cd1b37af2d1559f3e563c661dbc7c42eebf4b36d`
- CI runs 53 and 54: all repository scan, clean-schema/Auth/RLS/Storage, Flutter analyze/test, web, Android debug, and release-signing refusal gates passed.
- Live migration and Edge Function version 1 deployed to the RAD Supabase project.
- Bounded production smoke job succeeded in one attempt with 3 snapshots and 3 review findings.
- Two daily cron jobs are active: idempotent enqueue at 03:17 UTC and authenticated worker invocation at 03:27 UTC.
- Supabase Security Advisor has no actionable table/RLS findings. Its remaining warning concerns `pg_net`, a non-relocatable platform extension installed in `public`.
