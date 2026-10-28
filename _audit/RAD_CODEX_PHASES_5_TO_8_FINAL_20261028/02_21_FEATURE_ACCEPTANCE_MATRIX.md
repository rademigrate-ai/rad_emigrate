# RAD EMIGRATE — 21-FEATURE ACCEPTANCE MATRIX
**Date:** 2026-10-28  
**Scope:** All 21 Application Feature Modules in `lib/features/`  
**Execution:** Automated Unit/Widget Suites, Production Router Regression, Real Local GoTrue/PostgREST Backend  

---

## 1. COMPREHENSIVE FEATURE STATUS TABLE

| # | Feature Directory | Primary Pages & Contracts | Test Suite / Evidence | Verdict | Notes |
|---|---|---|---|---|---|
| 01 | `splash` | `SplashPage` (`/splash`) | `test/features/splash/splash_page_test.dart` | **PASS** | 5 tests passing; brand scene, loading tiers, auth routing, error fallback |
| 02 | `auth` | `LoginPage`, `RegisterPage`, `OtpPage`, `ForgotPasswordPage`, `ResetPasswordPage`, `ProfileCompletionPage` | `test/features/auth/auth_forms_resilience_test.dart`, `test/core/app_router_public_routes_test.dart` | **PASS** | Progressive auth, OTP deep-link parsing, form validations, session recovery |
| 03 | `dashboard` | `DashboardPage` (`/dashboard`) | `test/features/dashboard/`, `test/core/app_router_public_routes_test.dart` | **PASS** | Guest access, quick action pills, news ticker, responsive grids |
| 04 | `visa` | `VisaPage` (`/visa`, `/explore`), `UniversityScholarshipPage` | `test/features/visa/`, `test/visa/` | **PASS** | Square cards at all breakpoints (280/390/744/1200), smart search, filter resets |
| 05 | `knowledge` | `EvidenceRegistry`, `KnowledgeIntegrity`, `ResearchPublicationPipeline` | `test/knowledge/`, `test/features/ai_assistant/` | **PASS** | Authority hierarchy (gov > institutional > radProject > aiGenerated), research feed write lock |
| 06 | `applications` | `ApplicationsPage`, `CaseTracker` (`/applications`) | `test/features/applications/case_tracker_flow_test.dart` | **PASS** | Milestone gauges, checklist items, user isolation |
| 07 | `documents` | `DocumentsPage`, `DocumentDraftPage` (`/documents`, `/documents/draft`) | `test/features/documents/`, `test/documents/` | **PASS** | CV/SOP generation flow, MIME validation, private bucket isolation |
| 08 | `consultation` | `ConsultationPage` (`/consultation`) | `test/features/consultation/`, `test/core/app_router_public_routes_test.dart` | **PASS** | Topic query prefilling, submission handling, admin consultation lifecycle |
| 09 | `booking` | `BookingPage`, `BookingServicePage` (`/booking`, `/booking/service/:serviceId`) | `test/features/booking/` | **PASS** | Explicit supported slots, conflict handling, fail-closed offline states |
| 10 | `interviews` | `InterviewsPage` (`/interviews`) | `test/features/interviews/interviews_flow_test.dart`, `test/core/app_router_public_routes_test.dart` | **PASS** | User session appointment requests, list views, status indicators |
| 11 | `interview_scheduling` | `InterviewSchedulingPage` (`/interview-scheduling`) | `test/core/app_router_public_routes_test.dart`, `test/features/interview_scheduling/` | **PASS** | BUG-001 fixed; resolves dedicated page, EN/FA CTA navigates to `/consultation` |
| 12 | `comparison` | Country/Visa comparison tables | `test/features/comparison/comparison_page_test.dart` | **PASS** | 2-pathway selection prompt, responsive comparison tables |
| 13 | `pathway_comparison` | `PathwayComparisonPage` (`/compare/pathways`) | `test/features/pathway_comparison/` | **PASS** | Structured visa comparison criteria, source fidelity |
| 14 | `university_comparison` | `UniversityComparisonPage` (`/compare/universities`) | `test/features/university_comparison/` | **PASS** | Program, tuition, degree comparison grids |
| 15 | `cost_calculator` | `CostCalculatorPage` (`/calculator/cost`) | `test/features/cost_calculator/`, `test/visa/fx_rate_test.dart` | **PASS** | Currency conversion (IRR / Toman), dynamic rounding, FX disclaimer |
| 16 | `global_time` | `WorldClockPage` (`/world-clock`) | `test/features/global_time/` | **PASS** | Multi-timezone catalog, daylight saving adjustments, clock dials |
| 17 | `ai_assistant` | `AiAssistantPage` (`/ai-assistant`) | `test/features/ai_assistant/`, `test/acceptance/ai_safety_grounding_test.dart` | **PASS** | Quota grounding, zero hallucinations on empty prompts, no autonomous feed publication |
| 18 | `feed` | `FeedPage` (`/feed`) | `test/features/feed/`, `test/test/backend-feed-human-guard-20261018` | **PASS** | Public listing, bookmarking, strictly human-moderated publication pipeline |
| 19 | `notifications` | `NotificationsPage` (`/notifications`) | `test/features/notifications/notifications_page_test.dart` | **PASS** | 4 tests passing; sign-in prompt for guest, empty state, unread badges, retry |
| 20 | `profile` | `ProfilePage`, `ImmigrationProfilePage` (`/profile`, `/profile/immigration`) | `test/features/profile/`, `test/security/private_view_assurance_test.dart` | **PASS** | Profile edits, role protection, session logout clearing private state |
| 21 | `admin` | `AdminHubPage`, `AdminOperationsPage`, `AdminCmsArticlesPage`, `AdminAiWorkspacePage`, `AdminSourceMonitorPage` | `test/features/admin/`, `test/admin/` | **PASS** | Role boundary enforcement (USER denied admin), CMS article lifecycle, audit events |
