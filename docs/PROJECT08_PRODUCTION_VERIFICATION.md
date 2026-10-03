# RAD EMIGRATE — PROJECT 08 PRODUCTION VERIFICATION

**Status at audit close: ENGINEERING COMPLETE — EXTERNAL RELEASE ACTIONS REMAIN.** This report separates isolated integration results from the unverified live production acceptance steps.

Audit date: 2026-10-03. The production Supabase project is RAD, ref `inshddthftkhcdosoqcn`, region `eu-west-1`, PostgreSQL `17.11.0.002`. GitHub repository: `rademigrate-ai/rad_emigrate`.

## Environment

- **VERIFIED** — Supabase reports RAD as `ACTIVE_HEALTHY`.
- **VERIFIED** — The connected GitHub API sees PR #2 open, mergeable, and in draft; its base is current `main`.
- **VERIFIED** — The current workspace has no Git checkout. A local branch, worktree status, tags, local diff, and direct Flutter/Android commands cannot be reported from this workspace.
- **UNVERIFIED** — No production application URL or hosting provider could be identified from repository configuration. No production deployment was performed.

## Git baseline

- **VERIFIED** — Project 07 began from `main` SHA `f3ec28e6f3a4f98c7461ed4852dea78531a6346b`.
- **VERIFIED** — Current `main` SHA observed at the start of Project 08 synchronization: `fb5e3233438d69b7562f20209314a868f150a45a`.
- **VERIFIED** — PR #2 was based on that current `main`; the API reported mergeable with no conflict indicator. No rebase/merge was needed.
- **VERIFIED** — PR #2 remains a draft and is not merged. No release tag was created.
- **UNVERIFIED** — Git status, fetch/prune, local log, and local tag state; the workspace is not a checkout.
- **BLOCKED EXTERNALLY** — Branch protection and repository ruleset reads returned HTTP 403. GitHub reports the integration cannot access branch protection and this private repository needs an eligible GitHub plan for rulesets. The connected tools expose GET access here, not a ruleset write operation.

## Auth E2E

- **VERIFIED (isolated local stack only)** — The Project 08 CI integration creates two random, confirmed users in the disposable local Supabase stack, obtains separate Auth-issued JWTs, tests password login and invalid-password rejection, and tests logout refresh-token revocation. The stack is stopped with `supabase stop --no-backup`; no production users or credentials are created.
- **UNVERIFIED (RAD production)** — Real signup, password login, logout, session restoration after app restart, redirect behavior, malformed signup, weak-password policy, duplicate-account responses, and invalid/expired production sessions.
- **UNVERIFIED** — Production email confirmation/OTP settings and inbox delivery. The app code calls Supabase email/password signup, routes to a six-digit email verification screen, and verifies with the Supabase Dart email OTP type. The connected Supabase management tools do not expose the Auth provider, confirmation, OTP, session, or redirect settings; no production test inbox is available through this session.
- **FIXED** — Added a resend confirmation-code action backed by Supabase Auth `resend(type: signup)`; controller regression tests ensure the pending signup state survives success and failure.

## Profile E2E

- **VERIFIED (isolated local stack only)** — Admin-created test users trigger profile bootstrap; User A reads and updates its profile; User B gets no row and cannot update A's profile. The integration is executed with distinct authenticated JWTs.
- **UNVERIFIED (RAD production)** — Profile bootstrap/persistence and cross-user behavior have not been exercised with live RAD accounts. The production `profiles` table had zero rows at inspection time.
- **VERIFIED by live structure only** — `profiles` has RLS enabled, an owner policy, and the auth signup trigger. This structural evidence is not counted as a production cross-user test.

## Applications E2E

- **VERIFIED (isolated local stack only)** — User A creates, reads, and updates an application; User B cannot read or update it using a separate JWT.
- **UNVERIFIED (RAD production)** — Production application CRUD and two-user isolation were not run. The production `applications` table had zero rows at inspection time.
- **VERIFIED by policy inventory only** — The production application policies scope select/insert/update to `auth.uid() = user_id`. No application delete grant/policy was present, so deletion is not treated as a supported app action.

## Documents E2E

