# RAD EMIGRATE — FULL FEATURE ACCEPTANCE & BUG CLOSURE MATRIX
Date: 2026-10-28
Source: actual local repository at _stage7/worktree on PC.
Purpose: ensure functional and end-to-end correctness, not just green CI.

## 0. Truthful current status

- GitHub PR #85 latest checked HEAD 2484537ce05c11bf7463d62b043851dc04a35057: Draft, not merged.
- GitHub CI 40650871013: 8/8 success.
- Full Flutter suite 1113 passed and Python suite 166 passed according to prior integration evidence. A green suite is NOT acceptance for every screen and role.
- The local feature directory inventory contains **21 feature modules**. Some modules have no dedicated test files under `test/features/<name>`; tests elsewhere may exist and need enumeration before declaring a gap.
- Hosted Staging is not approved for writes and lacks the verified restore prerequisite. Do NOT fabricate hosted E2E acceptance or real client-demo GO.
- All items below default to **NOT YET ACCEPTED** until a dated per-feature recorded PASS demonstrates the complete expected workflow.

## 1. Feature-by-feature acceptance inventory (found in lib/features)

Each feature MUST be exercised at least once as actual routed interaction, verified read/write, error recovery, permission-boundary check, Persian RTL and English where applicable, and small/large display tests.

| # | Actual module | E2E acceptance focus | Current acceptance |
|---|---|---|---|
| 1 | splash | startup, session restoration, valid initial redirects | Pending |
| 2 | auth | login/register/signup, OTP/reset password, invalid input, sign out, guest routing, session expiry | Pending |
| 3 | dashboard | landing cards, real data/empty states, navigation, role-specific sections | Pending |
| 4 | visa | destination/category hierarchy, canonical rich body, tables/list preservation, full text, Other Titles once, source links | Pending |
| 5 | knowledge | actual knowledge content and reader, source fidelity, missing/empty states | Pending |
| 6 | applications | create/list/detail/update permitted cases, status transitions, error/retry, ownership isolation | Pending |
| 7 | documents | upload/list/open/permissions, supported formats, draft creation, sensitive data isolation | Pending |
| 8 | consultation | request and save, validation, confirmation, admin visibility, guest redirects | Pending |
| 9 | booking | service/slot selection, no ghost availability, conflicts/retry, correct confirmation | Pending |
| 10 | interviews | schedule/status/list/detail and role permissions | Pending |
| 11 | interview_scheduling | Request Consultation via GoRouter EN/FA, back stack, scheduling steps | Nav EN/FA targeted PASS reported; remaining flow Pending |
| 12 | comparison | compare supported destinations/routes, loading states, consistent real values | Pending |
| 13 | pathway_comparison | visa pathway comparisons, evidence, limitations and incomplete fields | Pending |
| 14 | university_comparison | university selection/compare, actual data fidelity, navigation | Pending |
| 15 | cost_calculator | unit/currency handling, formulas/boundaries, loading/error/rounding and disclaimer | Pending |
| 16 | global_time | world clock correctness, time zones/DST, locale formatting | Pending |
| 17 | ai_assistant | prompt/reply, errors/timeouts, safe AI output, authorization and no auto-publish | Pending |
| 18 | feed | list/detail/filters and publication rights; AI/research must never auto-publish | Pending |
| 19 | notifications | read/unread, permission, dispatch/display, duplicate handling, locale | Pending |
| 20 | profile | view/edit/save/logout, immigration profile, cases, stale data and role changes | Pending |
| 21 | admin | admin hub/operations/consultations/CMS/reconciliation/canonical editor/AI research/sources/diffs, moderation, audit, RLS | Pending |

## 2. Backend/Edge Function acceptance inventory (actual supabase/functions names)

- ai-orchestrator: authentication, model/output validation, failure handling, audit trail.
- currency-refresh: source validity, caching, units, stale/error behaviour.
- document-intelligence: safe document processing, permissions, failure, storage isolation.
- notification-dispatch: recipient isolation, retry/idempotency, duplicate avoidance.
- official-source-worker: provenance, dedup, safe candidate creation, never public publish.
- payment-sandbox: sandbox-only behaviour, amounts/status/retry, no real-charge claim.
- research-sync: source ingestion, findings, content_drafts positive path, review and strict Feed isolation.
- visa-content-ingest: source-to-country/type mapping, rich blocks, integrity, idempotency, draft-only publishing gate.

