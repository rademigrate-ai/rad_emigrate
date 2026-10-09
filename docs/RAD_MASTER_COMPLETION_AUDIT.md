# RAD Master Completion Audit — Stage 1 Baseline

Date: 2026-10-09
Scope: original RAD Immigration Intelligence Platform vision versus current repository and verified release evidence.
Status: IN PROGRESS — documentary baseline, not production acceptance.

## Evidence rules
- **Implemented** means code or architecture exists; not proof of a working production user journey.
- **Partial** means evidence supports only part of the original requirement.
- **Unverified** means the current evidence does not prove delivery. It does **not** automatically mean absent.
- **External blocker** means owner/provider/content/legal action is required.
- Never claim that CI success proves deployment, correct live content, paid transactions, or device acceptance.
- No research/AI process may publish to Feed without explicit authorized human approval.
- Do not fabricate immigration facts, payments, provider credentials, or production data.

## Evidence reviewed
- Original user-supplied RAD platform blueprint: Web/iOS/Android, CMS, RAG, two agents, immigration content, payments, CRM, notification, security, and advanced tools.
- `README.md`: Flutter, Supabase, current product architecture and release configuration.
- `docs/REMAINING_PRODUCT_ROADMAP.md`: original project objectives and acceptance gates.
- `docs/FINAL_EXTERNAL_DEPENDENCIES.md`: owner/content/legal dependencies.
- `docs/FINAL_PRODUCTION_BASELINE.md`: snapshot; must not be treated as current production evidence.
- GitHub main at audit start: `8a7fce25c`; GitHub Actions CI succeeded on that commit.

## Initial acceptance matrix

| Area / original requirement | Status | Evidence / unresolved acceptance |
| --- | --- | --- |
| Flutter Web frontend | Implemented / runtime unverified | CI web build; production smoke and responsive E2E required |
| Android app | Implemented / release blocked | CI debug APK; production identity, signing and store acceptance owner-owned |
| iOS app | Unverified / external blocker | iOS target exists; Apple bundle ID/signing and device/store acceptance required |
| User Auth and protected routes | Partial | Supabase-backed routes exist; real email OTP, SMS and two-user E2E need evidence |
| Admin / Super Admin | Partial | Role-gated operations described; actual role journey and audit acceptance needed |
| Country and visa catalog | Partial / documented seeded | `docs/VISA_PRODUCTION_EVIDENCE.md` records 22 destinations, 44 localized summaries, 10 programs, 20 descriptions, 8 review-required requirements and 18 review-required steps; 0 official-regulatory verified steps/descriptions; verify current production |
| Content CMS and human review | Partial | Reviewed Feed model exists; full original content types and editorial UX require mapping |
| RAD 3-site ingestion | Unverified | Verify URL inventory, approved ingestion, provenance, update frequency and live corpus |
| User AI with citations | Partial | Grounded orchestration described; source-level accuracy, freshness, cost and latency acceptance needed |
| Five free anonymous questions | Documented pass / current runtime unverified | `docs/USER_AI_PRODUCTION_EVIDENCE.md` records Q1–Q5 allowed, Q6 rejected; retest against current deployed version and validate guest-to-account behavior |
| Email/SMS OTP | External blocker | Owner email E2E and SMS provider documented as outstanding |
| Subscription and payment | External blocker / partial | `docs/PAYMENT_PRODUCTION_READINESS.md` explicitly NOT READY; owner must supply provider, credentials, plans/prices, webhook secrets and legal copy |
| Knowledge search / RAG / conflict | Partial | Knowledge foundation exists; corpus, semantic retrieval, stale/conflict regression need evaluation |
| Research Agent and change monitoring | Partial | Research sync exists; end-to-end detection, review-candidate creation and alerts must be tested |
| Research-to-Feed publishing | Partial | Explicit Admin approval required; verify no automated publication path |
| Document intelligence / OCR | Partial | Document intelligence function exists; privacy, fixture accuracy, review and retention acceptance needed |
| Consultation and CRM lead flow | Partial | Consultation UI exists; handoff, assignment and conversion E2E unverified |
| Notifications across channels | Partial | In-app UI exists; push/SMS/email provider delivery unverified |
| User immigration profile / pathway comparison | Unverified | Structured assessment and evidence-based matching need feature audit |
| Document checklist / immigration timeline | Unverified | Check screens, persistence and source-backed content |
| AI evaluation, feedback and monitoring | Partial / unverified | Confirm production observability, fixture quality and feedback loops |
| Multi-language Persian/English | Partial | Existing localization; route-by-route completeness and RTL checks required |
| Security, RLS, secrets and migration history | Implemented / production unverified | CI security and reconstruction gates pass; owner deployment and production checks separate |
| Production deployment and release acceptance | External blocker | Render deployment owner-only; owner must verify production SHA, smoke, auth and privacy |
| Advanced tools (CV/SOP, voice, university/scholarship) | Unverified | Scope and implemented feature inventory required; no completion claim |

