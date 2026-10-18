# RAD local coordination — 2026-10-18

User local-first policy supersedes incremental GitHub delivery. No intermediate push, PR, issue updates or production mutation.

Codex backend writer: /root, active in rad_codex_master_47_20261018 on feat/codex-master-47-execution-20261018. Owns Supabase/functions/tests, backend scripts, migrations and RAD_CODEX_BACKEND_PROGRESS.md. Frontend worktree and RAD_ANTIGRAVITY_FRONTEND_PROGRESS.md are Antigravity-owned.

Integration ownership: rad_final_47_integration already exists and an in-progress cherry-pick/conflict was observed. Preserve its active writer; do not edit or reset it. The existing integration writer alone should maintain canonical ledger and consume tested Codex commits. Coordinate by reading this backend record and committed handoff entries.

Backend queue: establish disposable local DB execution; harden/test document-intelligence using synthetic files; implement and test notification sandbox delivery, CRM invariants and payment sandbox integrity. Changes to frontend-facing contracts will be recorded here before implementation.

## OCR contract reservation — Codex

Codex owns document-intelligence/index.ts, new document-intelligence/handler.ts and tests/document_intelligence_test.ts for this slice. Preserve existing success fields (job_id, extraction_id, status=review_required, field_count) and no-provider code. Failures use fixed safe codes; no raw provider diagnostics. File types remain PDF/JPEG/PNG and the private bucket's 10 MiB maximum. No frontend change is required. Use only synthetic files and mocked provider requests; real OCR credentials/consent remain external. Local database runtime will use its own project/container ID and ports 55320–55329 to avoid the integration writer's stack.

## CRM and notification contract reservation — Codex

CLI-generated local proposal 20261018125432_local47_crm_notification_outbox.sql will add consultation version/history and optional optimistic transition/assignment RPCs. Existing submit/list/update RPC signatures remain compatible. History exposed to owners will exclude internal notes and actor identity. New notification delivery uses the existing preference table, adds explicit SMS opt-in and IANA time zone, and creates a sandbox-only outbox with atomic leases/retry/idempotence. No real email/SMS/push delivery is enabled and no sandbox receipt is labelled externally delivered. No new frontend dependency is required; Antigravity may consume the optional contracts after tested handoff. Canonical master ledger remains integration-owned.

## Payment sandbox contract reservation — Codex

Codex owns the CLI-generated local47_payment_sandbox_integrity migration, payment-sandbox handler, and payment sandbox SQL/Deno tests. This is an explicitly synthetic sandbox protocol with HMAC-signed events; it is not a selected merchant/provider integration. The handler is disabled by default and refuses non-loopback Supabase targets. Sandbox subscription state is separate from ai_entitlements, and synthetic events never grant production paid access. Event deduplication, body-hash conflicts, owner/currency binding, stale-event ordering and terminal refund/cancellation handling will be tested. Real provider contracts, plans/prices, taxes, store/geography approval and real-provider sandbox verification remain external gates.

## Runtime privilege alignment — Codex

The local runtime inventory contains 59 active SECURITY DEFINER routines; historical source declaration counts are not unique-runtime counts. The new privilege-alignment proposal revokes direct client calls to private helpers except has_role (needed by RLS), preserves service execution, disables PUBLIC execute defaults for future functions, and repairs create_user_notification service/admin authorization and its invalid default notification type. This deliberately changes only the core set_updated_at trigger routine's effective anon/auth EXECUTE flags in the eight-dimension fingerprint. A diagnostic restoring those two flags exactly reproduces the original e05d93ee347104597a7b8b458b0d03da hash; the new value is fc57d0f49dfab1be19b4469a05b19cf8. Other seven dimensions and function bodies remain unchanged. The pin will be updated with this explicit ACL rationale, then all role/RLS/trigger regressions rerun.

Historical reconstruction reserves ports 57320–57329. The first attempt at 56322 failed because an existing unrelated local project owns that port; that project was left untouched. Canonical tests continue on 55320–55329. Only rad_codex_local47 and rad_codex_local47_reconstruct are Codex-owned disposable stacks.
