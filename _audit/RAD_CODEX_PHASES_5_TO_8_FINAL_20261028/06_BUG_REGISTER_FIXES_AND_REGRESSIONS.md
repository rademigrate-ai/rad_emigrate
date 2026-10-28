# RAD EMIGRATE — DEFECT REGISTER, FIXES & REGRESSIONS
**Date:** 2026-10-28  
**Scope:** Engineering Defects Identified, Fixed, and Regression-Tested in Phases 5–8  

---

## 1. DEFECT LEDGER

### BUG-001 (P1): Production Route Binding Mismatch for `/interview-scheduling`
- **Severity**: **P1 (High)**
- **Component**: `lib/core/routing/app_router.dart`
- **Discovered By**: Codex (during browser navigation QA); confirmed and reproduced by Antigravity.
- **Symptom**: Navigating to `/interview-scheduling` mounted `InterviewsPage` (user appointment requests) instead of `InterviewSchedulingPage` (expert interview simulator and scheduling overview).
- **Impact**: The primary "Request Consultation" / "درخواست مشاوره تخصصی" call-to-action on the interview scheduling page was unreachable via production deep links.
- **Root Cause**:
  ```dart
  // BEFORE:
  GoRoute(
    path: '/interview-scheduling',
    builder: (_, _) => const InterviewsPage(),
  ),
  GoRoute(
    path: '/interviews',
    builder: (_, _) => const InterviewsPage(),
  ),
  ```
- **Red Test Evidence**:
  - Captured on `test/core/app_router_public_routes_test.dart` against unmodified router:
    `Expected: exactly one matching candidate`
    `Actual: _TypeWidgetFinder:<Found 0 widgets with type "InterviewSchedulingPage": []>`
- **Fix Applied**:
  - Imported `InterviewSchedulingPage` into `lib/core/routing/app_router.dart`.
  - Re-pointed `/interview-scheduling` route builder to `const InterviewSchedulingPage()`.
  - Preserved `/interviews` mapped to `const InterviewsPage()`.
- **Green Regression**:
  - `test/core/app_router_public_routes_test.dart` passes both English and Persian tests.
  - Confirmed tapping the CTA navigates cleanly to `ConsultationPage`.

---

### BUG-002 (P2): Missing Test Coverage for `SplashPage` and `NotificationsPage`
- **Severity**: **P2 (Medium - Acceptance & Quality Gate)**
- **Component**: `lib/features/splash/`, `lib/features/notifications/`
- **Discovered By**: Antigravity (during feature test inventory).
- **Symptom**: `lib/features/splash` and `lib/features/notifications` had no dedicated test suites in `test/features/`.
- **Fix Applied**:
  - Created `test/features/splash/splash_page_test.dart` (5 tests covering branding, guest routing to `/dashboard`, protected routing to `/login?from=...`, authenticated bypass, and bootstrap error recovery).
  - Created `test/features/notifications/notifications_page_test.dart` (4 tests covering unauthenticated sign-in prompt, empty notifications state, unread badge indicators, and error/retry states).
- **Result**: 9/9 tests passing cleanly.

---

### BUG-003 (P2): Unused Imports in Newly Added Test Files
- **Severity**: **P2 (Code Quality / Analysis Gate)**
- **Component**: `test/features/notifications/notifications_page_test.dart`, `test/features/splash/splash_page_test.dart`
- **Symptom**: `flutter analyze` flagged `unused_import` warnings on `loading_state.dart` and `theme_controller.dart`.
- **Fix Applied**: Removed redundant imports. Re-ran `flutter analyze` — zero issues reported.
