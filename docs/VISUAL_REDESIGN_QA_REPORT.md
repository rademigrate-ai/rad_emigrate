# RAD Visual Redesign — Delivery and QA Report

**Date:** 2026-10-08  
**Comparison baseline:** commit `02dc1d8`  
**Reference reviewed:** [Bixa](https://bixa.ai/) public landing page, observed directly in a browser

## What changed

The redesign creates an original RAD visual language around a **midnight-navy journey canvas**, restrained teal/cyan coordinates, the official supplied RAD mark, and red primary actions. It does not reuse Bixa code, imagery, copy, or branding.

### Shared visual system

- New Flutter-rendered `PremiumCanvas`, editorial index/kicker, custom RAD orbital route artwork, cinematic auth frame, and premium hero surfaces.
- Thin coordinate-grid texture, localized teal light, red route markers, rounded but structured panels, and editorial labels such as `01 / YOUR JOURNEY`.
- Responsive artwork: mobile hides purely decorative hero orbit artwork where it could overlap actions.
- Motion remains reduced-motion-aware through the existing centralized tokens. Idle AI artwork is static; processing feedback remains tied to an active request state.

### High-impact product areas

| Area | Redesigned result |
|---|---|
| Authentication | Cinematic two-panel login and registration; the mobile version becomes a compact dark journey masthead and elevated form surface. All existing validation and navigation remain intact. |
| Splash | Full-screen RAD orbit loader with semantic progress feedback. |
| Dashboard | Editorial journey hero, visible next-action state, dark data metrics, and scanable quick-action rail. |
| Visa discovery | Pathway-explorer header, source/disclaimer-preserving search deck, structured filters, and contrast-rich destination cards. |
| Applications | Case-room header and numbered case tiles with status color only reflecting existing status data. |
| AI workspace | Dark intelligence canvas, high-contrast chat bubbles, focus-safe composer, and visual QA-only synthetic processing state. |
| Feed | Briefing header and editorial update cards. |
| Admin hub | Full command-deck surface with a strong operations hierarchy. |

## Before / after evidence

The login comparison uses the same unauthenticated route, language, and viewport against commit `02dc1d8` and the current working tree.

| Viewport | Before | After |
|---|---|---|
| Desktop, 1280×800 | [Before login](visual_qa/login_before_desktop.png) | [After login](visual_qa/login_after_desktop.png) |
| Mobile, 390×844 | [Before login](visual_qa/login_before_mobile.png) | [After login](visual_qa/login_after_mobile.png) |

### Current desktop product surfaces

| Surface | Screenshot |
|---|---|
| Dashboard | [Dashboard desktop](visual_qa/dashboard_after_desktop.png) |
| Visa explorer | [Visa desktop](visual_qa/visa_after_desktop.png) |
| AI workspace | [AI desktop](visual_qa/ai_after_desktop.png) |
| Feed | [Feed desktop](visual_qa/feed_after_desktop.png) |
| Admin command deck | [Admin desktop](visual_qa/admin_after_desktop.png) |

### Current mobile product surfaces

| Surface | Screenshot |
|---|---|
| Dashboard | [Dashboard mobile](visual_qa/dashboard_after_mobile.png) |
| Visa explorer | [Visa mobile](visual_qa/visa_after_mobile.png) |

> The Dashboard, Visa, AI, Feed, and Admin screenshots are rendered by the isolated `lib/visual_qa_main.dart` entrypoint. The entrypoint imports actual screen implementations but overrides data with clearly labeled synthetic, non-customer records. It is not referenced from the production app router.

### Actual motion evidence

[Login orbit and focused-field feedback — MP4](visual_qa/login_motion_focus.mp4) and [GIF preview](visual_qa/login_motion_focus.gif) were captured from the rendered production entrypoint using Chromium. The capture includes the real focal-orbit movement and a real email-field focus interaction; it is not a mock animation.

## Validation performed

| Check | Result |
|---|---|
| `dart format lib test` | Passed |
| `flutter analyze` | Passed with no issues |
| `flutter test test/visual_qa_smoke_test.dart` | Passed: Login, Dashboard, Visa, AI, Feed, Admin layouts |
| `flutter test test/ai_assistant/ai_assistant_page_test.dart` | Passed: 4 tests |
| Full `flutter test` | Re-run after the final no-settle repair before merge |
| Production web build | Built with placeholder Supabase build-time values only; no credentials recorded in the repository |
| QA web build | Built from `lib/visual_qa_main.dart` with synthetic data only |

## Functional boundaries retained

- No auth flow, token behavior, Supabase schema, database contents, backend, hosting, or environment configuration changes were made.
- The project’s primary user data and business actions are untouched. The optional QA entrypoint uses synthetic data exclusively.
- No fictional immigration approvals, visa requirements, official processing times, customer claims, or statistics were introduced.
