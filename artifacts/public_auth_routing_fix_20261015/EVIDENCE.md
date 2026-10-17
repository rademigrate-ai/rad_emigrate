# Public auth routing fix — QA evidence (2026-10-15)

Branch: `fix/public-auth-routing-20261015`
Base: `origin/main` at `28154f1` (Merge PR #47)

All screenshots were captured from a release web build
(`flutter build web` with non-production placeholder Supabase defines, same as
the CI `web-build` job) served locally with path-URL deep links, driven by
headless Chromium (Playwright).

## Screenshots

| File | Proves |
| --- | --- |
| `desktop_register_en.png` | Register form renders at `/register` on 1280×800 desktop (EN/LTR) |
| `desktop_register_fa_typed_state.png` | BUG-001: after one locale toggle the form is fully present in FA/RTL **with the typed email preserved** |
| `desktop_register_en_after_five_toggles.png` | BUG-001: five consecutive toggles later the form and typed state are still intact |
| `mobile_register_en.png` | Register form at 390×844 mobile (EN) — no kicker or button overflow |
| `mobile_register_fa.png` | BUG-001: mobile FA/RTL — long localized labels fit (previously 36 px / 183 px RenderFlex overflows) |
| `desktop_signup_alias.png` | BUG-002: `/signup` renders the register form directly |
| `desktop_unknown_route_not_found.png` | BUG-003: `/this-route-does-not-exist` shows “Page not found”, no login redirect |
| `desktop_otp_bare_redirects_to_login.png` | BUG-004: bare `/otp` resolves to `/login` (URL confirmed `.../login`) — no contextless code form |
| `desktop_otp_with_flow_context.png` | BUG-004: `/otp?identifier=qa%40example.test&mode=signup` keeps the verification form with the identifier pinned |

## Automated verification (all run on this branch, all PASS)

- `dart format --set-exit-if-changed lib test` — clean
- `flutter analyze --no-pub` — No issues found
- `flutter test --no-pub` — **298 passed**, including:
  - `test/auth/register_locale_resilience_test.dart` (new): 5 consecutive
    locale toggles × desktop 1280×900 / mobile 390×844, form state preserved,
    submit still valid; fails on base `main` (reproduced the defect),
    passes with the fix
  - `test/core/auth_redirect_test.dart` (extended): `/signup` alias rules,
    unknown-route fall-through for every auth state, protected-route
    enforcement, `/otp` flow-context rules
  - `test/core/app_router_public_routes_test.dart` (new): real
    `appRouterProvider` — `/signup` renders `RegisterPage`, unknown routes
    render `NotFoundPage`, `/dashboard` still redirects unauthenticated
    visitors to `/login`, bare `/otp` never presents the code form while
    `/otp?identifier=…` does
- `flutter build web` (CI placeholder defines) — PASS
- `flutter build apk --debug --target-platform android-arm64` — PASS
- `git diff --check` — clean
- `deno test --allow-env supabase/functions/tests` — not run locally (deno
  unavailable); `supabase/` is untouched by this branch, CI covers it

## Root causes

- **BUG-001** `lib/core/widgets/app_button.dart`,
  `lib/core/widgets/premium_visuals.dart`: `AppButton`'s label Row and
  `EditorialKicker`'s Row sized to `MainAxisSize.min` with un-bounded `Text`
  children. FA labels are longer than EN ones, so switching locale
  recalculated layout into `RenderFlex` overflow exceptions (36 px kicker,
  183 px button at 390 px; 85 px at 1280 px), breaking the register page's
  rebuild. Labels are now bounded (`Flexible` + wrap/ellipsis) and keep
  their visual identity when they fit.
- **BUG-002** `lib/core/routing/app_router.dart`,
  `lib/core/routing/auth_redirect.dart`: `/signup` did not exist and fell
  into the unknown-route branch; it is now a public alias of `/register`.
- **BUG-003** `lib/core/routing/auth_redirect.dart`: the redirect treated
  *every* non-public location as protected, so unknown routes bounced
  unauthenticated visitors to `/login`. Unknown locations now fall through
  to the router's `errorBuilder` (`NotFoundPage`) for every auth state,
  while `_protectedRoutes` enforcement is unchanged.
- **BUG-004** `lib/core/routing/auth_redirect.dart`: `/otp` rendered its
  verification form even with no pending flow. It now requires an email
  `identifier` query parameter (the only context the register and
  login-with-OTP flows ever produce) and otherwise redirects to `/login`.

## Scope safety

No changes to: AI Assistant feature, AI Companion assets, Phoenix
bird/navigation visuals, security migrations, `supabase/` production SQL,
Render configuration. Work was done in an isolated worktree on branch
`fix/public-auth-routing-20261015` cut from `origin/main`.
