# RAD Loading Motion System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every meaningful pending state in RAD Emigrate use a performant, accessible RAD Earth-and-bird loading identity.

**Architecture:** A new `RadLoadingIndicator` owns a lifecycle-safe animation controller and paints the globe/orbit scene locally. `LoadingState` adapts the existing page integration API to full-screen, section, and compact tiers; existing state branches select the proper tier without altering data, auth, or error control flow.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Material, Riverpod 2.6, CustomPainter, widget tests.

**Spec:** `docs/superpowers/specs/2026-10-08-rad-loading-system-design.md`

## Global Constraints

- Derive the bird asset solely from `assets/branding/rad_official_logo.png`; render it solid RAD red.
- Add no runtime dependency, network request, or heavyweight 3D engine.
- Animate only while a real pending branch is visible; retain all existing error/retry branches.
- Respect `MediaQuery.disableAnimations`, `TickerMode`, semantic live regions, RTL, and mobile bounds.
- Do not replace ordinary button spinners or tiny submit controls with the full loading scene.

## Review Focus

- Reduced-motion devices show the same branded progress status without an active animation ticker.
- Transitioning a pending boolean from true to false removes the loader and stops its controller.
- A screen error remains the existing actionable `ErrorState`, not a permanently visible loader.
- Compact loaders fit chat rows, sheet upload feedback, and narrow mobile viewports without overflow.
- Existing full page loading branches preserve their real provider/controller state ownership.

---

### Task 1: Derive and render the core RAD loading scene

**Files:**
- Create: `tools/derive_rad_bird_asset.py`
- Create: `assets/branding/rad_bird_silhouette.png`
- Create: `lib/core/widgets/rad_loading.dart`
- Test: `test/core/rad_loading_test.dart`

**Interfaces:**
- Produces: `enum RadLoadingSize { fullScreen, section, compact }`
- Produces: `class RadLoadingIndicator extends StatefulWidget` with `size`, `label`, `message`, `active`, and `dark` properties.
- Produces: `class RadInlineLoading extends StatelessWidget` for compact layouts.

- [ ] **Step 1: Write the failing widget tests**

```dart
expect(find.byType(RadLoadingIndicator), findsOneWidget);
expect(tester.getSemantics(find.byType(RadLoadingIndicator)).label, 'Loading cases');
```

Add coverage for all three size tiers, Reduced Motion, and active-to-inactive updates.

- [ ] **Step 2: Run the new test to verify it fails**

Run: `flutter test test/core/rad_loading_test.dart`
Expected: FAIL because `rad_loading.dart` and its public types do not yet exist.

- [ ] **Step 3: Add the derived official bird asset and core scene**

Use a deterministic component extractor over the official logo for the largest bird body and wing components. Implement an isolated `CustomPainter(repaint: controller)` globe/trail scene, a transformed asset bird, `RepaintBoundary`, `TickerMode`, Reduced Motion, semantic label, and controller disposal.

- [ ] **Step 4: Run targeted tests**

Run: `dart format tools/derive_rad_bird_asset.py lib/core/widgets/rad_loading.dart test/core/rad_loading_test.dart && flutter test test/core/rad_loading_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/derive_rad_bird_asset.py assets/branding/rad_bird_silhouette.png lib/core/widgets/rad_loading.dart test/core/rad_loading_test.dart
git commit -m "feat(ui): add RAD branded loading scene"
```

### Task 2: Adapt shared and full-screen loading states

**Files:**
- Modify: `lib/core/widgets/loading_state.dart`
- Modify: `lib/features/splash/presentation/pages/splash_page.dart`
- Modify: `lib/features/visa/presentation/pages/visa_page.dart`
- Modify: `lib/features/applications/presentation/pages/applications_page.dart`
- Modify: `lib/features/documents/presentation/pages/documents_page.dart`
- Modify: `lib/features/feed/presentation/pages/feed_page.dart`
- Modify: `lib/features/admin/presentation/pages/admin_operations_page.dart`
- Modify: `lib/features/admin/presentation/pages/admin_consultations_page.dart`
- Modify: `lib/features/notifications/presentation/pages/notifications_page.dart`
- Modify: `lib/features/profile/presentation/pages/profile_page.dart`
- Test: `test/core/rad_loading_test.dart`

**Interfaces:**
- Consumes: `RadLoadingIndicator` from Task 1.
- Produces: `LoadingState.fullScreen`, `LoadingState.section`, and `LoadingState.compact` named constructors.

- [ ] **Step 1: Extend failing tests for shared constructor selection**

Assert `LoadingState.fullScreen` uses `RadLoadingSize.fullScreen`, the default and section constructors use `section`, and error branches are untouched at their page call sites.

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `flutter test test/core/rad_loading_test.dart`
Expected: FAIL because named loading constructors do not exist.

- [ ] **Step 3: Implement shared variants and migrate page-level pending branches**

Keep existing error/retry callbacks. Splash uses `fullScreen`; all data-backed pages listed above use `section`, including Notifications/Profile substitutions for their generic full-page indicators.

- [ ] **Step 4: Run target tests and analysis**

Run: `dart format lib/core/widgets/loading_state.dart lib/features && flutter analyze && flutter test test/core/rad_loading_test.dart`
Expected: PASS with no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/loading_state.dart lib/features/splash lib/features/visa lib/features/applications lib/features/documents lib/features/feed lib/features/admin lib/features/notifications lib/features/profile test/core/rad_loading_test.dart
git commit -m "feat(ui): apply RAD loader to app loading states"
```

### Task 3: Replace appropriate inline indicators and document visual QA

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- Modify: `lib/features/documents/presentation/pages/documents_page.dart`
- Modify: `lib/features/applications/presentation/pages/applications_page.dart`
- Modify: `lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart`
- Modify: `lib/features/admin/presentation/pages/admin_ai_config_page.dart`
- Modify: `lib/visual_qa_main.dart`
- Modify: `test/visual_qa_smoke_test.dart`
- Create: `docs/RAD_LOADING_MOTION_SYSTEM.md`
- Create: `docs/visual_qa/loading_motion_desktop.png`
- Create: `docs/visual_qa/loading_motion_mobile.png`
- Create: `docs/visual_qa/loading_motion.gif`

**Interfaces:**
- Consumes: `RadInlineLoading` from Task 1 and `LoadingState` constructors from Task 2.
- Produces: visual QA selection state for each loading tier and a documented capture record.

- [ ] **Step 1: Extend visual QA smoke coverage**

Add test-selectable loading scenes and assert the compact indicator is present for an inline loading screen.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/visual_qa_smoke_test.dart`
Expected: FAIL until visual-QA loading state selection is implemented.

- [ ] **Step 3: Replace only meaningful inline generic progress controls**

Use compact RAD loading for dashboard updates, document upload, application status update, AI response row, and admin AI configuration list. Preserve button/dialog submission spinners.

- [ ] **Step 4: Capture and review web visual evidence**

Build `visual_qa_main.dart`, serve locally, capture desktop/mobile static loading states plus a short actual animation recording, and add an implementation note with the full mapping and performance constraints.

- [ ] **Step 5: Run full quality gates**

Run: `dart format --set-exit-if-changed lib test && flutter analyze && flutter test && flutter build web --no-web-resources-cdn --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=visual-qa && flutter build apk --debug --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=visual-qa`
Expected: all commands pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard lib/features/documents lib/features/applications lib/features/ai_assistant lib/features/admin lib/visual_qa_main.dart test/visual_qa_smoke_test.dart docs/RAD_LOADING_MOTION_SYSTEM.md docs/visual_qa
git commit -m "feat(ui): extend RAD loading motion across pending states"
```
