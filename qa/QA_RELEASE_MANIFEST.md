# RAD Emigrate Independent QA Release Manifest

Captured: 2026-10-18. This is an independent QA handoff, not owner acceptance or a release approval.

## Baseline and authority

- Master Issue #57: [RAD Emigrate one master task](https://github.com/rademigrate-ai/rad_emigrate/issues/57). Its checklist requires code, tests, negative tests, evidence, and owner acceptance where applicable; green local CI does not complete the product gates.
- Acceptance authority: [47-task master ledger](../docs/RAD_47_TASK_MASTER_LEDGER.md). It records **3/47 VERIFIED_PASS**, 15 IN_PROGRESS, 19 BLOCKED, and 10 IMPLEMENTED. Release remains **NO-GO**. No gate status was upgraded by this work.
- QA branch: `qa/copilot-independent-quality-release`, created in the requested `rad_copilot_quality_release` worktree from local integration HEAD `1bac02140cf9498bc1a60d6f167dda707ec760cf`.
- Read-only source heads inspected: Grok `7f15cba01472ce6c7d9008e408f449b5d0ce477b`; Antigravity `19f46189ff9106c615b5c11c10f1c11749aca3fd`. No source-agent worktree was modified. The latest Antigravity case controller is not present in the integrated base, so its issue is delivered as an isolated failing handoff test.

## Regression coverage map

The complete integrated Flutter suite ran successfully, including these existing deterministic slices:

| Scenario | Existing test evidence | Boundary |
|---|---|---|
| Cross-user isolation | `test/applications/application_local_isolation_test.dart`, `test/profile/immigration_profile_local_isolation_test.dart`, `test/applications/case_lifecycle_test.dart` | Local persistence and pure-domain checks; no live two-user Supabase/Storage E2E. The case checklist legacy-key gap below is reproduced separately. |
| Login, logout, and session changes | `test/core/session_manager_test.dart`, `test/profile/profile_session_regression_test.dart`, `test/auth/profile_name_session_test.dart`, `test/features/guest_mode/guest_mode_flow_test.dart` | Simulated sessions/repositories; no real mailbox or authenticated account switch against a deployed service. |
| Protected navigation | `test/core/app_router_protected_routes_matrix_test.dart` | Route matrix runs locally; deployed-release browser E2E remains open. |
| Immigration profile persistence | `test/profile/immigration_profile_local_isolation_test.dart`, `test/profile/profile_repository_test.dart` | Deterministic preference-backed persistence and isolation. |
| Case lifecycle, checklist, reminders | `test/applications/case_lifecycle_test.dart`, `test/applications/case_checklist_test.dart`, `test/domain_integration/cross_module_pipeline_test.dart` | Domain transitions and reminder metadata; controller-specific legacy migration is not in the integrated base. |
| University catalog and evidence | `test/visa/university_scholarship_test.dart`, `test/knowledge/evidence_registry_test.dart` | Catalog freshness/missing-source states and evidence approval gates. No live university source verification or human editorial acceptance. |
| Fail-closed evidence and recommendations | `test/knowledge/evidence_registry_test.dart`, `test/knowledge/knowledge_integrity_test.dart`, `test/profile/recommendation_engine_test.dart` | Pending, stale, conflicting, and insufficient evidence paths are deterministic; no legal eligibility guarantee is asserted. |
| Document ownership and failures | `test/acceptance/document_acceptance_test.dart`, `test/core/document_private_preview_path_test.dart`, `test/documents/document_storage_test.dart`, `test/documents/document_signed_url_cache_test.dart` | Ownership paths/cache behavior are local; actual private Storage upload/download, MIME/size rejection, and two-user denial remain external E2E. |
| Research → draft → editorial approval → Feed | `test/acceptance/stage2_review_feed_publish_test.dart`, `test/acceptance/no_ai_research_auto_publish_test.dart`, `test/acceptance/stage1_ai_research_completion_test.dart` | Static migration/source and no-auto-publish guards pass. No disposable-DB human approval/publication replay was run in this QA worktree; production drafts still require human review. |
| Network failures and duplicate submissions | `test/auth/password_reset_recovery_test.dart`, `test/features/feed/feed_flow_resilience_test.dart`, `test/features/admin/admin_consultations_lifecycle_test.dart`, `test/core/supabase/rpc_compat_test.dart` | Simulated failures/retry guards; provider/mail/production network behavior is not claimed. |
| RTL, accessibility, responsive layouts | `test/acceptance/rtl_directionality_test.dart`, `test/core/phoenix_navigation_layout_test.dart`, `test/core/app_shell_navigation_test.dart`, `test/features/dashboard/dashboard_page_test.dart`, `test/visual_qa_smoke_test.dart` | Widget/semantics and viewport checks; real browser, assistive technology, and physical-device sign-off remain open. |

