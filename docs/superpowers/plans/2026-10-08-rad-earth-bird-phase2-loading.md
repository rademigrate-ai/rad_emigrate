# RAD Earth-and-Bird Phase 2 Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse the approved RAD Earth-and-bird renderer for Splash and all existing full-screen, section, and compact loading densities without changing Login, authentication, data/provider logic, or unrelated UI.

**Architecture:** `RadLoadingIndicator` becomes a lifecycle/semantics/layout adapter over `RadEarthBirdScene`; it removes its duplicate painter and controller. A dedicated additive Splash constructor selects `splash`, while all existing `RadLoadingSize` callers map deterministically to the approved loading variants. The visual-QA app holds the real Splash pending and captures each density from real Flutter widgets.

**Tech Stack:** Flutter/Dart 3.13, Material, Riverpod overrides, existing `RadEarthBirdScene`, widget tests, Playwright/Chromium, FFmpeg/ffprobe.

**Spec:** `docs/superpowers/specs/2026-10-08-rad-earth-bird-phase2-loading-design.md`

## Global Constraints

- Preserve the approved Login Hero, Login/Registration/auth/Supabase/business logic, existing provider pending/error mapping, RTL/LTR, and all unrelated UI.
- Reuse `RadEarthBirdScene`, `assets/branding/rad_bird_silhouette.png`, existing orbital geometry, and motion lifecycle; remove rather than maintain the old duplicate loading renderer.
- Do not introduce a wireframe/flat globe, generic bird, low-contrast scene, or an Earth in compact mode.
- Keep one live loading announcement, Reduced Motion, `TickerMode`, active-state stopping, `RepaintBoundary`, disposal, and real pending-state ownership.
- Keep ordinary button/dialog spinners unchanged.
- Commit locally only. Do not push, merge, or deploy.

## Review Focus

1. **Semantic duplication:** a loading adapter must expose exactly one live announcement while its visual scene remains decorative to the parent semantics boundary; Task 1 tests this.
2. **Visual-tier mismatch:** each existing size must select its matching approved scene and compact must not paint an Earth; Task 1 tests this.
3. **Splash fidelity:** the real Splash pending branch must select `splash`, remain on the dark premium canvas, and omit only the generic skeleton preview; Task 2 tests this.
4. **Pending-state preservation:** existing provider/error branches and Login/auth state must not be touched; Task 2 changes only the Splash visual constructor and QA-only provider override.
5. **Responsive contrast and motion:** desktop/mobile evidence must show every density, section contrast on light/dark surfaces, a continuous bird orbit, and no browser application errors; Task 3 verifies this.

---

### Task 1: Delegate the shared loading adapter to the approved scene

**Files:**
- Modify: `test/core/rad_loading_test.dart`
- Modify: `lib/core/widgets/rad_loading.dart`

**Interfaces:**
- Consumes: `RadEarthBirdScene`, `RadEarthBirdVariant`, existing `RadLoadingSize`.
- Produces: Existing `RadLoadingIndicator`/`RadInlineLoading` public API backed by a single approved renderer, with full/section/compact size-to-variant mapping.

- [ ] **Step 1: Write failing adapter tests**

Add tests that mount full, section, and compact `RadLoadingIndicator` instances and expect exactly three `RadEarthBirdScene` descendants configured as `fullScreenLoading`, `sectionLoading`, and `compactLoading`. Assert that the full loader keeps one live label and that the compact adapter has the compact scene variant.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/core/rad_loading_test.dart`

Expected: FAIL because the existing loader still owns `_RadLoadingScenePainter` and does not mount `RadEarthBirdScene`.

- [ ] **Step 3: Replace the duplicate renderer**

Refactor `RadLoadingIndicator` into a focused stateless adapter. Preserve its constructor fields and visible message behavior; map each `RadLoadingSize` to the matching `RadEarthBirdVariant`; wrap the child scene in `ExcludeSemantics` beneath the existing live region. Remove the duplicate controller, custom painters, orbit geometry, and bird widget from `rad_loading.dart`. Keep `RadInlineLoading` as the compact convenience wrapper.

- [ ] **Step 4: Run targeted tests to verify they pass**

Run: `flutter test test/core/rad_loading_test.dart test/core/rad_earth_bird_scene_test.dart`

Expected: PASS; all loading lifecycle semantics and Earth-and-bird scene lifecycle tests are green.

- [ ] **Step 5: Commit the shared renderer migration**

```bash
git add lib/core/widgets/rad_loading.dart test/core/rad_loading_test.dart
git commit -m "refactor(ui): reuse Earth and bird scene for loading"
```

### Task 2: Integrate the approved Splash variant and actual pending-state QA

**Files:**
- Modify: `test/core/rad_loading_test.dart`
- Modify: `test/visual_qa_smoke_test.dart`
- Modify: `lib/core/widgets/rad_loading.dart`
- Modify: `lib/core/widgets/loading_state.dart`
- Modify: `lib/features/splash/presentation/pages/splash_page.dart`
- Modify: `lib/visual_qa_main.dart`

**Interfaces:**
- Consumes: Task 1 adapter plus `appBootstrapProvider`.
- Produces: `RadLoadingIndicator.splash`, `LoadingState.splash`, real `SplashPage` visual-QA pending route, and visual-QA routes for full/section/compact evidence.

- [ ] **Step 1: Write failing Splash and QA tests**

Add tests for `LoadingState.splash` expecting one `RadEarthBirdScene(splash)`, visible status copy, and no `_LoadingSkeletonPreview`; add visual-QA expectations that `splash`, `loading-full`, `loading-section`, and `loading-compact` build, and that the Splash QA route mounts `SplashPage` with `RadEarthBirdVariant.splash`.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/core/rad_loading_test.dart test/visual_qa_smoke_test.dart`

