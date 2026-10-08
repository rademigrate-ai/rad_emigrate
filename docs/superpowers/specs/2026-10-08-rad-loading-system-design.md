# RAD Loading Motion System Design

**Status:** Approved implementation brief transcribed from the request on 2026-10-08.

## Goal

Replace generic app, screen, section, and appropriate inline loading feedback with one recognisable RAD loading system: a cyan-accented Earth with the official red RAD bird travelling a smooth orbit. The design must never conceal pending-operation failures, must respect system Reduced Motion, and must stay inexpensive on Flutter Web and Android.

## Constraints

- Use the owner-supplied RAD mark and derive a dedicated, solid-red bird-only asset from it; do not introduce stock or generated logo artwork.
- Keep existing repository logic, authentication, Riverpod pending/error states, retry behavior, and button submission behavior unchanged.
- Provide only three presentation tiers:
  - **Full-screen:** Earth, orbiting bird, status copy, and restrained skeleton preview for app bootstrap.
  - **Section:** smaller Earth-and-bird scene with message and lightweight skeleton for data-backed screen content.
  - **Compact:** small red RAD bird orbit for chat, dashboard refresh, upload, and status-update feedback.
- Keep conventional button spinners inside buttons and tiny dialog submit controls; those are intentionally not promoted to a visual scene.
- The loader is created only by existing `AsyncValue.loading` or boolean pending branches, so it is disposed automatically when data or an error arrives.
- Existing `ErrorState` branches remain responsible for user-visible errors and retry actions.
- Honor `MediaQuery.disableAnimations` and `TickerMode`; reduced-motion mode presents the same branded static scene without a repeating ticker.
- Use Flutter framework primitives only. No animation package, network request, shader asset, or 3D dependency is introduced.

## Architecture

### Public component contract

`lib/core/widgets/rad_loading.dart` will provide:

- `RadLoadingSize { fullScreen, section, compact }` — semantic visual tier rather than arbitrary dimensions.
- `RadLoadingIndicator` — the reusable visual scene. It accepts `size`, `label`, `active`, `dark`, and optional `message`; it owns and disposes its `AnimationController`.
- `RadInlineLoading` — a constrained compact convenience wrapper for inline layouts.

`lib/core/widgets/loading_state.dart` will remain the existing loading-state integration point and expose named constructors:

- `LoadingState.fullScreen(...)`
- `LoadingState.section(...)`
- `LoadingState.compact(...)`

The default constructor remains a section-level state for compatibility with existing page branches.

### Rendering and performance

The Earth is a 2.5D `CustomPainter` composed of a clipped radial sphere, rotated cyan latitude/longitude arcs, soft cloud/continent shapes, rim lighting, and an orbital trail. The official bird-only asset is displayed in its own transformed layer above the painter. `CustomPainter(repaint: controller)` and one `RepaintBoundary` isolate repaint work to the loading scene; no full-page rebuild occurs per frame.

The orbit has slight perspective and forward rotation so the mark reads as a bird moving around a globe, not as a generic dot. The compact tier paints no globe and moves only the red bird around a cyan ellipse.

### Pending and error flow

No provider, repository, or controller API changes are needed. Existing loading branches instantiate the right visual tier; their existing `ErrorState`, `SnackBar`, and retry branches continue unchanged. Therefore a loader begins only with a real pending operation and stops as soon as its branch leaves loading.

### Screen mapping

| Surface | Existing pending signal | Variant |
| --- | --- | --- |
| Splash/app bootstrap | `appBootstrapProvider.future` while routing | Full-screen |
| Visa, Applications, Documents, Feed, Admin operations/consultations | page `AsyncValue.loading` or `_loading` | Section |
| Admin AI configuration provider list | nested `AsyncValue.loading` | Compact |
| Dashboard updates | `feedProvider(locale).loading` | Compact |
| Document upload sheet | `uploading.value` | Compact |
| Application status transition | `_updatingStatus` | Compact |
| AI message generation | `_loading` message row | Compact |
| Notifications and Profile first data load | `_loading` / `profileState.loading` | Section |

## Accessibility and motion behavior

Each loader exposes one `Semantics` live-region label using existing localized loading copy. Decorative Earth, trail, and bird layers are excluded from the accessibility tree. Reduced Motion and off-stage `TickerMode` halt the controller, preserve a readable static composition, and avoid an animation loop.

## Verification

1. Widget tests prove all three variants render, preserve their live-region label, and remain stable when reduced motion is enabled.
2. Widget tests exercise active-to-inactive updates so a loader does not depend on an orphaned ticker.
3. Existing screen, accessibility, and full Flutter tests still pass.
4. A built local web QA route captures desktop and mobile loading variants and a short real motion recording.
5. `flutter analyze`, `flutter test`, web build, and Android debug build pass before delivery.

## Framework sources

- Flutter animation tutorial: https://docs.flutter.dev/ui/animations/tutorial — `AnimationController` receives a `vsync`, reusable animated content can be separated through `AnimatedBuilder`, and controllers are disposed with their state.
- Flutter accessibility guidance: https://docs.flutter.dev/ui/accessibility — Flutter recommends accessible, intelligible screen-reader descriptions, visible error feedback, and UI that remains usable with system accessibility preferences.
