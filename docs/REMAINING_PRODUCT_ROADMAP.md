# Remaining Product Roadmap

**Project 08 status: ENGINEERING COMPLETE — EXTERNAL RELEASE ACTIONS REMAIN.** Local integration and CI do not substitute for production Auth, hosting, and two-user acceptance. Do not mark the production gate complete until its external steps pass.

## PROJECT 09 — Visa and Product Data Layer

**Objective:** Provide an accurate, maintainable catalog of RAD visa programs, countries, services, and eligibility information.

**Dependencies:** Approved RAD service taxonomy; authoritative and current institutional sources; content ownership and update process.

**Major deliverables:**

- Structured visa, country, program, and service catalog.
- Source provenance, last-verified dates, version history, and ownership.
- Data validation and a workflow for reviewing and publishing changes.

**Completion gate:** Every client-visible program claim has a traceable source and freshness date; data review and update tests pass.

## PROJECT 10 — RAD Knowledge Base

**Objective:** Build a governed retrieval corpus for RAD content and authoritative external immigration sources.

**Dependencies:** Project 09's source taxonomy and an approved content ingestion/retention policy.

**Major deliverables:**

- Ingest RAD material from `radvisa.com`, `digivisa.ir`, and `radmohajer.ir/fa/`.
- Ingest relevant authoritative government, embassy, university, and institutional sources.
- Store source metadata, version, jurisdiction, citations, and freshness.
- Add access control, retrieval evaluation, and update governance.

**Completion gate:** Retrieval returns current, attributable sources and rejects stale or unsupported content in a reviewed evaluation set.

## PROJECT 11 — AI Assistant Production

**Objective:** Deliver an approved AI service grounded in the RAD Knowledge Base without fabricating immigration guidance.

**Dependencies:** Project 10; owner approval of a provider, privacy terms, budget, and operational controls.

**Major deliverables:**

- Provider abstraction and secret-safe server-side integration.
- Grounded responses with citations, refusal behavior, and uncertainty handling.
- Rate limits, cost controls, monitoring, persistence, and user data retention policy.

**Completion gate:** A reviewed evaluation set meets accuracy, citation, privacy, safety, latency, and cost thresholds; no provider secret is shipped in the client.

## PROJECT 12 — Document Intelligence

**Objective:** Help users and authorized staff organize and process uploaded documents.

**Dependencies:** Project 08 Storage production gate; approved retention/access policy; Project 11 only if AI processing is used.

**Major deliverables:**

- OCR, extraction, classification, and validation pipeline.
- Explicit processing/error states and retry behavior.
- User-visible correction/review flow and per-document audit history.

**Completion gate:** Supported fixture set meets extraction and privacy requirements, cross-user access is denied, and delete/retention behavior is verified.

## PROJECT 13 — Operations and Admin

**Objective:** Give authorized staff safe tools to manage users, cases, content, and reviews.

**Dependencies:** Role and authorization model; audit requirements; Project 09/10 data ownership.

**Major deliverables:**

- Staff/admin role model with least privilege.
- User and case management, document review, and content/AI administration.
- Durable audit logs for privileged actions.

**Completion gate:** Authorization tests cover allowed and denied operations for each role; privileged changes are attributable and auditable.

## PROJECT 14 — Client Workflow

**Objective:** Support a clear, secure client case journey from intake through document requests and status updates.

**Dependencies:** Projects 09 and 13; approved notification channels and communication templates.

**Major deliverables:**

- Checklists, deadlines, document requests, case updates, and status history.
- Notifications and client communications with delivery state.
- Accessible workflows for reviewing or correcting submitted information.

**Completion gate:** End-to-end client and staff workflows pass with authorization, accessibility, retry, and notification-delivery checks.

## PROJECT 15 — Observability and Analytics

**Objective:** Detect service failures and understand product quality while minimizing personal data collection.

**Dependencies:** Privacy and retention policy; operational ownership and incident response process.

**Major deliverables:**

- Privacy-safe crash reporting and error monitoring.
- Performance, availability, and operational dashboards.
- Carefully scoped product events and analytics retention controls.

**Completion gate:** A simulated incident is detected and triaged; telemetry excludes credentials and unnecessary personal data.

## PROJECT 16 — Final Release QA

**Objective:** Complete release-wide verification across supported platforms and operational controls.

**Dependencies:** Projects 08–15; production hosting, Android identity/signing, and approved release process.

**Major deliverables:**

- Integration and end-to-end suite across browser/device sizes and accessibility.
- Security regression, load/performance, backup/restore, and release configuration checks.
- Final release checklist, rollback procedure, and signed artifacts.

**Completion gate:** All required production checks pass, owner review is complete, release artifacts are signed with owner-controlled credentials, and deployment/rollback are verified.

## Project 08 external release actions

- Select the production web host/domain and set Flutter SPA fallback to `index.html`.
- Configure only the selected production redirect URLs in Supabase Auth and verify email confirmation with dedicated inboxes.
- Run live RAD signup/login/logout/session restoration, profile/application persistence, and two-user database/Storage isolation tests.
- Select the production Android application ID and provide signing values through the secure release process.
- Configure protected branch governance with the successful CI jobs under an eligible repository plan.
- PR #2 has merged. Project 08 is engineering complete; it is not fully deployed until the remaining owner-selected deployment and live acceptance checks above pass.

The RAD migration-ledger mismatch remains documented. Keep historical production migration repair separate; never reset or rewrite the live ledger to align filenames.
