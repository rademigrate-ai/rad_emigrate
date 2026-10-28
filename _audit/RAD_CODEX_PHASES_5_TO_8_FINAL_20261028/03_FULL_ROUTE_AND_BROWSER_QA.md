# RAD EMIGRATE — FULL ROUTE & BROWSER QA REPORT
**Date:** 2026-10-28  
**Scope:** Authoritative Registered Routes in `lib/core/routing/app_router.dart` and `auth_redirect.dart`  
**Execution:** `test/core/app_router_public_routes_test.dart`, `test/core/app_router_protected_routes_matrix_test.dart`, Local SPA Server at `http://127.0.0.1:64331/`  

---

## 1. ROUTE DEFINITIONS & ACCESS CONTROL AUDIT

| Route Path | Category | Access Rule | Destination / Component | Verified Behavior |
|---|---|---|---|---|
| `/` | System | Auto Redirect | `/splash` or `/dashboard` | Redirects safely based on bootstrap state |
| `/splash` | Public | Unrestricted | `SplashPage` | Boots session; redirects unauthenticated visitors to `/dashboard` |
| `/login` | Public Auth | Unrestricted | `LoginPage` | Accepts `from` query param; redirects authenticated users |
| `/register` | Public Auth | Unrestricted | `RegisterPage` | Signup form with 3 fields |
| `/signup` | Public Auth | Alias | `RegisterPage` | Alias to `/register` verified |
| `/otp` | Public Auth | Conditional | `OtpPage` | Requires signup identifier; bare `/otp` falls back to login |
| `/forgot-password` | Public Auth | Unrestricted | `ForgotPasswordPage` | Email validation, back button |
| `/reset-password` | Public Auth | Deep Link | `ResetPasswordPage` | Validates recovery tokens |
| `/profile-completion`| Auth Flow | Authenticated | `ProfileCompletionPage` | Triggered when `profileComplete == false` |
| `/dashboard` | Public In-App | Guest Allowed | `DashboardPage` | Full guest explore mode |
| `/explore` | Public In-App | Alias | `VisaPage` | BUG-L01 alias verified |
| `/visa` | Public In-App | Guest Allowed | `VisaPage` | Canonical explorer route |
| `/visa/:countryId/:category` | Public | Guest Allowed | `VisaPage` | Canonical rich continuous page |
| `/universities` | Public In-App | Guest Allowed | `UniversityScholarshipPage`| Authoritative university catalog |
| `/feed` | Public In-App | Guest Allowed | `FeedPage` | Filterable news feed |
| `/world-clock` | Public In-App | Guest Allowed | `WorldClockPage` | Multi-timezone clock |
| `/ai-assistant` | Public In-App | Guest Allowed | `AiAssistantPage` | Free tier limits respected |
| `/consultation` | Public In-App | Guest Allowed | `ConsultationPage` | Supports optional `topic` param |
| `/booking` | Public In-App | Guest Allowed | `BookingPage` | Service category overview |
| `/booking/service/:serviceId`| Public | Guest Allowed | `BookingServicePage` | Service detail booking |
| `/interview-scheduling` | Public In-App | Guest Allowed | `InterviewSchedulingPage` | **FIXED (BUG-001)**: Opens dedicated page & consultation CTA |
| `/interviews` | Public In-App | Guest Allowed | `InterviewsPage` | User interview appointment request form |
| `/calculator/cost` | Public In-App | Guest Allowed | `CostCalculatorPage` | Currency calculator |
| `/compare/pathways` | Public In-App | Guest Allowed | `PathwayComparisonPage` | Visa comparison |
| `/compare/universities` | Public In-App | Guest Allowed | `UniversityComparisonPage`| University comparison |
| `/profile` | Public In-App | Guest Allowed | `ProfilePage` | Shows login prompt if unauthenticated |
| `/profile/immigration` | Public In-App | Guest Allowed | `ImmigrationProfilePage` | Drafts immigration details |
| `/applications` | Protected | Authenticated | `ApplicationsPage` | Redirects guest to `/login?from=%2Fapplications` |
| `/documents` | Protected | Authenticated | `DocumentsPage` | Redirects guest to `/login?from=%2Fdocuments` |
| `/documents/draft` | Protected | Authenticated | `DocumentDraftPage` | Redirects guest to `/login?from=%2Fdocuments%2Fdraft` |
| `/notifications` | Protected | Authenticated | `NotificationsPage` | Redirects guest to `/login?from=%2Fnotifications` |
| `/admin/*` | Admin Only | Admin Role | `AdminHubPage` & sub-pages | Redirects unauthenticated; denies non-admin roles |

---

## 2. BROWSER SPA SERVER VERIFICATION

- **Server Endpoint**: `http://127.0.0.1:64331/` (`tools/final_acceptance/serve.py`)
- **Headers Verified**: `Cache-Control: no-store`
- **Fallback Rule**: Direct path requests (e.g. `/interview-scheduling`) rewrite to `/index.html` for client-side routing.
- **RTL Directionality**: Root HTML explicitly renders `<html lang="fa" dir="rtl">`.
