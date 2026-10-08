# RAD Earth-and-Bird Phase 2 QA Report

**Scope:** Approved Phase 2 local rollout of the Login-approved Earth-and-bird scene to Splash and full-screen, section, and compact loading surfaces.
**Delivery restriction:** Local commits only. No push, merge, deployment, Login redesign, Registration/auth/Supabase change, or business-logic change was performed.

## Implementation summary

| Requirement | Delivered implementation |
| --- | --- |
| Preserve Login and approved scene | `LoginPage`, `premium_visuals.dart`, Login layout/auth behavior, and `RadEarthBirdScene(loginHero)` were not modified in Phase 2. |
| One shared architecture | `RadLoadingIndicator` delegates to the already-approved `RadEarthBirdScene`; the former duplicate loader controller/painters/orbit code was removed. |
| Splash | `SplashPage` uses new `LoadingState.splash`, which selects the prominent `splash` scene on the existing dark premium canvas and removes only the generic skeleton preview. |
| Full-screen | Existing `RadLoadingSize.fullScreen` maps to `fullScreenLoading`. |
| Section | Existing section loaders map to `sectionLoading`; visual QA records light and dark contrast surfaces. |
| Compact | Existing inline loaders map to `compactLoading`; it contains the official red bird plus one cyan ellipse and no Earth. |
| Pending/error behavior | Existing provider/local pending branches, retry/error states, and ordinary button spinners remain unchanged. |
| Lifecycle/accessibility | Existing `active`, Reduced Motion, `TickerMode`, `RepaintBoundary`, controller disposal, RTL/LTR, and one live announcement contract remain in the shared renderer/adapter tests. |

## Actual Flutter evidence

All evidence is generated from a local `flutter build web -t lib/visual_qa_main.dart` with non-secret placeholder build values. `splash` mounts the **actual `SplashPage`** and holds its real bootstrap provider pending using a visual-QA-only Riverpod override. Other routes mount actual shared production loading widgets; no customer state or credentials were used.

| Surface | Desktop screenshot (1280×800) | Mobile screenshot (390×844) | Native browser recording |
| --- | --- | --- | --- |
| Splash | [`phase2_splash_desktop.png`](visual_qa/phase2_splash_desktop.png) | [`phase2_splash_mobile.png`](visual_qa/phase2_splash_mobile.png) | [`phase2_splash_orbit.mp4`](visual_qa/phase2_splash_orbit.mp4) |
| Full-screen loading | [`phase2_full_loading_desktop.png`](visual_qa/phase2_full_loading_desktop.png) | [`phase2_full_loading_mobile.png`](visual_qa/phase2_full_loading_mobile.png) | [`phase2_full_loading_orbit.mp4`](visual_qa/phase2_full_loading_orbit.mp4) |
| Section loading | [`phase2_section_loading_desktop.png`](visual_qa/phase2_section_loading_desktop.png) | [`phase2_section_loading_mobile.png`](visual_qa/phase2_section_loading_mobile.png) | [`phase2_section_loading_orbit.mp4`](visual_qa/phase2_section_loading_orbit.mp4) |
| Compact loading | [`phase2_compact_loading_desktop.png`](visual_qa/phase2_compact_loading_desktop.png) | [`phase2_compact_loading_mobile.png`](visual_qa/phase2_compact_loading_mobile.png) | [`phase2_compact_loading_orbit.mp4`](visual_qa/phase2_compact_loading_orbit.mp4) |

Additional dark-section contrast captures: [`desktop`](visual_qa/phase2_section_loading_dark_desktop.png) and [`mobile`](visual_qa/phase2_section_loading_dark_mobile.png). The compact screenshots each contain the actual compact loader on **both** a light surface (`dark: false`) and a dark surface (`dark: true`).

Each MP4 is H.264, 1280×800, 25 fps, silent, and exactly **14.000 seconds**. The reproducible capture implementation and exact file metadata/console observations are in [`tools/capture_phase2_loading_motion.py`](../tools/capture_phase2_loading_motion.py) and [`phase2_loading_capture_report.json`](visual_qa/phase2_loading_capture_report.json).

## Motion investigation record

The recording analyzer initially flagged possible bird disappearance/reset defects. Investigation was completed before accepting the evidence:

1. The renderer intentionally draws the back half of the bird **below** the Earth. At the central part of that far arc, the dimensional globe completely occludes the bird; this is expected depth behavior, not an alternate bird or a missing renderer.
2. The orbit geometry uses the same closed phase expression as the approved Login scene: `(progress × 2π) − 0.78`; `progress = 0` and `progress = 1` are identical positions. The compact bird only applies a bounded rotation (`−0.12 + cos(phase) × 0.24` radians); it is never mirrored.
3. Deterministic red-component tracking through each recording's actual 11/12-second loop boundary found continuous screen-space motion. Full loading moved through `(701.7, 373.7) → (610.5, 376.8)` across 9.6–11.4 seconds; Splash moved through `(715.1, 423.5) → (620.8, 430.5)` across 10.6–12.4 seconds. No centroid discontinuity occurred at either sampled boundary.

Therefore the initial analyzer descriptions are recorded as conservative automated-review observations, not accepted regressions. The implementation deliberately preserves the already approved Login scene's orbital geometry and occlusion behavior.

## Browser observations

The capture tool now records console observations for every desktop/mobile target, including the additional dark-section capture, and fails the capture when any console entry has type `error`. It validates an exact 15-file manifest (four desktop screenshots, four mobile screenshots, four MP4s, two dark-section screenshots, and JSON report) plus report target keys/video references before publication. It stages the complete evidence set and JSON report in a temporary directory, then moves prior evidence to a temporary backup and rolls back the full prior set if any replacement fails. The final report contains zero error entries for Splash, full, section, compact, dark-section desktop, and dark-section mobile.

The recorded non-error entries are only Playwright's script-injection debug message and Chromium WebGL `GL_CLOSE_PATH_NV` / `ReadPixels` performance warnings while taking screenshots. Those warnings arise in the headless capture environment and do not identify an application exception.

## Independent review remediation

A fresh-context review identified two Important evidence gaps: compact QA covered only the dark surface, and the capture code did not enforce zero browser errors or record dark-section console events. The remediation adds light-and-dark compact QA surfaces and smoke coverage, enforces `error`-level console failure across every captured surface, and writes dark-section console observations into the JSON report. It also removes the compact cyan node so compact rendering is precisely the official red bird plus one cyan ellipse. Follow-up reviews hardened publication further: the capture set now has an exact manifest validator and rollback-safe replacement, with focused tests for console-error cleanup, successful-but-incomplete capture, and a failure during the second candidate file replacement.

## Automated verification

All commands below were run after the Phase 2 implementation and evidence capture:

| Check | Result |
| --- | --- |
| `dart format --set-exit-if-changed lib test` | PASS — 179 files already formatted. |
| `flutter analyze` | PASS — “No issues found!” |
| `flutter test` | PASS — **225 tests**. |
| `python3 tools/test_capture_phase2_loading_motion.py` | PASS — 3 tests covering console-error cleanup, incomplete-manifest rejection, and mid-publication replacement rollback. |
| Production `flutter build web --no-web-resources-cdn ...` | PASS — 82.1 s. |
| Visual-QA `flutter build web -t lib/visual_qa_main.dart --no-web-resources-cdn ...` | PASS — 77.1 s. |
| `flutter build apk --debug ...` | PASS — debug APK produced at `build/app/outputs/flutter-apk/app-debug.apk` (185 MB). |
| Capture script `python3 tools/capture_phase2_loading_motion.py` | PASS — 4 recordings, 10 screenshots, JSON diagnostics. |

The web builds emit existing WebAssembly dry-run notices from `flutter_secure_storage_web` (`dart:html`, `dart:js_util`, and `package:js`), and the Android build emits an existing future Kotlin Gradle Plugin compatibility notice from `file_picker`. Both builds complete successfully; neither was introduced by this Phase 2 visual change.

## Bundle measurement

The production web output was measured with the identical build configuration before and after migration:

| Measure | Bytes |
| --- | ---: |
| Pre-migration output | 44,192,558 |
| Phase 2 output | 44,187,977 |
| Delta | **−4,581** |

The small decrease is consistent with removing the duplicate loader painter/controller while reusing the Login-approved renderer.

## Source references

- [Flutter `AnimationController` lifecycle](https://api.flutter.dev/flutter/animation/AnimationController-class.html)
- [Flutter `TickerMode.valuesOf`](https://api.flutter.dev/flutter/widgets/TickerMode/valuesOf.html)
- [Flutter `CustomPaint`](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)