## Phase 1 execution checklist
1. Enumerate original blueprint requirements into individually testable acceptance criteria.
2. Inventory code routes/screens, Edge Functions, migrations, tests and documented external dependencies.
3. Classify each requirement with a direct code/test/document reference and owner.
4. Verify actual production state only through authorized read-only checks; no deployment or migration repair.
5. Rank P0 security/data correctness, P1 broken journeys, P2 completeness and polish.
6. Produce phase 2–8 implementation backlog with dependencies and measurable gates.
7. Record unresolved owner decisions: SMS provider, email OTP, payments/plans, Android signing/ID, Apple signing/ID, Render deployment, leaked-password protection, content approval, privacy/legal.

## Non-goals
No production mutations, no Render changes, no automatic AI publication, no unsourced immigration content, no declaring release complete from green CI.

## Stage 1 — repository evidence pass (2026-10-09)

GitHub `main` recursive tree inventory: **1,789 tracked blobs**, **13 Flutter feature directories**, **57 test files**, **159 documentation files**. Edge Functions: `ai-orchestrator`, `document-intelligence`, `research-sync` (plus shared code and tests). These are repository counts, not coverage metrics or runtime proof.

### Corrections to preliminary classifications
- Visa: latest documented production evidence shows **44 localized destination summaries**, **20 localized program descriptions**, **8 requirements** and **18 steps**; the steps and requirements are review-required, and **zero official-regulatory verification** is documented. Do not repeat the older claim that all summaries/steps are empty without checking the timestamp and live database.
- Guest AI: `docs/USER_AI_PRODUCTION_EVIDENCE.md` reports Q1–Q5 allowed and Q6 blocked. The report also documents authenticated Persian/English responses with citations. This is evidence of a past smoke test, not confirmation of current deployment.
- Payment: `docs/PAYMENT_PRODUCTION_READINESS.md` explicitly says NOT READY pending owner payment provider, plans/prices, webhook secrets and legal/commercial copy.
- Historical `docs/FINAL_ACCEPTANCE_REPORT.md` states CI NO-GO; that report is stale relative to GitHub Actions success at `8a7fce25c`. Do not silently use it as current CI status.
- Original blueprint recommends Next.js/React Native/NestJS, but the actual project uses Flutter + Supabase. Acceptance should assess required **capabilities**, not assume an unapproved framework rewrite.

### Next evidence collection
- Map each GoRouter route to screens and tests, including protected/admin route behavior.
- Inventory SQL/RPCs and Edge authorization contracts for research, publication, quotas, payments and documents.
- Establish current deployed build SHA and repeat owner-authorized live E2E checks before declaring production readiness.
- Validate corpus coverage and official source freshness, especially regulatory claims.

## Stage 1 — route and test traceability pass

Source: `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart`, and repository `test/` inventory on main.

### User-facing route inventory
- Public/auth: `/splash`, `/login`, `/register`, `/forgot-password`, `/reset-password`, `/otp`.
- Onboarding: `/profile-completion`.
- Authenticated shell: `/dashboard`, `/visa`, `/applications`, `/documents`, `/consultation`, `/notifications`, `/profile`, `/ai-assistant`, `/world-clock`, `/feed`.
- Staff: `/admin`, `/admin/ai-config`, `/admin/operations`, `/admin/consultations`, `/admin/ai-research`.

**Important:** `auth_redirect.dart` only enforces authentication and onboarding navigation. The file explicitly says admin authorization is server-side via role/RLS; route presence does not establish privilege enforcement.

### Test-to-feature traceability (representative)
| Journey | Existing test files | Missing acceptance evidence |
| --- | --- | --- |
| Auth/recovery/redirect | `test/acceptance/auth_redirect_acceptance_test.dart`, `test/auth/password_reset_recovery_test.dart`, `test/core/session_manager_test.dart` | Real email/SMS OTP and browser recovery |
| Admin authorization | `test/acceptance/admin_role_authorization_test.dart`, `test/acceptance/schema_policy_acceptance_test.dart` | Staff/nonstaff real-session checks |
| User AI / quotas / safety | `test/ai_assistant/ai_assistant_page_test.dart`, `test/acceptance/ai_safety_grounding_test.dart`, `test/acceptance/admin_ai_quota_test.dart` | Current live provider, guest quota and citations |
| Research / Feed | `test/acceptance/stage1_ai_research_completion_test.dart`, `test/acceptance/stage2_review_feed_publish_test.dart`, `test/acceptance/no_ai_research_auto_publish_test.dart` | Research finding → draft → manual approval → publication E2E |
| Applications / documents | `test/acceptance/application_status_acceptance_test.dart`, `test/acceptance/document_acceptance_test.dart`, `test/documents/document_storage_test.dart` | Two-account isolation and real file upload/deletion |
| Visa | `test/visa/visa_entities_test.dart`, `test/acceptance/stage2_review_feed_visa_test.dart` | Content completeness and official evidence approval |
| World Time / UX | `test/features/global_time/timezone_engine_test.dart`, `test/core/app_shell_navigation_test.dart`, `test/visual_qa_smoke_test.dart` | Browser/device visual and timezone-map smoke |

