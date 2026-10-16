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

Before evidence is reused from the existing actual Flutter captures: [FA light navigation](../fidelity/screens/mobile-fa-light-shell.png), [FA dark](../fidelity/screens/mobile-fa-dark-shell.png), [EN light](../fidelity/screens/mobile-en-light-shell.png), [EN dark](../fidelity/screens/mobile-en-dark-shell.png), [loading tiers](../fidelity/screens/mobile-fa-dark-loading.png). The captured navigation/loading code is identical to baseline; the intervening desktop-label correction does not affect these widgets.

Capture budget: **seven after screenshots only** — navigation EN/FA in light/dark, full-screen loading, section loading and inline/card short-operation loading. No full matrix or new assets. If a capture fails technically, diagnose it before retrying that single failed view.

All routes, callbacks, semantics, keyboard shortcuts, RTL order, six-stage kinetics, ticker lifecycle and Reduced Motion behavior remain in scope for regression verification. No other pages are redesigned.