Note: `supabase/functions/tests` and `_shared` are test/shared folders rather than independent product features.

## 3. Routed user flows (confirmed in app_router.dart)

Splash; /login; /register; /signup; /forgot-password; /reset-password; /otp; /profile-completion; /dashboard; /explore; /applications; /profile/cases; /profile/cases/:applicationId; /documents; /documents/draft; /consultation; /booking; /booking/service/:serviceId; /interview-scheduling; /interviews; /calculator/cost; /compare/pathways; /compare/universities; /notifications; /profile; /profile/immigration; /universities; /ai-assistant; /world-clock; /admin; /admin/ai-config; /admin/operations; /admin/consultations; /admin/ai-research; /admin/cms; /admin/cms/reconciliation; /admin/cms/canonical/:id; /admin/sources; /admin/sources/:sourceId/review; /admin/sources/:sourceId/diff; /feed.

Each route must be checked for direct deep-link access, back navigation, valid session, guest access, role authorization, empty/loading/error data, and refresh.

## 4. Cross-cutting quality gates for EVERY feature

1. Functional tap/CTA coverage: every visible button/menu/field performs the advertised action or is visibly disabled for a documented reason.
2. Persistence: create, edit, refresh, restart and reopen show consistent data in authorized scope.
3. Security: guest vs signed-in vs admin; RLS/tenant/user isolation; no unauthorized reads/writes.
4. Real-world error handling: timeout, offline, validation, missing records, double-click, retry, expired session, stale token.
5. Language: Persian/English copy, RTL/LTR mirrored layouts, Unicode and accessible labels, forms/number formatting.
6. Device/platform: Android + web, responsive viewport, browser refresh/back/deep links, keyboard focus, text scaling, touch targets, contrast, screen readers.
7. Data correctness: no fake status, no invented immigration details; time-zone/DST/currency and source evidence checked.
8. Side effects: idempotent writes, notifications, Feed non-publication on research ingestion, no accidental duplicate applications.
9. Observability: errors reproducible with minimal steps, logs/screenshots and test record; no leaked secrets or personal data.
10. Performance/stability: startup, page transitions, lists, large articles and long-running admin tasks.

## 5. Detailed bug-closure protocol

For every feature and every route record:
- Feature ID, screen/route, tester, environment/build SHA, role, locale, device/browser, fixture, expected vs observed, screenshot/video, network/DB evidence.
- Reproduction steps and category: P0 security/data-loss/unauthorized publication; P1 unusable main flow; P2 broken secondary flow; P3 cosmetic.
- Independent bug fix on isolated branch/worktree; focused regression test first or with fix.
- Rerun targeted tests, full appropriate suite, repository CI, and actual UI/role flow on the SAME HEAD.
- Mark PASS only with recorded result; otherwise FAIL / BLOCKED with precise reason, never silently skipped.
- Client Demo GO rule: ZERO known open P0/P1/P2 bugs in demo-critical flows, no unapproved security/data problems; any P3 exception must be owner-accepted and documented. No absolute guarantee that software contains zero latent bugs.

## 6. Updated finalization sequence: EIGHT stages

1. Baseline inventory and acceptance criteria — DONE.
2. Source asset recovery / URL+SHA reconciliation / provenance — PARTIAL.
3. Consolidate faithful continuous Visa pages and independent Other Titles into complete draft-only import package — PENDING.
4. Integrate source changes, local schema/API data contracts, automated regression suite on one HEAD — CI green for current HEAD but full local content acceptance pending.
5. **Dedicated FULL FEATURE ACCEPTANCE AND BUG FIXING** — run 21-module + 8-edge-function + all-route/role/locale/device matrix, fix actual defects; local and authorized test environments. Not yet accepted.
6. Owner-approved encrypted hosted Staging backup + isolated restore dry-run — BLOCKED pending authorized access.
7. Owner-authorized Staging draft import and hosted Admin/User/Research/Feed positive/negative E2E; re-run feature matrix against real Staging — BLOCKED by stage 6.
8. Independent final QA, client-demo decision, owner-approved merge/release/deploy (if authorized) — PENDING.

Do not approve hosted production or release on green CI alone.
