# RAD Earth-and-Bird Phase 2 Loading Design

**Status:** Approved by the project owner on 2026-10-08 for local implementation only.
**Canonical visual baseline:** approved Login Hero scene at `1a31d31`; Login visual-gate record at `16ee7e8`.

## Goal

Propagate the **already approved** dimensional RAD Earth-and-red-bird scene to Splash and the three existing loading densities without changing Login, Registration, authentication, Supabase integration, provider/business logic, or unrelated product UI.

## Scope and invariants

### In scope

| Surface | Variant | Required result |
| --- | --- | --- |
| `SplashPage` while `appBootstrapProvider.future` is pending | `splash` | Prominent centered dimensional Earth, original red RAD bird, cinematic dark premium canvas, visible localized status; no generic skeleton preview. |
| Existing full-screen loading state | `fullScreenLoading` | Same rich Earth-and-bird visual on the existing full-loading layout. |
| Existing provider-backed section states | `sectionLoading` | Smaller dimensional Earth-and-bird scene readable on both light and dark backgrounds. |
| Existing inline non-button pending states | `compactLoading` | Original red bird and one restrained cyan ellipse only; no Earth. |

### Explicitly preserved

- The approved Login Hero composition, its `RadEarthBirdScene(loginHero)` instance, all Login/Registration/auth behavior, routes, validation, copy, and responsive geometry.
- Existing real pending/error branches: providers and local state still decide whether a loader mounts; existing `ErrorState`, retry controls, and failure `SnackBar` paths remain unchanged.
- Existing generic button/dialog progress indicators. They remain appropriate control-local feedback and are not replaced by an Earth scene.
- Existing `RadLoadingSize`, `LoadingState`, and `RadInlineLoading` call sites, so provider mapping requires no business-logic change.
- Existing Reduced Motion, `TickerMode`, RTL/LTR, live-region semantics, `RepaintBoundary`, and controller-disposal behavior.
- No packages, remote media, shaders, 3D runtime, external assets, network requests, merge, push, or deployment.

## Architecture

`RadEarthBirdScene` is the only renderer for the Earth, orbit geometry, original bird asset, animation lifecycle, and paint-layer depth ordering. The prior duplicate painter/controller in `rad_loading.dart` is removed.

`RadLoadingIndicator` remains the stable loading adapter. It keeps the existing public `RadLoadingSize` API, visible status copy, `active`, `dark`, and live semantic label, while internally mapping sizes to the approved scene variants:

| Existing loading size | Default scene variant |
| --- | --- |
| `fullScreen` | `fullScreenLoading` |
| `section` | `sectionLoading` |
| `compact` | `compactLoading` |

A dedicated additive `RadLoadingIndicator.splash` constructor resolves `RadEarthBirdVariant.splash`; it is intentionally not a public generic override so callers cannot combine incompatible visual tiers. `LoadingState.splash` uses that constructor with a full-screen layout and no skeleton preview. `SplashPage` changes only from `LoadingState.fullScreen` to `LoadingState.splash`.

The adapter owns the live loading announcement and wraps the decorative scene in `ExcludeSemantics`, preserving exactly one meaningful live region. `RadEarthBirdScene` continues to own animation for the visual subtree: it starts only when active, Reduced Motion is off, and `TickerMode.valuesOf(context).enabled`; it is disposed when its pending-state parent disappears.

## Visual-QA and evidence plan

The non-production `visual_qa_main.dart` entrypoint will expose:

- `splash`: the actual `SplashPage` held in its real pending state via a never-completing visual-QA override of `appBootstrapProvider`;
- `loading-full`: actual `LoadingState.fullScreen`;
- `loading-section`: actual section loaders on both light and dark contrast surfaces;
- `loading-compact`: actual compact loaders on both light and dark surfaces.

A Playwright/Chromium script will generate a **native-timing 12–15 second MP4** plus desktop (1280×800) and mobile (390×844) screenshots for each surface. It uses synthetic/placeholder app state only, never credentials or customer data. The visual review explicitly rejects a flat/wireframe globe, low-contrast art, generic bird, lost back/front occlusion, or a compact Earth.

## Acceptance tests

1. `RadLoadingIndicator` maps full, section, and compact sizes to `RadEarthBirdScene` variants while preserving a single live semantic announcement.
2. `LoadingState.splash` maps to `RadEarthBirdVariant.splash`, shows status copy, and omits its generic skeleton preview.
3. Reduced Motion, disabled `TickerMode`, inactive updates, and disposal remain green through the shared scene tests.
4. The visual QA route for Splash mounts the real `SplashPage` in a pending state; all four visual-QA routes build without errors.
5. Existing full `flutter test` suite, analysis, formatting, web build, and Android debug build pass after the migration.

## Performance and implementation sources

No optimization hypothesis is introduced: the migration removes a duplicate animated painter/controller and delegates to the existing `RepaintBoundary`-bounded renderer. Production web-output bytes will be measured before and after the same build command.

- [Flutter `AnimationController` lifecycle](https://api.flutter.dev/flutter/animation/AnimationController-class.html): controllers created in `initState` should be disposed in `dispose`; `repeat` and `stop` control the ticker lifecycle.
- [Flutter `TickerMode.valuesOf`](https://api.flutter.dev/flutter/widgets/TickerMode-class.html): establishes the inherited ticker-mode dependency for the subtree.
- [Flutter `CustomPaint`](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html): painters remain bounded by their layout rectangle; `isComplex` and `willChange` are compositor-cache hints.