### False-positive acceptance tests
`test/acceptance/pending_implementation_gates_test.dart` contains four tests with `expect(true, isTrue)` placeholders for **external/deferred** work: Super Admin account bootstrap, optional global ARB localization, data export/account deletion UI, and production domain/DNS/Auth redirects/signing. These are not evidence that the named capabilities work. Retain explicit external-blocker classification; do not count them as accepted features.

### Prioritized next checks
- **P0:** production role/RLS isolation, no AI auto-publish, Auth recovery and document privacy; prove deployed version matches audited SHA.
- **P1:** Visa verified content and research-to-draft chain; real AI citations/quotas; broken page journeys and device responsiveness.
- **P2:** payment/provider integration, notification channels, full CRM handoff, advanced tools and app-store readiness, sequenced by owner dependencies.

## Stage 1 — research ingestion and publication contract pass

Code evidence: `supabase/migrations/20261007080002_research_atomic_review_candidate.sql`, `supabase/functions/research-sync/handler.ts`, `supabase/tests/corrective_routing_research.sql`.

- `public.ingest_research_snapshot` is restricted to `service_role`, validates HTTP 2xx and normalized text, deduplicates by document/hash, and writes snapshots/findings transactionally.
- `private.research_finding_review_candidate` is an AFTER INSERT trigger on `public.research_findings`, calling `public.create_research_review_candidate` within the same transaction. This is explicit code evidence of finding → human review candidate generation.
- The migration explicitly states **No Feed writes**. This is a design and regression-review gate; never relax it.
- `research-sync/handler.ts` implements HTTPS/host constraints, manual redirect validation, response size cap and timeouts. Full deployed SSRF/DNS rebinding and source-content quality acceptance is **not** established by reading code.
- Existing `supabase/tests/corrective_routing_research.sql` is a disposable CI fixture; production pipeline success and current deployment version remain unverified.
- **Caution:** This contract addresses review candidate creation, not the entire user-facing editorial journey; manually verify draft editing, approvals, publication and authorization.

## Stage 1 — executable phase backlog / gates

| Next phase | Must-have deliverables | Exit gate / evidence |
| --- | --- | --- |
| 2. Core Web/Admin | Route-by-route desktop/mobile smoke, auth/recovery, admin authorization, errors/loading, documents/consultations | Browser E2E artifacts + no open P0/P1 regression + single green CI HEAD |
| 3. Visa/CMS content | Source-backed localized country/program text, review-required official regulatory content, editorial ownership and freshness | Coverage report, content reviewer sign-off, no invented requirements |
| 4. Knowledge/User AI | RAD corpus inventory, source snapshots, current official sources, retrieval eval, guest/auth quota and citations | Reviewed bilingual eval dataset + live provider/quota checks |
| 5. Research/Editorial | Scheduled sync, change/conflict detection, finding→candidate→review→publish and audit trail | Disposable DB regression + production authorized smoke; zero auto-publish |
| 6. CRM/Commercial | Lead/consultant workflow, notification delivery, entitlements, approved payment provider | Two-user journey + payment sandbox/webhook + owner/legal sign-off |
| 7. Intelligence tools | Profile/pathway comparisons, source-backed checklist/timeline, document AI and privacy | Product acceptance fixtures + source provenance + isolation/deletion tests |
| 8. Release | Production SHA, real Web/Android/iOS E2E, signing, accessibility, security, privacy, rollback | Owner-approved release evidence; stores/deploy external actions complete |

### Stage 1 exit checklist (current status)
- [x] Establish original vision vs current product acceptance matrix
- [x] Inventory Flutter feature folders, Edge Functions and test file coverage
- [x] Map primary GoRouter routes to representative tests
- [x] Distinguish historical CI and production evidence from current status
- [x] Review research finding → review candidate SQL contract and explicit no-auto-publish boundary
- [x] Create phases 2–8 dependency and acceptance backlog
- [ ] Verify production deployment SHA, active Edge versions, live role/RLS and full research-to-publish journey (requires authorized live verification)
- [ ] Obtain owner/content/legal confirmations for external gates

**Engineering audit documentation is complete for the repository-level Stage 1 scope. Full Stage 1 production acceptance remains BLOCKED by live verification and owner inputs. Do not mark the whole stage completed or start Phase 2 under the user's condition until the missing gates are satisfied.**
