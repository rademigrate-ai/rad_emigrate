# RAD Loading Motion System

## Purpose

RAD Emigrate uses one recognizable loading identity for meaningful pending operations: a dimensional Earth, restrained cyan orbital trail, and the **original RAD bird silhouette** in solid RAD red. The bird asset is deterministically derived from `assets/branding/rad_official_logo.png`; it is not a generic icon or third-party substitute.

The single visual renderer is `lib/core/widgets/rad_earth_bird_scene.dart`. `lib/core/widgets/rad_loading.dart` is now a thin lifecycle/semantics/layout adapter over that renderer—there is no second Earth painter, orbital geometry implementation, bird asset treatment, or animation controller to drift from the approved Login Hero.

## Tiers

| Tier | Component | Scene variant | Intended use | Visual behavior |
| --- | --- | --- | --- | --- |
| Splash | `LoadingState.splash(...)` | `RadEarthBirdVariant.splash` | `SplashPage` while `appBootstrapProvider.future` is pending | Prominent centered dimensional Earth and red bird on the existing dark premium canvas, localized status copy, no generic skeleton preview. |
| Full-screen | `RadLoadingIndicator(size: RadLoadingSize.fullScreen)` / `LoadingState.fullScreen(...)` | `fullScreenLoading` | Major application loading | Rich Earth-and-bird scene plus contextual status and skeletal content preview. |
| Section | `LoadingState.section(...)` / `RadLoadingIndicator(size: RadLoadingSize.section)` | `sectionLoading` | Visa, applications, documents, feed, admin, notifications, and profile provider-backed states | Smaller dimensional Earth-and-bird scene with light/dark contrast support. |
| Compact | `RadInlineLoading(...)` / `LoadingState.compact(...)` | `compactLoading` | Dashboard updates, document upload, application status update, AI response row, and admin AI configuration | Original red bird with a single restrained cyan ellipse; **no Earth**. |

`RadLoadingIndicator.splash` is deliberately a dedicated constructor rather than a generic visual override, so callers cannot combine incompatible density and scene variants.

## Pending-state mapping

| Product surface | Pending signal | RAD variant | Failure behavior |
| --- | --- | --- | --- |
| Splash | `appBootstrapProvider.future` | Splash | Existing safe unauthenticated route remains the fallback. |
| Visa catalogue | `visaCatalogProvider(...).loading` | Section | Existing `ErrorState` with catalog retry. |
| Applications | `applicationControllerProvider.loading` | Section | Existing `ErrorState` with controller retry. |
| Application status update | `_updatingStatus` | Compact | Existing failure `SnackBar` remains. |
| Documents | `documentControllerProvider.loading` | Section | Existing `ErrorState` with controller retry. |
| Document upload | `uploading.value` | Compact | Existing upload failure `SnackBar` remains. |
| Feed | `feedProvider(...).loading` | Section | Existing `ErrorState` with provider invalidation. |
| Dashboard updates | nested `feedProvider(...).loading` | Compact | Existing retry shortcut remains. |
| AI Assistant | `_loading` response row | Compact | Existing failed-response/retry message remains. |
| Admin operations and consultations | provider / `_loading` state | Section | Existing `ErrorState` paths remain. |
| Admin AI configuration | `adminConsoleProvider.loading` | Compact | Existing configuration unavailable message remains. |
| Notifications and profile | `_loading` / profile provider state | Section | Existing errors remain visible. |

Ordinary button and dialog submit spinners remain intentionally unchanged. Replacing every spinner with an Earth scene would be slower, noisier, and inappropriate for controls whose label already conveys the pending action.

## Motion, lifecycle, and accessibility

The parent owns pending state. The scene is mounted only while a real page/provider/operation pending branch renders it; success, error, cancellation, and route replacement remove it and dispose its controller. Existing error branches remain visible rather than being masked by permanent loading feedback.

`RadEarthBirdScene` starts only while `active`, Reduced Motion is off, and `TickerMode.valuesOf(context).enabled`. In Reduced Motion or an inactive ticker subtree it keeps a static branded composition with no running ticker. The scene is enclosed by a `RepaintBoundary`; custom paint uses its controller as the repaint notifier so surrounding page content does not rebuild per frame.

`RadLoadingIndicator` owns one live loading announcement. Its visual scene is excluded from the parent accessibility subtree, preventing a duplicate announcement. `LoadingState` separates visible `message` from `semanticsLabel`; the default announcement remains the localized `loading` string. Splash displays localized `splashLoadingStatus` in English and Persian while retaining the standard localized loading announcement.

## Performance constraints

The dimensional Earth and orbital layers are Flutter vector paint with one small transparent RAD bird PNG. The compact variant does not paint an Earth. No package, network call, video, 3D runtime, shader asset, or external artwork was added. Reusing the approved renderer removed the former duplicate loader controller and painter implementation.

## Verification record

- `test/core/rad_loading_test.dart` covers all visual tiers, one live label, Splash selection without a skeleton, Reduced Motion, active-to-inactive updates, disabled `TickerMode`, disposal after removal, and the separation of display copy from its announcement.
- `test/core/rad_earth_bird_scene_test.dart` covers direct scene lifecycle and semantics.
- `test/visual_qa_smoke_test.dart` verifies the actual pending `SplashPage` visual-QA route, light/dark section states, and light/dark compact states.
- The Phase 2 capture tool fails if any captured browser route emits a console `error`, records console observations for both dark-section contrast captures, validates an exact evidence/report manifest, and rolls back the prior set if publication fails.
- Phase 2 visual evidence and exact verification results: [`RAD_EARTH_BIRD_PHASE2_QA_REPORT.md`](RAD_EARTH_BIRD_PHASE2_QA_REPORT.md).
- Flutter lifecycle sources: [AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html), [`TickerMode.valuesOf`](https://api.flutter.dev/flutter/widgets/TickerMode/valuesOf.html), and [`CustomPaint`](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html).
