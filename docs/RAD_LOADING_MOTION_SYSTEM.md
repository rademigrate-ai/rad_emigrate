# RAD Loading Motion System

## Purpose

RAD Emigrate now uses a single loading identity whenever a meaningful pending operation is visible: an atmospheric Earth, cyan orbital trail, and the **original RAD bird silhouette** in solid RAD red. The bird asset is deterministically derived from `assets/branding/rad_official_logo.png`; it is not a generic icon or third-party substitute.

The implementation lives in `lib/core/widgets/rad_loading.dart`. It uses one lifecycle-owned `AnimationController`, `CustomPainter(repaint: controller)`, and a `RepaintBoundary`, so only the loader scene repaints instead of the surrounding screen.

## Tiers

| Tier | Component | Intended use | Visual behavior |
| --- | --- | --- | --- |
| Full-screen | `RadLoadingIndicator(size: RadLoadingSize.fullScreen)` | Splash/app initialization | Larger cyan Earth, red bird orbit, status copy, and skeletal content preview |
| Section | `LoadingState.section(...)` or `RadLoadingIndicator(size: RadLoadingSize.section)` | Visa catalogue, applications, documents, feed, admin operations, notifications, profile | Medium Earth-and-bird scene with status and skeleton context |
| Compact | `RadInlineLoading(...)` or `LoadingState.compact(...)` | Dashboard updates, document upload, application status update, AI response row, admin AI configuration | Red bird orbit with cyan ellipse only; it omits the Earth to remain low-cost in dense layouts |

## Pending-state mapping

| Product surface | Pending signal | RAD variant | Failure behavior |
| --- | --- | --- | --- |
| Splash | `appBootstrapProvider.future` | Full-screen | Existing safe unauthenticated route remains the fallback |
| Visa catalogue | `visaCatalogProvider(...).loading` | Section | Existing `ErrorState` with catalog retry |
| Applications | `applicationControllerProvider.loading` | Section | Existing `ErrorState` with controller retry |
| Application status update | `_updatingStatus` | Compact | Existing failure `SnackBar` remains |
| Documents | `documentControllerProvider.loading` | Section | Existing `ErrorState` with controller retry |
| Document upload | `uploading.value` | Compact | Existing upload failure `SnackBar` remains |
| Feed | `feedProvider(...).loading` | Section | Existing `ErrorState` with provider invalidation |
| Dashboard updates | nested `feedProvider(...).loading` | Compact | Existing retry shortcut remains |
| AI Assistant | `_loading` response row | Compact | Existing failed-response/retry message remains |
| Admin operations and consultations | provider / `_loading` state | Section | Existing `ErrorState` paths remain |
| Admin AI configuration | `adminConsoleProvider.loading` | Compact | Existing configuration unavailable message remains |
| Notifications and profile | `_loading` / profile provider state | Section | Existing errors remain visible |

Ordinary button and dialog submit spinners remain intentionally unchanged. Replacing every spinner with the Earth scene would be slower, noisier, and inappropriate for controls where the existing button label already conveys the pending action.

## Motion, lifecycle, and accessibility

The loader starts only while a real page/provider/operation pending branch renders it. On success, error, cancellation, or route replacement, Flutter removes the loader and its controller is disposed. The existing error branches are preserved instead of masking a failed operation with permanent loading feedback.

The component checks both `MediaQuery.disableAnimations` and `TickerMode.valuesOf(context).enabled`. If a user requests reduced motion or the loader is not in an active ticker subtree, the controller stops and a static branded composition remains visible. Its single `Semantics` container is a live region using the localized or operation-specific loading label; decorative painted layers and the bird asset are excluded from the accessibility tree.

## Performance constraints

The full and section variants use vector painting for the Earth, trails, atmosphere, and cloud/continent shapes. The only image is the small transparent RAD bird PNG. The compact variant does not paint an Earth. No package, network call, video, 3D runtime, or shader asset has been added.

## Verification record

- `test/core/rad_loading_test.dart` covers all visual tiers, live labels, reduced motion, inactive/static behavior, and shared `LoadingState` constructor selection.
- `test/visual_qa_smoke_test.dart` verifies that the isolated visual QA entrypoint renders all three loading tiers.
- Visual evidence: `docs/visual_qa/loading_motion_desktop.png`, `docs/visual_qa/loading_motion_mobile.png`, and `docs/visual_qa/loading_motion.gif`.
- The Flutter animation lifecycle pattern is based on the official [Flutter animation tutorial](https://docs.flutter.dev/ui/animations/tutorial), and current ticker-state usage follows [`TickerMode.valuesOf`](https://api.flutter.dev/flutter/widgets/TickerMode/valuesOf.html).
