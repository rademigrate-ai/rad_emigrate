# RAD Earth-and-Bird Scene Design

**Status:** Approved for Phase 1 implementation by the project owner on 2026-10-08.

## Purpose

Restore `cc8e015` (`feat(ui): deliver cinematic RAD visual redesign`) as the canonical premium visual baseline and replace **only** the Login Hero's central white RAD-logo tile with a cinematic, dimensional Earth and the supplied solid-red RAD bird silhouette. The same scene is designed for later reuse by Splash and loading states, but this document authorizes only the Login Hero until the owner approves the resulting visual evidence.

## Visual authority and scope

### Canonical baseline

- **Commit:** `cc8e015`
- **Desktop evidence:** `docs/visual_qa/login_after_desktop.png`
- **Mobile evidence:** `docs/visual_qa/login_after_mobile.png`
- **Supplied composition reference:** `CosmicImmigrationLoginPortal.png` attached by the project owner on 2026-10-08.

The approved baseline remains the authority for Login topology, typography, copy, color palette, spacing, glass panel, route transitions, responsive breakpoints, RTL/LTR behavior, and the surrounding premium orbit composition. The supplied reference guides only the Earth treatment, richer depth, and front/back bird flight; it does not authorize changes to the Login form, factual copy, or product layout.

### Explicitly preserved

- Midnight-navy `PremiumCanvas`, cyan atmospheric glow, diagonal texture, red route marker, and original editorial composition.
- Existing split-screen desktop layout and stacked mobile masthead/form layout.
- Existing glass authentication form, controls, field validation, loading behavior, keyboard flow, localization, and auth routing.
- Existing `RadOrbit` consumers outside Login. Their current artwork is out of scope for Phase 1.
- Current real pending-state mapping, loader semantics, reduced-motion behavior, and generic button spinners.

### Explicitly out of scope for Phase 1

- Replacing the live Splash or the existing full-screen, section, and compact loader artwork.
- Modifying Dashboard, Visa, AI, Feed, Admin, Register, or other route artwork.
- Changing business logic, provider state, auth state, API calls, localization behavior, or app routing.
- Adding packages, third-party rendering runtimes, external assets, or copied Bixa material.

## Component contract

Create a core presentation component in `lib/core/widgets/rad_earth_bird_scene.dart`.

```dart
enum RadEarthBirdVariant {
  loginHero,
  splash,
  fullScreenLoading,
  sectionLoading,
  compactLoading,
}

class RadEarthBirdScene extends StatefulWidget {
  const RadEarthBirdScene({
    super.key,
    required this.variant,
    required this.semanticLabel,
    this.size,
    this.active = true,
    this.dark = true,
  });

  final RadEarthBirdVariant variant;
  final String semanticLabel;
  final double? size;
  final bool active;
  final bool dark;
}
```

The component is intentionally visual-only. It neither owns network/auth state nor decides whether an operation is pending. Its parent controls `active`; removing the parent removes and disposes its controller.

The public enum expresses the planned visual family without migrating the non-Login surfaces in Phase 1. `loginHero` is the only variant mounted by production code in this phase.

## Scene composition

### Earth

The Earth is an original Flutter-rendered scene, not a borrowed texture, a wireframe globe, or a generic low-detail circle:

1. A clipped spherical ocean disc uses a deep-blue radial gradient with an offset highlight and terminator shadow.
2. Recognizable, stylized Eurasia/Africa and Americas continent silhouettes sit inside the disc. A clipped horizontal translation and slight parallax shift creates slow apparent planetary rotation without a 3D runtime.
3. Low-opacity cloud/rim layers and a restrained cyan edge light establish depth; no grid latitude/longitude wireframe may dominate the object.
4. The existing thin orbital lines remain outside the Earth and keep their current quiet cyan/red hierarchy.

### Bird and orbit

- The bird uses `assets/branding/rad_bird_silhouette.png`, which is derived from the supplied official RAD logo and contains no lettering or opaque background.
- `ColorFiltered` supplies the exact solid `AppColors.primaryRed`; no new bird illustration is introduced.
- One closed elliptical path drives position, tangent-facing rotation, and a restrained depth scale. The scene should complete a calm orbit in approximately 10–12 seconds for the Login Hero.
- Layering is explicit: the back-half bird is drawn below the Earth, while the near-half bird is drawn above it. The crossover is eased over a small phase band to avoid a visible pop.
- The orbit motion must be continuous: controller repeats from an identical phase, and no reset/spin is visible at the loop boundary.

### Accessibility and motion

- The scene is a single semantic image/status with the parent-provided label. The Earth, decorative orbit lines, and bird image are excluded from the semantics tree.
- It starts only when `active`, `TickerMode.valuesOf(context).enabled`, and reduced motion is not requested.
- Reduced motion and disabled ticker mode render a stable, well-composed phase without a running ticker.
- The controller is created in `initState`, updates through widget/dependency changes, and is disposed in `dispose`.
- A `RepaintBoundary` encloses the scene. Custom paint uses the controller as its repaint notifier so the surrounding form does not rebuild per frame.

## Login integration

`AuthCinematicFrame` gains one optional visual slot for the hero centerpiece. The fallback is the existing `RadOrbit`, preserving Register and every current non-Login consumer. `LoginPage` passes a `RadEarthBirdScene` configured as `loginHero`; no form, controller, router, copy, or auth-provider behavior changes.

Desktop maintains the current central position and outer orbit scale; mobile uses the existing 288 px hero masthead with a proportional scene that stays clear of the form surface. The Earth remains visually readable without overlapping the editorial label or the panel transition.

## Future loading rollout — held behind visual approval

After the Login Hero is visually approved, the same component will be adapted without a second visual language:

| Variant | Intended surface | Rule |
| --- | --- | --- |
| `splash` / `fullScreenLoading` | App bootstrap and major screen loading | Large premium Earth-and-bird scene on the existing dark premium canvas. |
| `sectionLoading` | Provider-backed page regions | Medium Earth-and-bird scene with light/dark contrast support. |
| `compactLoading` | Inline pending feedback | Exact recognizable red bird plus one restrained cyan ellipse; no Earth and no replacement of button spinners. |

The current loading-state architecture remains in place until the owner approves the Phase 1 Login evidence.

## Verification contract

### Automated

- A red/green widget test proves the scene mounts as `loginHero`, honors reduced motion and disabled ticker mode, exposes one semantic label, and disposes cleanly after removal.
- Existing auth and motion tests remain green.
- Production web build, Flutter analysis, format, full test suite, and Android build run after Phase 1.

### Actual Flutter visual evidence

The Login Hero gate requires a production Flutter route recording—never a static concept or only synthetic QA—with:

1. One 10–15 second desktop recording containing a complete bird orbit and visible front/back Earth occlusion.
2. Desktop Login screenshot at 1280×800.
3. Mobile Login screenshot at 390×844.
4. A comparison to the approved `cc8e015` captures showing that the composition is unchanged outside the central scene.
5. Browser console and accessibility-tree checks for the production route.

Phase 2 loading migration stops until the project owner explicitly approves this evidence.

## Implementation sources

- Flutter `AnimationController` lifecycle: <https://api.flutter.dev/flutter/animation/AnimationController-class.html>
- Flutter `CustomPaint` repaint and bounds guidance: <https://api.flutter.dev/flutter/widgets/CustomPaint-class.html>
- Flutter `TickerMode.valuesOf` state dependency: <https://api.flutter.dev/flutter/widgets/TickerMode-class.html>
