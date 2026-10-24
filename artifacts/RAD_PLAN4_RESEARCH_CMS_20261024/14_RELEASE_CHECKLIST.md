# 14 — RELEASE CHECKLIST

## Plan 4 Preflight & Delivery Verification

- [x] **Repository Worktree & Branch Integrity:**
  - Dedicated worktree: `C:\Users\Mehrshad\Desktop\RAD - Emigrate\rad_plan4_research_cms`
  - Target branch: `feat/plan4-research-cms-20261024`
  - Baseline commit: `16810a583ad4544d87f289bd16984c0e758a1515` (verified `origin/main`)
- [x] **No Modifications to Prohibited Branches:**
  - Grok's PR #78 untouched.
  - Codex Plan 3 branch untouched.
  - Hosted production Supabase (`inshddthftkhcdosoqcn`) strictly untouched (read-only verification).
- [x] **Contract Schema Alignment:**
  - Ran `scripts/generate_dart_contracts.py` generating `rad_contract_schemas.dart`.
  - All 20 Plan 4 request and response schemas verified against `supabase/contracts/rad_v1.json`.
- [x] **Static Code Analysis:**
  - Command: `dart analyze`
  - Result: `No issues found!` (0 errors, 0 warnings, 0 infos).
- [x] **Unit & Widget Test Coverage:**
  - Command: `flutter test`
  - Result: `1032 / 1032 tests passed!` (100% pass rate).
- [x] **Production Web Compilation:**
  - Command: `flutter build web --release`
  - Result: Succeeded in 167.5s (`build/web` generated).
- [x] **Zero AI Auto-Publish Invariant:**
  - Proposal review acceptance strictly transitions to `draft` in CMS, never auto-publishes.
  - User change highlights banner strictly reads published revisions.
- [x] **UI/UX Design System Compliance:**
  - `AdminSourceDiffPage`, `AdminSourceMonitorPage`, `AdminCmsCanonicalEditorPage`, `ArticleChangeHighlightsBanner` conform to `AppColors`, `AppRadii`, RTL Persian directionality, and accessibility standards.
- [x] **Documentation & Deliverables:**
  - 18 deliverables generated in `artifacts/RAD_PLAN4_RESEARCH_CMS_20261024/`.
  - Cryptographic checksums calculated in `CHECKSUMS.sha256`.
  - Machine-readable manifest compiled in `PLAN4_MANIFEST.json`.
