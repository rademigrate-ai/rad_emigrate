# RAD Earth-and-Bird Login Hero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace only the approved Login Hero logo tile with a dimensional Earth and original red RAD bird scene while preserving the `cc8e015` premium Login composition.

**Architecture:** A visual-only `RadEarthBirdScene` owns the Earth painter, official bird treatment, seamless orbital geometry, depth ordering, reduced-motion behavior, and ticker lifecycle. `AuthCinematicFrame` receives an optional centerpiece slot so Login adopts the new scene while Register and existing `RadOrbit` consumers retain their baseline behavior.

**Tech Stack:** Flutter/Dart 3.13, Material, `CustomPaint`, `AnimationController`, existing `AppMotion`, existing RAD image assets, Flutter widget tests, Playwright/Chromium evidence capture.

**Spec:** `docs/superpowers/specs/2026-10-08-rad-earth-bird-scene-design.md`

## Global Constraints

- Preserve `cc8e015` Login layout, colors, typography, glass panel, copy, spacing, route/auth behavior, RTL/LTR behavior, and surrounding premium composition; only replace the centerpiece.
- Use `assets/branding/rad_bird_silhouette.png` in solid `AppColors.primaryRed`; do not introduce a generic bird, lettering, background, packages, external assets, or 3D runtime.
- Use one closed bird orbit with depth scale/orientation and actual back/foreground Earth occlusion; no wireframe-dominant globe or loop-boundary reset.
- The scene must honor `active`, `MediaQuery.disableAnimations`, `TickerMode.valuesOf(context)`, one semantic label, `RepaintBoundary`, and controller disposal.
- Implement only the Login Hero in this plan. Splash and loading variants require the owner’s visual approval after the Phase 1 recording.
- No merge, deploy, or loading-system propagation.

## Review Focus

1. **Desktop and mobile constraints:** the 1280×800 and 390×844 Login layout must keep the approved form geometry and preserve a readable, non-overlapping centerpiece.
2. **Orbit crossover:** a bird crossing the Earth’s near/far phase must change layers without a pop, duplication, or a visible reset.
3. **Motion preference changes:** reduced motion and disabled `TickerMode` must stop tickers while leaving a stable visible Earth and bird.
4. **Semantics:** exactly one meaningful scene label should be exposed; decorative paint and image content must not be announced separately.
5. **Auth regression:** Login submit/OTP routing and existing form interactions must remain unchanged.

---

### Task 1: Define the Earth-and-bird scene contract with red tests

**Files:**
- Create: `test/core/rad_earth_bird_scene_test.dart`
- Create: `lib/core/widgets/rad_earth_bird_scene.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppMotion`, `assets/branding/rad_bird_silhouette.png`.
- Produces: `RadEarthBirdVariant` and `RadEarthBirdScene(variant, semanticLabel, size, active, dark)` for Login and future loading variants.

- [ ] **Step 1: Write failing widget tests**

