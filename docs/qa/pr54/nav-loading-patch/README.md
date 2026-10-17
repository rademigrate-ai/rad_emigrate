# Navigation and loading fidelity patch

Baseline: `9e81a366e07186da916946756720c2a8a6ccc755`, fetched on the existing PR 54 branch with a clean working tree. The four owner-supplied boards were inspected at original resolution. Earlier navigation MATCHED classifications are historical QA assessments, not owner acceptance.

## Measured discrepancies before changes

| Area | Existing implementation/render | Approved target and scoped correction |
|---|---|---|
| Capsule contour | 96 px reserved height; side top at y=24, center top at y=1: a 23 px hump | Continuous rounded capsule with a straight top edge; retain safe-area insets and five destinations |
| Glass | Light opacity .88-.96 and dark .83-.92; 18 px blur | More translucent pearl/smoky surface, soft edge highlight and stronger diffusion |
| Bird | 60 px frame, approximately 50 px visible artwork, plus a circular orb/rim | Larger raised original bird, no circular frame; diffuse glow only |
| Selection/icons | 26 px icons, underline-only selection; globe for Explore | 24 px icons, compass Explore and a soft red selected background |
| Loading scale | Full 280 px, section 120 px, compact 40 px | Full 128 px, section 72 px, compact 32 px; restrained bird proportions within each context |
| Loading aura | Large stroked circular ring around full/section bird | Diffuse red light without a visible ring; keep original layered colors and six-stage articulation |
| Full-screen composition | Bird/skeleton stack; parent atmosphere varies | Centered bird and operation text on a restrained pearl/near-black atmosphere; skeletons stay in section/list feedback |
| Short-operation button | 20 px white silhouette on the disabled surface | 28 px original layered red bird; disabled callbacks and the existing neutral surface remain |

Before evidence is reused from the existing actual Flutter captures: [FA light navigation](../fidelity/screens/mobile-fa-light-shell.png), [FA dark](../fidelity/screens/mobile-fa-dark-shell.png), [EN light](../fidelity/screens/mobile-en-light-shell.png), [EN dark](../fidelity/screens/mobile-en-dark-shell.png), [loading tiers](../fidelity/screens/mobile-fa-dark-loading.png). The captured navigation/loading code is identical to baseline; the intervening desktop-label correction does not affect these widgets.

Capture budget: **seven after screenshots only** — navigation EN/FA in light/dark, full-screen loading, section loading and inline/card short-operation loading. No full matrix or new assets. If a capture fails technically, diagnose it before retrying that single failed view.

All routes, callbacks, semantics, keyboard shortcuts, RTL order, six-stage kinetics, ticker lifecycle and Reduced Motion behavior remain in scope for regression verification. No other pages are redesigned.

## Focused result

Implementation source: `ab13c5a18c4f84a3ea91427e8feb6cbd7f915360`; application tree `063a30b8298b8727b79c7c69e8ed7d878eb1ac4e`. The QA build used the identical application tree. Exactly seven after screenshots were captured in one pass, with zero browser errors, and inspected at original resolution. No further capture pass is planned.

| View | Before | After |
|---|---|---|
| Navigation EN / light | [Existing](../fidelity/screens/mobile-en-light-shell.png) | [Result](after/nav-en-light.png) |
| Navigation EN / dark | [Existing](../fidelity/screens/mobile-en-dark-shell.png) | [Result](after/nav-en-dark.png) |
| Navigation FA / light | [Existing](../fidelity/screens/mobile-fa-light-shell.png) | [Result](after/nav-fa-light.png) |
| Navigation FA / dark | [Existing](../fidelity/screens/mobile-fa-dark-shell.png) | [Result](after/nav-fa-dark.png) |
| Full-screen loading | [Existing tier showcase](../fidelity/screens/mobile-fa-dark-loading.png) | [Result](after/loading-full.png) |
| Section/list loading | [Existing tier showcase](../fidelity/screens/mobile-fa-dark-loading.png) | [Result](after/loading-section.png) |
| Inline/card and short operation | [Existing tier showcase](../fidelity/screens/mobile-fa-dark-loading.png) | [Result](after/loading-inline-short.png) |

The capsule now has a uniform top at y=12 and an 83 px body within the unchanged 96 px reserved area; no 23 px center hump remains. Side/bottom margins remain 12/8 px outside device-safe insets. The 76 px bird frame is 27% larger than before, with no orb/rim; surrounding icons are 24 px. Blur is 32 px, with .76-.86 light and .72-.86 dark surface opacity. Selection uses a 46 px soft red background. These are logical component measurements, not a raw pixel similarity score.

The three loading views show smaller original birds, diffuse red light without outlined rings, and real supported pending controls. Full-screen feedback centers the bird and text without a synthetic skeleton; sections retain skeletons. The short-operation button preserves the layered red asset and remains disabled against duplicate submission. English fixture captions in these QA loading hosts are not production localization changes. Before/after loading framing differs; compare the bird, scale, aura and context rather than subtracting unlike images.

See [asset/behavior preservation](preservation.json), [capture manifest](after/manifest.json), and [final verification](verification.json). The full Flutter suite covers safe-area geometry, EN/FA, both themes, narrow/large text, keyboard activation, semantics, lifecycle and Reduced Motion. No business, auth, backend, content, dependency or migration files changed.

## Remaining differences and stop point

Major identified navigation/loading discrepancies are corrected. This is a focused visual improvement for owner review, not a renewed MATCHED or pixel-perfect claim. The immutable supplied bird has a taller wing/tail silhouette than some conceptual illustrated poses; its anatomy and six-stage kinetics are retained. The actual short-operation button keeps its existing neutral disabled surface rather than the illustrative red pending button. Device bezels/system gesture bars and native rendering differ from browser fixtures. Physical-device/native-keyboard testing and production service operations were not performed.

The original bird PNGs are byte-identical. No alternative artwork or animation package was invented. Other pages and the second clone are untouched. PR 54 remains Draft: no merge, deployment, production Supabase change or destructive cleanup.
