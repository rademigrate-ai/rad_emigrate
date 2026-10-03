# RAD EMIGRATE — PROJECT 07 AUDIT AND HARDENING

**Status: Project 07 code and clean-schema validation pass. Production readiness remains unverified.**

Audit baseline: 2026-10-03, repository `rademigrate-ai/rad_emigrate`, initial `main` SHA `f3ec28e6f3a4f98c7461ed4852dea78531a6346b`, Supabase RAD project `inshddthftkhcdosoqcn` in `eu-west-1`. Database engine version: `17.11.0.002`.

## Verified

### Repository and architecture

- Main was unprotected and no GitHub Actions workflow existed at the starting SHA. A CI workflow has now been added on this branch for pull requests and pushes to main.
- Existing architecture is Flutter, Riverpod, GoRouter, feature-first layers, repositories, data sources, and Supabase. Source inspection found no direct Supabase calls in feature presentation files.
- The current tree includes generated `graphify-out` caches/reports and a nested `graphify-8` tool tree. Their ownership/purpose was not established; they were not removed.
- A static scan of tracked source/config for common service-role, secret, JWT, database URL, and API-key patterns returned no matching file paths. This is heuristic and does not prove secret absence.
- The legacy Project 06 statement about there being no PR branch was corrected with a dated follow-up. PR #1 remains closed without merge and its branch/document remain available.

### Live Supabase

- Five public tables exist: `profiles`, `applications`, `documents`, `ai_sessions`, `ai_session_messages`. Each has RLS enabled. The live policies are owner-scoped: 17 policies across these tables.
- The auth signup trigger `auth.on_auth_user_created` exists. `public.handle_new_user()` is SECURITY DEFINER with `search_path = ''`; execute is denied to `anon` and `authenticated`.
- The `documents` Storage bucket is private. Its live configuration now limits files to 10 MiB and PDF/JPEG/PNG. Storage RLS policies scope read/write/delete paths to the authenticated user. Client validation also checks the same content types and byte limit; `.jpg` and `.jpeg` map to `image/jpeg`.
- After applying the bucket restriction migration, Security Advisor returned zero findings.
- Performance Advisor reported ten informational unused indexes. The tables were empty at inspection time; indexes remain because they support owner filters, relationships, or RLS.
- No Edge Functions were listed.
- The only live Supabase change in this task was applying bucket upload restrictions under version `20261003102347`. No tables, users, or Storage objects were changed.

## Migration reconciliation

At the starting SHA the repository tracked nine migrations (`001`–`009`) while RAD's live ledger had 16 timestamped records. The repository now has ten migration files after adding the paired live bucket restriction migration; the live ledger now has 17 records.

The mismatch comes from missing historical migration source and missing core-schema creation SQL in the repository. Some final effects correspond to the current numbered scripts, but the exact original boundaries for all live-only entries cannot be recovered from ledger names. No production history was renamed, fabricated, or repaired.

For clean projects, this branch adds:

- `supabase/bootstrap/clean_schema.sql`: guarded current-schema bootstrap; it aborts if RAD tables already exist.
- `scripts/verify_clean_schema.sh`: starts a local Supabase stack without automatically replaying the legacy migrations, applies the guarded bootstrap, then applies the tracked SQL files in order and checks tables, RLS, policies, signup trigger, and bucket settings.
- `docs/SUPABASE_MIGRATION_RECONCILIATION.md`: per-version reconciliation and safe future migration guidance.

The clean replay **passed** in [GitHub Actions run 9](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/37117517484). The Flutter workflow checks also passed on that commit. Do not run `supabase db push`, reset RAD, or alter its historical ledger until a dedicated production migration plan is reviewed.

## Fixed or changed on this branch

- Removed false demo login/OTP credentials from `README.md`.
- Changed GoRouter auth redirects to respect the bootstrap restoration state, send protected deep links through splash while restoration is pending, and preserve a validated in-app destination after restoration.
- Added six unit tests covering cold unauthenticated startup, restored protected deep links, invalid sessions, incomplete profiles, authenticated public-route redirects, and destination validation.
- Added timestamp-matched SQL source for the additive documents bucket restriction applied live.
- Added CI for Flutter format/analyze/tests/web build and isolated clean-schema replay. The actual run is still in progress.

## Unverified and current validation

| Check | Result |
| --- | --- |
| Local Git checkout / working tree | No checkout available; source was read through GitHub API. |
| Local Flutter/Dart commands | Not available in this environment. |
| GitHub Actions CI | Passed on commit `4dfa45f`: format, analyze, tests, web build, clean schema replay, and `git diff --check`. |
| Router regression tests | Six tests passed in GitHub Actions. |
| Clean Supabase replay | Passed in GitHub Actions against an isolated Supabase stack. |
| Flutter format | Passed strict CI check. |
| Flutter analyze | Passed. |
| Flutter tests | Passed. |
| Flutter web build | Passed with placeholder non-production Supabase values. |
| `git diff --check` | Passed. |
| Supabase Security Advisor | Verified after the live bucket configuration change: zero findings. |
| Supabase Performance Advisor | Verified: ten informational unused-index findings; retained with rationale above. |
| Real signup/login, multi-user isolation, web hosting/deployment | Not tested. |

## External configuration and remaining blockers

### REMAINING RELEASE BLOCKERS

- RAD's deployed migration history still lacks a one-to-one checked-in source history. The clean bootstrap makes a new project reproducible, but does not make `supabase db push` safe against the existing RAD project.

### EXTERNAL CONFIGURATION

- `main` remains unprotected. Enable required CI checks and prevent force-push/deletion using the repository's intended governance after the workflow has a successful run.
- Production Supabase redirect URLs, hosting environment values, real account flows, and multi-user/storage isolation require the live hosting/account setup and were not changed here.

### FUTURE PRODUCT WORK

AI provider integration, the RAD knowledge base, OCR/document intelligence, admin/operations, client workflows, and observability remain outside Project 07. See `docs/REMAINING_PRODUCT_ROADMAP.md`.

## Production readiness

**Not fully verified.** Live database security and Storage settings were checked, and code plus clean reconstruction passed CI. Real user flows, hosting configuration, and production deployment remain unverified.
