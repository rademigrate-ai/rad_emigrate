# Login Earth-and-Bird Visual Gate

**Date:** 2026-10-08
**Canonical baseline:** `cc8e015` — premium visual redesign
**Implementation commits:** `2461354` (shared scene), `1a31d31` (Login-only placement)
**Gate status:** **Pending project-owner approval**

## Scope and boundary

This gate evaluates **only the production Login Hero**. The approved Login form, glass panel, typography, copy, color system, background composition, responsive split layout, and authentication behavior are retained. The former central `RadOrbit` tile is the only visual element replaced.

No Splash, full-screen loading, section loading, compact loading, Registration, or other `RadOrbit` usage was changed. Phase 2 remains blocked until the owner approves this evidence.

## Production-route evidence

All evidence comes from the compiled production Flutter entrypoint at `/#/login`, built with non-secret placeholder Supabase values. The capture script does not enter credentials, submit forms, or use customer data.

| Evidence | View / purpose |
| --- | --- |
| [Desktop Login screenshot](visual_qa/login_earth_bird_desktop.png) | 1280×800 production Login; demonstrates the foreground red bird phase beside the dimensional Earth. |
| [Mobile Login screenshot](visual_qa/login_earth_bird_mobile.png) | 390×844 production Login; demonstrates the compact responsive hero without affecting the form surface. |
| [14-second native browser recording](visual_qa/login_earth_bird_orbit.mp4) | 1280×800 H.264 / 25 fps; one complete Login-Hero orbit captured from Chromium. |
| [GIF motion preview](visual_qa/login_earth_bird_orbit.gif) | Lightweight preview of the same native browser recording. |
| [Capture diagnostics](visual_qa/login_earth_bird_capture_report.json) | Route, viewports, capture duration, and browser-console observations. |

The final MP4 duration was measured with `ffprobe`: **14.000 seconds** at **1280×800** and **25 fps**.

## Comparison with the approved visual baseline

| Element | Approved baseline | Current Login Hero result |
| --- | --- | --- |
| Outer composition | Midnight editorial visual panel paired with a white glass access panel | Unchanged |
| Login panel, fields, copy, and actions | Existing spacing, typography, colors, and behavior | Unchanged |
| Desktop central artwork | Original `RadOrbit` logo tile | Replaced by the Earth-and-bird scene only |
| Mobile masthead | Compact dark journey masthead with a centered visual | Preserved; the scene scales to the existing 132 px visual slot |
| Surrounding orbit/grid language | Cyan/teal orbital lines and restrained red markers | Preserved and visually harmonized with the new centerpiece |

Reference screenshots: [approved desktop baseline](visual_qa/login_after_desktop.png) and [approved mobile baseline](visual_qa/login_after_mobile.png).

## Scene acceptance review

- **Earth:** rendered with layered ocean shading, clipped stylized continents, city lights, a terminator shadow, atmospheric halo, cyan rim lighting, and a continuous texture shift. It reads as a dimensional globe rather than a wireframe or flat circle.
- **RAD bird:** rendered exclusively from the project’s extracted official `rad_bird_silhouette.png`, color-filtered solid RAD red, without lettering or background.
- **Orbit:** the bird position derives from continuous `sin`/`cos` ellipse geometry. Its back-half layer is drawn before the Earth; its front-half layer is drawn after the Earth. Scale and bank use bounded continuous values, preventing synthetic full-axis spinning.
- **Frame-level verification:** a bounded review of the real recording across the back-to-front transition confirmed that the bird is intentionally occluded at the rear of the Earth, then emerges continuously at the upper-right foreground. The apparent absence during the back half is depth occlusion, not a reset.
- **Responsive layout:** desktop preserves the original 330 px visual slot; mobile preserves the 132 px masthead visual slot and does not overlap or alter the form surface.

## Browser, accessibility, and lifecycle evidence

- The compiled production Login route was opened in the sandbox browser; its browser console contained **no application console output, warnings, or errors**.
- Flutter web semantic DOM is opt-in in the headless canvas environment; the browser exposed only its hidden `Enable accessibility` control even when `?semantics` was supplied. This limited external accessibility-tree inspection, not the application’s semantic implementation.
- Widget coverage verifies that `RadEarthBirdScene` exposes one semantic image label, honors Reduced Motion, respects `TickerMode`, stops when inactive, and disposes its animation controller.

## Final quality gates

| Check | Result |
| --- | --- |
| `dart format --set-exit-if-changed lib test` | Passed; 179 files checked with no changes. |
| `flutter analyze` | Passed; no issues found. |
| Focused scene, Login visual-QA, and app-widget tests | Passed; 14 tests. |
| Production web build | Passed with placeholder build values only; output served locally for the capture. |
| Final MP4 probe | Passed; 14.000 seconds, H.264, 1280×800, 25 fps. |

The Flutter build emitted existing WebAssembly dry-run compatibility findings from `flutter_secure_storage_web` (`dart:html` / `dart:js_util`). They do not affect this CanvasKit/HTML production capture and were not introduced by the Login Hero change.

## Approval request

Please review the desktop/mobile screenshots and the **14-second MP4**. Approval authorizes only the subsequent planned reuse of this approved scene in Splash and the RAD loading variants. Until approval is received, this branch must not propagate the scene or be merged/deployed.
