# RAD EMIGRATE — PROJECT 08 PRODUCTION VERIFICATION

**Status: ENGINEERING COMPLETE — EXTERNAL RELEASE ACTIONS REMAIN.** Production hosting, live account acceptance, and release identity/signing still require owner inputs.

Verification date: 2026-10-03. Repository: `rademigrate-ai/rad_emigrate`. RAD Supabase project: `inshddthftkhcdosoqcn`, region `eu-west-1`.

## Git and CI

- **VERIFIED** — PR #2 merged into `main`; merge commit and current main SHA at verification: `feb1e0af3ceff43b0678c41666b79effefcb89f3`.
- **VERIFIED** — Post-merge GitHub Actions run #42 succeeded: Flutter, clean-schema, and repository-keyword-scan jobs all passed.
- **VERIFIED** — CI covered strict formatting, Flutter analysis/tests, web build, Android debug APK, release-signing guard, `git diff --check`, clean schema replay/fingerprint, two-user local Auth/RLS/Storage integration, and credential scan.
- **VERIFIED** — The finalization cleanup removes the temporary local Storage logging trigger and its workflow steps. The ordinary local integration test remains in CI.
- **UNVERIFIED** — There is no local Git checkout in the execution workspace, so local `git status` cannot be reported. Remote `main` and PR state were verified through GitHub.

## Real Auth E2E

- **VERIFIED (disposable local Supabase)** — CI creates two random, confirmed users, obtains distinct Auth JWTs, tests sign-in, invalid-password rejection, and refresh-token revocation.
- **UNVERIFIED (production RAD)** — Real signup, email confirmation/OTP delivery, login/logout, session restoration, redirect handling, and invalid/expired production sessions were not exercised.
- **FIXED** — The signup flow has a resend-confirmation action backed by Supabase Auth and regression coverage for preserving pending signup state.

## Profile, applications, documents, and AI

- **VERIFIED (disposable local Supabase)** — The two-JWT integration checks profile bootstrap/update and cross-user denial; application create/read/update and cross-user denial; document metadata ownership; and AI session/message ownership.
- **VERIFIED (disposable local Supabase)** — Storage PDF/JPEG/PNG upload, owner read/sign/delete, invalid content rejection, and cross-user read/sign/upload/overwrite/delete checks passed in CI run #42.
- **UNVERIFIED (production RAD)** — No production user JWTs or test inboxes were available, so live persistence and two-user database/Storage isolation are not claimed.
- **UNVERIFIED (production RAD)** — Browser/device journeys, email delivery, and session restoration on a deployed application were not run.

## Supabase production

- **VERIFIED (read-only inspection)** — RLS is enabled on all five application tables: `profiles`, `applications`, `documents`, `ai_sessions`, and `ai_session_messages`.
- **VERIFIED (read-only inspection)** — The `documents` bucket is private, capped at 10 MiB, and allows PDF, JPEG, and PNG MIME types.
- **VERIFIED (read-only inspection)** — The enabled auth signup trigger invokes the security-definer `handle_new_user` function with an empty configured search path.
- **VERIFIED** — Security Advisor returned zero findings. Performance Advisor reported ten INFO unused-index notices; indexes were retained.
- **VERIFIED** — No production users, rows, Storage objects, policies, auth settings, or migrations were changed during this continuation.
- **UNVERIFIED** — Production Auth confirmation/OTP/session settings and live Storage behavior with two real production JWTs.
- **EXTERNAL ACTION REQUIRED** — The production migration ledger has 17 entries and differs from checked-in historical SQL. Keep reconciliation within a separately reviewed migration plan; do not reset or rewrite the live ledger.

## Web and Android

- **VERIFIED** — Flutter web build passed in CI using placeholder non-production Supabase values.
- **UNVERIFIED** — No production web host/domain, SPA fallback, or production redirect allowlist has been configured; no deployment or browser smoke test was performed.
- **VERIFIED** — Android debug APK build passed in CI; release packaging correctly fails closed when signing values are absent.
- **EXTERNAL ACTION REQUIRED** — Select the permanent Android application ID (currently `com.example.rad_emigrate`) and supply signing values through the owner's secure release process.

## Branch protection and release actions

- **BLOCKED EXTERNALLY** — Branch protection/ruleset inspection was unavailable to the connected GitHub integration; rulesets require an eligible plan/settings permission.
- **EXTERNAL ACTION REQUIRED** — Choose a production web host/domain, inject browser-safe Supabase configuration, configure SPA fallback and exact Auth redirect URLs, and test against dedicated inboxes/accounts.
- **EXTERNAL ACTION REQUIRED** — Configure branch protection to require `flutter`, `clean-schema`, and `repository-keyword-scan` and block force-push/deletion.

## Bugs fixed during Project 08

- Added the resend email confirmation-code flow and controller regression tests.
- Added Android Internet permission and RAD Emigrate app label; removed debug-key release signing and added keystore ignores.
- Added disposable two-user acceptance coverage for Auth, RLS, Storage, AI ownership, and supported document restrictions.

## Test data cleanup

- **VERIFIED** — CI uses random local-only test users and fixtures, then stops the disposable Supabase stack with `supabase stop --no-backup`.
- **VERIFIED** — No production acceptance-test data or objects were created.

## Projects 09–16

Roadmap entries remain in `docs/REMAINING_PRODUCT_ROADMAP.md`; Project 08 is engineering complete and no later project work started in this task.