## Reproduced defect and owner handoff

**Severity: high, cross-user local data disclosure on account switch.** In Antigravity HEAD `19f46189ff9106c615b5c11c10f1c11749aca3fd`, `lib/features/applications/presentation/providers/case_tracker_controller.dart` reads the user-scoped key first and then falls back to the unscoped `rad_case_checklist_<caseId>` key. When the scoped key is absent, a different account opening the same case ID loads data stored under that legacy key. The existing `test/features/applications/case_tracker_flow_test.dart` isolation test starts with empty preferences and therefore does not catch this migration path.

Reproducer: [isolated failing test](antigravity_case_tracker_legacy_isolation_test.dart). Run from `rad_copilot_quality_release` with:

```powershell
flutter test qa/handoffs/antigravity_case_tracker_legacy_isolation_test.dart
```

Observed result: **FAIL, expected the other account not to see the marker; actual value was `true`**. The test seeds only synthetic SharedPreferences data and imports the current Antigravity controller read-only. It is outside `test/`, so the default suite remains green. The failing assertion is intentionally retained until the owning code is fixed.

**Exact handoff to Antigravity:**

- `lib/features/applications/presentation/providers/case_tracker_controller.dart`: remove the unscoped fallback for authenticated users, or migrate only with independently verifiable ownership. An unowned legacy key must fail closed; the key contains no owner identity to authorize migration.
- `test/features/applications/case_tracker_flow_test.dart`: add a regression that seeds `rad_case_checklist_<caseId>` with User A's private item, opens the same case as User B with no scoped value, and asserts no disclosure. Keep the current same-user persistence and scoped-key precedence checks.
- Integration owner: Freebuff. Do not cherry-pick or merge the source branch based only on this QA finding; require the owner regression to pass and re-run integration gates.

No production/controller fix was applied because this file belongs to Antigravity and is absent from the QA branch base. No other reproducible production defect was established in this run.

## Release verification evidence

| Check | Observed result |
|---|---|
| `flutter test` | **PASS: 657 tests**, full integrated suite. |
| `flutter analyze` | Completed with no errors/warnings; **2 informational** `depend_on_referenced_packages` notices remain in `test/features/admin/admin_consultations_lifecycle_test.dart` for undeclared `http` imports. |
| `flutter build web --release` | **Exit code 0**. `build/web/index.html` exists (6,014 bytes; local artifact timestamp 2026-10-18). |
| `flutter build appbundle --release` | **BLOCKED by release guard** after 745.8 seconds: required `RAD_ANDROID_APPLICATION_ID` is unset (placeholder application ID rejected). The documented signing variables were not printed; no release artifact/signature is claimed. |
| Performance | Observed full Flutter suite duration: about 7m 04s. Android attempt stopped at the pre-signing guard after 12m 25.8s. No same-machine pre-change benchmark was available, so these are measurements only, **not evidence of a regression or improvement**. No performance claim is made. |

## Remaining acceptance blockers

- The reproduced cross-user case checklist issue requires Antigravity's fix and owner regression, followed by integration verification.
- Actual mailbox-based login/recovery, deployed two-user RLS and private Storage tests, and production-like service calls were not run; no production writes were made.
- Research publication has only static fail-closed guards here; human editorial review and a disposable-database approval-to-publish replay remain required.
- Current university catalog tests establish freshness/unknown-source behavior, not human approval of authoritative listings.
- Real browser/assistive-technology/device matrix, signed owner-configured Android release, iOS signing, backup restore, measured performance baseline, and client handover remain external gates.
- The canonical ledger remains 3/47 VERIFIED_PASS and release NO-GO. No push, PR, issue comment, deployment, or production data operation was performed.