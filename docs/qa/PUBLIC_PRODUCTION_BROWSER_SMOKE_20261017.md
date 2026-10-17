# RAD Emigrate — public production browser route smoke (read-only)

**Audited:** 2026-10-17, Chromium headless from authorized desktop, production `https://rad-emigrate.onrender.com`.  
**Master delivery:** [#57](https://github.com/rademigrate-ai/rad_emigrate/issues/57).  
**Evidence quality:** navigation/boot sanity only; no authenticated test user, UI visual assertions, payment, real-mail recovery, accessibility attestation, or private-action verification. The deployed frontend is **main**, not PR #58 or PR #59.

## Procedure

Headless Chromium/Puppeteer navigated each of 12 direct deep links at two viewports:
- Desktop: 1365 × 900.
- Mobile: 390 × 844.
- Checked response code, navigation errors, uncaught page errors, `flutter-view` existence, document title, document language/direction.
- Waited ~2.6 seconds after DOMContentLoaded; a separate `/login` observation at ~7.5 seconds was also performed.

## Routes examined

`/`, `/login`, `/register`, `/forgot-password`, `/reset-password`, `/dashboard`, `/visa`, `/feed`, `/ai-assistant`, `/consultation`, `/admin`, `/world-clock`.

| Probe | Evidence | Interpretation |
|---|---|---|
| Desktop direct HTTP deep links | All **12** returned HTTP **200** | SPA rewrite responding |
| Mobile direct HTTP deep links | All **12** returned **304** conditional/cache responses | Normal cache revalidation; **not** an HTTP failure |
| Headless navigation errors | 0 | Loading direct routes did not fail to navigate |
| Uncaught JavaScript `pageerror` | 0 in 24 navigations | Does not guarantee all in-app handlers work |
| Flutter view presence | 23/24 at ~2.6s | Root `/` was still on startup screen at that moment; potential cold startup UX delay |
| Additional `/login` after 7.5 seconds | `flutter-view` exists | Flutter eventually bootstraps |
| HTML `lang` vs `dir` | Observed `lang=en`, `dir=rtl` after navigation | Needs RTL/LTR audit; **not enough alone** to establish an in-app layout failure |
| Password recovery script at live URL | HTTP 404 before PR #58 deploy | Expected; PR #58 is draft/unmerged, not active Production |

**Limitations:** Flutter canvas does not expose meaningful `body.innerText`; a blank DOM text result is not evidence the user sees an empty screen. This is *not* a full page UI acceptance or an authenticated Admin authorization test. Manual browser/screenshots, keyboard/focus, screen-reader semantics, and actual logged-in workflows are still required.

**Security:** No credentials, user mutation, login attempt, SQL mutation, deployment or Feed publication. All observations are browser GETs.

## Follow-up blocking acceptance checks

1. English/Persian/RTL direction state and semantic accessibility on mobile+desktop, especially after toggling language.
2. First-load startup performance and blank/blocked loading indicators, with paint/screenshot evidence.
3. Logged-in user and admin journeys with independently authorized controlled test accounts.
4. After reviewed PR #58 is actually deployed, callback script must return HTTP 200 and real recovery token+session round-trip must pass in a controlled mailbox.
