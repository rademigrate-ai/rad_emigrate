# RAD — Independent Hosting & Employer Acceptance Finalization Plan
Date: 2026-11-04
Status: IN PROGRESS / NOT CERTIFIED FOR DELIVERY
Repository: rademigrate-ai/rad_emigrate, PR #89, inspected HEAD f7b9dd48b68e5298ed83bdaca82909adac28a60d

## Owner decision and boundaries
- Supabase.com is a **temporary testing system**, not the target production host.
- Maral Host **FR-VPS-M2** is the provisional eventual host, **not purchased**. The previously quoted 6 vCPU / 12 GiB RAM / 60 GiB NVMe is not independently accepted as a final quote; verify checkout and upgrade disk to at least 80 GiB (prefer 100 GiB) if using a full stack.
- Do not buy hosting, migrate personal data, deploy, apply hosted schema changes, merge PR #89, or weaken security on the basis of this plan.
- Employer will test the *deployed* app after owner deploy; this is not a condition for completing local engineering.
- Prior constraints that were specifically Supabase.com managed-service lock/Storage-lifecycle restrictions must be **reassessed for a self-hosted deployment**. Do not indiscriminately remove application authorization, transaction safety, audit, RLS, immutable content holds, or rollback safeguards.
- Keep existing working trees, frozen source corpus, article provenance, and external secrets unchanged.

## Evidence checked
- PR #89 is draft/unmerged; current verified final-head CI was 8/8 on f7b9dd4 (managed-platform branch tests, not self-host E2E).
- Latest acceptance reference: docs/master_execution/acceptance_gates.json (47 gates, status recorded 2026-10-31: 2 VERIFIED_PASS, 25 IN_PROGRESS, 13 BLOCKED_EXTERNAL, 7 BLOCKED_OWNER_APPROVAL); this is a historical **gate inventory**, not a current functional verdict.
- Employer/client-related route matrix: docs/RAD_FEATURE_ACCEPTANCE_MATRIX.md; note its 2026-10-18 evidence date.
- Requirements and source boundaries: docs/RAD_47_TASK_MASTER_LEDGER.md, docs/master_execution/THREE_SITE_DELIVERY_ACCEPTANCE_20261103.md, docs/master_execution/FINAL_EMPLOYER_DEPLOY_READINESS.md.
- Local checkout contains 118 SQL migration files, eight Edge Function entry points, and Supabase local config selecting PostgreSQL 17. Desktop Docker is available and a **development** Supabase stack is running; a live self-hosted production-equivalent deployment is NOT yet tested.
- Current PR content package has 1,077 publication candidates, 23 held items, 355 incomplete-URL cases, and zero recorded published heads in the former managed Production. Candidate != approved or published.

## Finalization workstreams in acceptance order

### P0 — Contract and complete-app feature verification
1. Make a current 47-gate feature-to-route/backend/test matrix from the latest HEAD, with evidence dated and explicitly distinguishing implemented, isolated-tested, deployed-tested, blocked, and not-in-release.
2. Verify the exact signed employer requirements against the ledger; do not silently exclude or promise long-tail payments, OCR, bookings, university feeds, native signing, or voice capabilities.
3. Focus on complete authenticated journeys: login/recovery and two-role isolation; user dashboard/profile/applications/documents; Visa country/article/Other Titles; source-backed Research Assistant -> proposal -> admin review -> persisted unpublished CMS draft; Admin operations and audit; human-only publication.
**Pass:** each in-scope journey has real backend integration + browser UI negative cases. Honest unavailable states are documented, not called complete.

