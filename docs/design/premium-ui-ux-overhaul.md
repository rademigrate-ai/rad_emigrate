# RAD Emigrate — Premium UI/UX Overhaul

Status: **Implementation in progress**. This document is the approved design and acceptance contract, not a claim of completed implementation.

## Approved direction

- Premium, restrained RAD red/black/white visual identity, cohesive in light/dark/system themes; preserve Vazirmatn and Persian RTL.
- Adaptive navigation: mobile safe-area-aware bottom dock with Home, Explore, **دستیار هوشمند**, Cases, Profile. Assistant bird centered and visually raised, label **دستیار هوشمند** always visible; desktop collapsible sidebar. Preserve existing route protection and browser history.
- Bird animation based on user-supplied red bird artwork; preserve recognizable silhouette, refine wing articulation for natural flapping. States: idle, listening, thinking, responding, new message. Reduce Motion and low-power/static fallback. Do not use a static PNG as evidence of real wing animation.
- Loading: branded bird for startup and major transitions, skeletons for lists/cards, scoped progress indicators for mutations; handle error, empty, offline and retry.
- Visa: continent-first grouping, search/filter, larger destination cards with properly licensed destination photography, cache and fallback. Show only real destinations and evidence-backed immigration content; missing information remains explicitly unavailable.
- World Time: photographic city/timezone cards, accurate IANA timezone clocks, day/night indicator; do not imply a country has only one timezone.
- Profile: structured identity header, grouped settings, support, about, logout; inspired by approved reference screenshots but with RAD branding and existing supported actions only.
- Guest-first exploration, protected actions gated by login, safe return routes, persisted consultation/AI drafts, **never auto-submit**.
- Responsive mobile/tablet/desktop Web and Android; keyboard navigation, focus, text scaling, contrast, RTL/LTR, performance, no overflow.
- Maintain functionality and data integrity. No fabricated services, destinations, immigration requirements or data.

## Execution plan (one initiative, staged commits)

1. Audit every route, existing theme usage, navigation and assets; establish baseline screenshots/tests.
2. Centralize theme tokens, responsive breakpoints and reusable premium components.
3. Build responsive navigation and assistant button with its persistent label; implement real wing animation assets and states with reduced-motion fallback.
4. Standardize startup/loading/error/empty/offline states.
5. Redesign Profile, Visa continent grouping and images, World Time cards.
6. Polish all remaining guest and authenticated pages, respecting existing flows and security.
7. Run Flutter format/analyze/tests, web/Android builds, route/security tests, visual regression and real browser/device smoke tests where available. Label unavailable testing BLOCKED, never PASS.
8. Update PR with evidence and final readiness status; obtain explicit user approval before merge or deploy.

## Acceptance criteria

- Every approved screen/route has coherent Light/Dark/System appearance, RTL, accessibility and responsive behavior.
- Center assistant bird has visible «دستیار هوشمند» label and five meaningful animation states; no overlap with navigation, system UI or keyboard.
- Web navigation handles deep links, history, refresh, desktop/mobile layout and protected routes.
- Every existing Visa destination and World Time card has an image or deliberate branded fallback, never broken media.
- Guest, login, draft restoration and manual-send flows retain their PR #53 guarantees.
- All required CI jobs green on a single final HEAD; actual browser and Android smoke tests recorded separately.
- No production migrations, Supabase writes, merge or deployment without explicit authorization.

## Reference assets

User provided a red bird visual reference, wing-motion storyboard, dark/light navigation concepts and profile screenshots in conversation. These references are not yet committed as reusable production assets. Asset licensing, transparency, resolution, wing-rigging and runtime performance must be verified before use.
