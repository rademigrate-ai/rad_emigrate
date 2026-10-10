# Stage 2 Local Acceptance Execution — 2026-10-10

## Decision

**STAGE 2 LOCAL GO**

All locally executable Stage 2 acceptance gates passed on 2026-10-10 against the preserved isolated local Supabase stack. This is a local engineering decision only. It is not staging or production authorization, and no deployment, production write, migration operation, commit, push, merge, or branch creation was performed.

## 1. Tested source and environment

- Repository: `rademigrate-ai/rad_emigrate`
- Branch: `handoff/codex-stage1-stage2-20261010`
- HEAD: `271e43e7bc67bc6b1a87b2bdb4db72813ebb78a6`
- Working tree: intentionally dirty; all inherited changes were preserved
- Flutter: `3.47.6` stable
- Dart: `3.13.5`
- Python: `3.14.7`
- Supabase CLI: `2.119.0`
- Deno: `2.5.4`
- Database target: isolated loopback project `rad_emigrate_current_clean_20261010`
- Local API: loopback only (`127.0.0.1:54321`)

The final release Web bundle contains the loopback Supabase origin and no hosted `*.supabase.co` origin. SHA-256 of `build/web/main.dart.js`:

`3805DA5FE54E6829CEF3832DE52B1C7579F408A778026DC1B7AB7529ED23A9F9`

## 2. Complete working-tree change inventory

Tracked modifications present at final acceptance:

| Path | Classification | Purpose/status |
|---|---|---|
| `lib/features/documents/data/datasources/document_remote_datasource.dart` | Functional fix | Requires the owner-scoped document delete to return exactly one row; otherwise raises `document_delete_failed`. Verified by real browser/API/Storage deletion E2E. |
| `scripts/verify_stage2_browser_e2e.py` | Acceptance harness improvement | Adds reliable Flutter Web input focus/key/blur handling and retention assertions, Flutter-aware RTL layout evidence, safe Unicode failure output, and separates the authoritative document upload/delete diagnostic from the broad route suite. |
| `supabase/config.toml` | Local acceptance configuration | Adds loopback Auth site URL and reset-password redirect for disposable local recovery verification only. |

Untracked items preserved from the continued worktree:

| Path | Classification | Purpose/status |
|---|---|---|
| `.freebuff/project-id` | Local tool state | Preserved; not product source. |
| `.work/targeted_consultation_e2e.py` | Focused diagnostic | Used to prove real Flutter semantic input retention and Consultation submission. |
| `.work/tools/npm-cache/**` | Generated local cache | Supabase/Deno tooling cache; not product source. |
| `scripts/diag_document_upload_delete_e2e.py` | Focused acceptance harness | Authoritative document upload/delete, database, Storage, cross-user RLS, and cleanup evidence. |
| `scripts/diag_password_recovery_e2e.py` | Focused diagnostic | Preserved from prior work; not required for the final run because recovery passed in the complete browser suite. |
| `scripts/diag_timezone_asset_e2e.py` | Closed diagnostic | Preserved historical timezone-asset investigation; not rerun. |
| `supabase/.branches/_current_branch` | Local Supabase state | Preserved; not product source. |
| ` include Stage 1 report and browser E2E dependencies` | Historical ANSI diff capture | Inspected. It is not an unapplied Grok/RTL patch; its substantive Stage 1 changes already exist in tracked files. Preserved unchanged. |
| `STAGE2_LOCAL_ACCEPTANCE_EXECUTION_20261010.md` | Final evidence report | This report. |

Ignored/generated final evidence:

- `build/stage2-browser-e2e-final-20261010/**`
- `build/stage2-document-e2e-final-20261010/**`
- `build/web/**`

`git diff --check` passed. The only message was Git's informational LF-to-CRLF working-copy warning for the browser verifier; no whitespace error was reported.

## 3. Consultation root cause and fix

### Diagnosis

The application does not recreate the Consultation controllers during rebuilds. `ConsultationPage` owns `late final` topic and message `TextEditingController` instances created once in `initState` and disposed in `dispose`. Browser inspection found exactly one Flutter semantic `<input aria-label="Topic">` and one `<textarea aria-label="Message">`.

The failure was automation-only: direct Playwright `fill()`/synthetic semantic-node interaction did not reliably reproduce the focus, key, blur, and commit lifecycle that Flutter Web expects. A focus transition could therefore leave a semantic backing element without the value retained by Flutter.

### Smallest fix

The browser verifier now:

1. focuses each Flutter semantic field;
2. sends real sequential key events with `press_sequentially`;
3. sends `Tab` and waits briefly for Flutter to commit the edit;
4. asserts both `input_value()` values before submission;
5. keeps the original submission and persisted-history assertions.

No application validation, authentication, authorization, or required field was bypassed or weakened.

### Evidence

Command (executed with the isolated Supabase worktree as the process directory):

```text
py C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\.work\targeted_consultation_e2e.py
```

Result: **PASS**, exit `0`.

- Topic retained: `Focused consultation topic`
- Message retained: `Disposable local browser acceptance request.`
- Submission confirmation rendered
- The Consultation appeared in the user's history
- The complete browser suite independently passed its randomized Consultation journey

Conclusion: there is no reproduced user-visible controller/state defect in the tested build. The defect was in browser automation interaction semantics.

## 4. Document upload/delete evidence

Exact command (from the isolated Supabase worktree):

```text
py C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\scripts\diag_document_upload_delete_e2e.py --web-root C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\build\web --artifacts C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\build\stage2-document-e2e-final-20261010 --port 3019
```

Result: **PASS**, exit `0`, 17 recorded steps, cleanup `true`.

Verified:

- real Flutter browser sign-in and session persistence;
- file chooser and upload UI;
- owner-correct document row with `uploaded` status;
- owner-prefixed private Storage path;
- Storage object returned HTTP `200` while present;
- a second authenticated user received HTTP `200` with zero rows for the owner's document, proving RLS denial without data leakage;
- UI deletion completed;
- final database row state was absent;
- final Storage object state was absent;
- diagnostic artifact cleanup passed;
- both diagnostic Auth identities were removed.

Evidence:

- JSON: `build/stage2-document-e2e-final-20261010/diag-document-upload-delete.json`
- Screenshot: `build/stage2-document-e2e-final-20261010/diag-document-upload-delete.png`
- JSON SHA-256: `8AAFFF0E1412FABB6926BCD13970C143423AFC027BDB640054716778C77D63F1`

## 5. RTL and localization evidence

Focused command:

```text
flutter test test/acceptance/rtl_directionality_test.dart test/core/locale_theme_controller_test.dart test/core/localization_completeness_test.dart test/core/persian_typography_test.dart
```

Result: **PASS**, exit `0`, 16 tests passed.

Coverage includes:

- Persian maps to Flutter `TextDirection.rtl` and English to `TextDirection.ltr`;
- the app root applies `Directionality` from the locale controller;
- directional navigation icons flip for RTL;
- primary pages avoid fixed-direction chevrons;
- English/Persian localization keys are complete and distinct;
- Persian typography uses RTL/Vazirmatn across 390 px and 1440 px, light and dark.

The complete browser suite used application geometry rather than inherited HTML CSS direction. Switching from English to Persian moved the login form by **670 px**, captured `public-desktop/login-fa-rtl.png`, then switched back to English and asserted the original layout returned within 10 px.

## 6. Complete Stage 2 browser acceptance

Exact command (from the isolated Supabase worktree):

```text
py C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\scripts\verify_stage2_browser_e2e.py --web-root C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\build\web --artifacts C:\Users\Mehrshad\Desktop\Projects\rad_emigrate\build\stage2-browser-e2e-final-20261010 --port 3018
```

Result: **PASS**, exit `0`.

- Artifact directory: `build/stage2-browser-e2e-final-20261010`
- Manifest: `build/stage2-browser-e2e-final-20261010/manifest.json`
- Manifest result: `PASS`
- Route captures: `40`
- PNG captures: `40`
- Manifest SHA-256: `70991677D2EACB7203C11D8177346325ACB19289C085B8ADD8504027EE4DFAE0`

Passed scenarios:

- public login, registration, forgot-password, reset-password, and OTP routes;
- invalid protected-route session handling and failed-login error state;
- password login, logout, session refresh, and local Mailpit recovery/password rotation;
- all ordinary-user routes on desktop and mobile;
- unknown-route sanitization back to the dashboard;
- document cross-user/error state and retry recovery;
- Consultation topic/message retention, submission, and history;
- ordinary-user denial from Admin;
- Admin desktop and mobile routes;
- Super Admin desktop routes and Super Admin-only AI configuration;
- Persian RTL layout and English layout restoration;
- browser console/page/request failure monitoring.

## 7. Flutter, Edge, and security quality gates