Add tests that expect a `RadEarthBirdScene` configured as `loginHero` to expose its semantic label, run motion when active, stop motion under `MediaQueryData(disableAnimations: true)`, stop after an active-to-inactive update, and dispose without an exception after removal.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/core/rad_earth_bird_scene_test.dart`

Expected: FAIL because `RadEarthBirdScene` and `RadEarthBirdVariant` do not yet exist.

- [ ] **Step 3: Implement the minimal visual-only scene**

Implement `RadEarthBirdScene` and the enum in `lib/core/widgets/rad_earth_bird_scene.dart`:

- a `StatefulWidget` using one controller and a `RepaintBoundary`;
- a painter-based ocean/continent/atmosphere Earth that remains dimensional without a wireframe grid;
- a transparent, color-filtered official bird image;
- two depth-aware bird layers around the Earth so the back phase is occluded and the foreground phase is visible;
- a continuous, closed tangent-oriented ellipse and stable reduced-motion phase.

Do not modify `rad_loading.dart` or migrate a loading surface.

- [ ] **Step 4: Run the targeted tests to verify they pass**

Run: `flutter test test/core/rad_earth_bird_scene_test.dart`

Expected: PASS with no exception or semantics duplication.

- [ ] **Step 5: Commit the scene contract**

```bash
git add lib/core/widgets/rad_earth_bird_scene.dart test/core/rad_earth_bird_scene_test.dart
git commit -m "feat(ui): add premium RAD Earth and bird scene"
```

### Task 2: Integrate the scene only into the Login Hero

**Files:**
- Modify: `lib/core/widgets/premium_visuals.dart:190-342`
- Modify: `lib/features/auth/presentation/pages/login_page.dart:103-223`
- Modify: `test/visual_qa_smoke_test.dart`

**Interfaces:**
- Consumes: `RadEarthBirdScene` from Task 1.
- Produces: `AuthCinematicFrame.heroVisual`, an optional display-only slot; Login uses `RadEarthBirdVariant.loginHero`, while null retains existing `RadOrbit` fallback.

- [ ] **Step 1: Write failing integration tests**

Add assertions that the visual QA Login route contains one `RadEarthBirdScene` with `loginHero` and preserve the existing QA Login screen selection.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `flutter test test/visual_qa_smoke_test.dart --plain-name "visual QA login uses the premium Earth and bird scene"`

Expected: FAIL because Login still renders the original logo-tile centerpiece.

- [ ] **Step 3: Integrate the optional hero slot**

Add a nullable `heroVisual` parameter to `AuthCinematicFrame`, using it in the existing desktop/mobile central position when supplied and retaining the current `RadOrbit` fallback otherwise. Configure only `LoginPage` with the Login Hero scene. Do not alter Register or any other `RadOrbit` caller.

- [ ] **Step 4: Run the focused tests to verify they pass**

Run: `flutter test test/core/rad_earth_bird_scene_test.dart test/visual_qa_smoke_test.dart`

Expected: PASS; the Login QA route mounts the new scene and existing visual QA screen contracts remain valid.

- [ ] **Step 5: Commit the Login-only integration**

```bash
git add lib/core/widgets/premium_visuals.dart lib/features/auth/presentation/pages/login_page.dart test/visual_qa_smoke_test.dart
git commit -m "feat(ui): place Earth and bird in approved Login Hero"
```

### Task 3: Run actual production visual gate and record evidence

**Files:**
- Create: `tools/capture_login_earth_bird_motion.py`
- Create: `docs/visual_qa/login_earth_bird_desktop.png`
- Create: `docs/visual_qa/login_earth_bird_mobile.png`
- Create: `docs/visual_qa/login_earth_bird_orbit.mp4`
- Create: `docs/visual_qa/login_earth_bird_orbit.gif`
- Modify: `docs/RAD_EARTH_BIRD_LOGIN_VISUAL_GATE.md`

**Interfaces:**
- Consumes: real production app entrypoint and the Login Hero from Task 2.
- Produces: production-route screenshots and a 10–15 second orbit recording suitable for owner approval; no synthetic QA artifact is sufficient by itself.

- [ ] **Step 1: Add a production-route capture script**

The script starts only after a production web build is served locally, captures desktop/mobile Login screenshots, records 10–15 seconds of the real Login route, and samples phases that demonstrate back and foreground occlusion. It must not send auth credentials or use customer data.

- [ ] **Step 2: Build and capture the real Login route**

Run the production Flutter web build with non-secret placeholder build values, serve it locally, then run the capture script. Do not substitute the visual QA entrypoint for the production Login evidence.

Expected: capture files exist and the recording contains a complete closed orbit.

- [ ] **Step 3: Inspect desktop and mobile evidence in one bounded visual pass**

Compare the new screenshots with `docs/visual_qa/login_after_desktop.png` and `docs/visual_qa/login_after_mobile.png`. Check that the form, panel, copy, typography, spacing, background, and outer composition remain unchanged apart from the center scene.

- [ ] **Step 4: Run focused quality gates**

Run:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/core/rad_earth_bird_scene_test.dart test/visual_qa_smoke_test.dart test/widget_test.dart
flutter build web --no-web-resources-cdn --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=placeholder
```

Expected: all commands exit zero. Record browser console and accessibility-tree results for the real Login route.

- [ ] **Step 5: Commit visual-gate evidence and stop**

```bash
git add tools/capture_login_earth_bird_motion.py docs/visual_qa/login_earth_bird_* docs/RAD_EARTH_BIRD_LOGIN_VISUAL_GATE.md
git commit -m "docs(ui): record Login Earth and bird visual gate"
```

After this commit, stop and ask the project owner to approve the evidence before changing Splash or any loading state.
