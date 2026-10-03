# RAD EMIGRATE — PROJECT 07 AUDIT AND HARDENING

**Status: Project 07 hardening, CI, and clean schema comparison passed. Production readiness remains unverified.**

Audit baseline: 2026-10-03, repository `rademigrate-ai/rad_emigrate`, initial `main` SHA `f3ec28e6f3a4f98c7461ed4852dea78531a6346b`, Supabase RAD project `inshddthftkhcdosoqcn` in `eu-west-1`. Database engine version: `17.11.0.002`. Main later advanced to `fb5e323` when PR #3 merged; this branch incorporates that history.

## Verified

### Repository and architecture

- Main was unprotected and no GitHub Actions workflow existed at the starting SHA. CI is now configured for pull requests and main pushes; all three jobs passed on the audit branch.
- Existing architecture is Flutter, Riverpod, GoRouter, feature-first layers, repositories, data sources, and Supabase. Source inspection found no direct Supabase calls in feature presentation files.
- The current tree includes generated `graphify-out` caches/reports and a nested `graphify-8` tool tree. Their ownership/purpose was not established; they were not removed.
- The path-only keyword scan surfaced historical documentation, expected password form/source fields, the nested graphify tool/cache, and the Android template TODO. The outdated demo credentials/fallback instructions were corrected. The high-risk credential scan found no service-role key assignment, Supabase secret key, JWT-like token, cloud access key, or private-key block. CI prints filenames only and now fails on a match or scan error.
- PR #1 remains closed without merge; its branch/document remain available. PR #3 merged during this audit; its Supabase-backed session bootstrap and database-backed profile completion restoration are included in the current branch.

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
- `scripts/verify_clean_schema.sh`: starts a local Supabase stack without automatically replaying legacy migrations, applies the guarded bootstrap and tracked SQL files, checks table/column/key/index/function/trigger/RLS/policy/bucket counts, and compares a deterministic structural fingerprint against the live intended schema.
- `docs/SUPABASE_MIGRATION_RECONCILIATION.md`: per-version reconciliation and safe future migration guidance.

The expanded clean replay and structural fingerprint comparison **passed** in [GitHub Actions run 17](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/37119626172), along with Flutter and keyword-scan checks. It verified 5 tables, 32 columns, 5 primary keys, 7 foreign keys, 15 indexes, the hardened signup function and trigger, RLS, 17 public policies, 3 Storage policies, and bucket restrictions. The fingerprint compared column definitions, constraints, index definitions, function source/security, triggers, policy definitions, RLS settings, and bucket config. Run 19 passed again after the high-risk scan was changed to fail closed on matches/errors; the isolated replay and fingerprint passed on that run as well. Do not run `supabase db push`, reset RAD, or alter its historical ledger until a dedicated production migration plan is reviewed.

## Fixed or changed on this branch

- Removed false demo login/OTP credentials from `README.md`, `docs/PROJECT01_IMPLEMENTATION.md`, and `docs/development.md`; corrected historical fallback claims in Project 02/04 documentation.
- Changed GoRouter auth redirects to respect bootstrap restoration state, send protected deep links through splash while restoration is pending, and preserve a validated in-app destination after restoration. The current auth bootstrap also restores profile completion from the owner-scoped `profiles` row.
- Changed the login field label to “Email” to match the Supabase email-only sign-in path.
- Added six unit tests covering cold unauthenticated startup, restored protected deep links, invalid sessions, incomplete profiles, authenticated public-route redirects, and destination validation.
- Added timestamp-matched SQL source for the additive documents bucket restriction applied live.
- Added CI for strict Dart format, Flutter analysis/tests/web build, clean schema replay/fingerprint comparison, and tracked-file/high-risk credential scans. High-risk matches and scan errors fail the scan job.

## Unverified and current validation

| Check | Result |
| --- | --- |
| Local Git checkout / working tree | No local checkout is available; source and branch state were handled through GitHub API. All changes are committed, and CI `git diff --check` passed. |
| Local Flutter/Dart commands | Not available in this environment. |
| GitHub Actions CI | Run 19 passed on workflow commit `3d2febd`: strict format, analyze, tests, web build, clean schema replay/fingerprint, fail-closed high-risk scan, keyword scan, and `git diff --check`. |
| Router regression tests | Six tests passed in GitHub Actions. |
| Clean Supabase replay | Expanded assertions and live structural fingerprint comparison passed on runs 17 and 19 against an isolated Supabase stack. |
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

- `main` remains unprotected. Require the `flutter`, `clean-schema`, and `repository-keyword-scan` checks, and prevent force-push/deletion using the repository's intended governance.
- Production Supabase redirect URLs, hosting environment values, real account flows, and multi-user/storage isolation require the live hosting/account setup and were not changed here.
- Android release configuration still uses the placeholder application ID `com.example.rad_emigrate` and debug signing. Set the production package ID and release signing through the owner's release process before distributing an Android build.
- A production web host must serve the Flutter SPA entry point (`index.html`) for direct GoRouter paths; no production hosting configuration was found or changed.

### FUTURE PRODUCT WORK

AI provider integration, the RAD knowledge base, OCR/document intelligence, admin/operations, client workflows, and observability remain outside Project 07. See `docs/REMAINING_PRODUCT_ROADMAP.md`.

## Production readiness

**Not fully verified.** Live database security and Storage settings were checked; code, Flutter validation, keyword scans, and clean schema equivalence passed CI. Real user flows, hosting configuration, and production deployment remain unverified.