### P1 — Reproducible independent backend
1. Select and pin an official self-hosted Supabase Docker release compatible with PostgreSQL 17, Auth/Storage/PostgREST/Edge/Realtime and the existing SQL extensions; document actual image digests and service versions. Do not deploy the Supabase CLI local development stack to a public VPS.
2. Produce a fresh-install Compose/config package with restricted network exposure, TLS reverse proxy, persistent DB/Storage volumes, health checks, environment-only secrets, SMTP configuration, Edge Function deployment, pg_cron/pg_net scheduling, logs, resource limits and migrations.
3. Reconstruct **all** needed schema from the 118 ordered SQL files or a fully verified baseline; identify migrations that assume managed Supabase-specific pre-existing objects. Never blindly replay the managed project's migration-history aliases.
4. Test from an empty disposable stack, not by copying user accounts/secrets. Capture schema fingerprints, Auth/RLS, Storage owner-path/MIME/size limits, RPC signature parity, role boundaries, Cron/Edge execution, idempotency and restart persistence.
5. Perform backup and restore rehearsal **only on a disposable isolated instance**, and document clear upgrade/rollback/forward-fix procedures. Never test destructive restore on real customer data.
**Pass:** a second clean machine/environment can rebuild and pass all requirements with documented commands, pinned dependencies, no managed-platform project id, and no external hidden state.

### P2 — Content, Research and AI runtime
1. Preserve original content bundles and holds; mechanically stage/import only source-faithful eligible drafts in disposable backend. Keep 23 holds, the 355 incompletely recovered URLs, author provenance, source hashes and old revisions intact.
2. Resolve real Research Assistant provider integration with an owner-approved, server-only credential, budget/quota and egress policy; fixtures alone are insufficient for real answers.
3. Run research evidence -> article-matched proposal -> admin edit/accept/reject -> persisted unpublished draft -> logout/login/reopen, then independently authorized publish test (disposable fixture only). Verify zero research/AI auto-Feed writes and strict unauthenticated denial.
4. Content completeness and legal/factual editorial verification remain human review gates; no invented immigration guidance or false 'all three sites complete' claim.
**Pass:** successful real end-to-end data persistence with citations and negative security tests in the independent stack; remaining editorial holds explicitly recorded.

### P3 — App and release QA
1. Browser automation across FA/EN, RTL/LTR, 390px/mobile/tablet/desktop, keyboard, SPA refresh/deep-links, error/loading/retry, accessibility and session rotation.
2. Flutter format/analyze/tests; Python, Deno, SQL/Auth/Storage regression suite; Web production build, Android debug. Do not call debug Android release-signed; certify signed Android/iOS only with owner credentials/device tests.
3. Run restart, load, disk, failure, notification/mail delivery, backup verification, logging redaction and secret scans against the independent stack.
**Pass:** one exact HEAD has both green CI and independent full-stack release receipts, not merely mocked tests.

### P4 — Owner handoff (NO HOST PURCHASE YET)
1. Deliver reviewed Compose/config templates, scripts, migration/seed artifacts, public env-example, secure secret-injection guide, HTTPS/domain/SMTP/backup setup, resource and cost checklist, smoke-test scripts, operational runbook, editor/Admin guide and honest unresolved-feature register.
2. Reassess FR-VPS-M2 capacity after measured stack peak RAM/storage/disk I/O, network connectivity to chosen AI providers, and expected employer traffic. Confirm CPU/RAM/disk, SSH/root, Docker, offsite backup, outbound egress and IP/domain requirements with Maral Host before purchase.
3. Obtain the owner's separate authorization for PR merge and handoff once all mandatory accepted requirements pass. Employer login/UAT occurs after deployment.

## Mandatory STOP / truthfulness
- Never promote passing isolated tests to deployed verification.
- No client/AI credentials or personal data in Git, screenshots or final reports.
- Do not claim all requested employer features are implemented until the owner/client acceptance scope is verified; current 47-gate ledger contains open contract/external requirements.
- No automated publishing, no weakening RLS or replacing protected locks with unenforced checks.
- The managed Supabase.com Support ticket may remain open for test-platform scope; it is NOT evidence that independent hosting requires an identical provider-specific approval.
- A release decision is GO only after P0–P3 have current, independent acceptance evidence and the owner has approved in-scope exclusions. Otherwise state the precise blockers and continue non-blocked work.

Reference: https://supabase.com/docs/guides/self-hosting/docker and https://supabase.com/docs/guides/self-hosting/restore-from-platform