- **VERIFIED (isolated local stack only)** — The CI integration creates a metadata row owned by User A and verifies User B receives no row.
- **UNVERIFIED (RAD production)** — Production document metadata CRUD and cross-user isolation were not executed.

## Cross-user isolation

- **VERIFIED (isolated local stack only)** — The two-user integration uses real Supabase Auth-created JWTs against the local PostgREST/Storage APIs. It checks profiles, applications, document metadata, AI sessions/messages, and Storage ownership.
- **VERIFIED by inspection only (RAD production)** — All five application tables have RLS enabled. The live policy definitions use owner IDs and relationship checks; Storage policies restrict object paths to the authenticated UUID and enforce MIME/size metadata.
- **UNVERIFIED (RAD production)** — No two production JWTs were available; no claim of live cross-user isolation is made.

## AI persistence

- **VERIFIED (isolated local stack only)** — User A creates an AI session and message; User B cannot read them or attach a message to A's session.
- **UNVERIFIED (RAD production)** — Production session/message persistence and ownership tests were not run.
- **VERIFIED** — The AI provider remains unavailable pending the approved RAD Knowledge Base/provider; no alternate AI vendor or fabricated immigration guidance was added.

## Web verification

- **VERIFIED** — The standard Flutter web build passes in CI with placeholder, non-production Supabase values. This is a build check, not a production configuration build.
- **UNVERIFIED** — Browser smoke tests, responsive sizes, signup/OTP, login/logout, dashboard flows, console/network review, and protected-route refresh on a deployed host.
- **UNVERIFIED** — No hosting provider configuration (Firebase, Vercel, Netlify, Cloudflare Pages, GitHub Pages, or another provider) or production app domain is present in the repository root.
- **UNVERIFIED** — Production SPA fallback and Supabase Auth redirect URL configuration. A host must serve Flutter's `index.html` for direct GoRouter paths; the production domain must be selected before narrow redirect URLs can be configured.
- **VERIFIED by code inspection** — Flutter reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (with legacy anon-key fallback) as compile-time values. A publishable/anon key is browser-safe; no service-role key is referenced by the Flutter runtime.
- **BLOCKED EXTERNALLY** — Production URL and publishable key are not supplied as build secrets/configuration in this repository/session. No production build or deployment was attempted.

## Supabase Auth configuration

- **UNVERIFIED** — Site URL, allowed redirect URLs, confirmation toggle, email OTP expiry/length/rate settings, password requirements, and token/session settings. The Supabase connector offers project/schema/SQL/advisor operations but no Auth settings endpoint.
- **FIXED** — The client flow represents pending signup separately (no authenticated session is fabricated) and includes a resend control.
- **EXTERNAL ACTION** — Verify the RAD Auth settings in the Supabase Dashboard, configure only the owner-selected production callback URLs, and test against a dedicated inbox/account pair.

## Storage verification

- **VERIFIED** — A fresh read of RAD shows bucket `documents` remains private, with a 10 MiB cap and allowed MIME types `application/pdf`, `image/jpeg`, and `image/png`.
- **VERIFIED by live policy inventory** — Three Storage policies scope read/upload/delete object paths to the first path segment matching `auth.uid()`; upload policy also checks permitted MIME metadata and size from 1 byte through 10 MiB.
- **VERIFIED (isolated local stack only)** — CI exercises PDF/JPEG/PNG upload, owner read/signed URL/delete, rejection of unsupported MIME, empty and over-limit content, and User B's read/sign/upload/overwrite/delete attempts against User A's object.
- **UNVERIFIED (RAD production)** — No live objects, upload/download/delete, or two-user Storage attacks were attempted; the production bucket contained no test artifacts created by this task.
- **FIXED** — No Storage production changes were made during Project 08.

## Android readiness

