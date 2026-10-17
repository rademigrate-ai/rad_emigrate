# RAD E2E & QA Evidence — 2026-10-18

**Main:** `2739567cc0c228c0b190da177266de9df811be5a` · **Flutter PR #68:** `f616078a56eb8159030911d38b66b1e961504dba` (open Draft, not merged) · **Production Render:** `449cd3b6cb0a0b53e852015ad4a3648bd817ad65` (old, auto-deploy OFF). No production writes or live user credentials were used.

## Verified actual test results

| Scope | Reproduction | Observed outcome | Caveat |
|---|---|---|---|
| Current `main` | [GitHub Actions #39072163776](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39072163776) | **PASS, 7/7 jobs**: Flutter, web, Android, routing, keyword scan, isolated clean-schema, migration reconstruction | Production is not running this SHA. |
| Flutter owned PR #68 | [PR CI #39071835147](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39071835147) | **SUCCESS** on PR HEAD | Not an integrated or deployed release; agent branch untouched. |
| Independent test-only merge of PR #68 into latest main | `git merge --no-commit --no-ff origin/feat/antigravity-flutter-e2e-completion`, in `rad_integrate68_readonly_20261018` | **PASS**: no merge conflicts or unmerged paths; `git diff --cached --check` exit 0 | Merge simulation on a separate *uncommitted* worktree, no shared branch merged. |
| Flutter analyzer on combined candidate | `flutter analyze --no-pub` in isolated merged worktree | **PASS**: zero issues (20.2s) | Static analyzer is not runtime E2E. |
| Complete Flutter tests on combined candidate | `flutter test --no-pub --reporter compact` | **PASS: 515/515**. `ci_merge_tests.log` ended in `All tests passed!` | Mostly unit/widget/mock provider; no actual signed-in Production tests. |
| Human Feed security | [PR #67 CI #39071925202](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39071925202) | **PASS 7/7** including rollback-only synthetic DB review→publish and unauthorized direct Feed INSERT tests | Production trigger is not deployed. |
| Migration reconciliation safeguard | Merged PR #65/#66, migration-reconstruction tests | **PASS** for intentionally failing `NO_GO` checks | A safe stop guard is **not** a successfully reconciled live DB. |

## Reviewed Flutter PR #68 (agent-owned)

14 new tests across four files: `auth_forms_resilience_test.dart` (5), `consultation_form_flow_test.dart` (4), `visa_navigation_presentation_test.dart` (3), `feed_flow_resilience_test.dart` (2). Changes cover RTL navigation arrows, Auth form errors and back routes, consultation duplicate-submit prevention, Feed refresh on empty/error and bookmark guard, and Visa search/empty-state/navigation. These are valuable regressions, **not a complete real-world E2E suite**.

PR #68 was initially reported `mergeable=false` by GitHub, but the isolated code merge trial on the newer main succeeded. That discrepancy may reflect mergeability recalculation or branch restrictions; it does not grant authority to force-merge. The combined local tree has not been committed into a single CI-tested HEAD.

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