Expected: FAIL because the factories and QA routes do not exist and Splash still selects `LoadingState.fullScreen`.

- [ ] **Step 3: Add explicit Splash factories and QA surfaces**

Add `RadLoadingIndicator.splash` and `LoadingState.splash` as additive focused constructors. `LoadingState.splash` uses full-screen layout, dark mode by default, no skeleton preview, and the splash scene variant. Change only `SplashPage` to use this constructor. In `visual_qa_main.dart`, override `appBootstrapProvider` with a pending visual-QA future and mount the actual `SplashPage`; add isolated full/section/compact QA surfaces that use the actual shared loading widgets on the contrast contexts required by the spec.

- [ ] **Step 4: Run targeted tests to verify they pass**

Run: `flutter test test/core/rad_loading_test.dart test/visual_qa_smoke_test.dart test/core/rad_earth_bird_scene_test.dart`

Expected: PASS; Splash and all tiers resolve to the approved variants without changing Login or pending/error ownership.

- [ ] **Step 5: Commit the Splash and QA integration**

```bash
git add lib/core/widgets/rad_loading.dart lib/core/widgets/loading_state.dart lib/features/splash/presentation/pages/splash_page.dart lib/visual_qa_main.dart test/core/rad_loading_test.dart test/visual_qa_smoke_test.dart
git commit -m "feat(ui): extend approved Earth scene to Splash"
```

### Task 3: Capture Phase 2 evidence and run complete verification

**Files:**
- Create: `tools/capture_phase2_loading_motion.py`
- Create: `docs/visual_qa/phase2_splash_*`
- Create: `docs/visual_qa/phase2_full_loading_*`
- Create: `docs/visual_qa/phase2_section_loading_*`
- Create: `docs/visual_qa/phase2_compact_loading_*`
- Create: `docs/RAD_EARTH_BIRD_PHASE2_QA_REPORT.md`
- Modify: `docs/RAD_LOADING_MOTION_SYSTEM.md`

**Interfaces:**
- Consumes: actual Flutter visual-QA routes from Task 2.
- Produces: one native 12–15 second MP4 and desktop/mobile screenshots for Splash, full, section, and compact variants; a reproducible capture script and validation report.

- [ ] **Step 1: Add the production-quality visual capture script**

Capture each route at 1280×800 and 390×844, record a native browser 12–15 second MP4 for each, probe duration/dimensions with ffprobe, record browser application-console observations, and never enter credentials or use customer data.

- [ ] **Step 2: Build, serve, capture, and inspect visual evidence**

Build `lib/visual_qa_main.dart` with non-secret placeholder values and serve it locally. Generate the four recordings and eight screenshots. Inspect desktop/mobile captures and sample orbit phases for a dimensional globe, official red bird, back/front occlusion, no compact globe, and readable contrast.

- [ ] **Step 3: Run final automated and performance checks**

Run:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=placeholder
flutter build web -t lib/visual_qa_main.dart --no-web-resources-cdn --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=placeholder
flutter build apk --debug --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=placeholder
```

Measure production web-output bytes against the pre-migration `44,192,558`-byte baseline using the identical production build setup.

Expected: every gate exits zero; any existing WebAssembly dry-run package notice is documented separately from this change.

- [ ] **Step 4: Document and commit Phase 2 evidence**

Update the loading-system documentation to name `RadEarthBirdScene` as its renderer and add a phase-2 QA report with exact evidence, tests, browser observations, and size measurement.

```bash
git add tools/capture_phase2_loading_motion.py docs/RAD_LOADING_MOTION_SYSTEM.md docs/RAD_EARTH_BIRD_PHASE2_QA_REPORT.md docs/visual_qa/phase2_*
git commit -m "docs(ui): record Phase 2 loading visual evidence"
```

- [ ] **Step 5: Request an independent whole-branch review**

Create a review package against `origin/main` and request a fresh-context review. Address only Critical or Important findings with a red/green fix pass; record deferred minors. Do not push, merge, or deploy.