- **FIXED** — Added `android.permission.INTERNET` to the main manifest (debug/profile previously had it but release did not) and set the app label to “RAD Emigrate”.
- **FIXED** — Removed debug-key signing from the release build. Release packaging now requires owner-provided `RAD_RELEASE_STORE_FILE`, `RAD_RELEASE_STORE_PASSWORD`, `RAD_RELEASE_KEY_ALIAS`, and `RAD_RELEASE_KEY_PASSWORD`; these values are not committed.
- **FIXED** — Added `android/key.properties`, `*.jks`, and `*.keystore` to `.gitignore`.
- **VERIFIED** — CI builds the Android debug APK and checks that a release build is refused without signing values.
- **UNVERIFIED / EXTERNAL ACTION** — Package ID remains `com.example.rad_emigrate`; the owner must select the permanent unique ID before publishing. No signing secret/keystore was available, so no production release APK/AAB was created.
- **VERIFIED by manifest inspection** — No app-specific cleartext-network opt-in is set. SDK versions inherit from the Flutter Gradle plugin and were not pinned or overridden here.

## Hosting readiness

- **UNVERIFIED** — No production host or domain is configured. No hosting platform was introduced and nothing was deployed.
- **FIXED** — Provider-neutral deployment requirements are documented in the roadmap: inject browser-safe Supabase values, configure SPA fallback to `index.html`, then add only the production host to Supabase redirect allowlists.
- **EXTERNAL ACTION** — The owner must select/identify the production host and domain before browser smoke tests or redirect configuration can be completed.

## Dependency and platform check

- **VERIFIED** — CI runs `flutter pub outdated` and reports the current package status; no broad dependency upgrades are included in this production-gate PR.
- **UNVERIFIED** — Review of the exact outdated dependency output is pending the current Project 08 CI run.
- **UNVERIFIED** — The latest web build log is being checked for the existing Flutter secure-storage WebAssembly notice. Standard web build remains the acceptance target; no Wasm-only build was introduced.

## CI

- **VERIFIED** — Final Project 08 CI is running on the current PR implementation commit. Required jobs are `flutter`, `clean-schema`, and `repository-keyword-scan`.
- **VERIFIED** — The Flutter job runs dependency resolution, dependency report, strict Dart format, analyze, tests, standard web build, Android debug APK build, expected release-signing guard, and `git diff --check`.
- **VERIFIED** — The clean-schema job rebuilds the isolated schema and then runs the two-user local Auth/RLS/Storage integration before stopping the disposable stack.
- **VERIFIED** — The credential scan fails closed on a high-risk match or scan error and prints filenames only.
- **UNVERIFIED** — This document must be updated with the final run ID and each job result after the in-progress run finishes.

## Branch protection

- **VERIFIED** — The GitHub API reports PR #2 based on the observed current `main` SHA.
- **BLOCKED EXTERNALLY** — Branch protection read returned “Resource not accessible by integration”; ruleset read returned that an eligible GitHub plan is required for this private repo. No setting was changed.
- **EXTERNAL ACTION** — Enable pull-request review, require `flutter`, `clean-schema`, and `repository-keyword-scan`, and block force-push/deletion through an owner-accessible plan/settings flow.

## Test data cleanup

- **VERIFIED** — No production users, rows, Storage objects, or schema were created/changed for acceptance tests.
- **VERIFIED (CI design)** — Local test users, rows, and objects exist only in the disposable Supabase stack; the CI cleanup runs `supabase stop --no-backup` even after failures.
- **VERIFIED** — Prior Project 07 bucket restriction is the only reported live Supabase change in this work; Project 08 made no production database changes.

## Remaining external actions

- Select a production web host/domain, provide its browser-safe Supabase URL/key, configure SPA fallback and exact Auth redirect allowlist.
- Arrange two dedicated test inboxes/accounts and run real RAD signup, confirmation/OTP, login/logout/reload, profile/application persistence, and live cross-user RLS/Storage tests.
- Select the permanent Android package ID and provide release signing values via the owner's secure release process.
- Configure branch protection/rulesets using an eligible GitHub plan/settings permission.
- Review and merge PR #2 through the repository's owner workflow. Do not merge, publish, or tag before that review.
- Reconcile the historical live migration ledger only through a separate reviewed production migration plan; do not reset or rewrite RAD's ledger.

## Projects 09–16

See `docs/REMAINING_PRODUCT_ROADMAP.md` for objectives, dependencies, deliverables, and completion gates. Project 08 remains an external-release gate; it is not marked fully complete.
