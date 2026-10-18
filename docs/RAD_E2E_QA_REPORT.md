# RAD E2E & QA Evidence — 2026-10-18

**Main:** `2739567cc0c228c0b190da177266de9df811be5a` · **Flutter PR #68:** `f616078a56eb8159030911d38b66b1e961504dba` (open Draft, not merged) · **Production Render:** `449cd3b6cb0a0b53e852015ad4a3648bd817ad65` (old, auto-deploy OFF). No production writes or live user credentials were used.

## Verified actual test results

| Scope | Reproduction | Observed outcome | Caveat |
|---|---|---|---|
| Current `main` | [GitHub Actions #39072163776](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39072163776) | **PASS, 7/7 jobs**: Flutter, web, Android, routing, keyword scan, isolated clean-schema, migration reconstruction | Production is not running this SHA. |
| Integrated PR #71 (PR #68 + #69 + #70) | [GitHub Actions #39115878394](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39115878394) | **SUCCESS 7/7 jobs** on HEAD `3977712f2e0ac591f9f71dafa67c10950f678ec1` | Integrated PR combining Flutter UX, 47-gate ledger, and CV/SOP editor. |
| Flutter owned PR #68 | [PR CI #39071835147](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39071835147) | **SUCCESS** on PR HEAD | Merged into integration candidate PR #71. |
| Full Flutter Test Suite | `flutter test` across all feature & core suites | **PASS: 546/546 tests** (ran in 2m 29s), `All tests passed!` | Includes route audit matrix (20 tests), CV/SOP (15 tests), auth resilience (5 tests), consultation (4 tests), visa (3 tests), feed (2 tests). |
| Flutter Analyzer | `flutter analyze` in current worktree | **PASS: No issues found!** (ran in 56.0s) | Clean static analysis across all Dart files. |
| Python Verification Suite | `python -m unittest discover -s scripts/tests` | **PASS: 25/25 tests** (ran in 0.571s) | Covers 47-gate ledger integrity, recorded SQL fingerprints, security definer audit, and Stage 10 FK indexes. |
| Password Recovery Redirect | `node scripts/check_password_recovery_redirect.cjs` | **PASS: 8/8 scenarios** | Verifies URL normalization before Flutter bootstrap. |
| Human Feed Security | [PR #67 CI #39071925202](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39071925202) | **PASS 7/7** including rollback-only synthetic DB review→publish and unauthorized direct Feed INSERT tests | Production trigger is not deployed. |
| Migration Reconciliation Safeguard | Merged PR #65/#66, migration-reconstruction tests | **PASS** for intentionally failing `NO_GO` checks | A safe stop guard is **not** a successfully reconciled live DB. |

## Reviewed Flutter UX & Route Audit Matrix

- PR #68 contributed 14 tests across four files: `auth_forms_resilience_test.dart` (5), `consultation_form_flow_test.dart` (4), `visa_navigation_presentation_test.dart` (3), `feed_flow_resilience_test.dart` (2).
- Route audit matrix `app_router_protected_routes_matrix_test.dart` added 20 tests verifying that all 10 protected routes enforce authentication, unauthenticated visitors can explore guest routes, and phishing redirect URLs are safely stripped to `/dashboard`.
- Total client test count: **546 tests PASS** with zero analyzer warnings.

## E8-04 CV/SOP Document Generator Implementation

- `lib/features/documents/domain/document_draft_generator.dart` and `document_draft_page.dart` provide offline bilingual CV/SOP draft assembly, plain-text preview, clipboard copying, and UTF-8 TXT export.
- 15 dedicated tests in `test/documents/` verify strict user-input preservation without hallucinated credentials.
- Integrated into `/documents` app bar with key `open_document_draft`.
- Staged as candidate implementation on PR #71; rich PDF/DOCX and physical-device UAT remain open.

## Required E2E / negative tests not yet accepted

| Feature | Test environment or missing dependency | Concrete acceptance |
|---|---|---|
| Registration/OTP/recovery | Approved test mailbox/OTP service, version-pinned release, synthetic account | Real recovery link changes password; expired token denied; session/redirect preserved. |
| Identity/role security | Two synthetic users + admin, authorized isolated DB/Auth/Storage | Cross-user IDOR, role escalation, signed Storage URL leakage are denied server-side. |
| AI User/Admin | Approved non-production provider keys/limits and vetted source corpus | Real grounded cited answer, Q1–Q5 accepted and Q6 denied, retries/failovers and timeouts measured. |
| Research/Feed | Trained human reviewer, official claims, Stage1 DB in non-production | Finding creates draft not Feed; admin explicitly approves; one audited, idempotent publication. |
| Visa content | RAD + official government/university sources, human editor | Every material immigration step/claim sourced, dated and bilingual; no fabricated fees/outcomes. |
| Web UX | Chrome/Firefox/Safari; 390px/768px/desktop; Persian/English; assistive tech | Form actions, keyboard navigation, focus/RTL, responsive layout, errors, screenshots and signoff. |
| Native | Signed Android/iOS builds and physical device owners | Install, login/deep links, background resume, notifications, storage and device accessibility. |
| Payments | Owner-approved sandbox merchant and plans | Signed webhook, replay/idempotence, success/failure/refund and correct entitlements; no live charges. |
| OCR/Voice | Approved providers, consent and synthetic fixtures | OCR extraction and review, retention/redaction, Voice AI accessibility and multilingual errors. |
| Client delivery | Authorized acceptance party and current deployed release | Client UAT scenarios signed and release/rollback rehearsed. |

## Environment and reporting rules

Local integrated tests ran on the authorized Windows machine using Flutter 3.47.x. iOS/Xcode build and physical-device acceptance were **not** executed. CI Android build is not a signed Android store release. Temporary generated desktop registrant file changes were not staged or shared. No user secrets, Production SQL/Edge/Vault/Render deployments, publication or live payment actions occurred.

**Release status:** NO-GO. Engineering CI green plus 515 widget/unit tests do not replace credentialed E2E, device/store testing, authoritative visa review, verified backup restoration and client signoff.