| Gate | Exact command (or equivalent isolated-worktree invocation) | Result |
|---|---|---|
| Dart formatting | `dart format --output=none --set-exit-if-changed lib test` | **PASS**, exit `0`; 214 files, 0 changed |
| Flutter analyze | `flutter analyze` | **PASS**, exit `0`; no issues |
| Focused auth/document/AI safety tests | `flutter test test/acceptance/no_ai_research_auto_publish_test.dart test/acceptance/stage2_review_feed_publish_test.dart test/acceptance/auth_redirect_acceptance_test.dart test/acceptance/document_acceptance_test.dart test/acceptance/schema_policy_acceptance_test.dart test/acceptance/admin_role_authorization_test.dart test/documents/document_storage_test.dart test/documents/document_cache_isolation_test.dart test/auth/auth_repository_impl_test.dart test/auth/password_recovery_session_test.dart` | **PASS**, exit `0`; 54 tests |
| Full Flutter suite | `flutter test` | **PASS**, exit `0`; 263 passed, 4 explicitly skipped external/deferred gates |
| Release Web build | `flutter build web --release` with loopback `APP_ENV`, `SUPABASE_URL`, and publishable-key defines resolved from the isolated stack | **PASS**, exit `0`; `build/web` produced |
| Deno format | `npx.cmd --yes deno@2.5.4 fmt --check supabase/functions` | **PASS**, exit `0`; 13 files |
| Deno lint | `npx.cmd --yes deno@2.5.4 lint supabase/functions` | **PASS**, exit `0`; 12 files |
| Edge tests | `npx.cmd --yes deno@2.5.4 test --allow-env --allow-net supabase/functions/tests` | **PASS**, exit `0`; 31 passed, 0 failed |
| SQL security regression | `security_regression.sql` through local `psql -v ON_ERROR_STOP=1` | **PASS**, exit `0` |
| Research/no-auto-publish SQL regression | `corrective_routing_research.sql` through local `psql -v ON_ERROR_STOP=1` | **PASS**, exit `0`; transaction rolled back |
| Real Auth/RLS/Storage regression | `python scripts/verify_local_auth_isolation.py` against the isolated stack | **PASS**, exit `0` |
| Supabase security advisor | `npx.cmd --yes supabase@2.119.0 db advisors --local --type security --level error --fail-on error` | **PASS**, exit `0`; no issues |
| Git whitespace check | `git diff --check` | **PASS**, exit `0` |

The real Auth/security regression proved two-user isolation for profiles, applications, documents, OCR, consultations, entitlements, and Storage; password login/logout; explicit human-only Feed publication; and atomic authenticated AI quota reservation with exactly 50 accepted, 16 rejected, and 50 unique persisted reservations.

The release build printed Flutter's non-fatal WebAssembly dry-run compatibility warnings for `flutter_secure_storage_web` (`dart:html`/`dart:js_util`). The requested JavaScript Web release build completed successfully; WebAssembly output was not a Stage 2 requirement.

The four full-suite skips are explicitly marked external/deferred and were not counted as passes: owner-verified Super Admin bootstrap, optional broader ARB localization architecture, legal/retention-dependent data export/account deletion UI, and production DNS/Auth redirects/app signing.

## 8. Cleanup verification

The final browser and document harnesses executed their cleanup paths. A final isolated-database audit also found four exact `stage2-browser-*@example.test` identities and one orphaned Stage 2 Storage object left by older interrupted/focused diagnostic runs. Only those exact disposable fixtures were removed.

Final verified counts:

```text
remaining_stage2_auth=0
remaining_stage2_documents=0
remaining_stage2_consultations=0
remaining_stage2_storage=0
```

No non-test rows or non-test Storage objects were deleted.

## 9. Remaining blockers and scope boundary

There is **no remaining locally executable Stage 2 blocker**.

Not executed, by explicit scope restriction:

- staging or production deployment;
- hosted Supabase writes or migrations;
- production Auth/redirect/domain changes;
- DNS, signing, app-store, or production-provider operations;
- commits, pushes, pull requests, merges, or branch changes.

Those are release/owner prerequisites, not failures of the local Stage 2 acceptance gates reported here.

## 10. Final decision

**LOCAL GO — Stage 2 is green for the tested uncommitted worktree at HEAD `271e43e7bc67bc6b1a87b2bdb4db72813ebb78a6`.**

This decision is supported by a passing targeted Consultation journey, Flutter-aware RTL evidence, a 40-artifact complete browser suite, an independent real document/Storage/RLS deletion suite, all Flutter quality gates, Edge tests, SQL security/no-auto-publish regressions, real two-user Auth isolation, a clean security advisor, and zero remaining disposable Stage 2 records in the isolated stack.
