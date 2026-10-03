# PROJECT 07 — Full Audit and Hardening (Audit Snapshot)

**Status: INCOMPLETE — production readiness is not verified.**

This snapshot records independently checked repository and live Supabase facts from 2026-10-03. The full Definition of Done was not completed because this environment has no Flutter, Dart, or PostgreSQL CLI, and Git clone access to this private repository is unavailable. Source files were read through the connected GitHub API. Findings marked “code review” were not runtime reproduced.

## 1. Baseline

- Repository: `rademigrate-ai/rad_emigrate`
- Starting branch: `main`
- Starting commit: `f3ec28e6f3a4f98c7461ed4852dea78531a6346b` (`chore: complete Project 06 production audit and hardening`)
- Audit date: 2026-10-03
- Declared Dart SDK constraint: `^3.13.4` in `pubspec.yaml`. Installed Flutter/Dart versions could not be checked because neither executable is available.
- Supabase: RAD, project `inshddthftkhcdosoqcn`, region `eu-west-1` (region supplied in the task).
- The local workspace did not contain a Git checkout or local changes; repository contents were inspected through GitHub API reads.

## 2. Areas inspected

Repository metadata, main and feature branches, tags, open PRs, commit history, repository tree, documentation for Projects 01–06, dependency/configuration files, app bootstrap, routing, authentication, profile/application/document data sources, storage service, AI session repository, tests, tracked Supabase migrations, live public tables and policies, Storage bucket/policies, signup trigger privileges, Supabase Security and Performance Advisors, Edge Function inventory, and repository secret-pattern matches.

Architecture scan found no direct Supabase calls in feature presentation files. The expected Flutter/Riverpod/GoRouter/repository structure is present. This was a source inspection, not a complete dependency graph or execution audit.

## 3. Findings

### Bugs

| Severity | Finding | Evidence and status |
| --- | --- | --- |
| High | The tracked migration history does not reproduce the live database history. | The repository has nine migrations named `001`–`009`. The live ledger has 16 timestamp-versioned migrations, including the initial core schema, signup/storage setup, backend indexes, table-grant hardening, and other versions without corresponding tracked migration files. A clean database cannot be reconstructed from the tracked migration directory alone. Confirmed by comparing the GitHub tree with the live Supabase migration ledger. No migration was applied during this audit. |
| Medium | Protected deep links can be redirected to login before session restoration completes. | Code review: `app_router.dart` treats a missing authenticated session as unauthenticated for protected routes; the bootstrap future restores the session asynchronously. A direct request to a protected route can therefore lose its destination during startup. This needs a router regression test and runtime reproduction. |
| Medium | README still advertises fake login and OTP credentials. | `README.md` said any email/password and OTP `123456` work, contradicting the Supabase-only authentication implementation and Project 06 report. This documentation defect was corrected on the audit branch. |

### Security findings

- Security Advisor returned no findings at audit time.
- All five application tables have RLS enabled and owner-scoped policies for their supported operations. `force row level security` is false; privileged service roles bypass RLS by design.
- The signup trigger function is `SECURITY DEFINER`, has an empty search path, and denies EXECUTE to `anon` and `authenticated`.
- Storage bucket `documents` is private. SELECT/INSERT/DELETE policies scope paths to the authenticated user's ID. The INSERT policy also checks MIME type and size metadata.
- Static repository scans for common service-role, secret, JWT, database URL, and API-key patterns returned no matching file paths. This is a heuristic scan, not a complete secret scanner or proof of secret absence.
- The bucket's live `file_size_limit` and `allowed_mime_types` are unset. Client validation and an RLS policy provide checks, but the bucket-level restrictions recommended by Supabase are not configured. This remains an external configuration hardening item.
- No Edge Functions were listed.
- No migration was applied, so post-migration advisor results do not apply.

## 4. Supabase schema and migration result

Live public tables: `profiles`, `applications`, `documents`, `ai_sessions`, and `ai_session_messages`. All were reported with RLS enabled and zero rows at inspection time. Storage contains the private `documents` bucket. The signup trigger and current policies were queried directly.

The repository's nine SQL files and the project's 16 live migration records have not been reconciled. Do not reset, repair, or deploy migrations until a canonical migration history is recovered and tested against a fresh database.

## 5. Code and documentation changes

- Removed the obsolete demo credential block from `README.md` and replaced it with accurate Supabase account/session guidance.
- No Dart or SQL code was changed because the repository could not be checked out and Flutter/Dart execution was unavailable.
- No Supabase migrations were applied.

## 6. Tests and validation

| Check | Result |
| --- | --- |
| `dart format` | Not run — Dart unavailable |
| `flutter analyze` | Not run — Flutter unavailable |
| `flutter test` | Not run — Flutter unavailable |
| `flutter build web` | Not run — Flutter unavailable |
| `git diff --check` | Not run — no local Git checkout |
| Fresh migration replay | Not run — migration source/ledger mismatch |
| Security Advisor | No findings returned |
| Performance Advisor | Ten informational unused-index findings; tables had zero rows, so index usage is not representative. No index was removed. |
| Secret scan | Heuristic filename-only scan found no matches |
| Re-audit after fixes | Not complete |

There are no GitHub Actions workflows in the repository tree. The `main` branch was reported as unprotected. No CI result exists to substitute for local Flutter validation.

## 7. Remaining limitations

### BUGS

1. High: tracked migrations do not match the live ledger and omit schema/bootstrap history needed for a reproducible fresh database.
2. Medium: protected deep-link routing may lose the requested route during asynchronous session restoration; add a regression test and verify with Flutter.
3. Low: generated `graphify-out` caches/reports and a nested `graphify-8` tool tree are committed. Their intended status must be checked before removal.

### EXTERNAL CONFIGURATION

- Configure bucket-level 10 MB and PDF/JPEG/PNG restrictions for `documents`, then verify the resulting settings live.
- Add CI for format, analyze, tests, and web build; protect `main` with required checks.
- Complete production-hosting environment, redirect URL, real-auth, multi-user isolation, Storage, and deployment smoke tests.
- Recover/reconcile the canonical Supabase migration history before making schema changes.

### FUTURE PRODUCT WORK

AI provider integration, OCR/document intelligence, visa catalog governance, knowledge-base ingestion, operations/admin, client workflow, and privacy-safe observability remain outside this audit snapshot.

## 8. Production readiness

**Not verified.** Live RLS, Storage privacy, trigger hardening, and current advisor output were inspected. Flutter build/test behavior, migration replay, real-user flows, multi-user isolation, and hosting configuration remain unverified. No claim of production readiness is made.

## Open PR review

PR #1, `feat: complete project 05 production launch hardening`, was closed without merge after comparison showed its only unique change was a Project 05 document and the branch was six commits behind `main`. The PR discussion records the reason; its branch and historical document remain intact.
