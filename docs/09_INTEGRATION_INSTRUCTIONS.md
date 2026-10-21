# Freebuff Feature Modules — Integration Handoff

Branch: `feat/rad-new-features-ui`
Code commit: `b16f71234c4e96e2539ec152f25a997d4a3000d2`
Integration owner: Antigravity (routing / shell), Grok (backend services)

This branch adds four self-contained feature modules. None of them modify
`app_router.dart`, `app_shell.dart`, migrations, or any shared routing file.
All routes are exported as ready-made `List<GoRoute>` values so integration is
a single spread addition per feature inside the existing `ShellRoute`.

## 1. Route registration (Antigravity)

In `lib/core/routing/app_router.dart`, inside the `ShellRoute` routes list,
add:

```dart
import '../../features/booking/presentation/booking_routes.dart';
import '../../features/interviews/presentation/interview_routes.dart';
import '../../features/cost_calculator/presentation/cost_calculator_routes.dart';
import '../../features/comparison/presentation/comparison_routes.dart';

// inside ShellRoute routes:
...bookingRoutes(),
...interviewRoutes(),
...costCalculatorRoutes(),
...comparisonRoutes(),
```

Resulting deep-linkable paths:

| Route | Page | Notes |
| --- | --- | --- |
| `/booking` | `BookingPage` | Catalog + booking history |
| `/booking/service/:serviceId` | `BookingServicePage` | Request form |
| `/interviews` | `InterviewsPage` | Appointment overview + request form |
| `/cost-calculator` | `CostCalculatorPage` | Published-fee breakdown |
| `/compare` | `ComparisonPage` | Side-by-side pathway grid |

If shell navigation entries (drawer/destinations) should expose these, add
them via `secondaryDestinations` or the shell's destination list — the pages
themselves use `AppBackButton(fallback: …)` so Back works with or without a
router (`GoRouter.maybeOf`).

## 2. Backend contracts required

### Booking
- `submit_consultation_request(p_topic, p_message)` — **already installed**
  (Stage 1 Migration 4, rate-limited). Consultation-type bookings use this
  real path.
- `list_service_catalog(p_locale)` → `[{id, slug, title, description, category,
  fulfillment, duration_minutes}]` — optional; when missing, the built-in
  consultation service is shown and history falls back to the
  `consultation_requests` table (RLS owner-read).
- `submit_booking_request(...)`, `list_my_booking_requests()` — **not
  installed**; the UI fails closed with an explicit "online booking is not
  deployed yet" state. Do not treat a request as confirmed until a backend
  confirmation exists.

### Interviews
- `list_my_appointments()`, `create_appointment_request(...)`,
  `reschedule_appointment(...)`, `cancel_appointment(...)` — **not
  installed**; all flows fail closed with explicit unavailable alerts.
  Appointment kinds: `rad_session` (RAD-hosted) and
  `externalGovernment` (user-recorded reminder — the UI refuses to "book"
  embassy slots and says so).
- Timezone handling: civil times are resolved through `TimezoneEngine`
  (IANA database); DST gaps produce a validation error and folds show the
  first occurrence with an ambiguity note. No offset is ever guessed when the
  tz database is unavailable.

### Cost calculator / comparison
- Both read **only** the existing verified visa catalog
  (`destinations`, `program_categories`, `visa_programs`,
  `*_localizations`, `content_sources`). No new tables or RPCs.
- No FX conversion is performed client-side. Totals combine figures only when
  they share one published currency; otherwise an explicit
  "no trusted conversion rate" notice is shown.

## 3. Delivery matrix

| Feature | Status | Routes | Backend dependency | Tests |
| --- | --- | --- | --- | --- |
| Booking | PASS (consultation path real; staff-scheduled BLOCKED by missing RPC, fails closed) | `/booking`, `/booking/service/:serviceId` | `submit_consultation_request` (installed) | 32 pass |
| Interview scheduling | PASS (request/action flows BLOCKED by missing RPCs, fail closed) | `/interviews` | appointment RPCs (not installed) | 35 pass |
| Cost calculator | PASS | `/cost-calculator` | visa catalog (existing) | 24 pass |
| University & scholarship comparison | PASS | `/universities` (already wired) | university catalog (existing) | 15 pass |
| Country & pathway comparison | PASS | `/compare` | visa catalog (existing) | 17 pass |

## 4. Verification evidence

- `flutter analyze --fatal-infos` — clean (whole package).
- `flutter test` — **805/805 pass** (108 of them cover the four new modules).
- `dart format` applied to every new/changed file.
- Widget tests cover: FA RTL + EN LTR, 390 px mobile viewports (no RenderFlex
  overflows), semantics labels, loading/empty/error/unavailable states,
  sign-in gating, and truthfulness contracts (no invented fees, prices,
  availability, or confirmations).

## 5. Known gaps / approvals needed

- Staff-scheduled booking and appointment RPCs must be designed with Backend
  (Codex/Grok) before those flows can leave the unavailable state. Contracts
  above are the client's expectations.
- Government fee figures shown by the cost calculator come strictly from
  published `fees_text`; when authorities publish only prose, the UI shows the
  wording and "no verified figure" — business may want a curated fee dataset
  later (still sourced, never hardcoded).
- No payment processing, admission guarantees, or embassy availability is
  implied anywhere in these modules.
