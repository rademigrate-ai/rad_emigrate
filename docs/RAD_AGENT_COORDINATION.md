# RAD Emigrate ΓÇö Local Two-Agent Coordination Record

**Workspace:** `C:\Users\Mehrshad\Desktop\RAD - Emigrate\rad_final_47_integration`  
**Branch:** `integration/local-final-47`  
**Latest Integrated HEAD:** `4b68d15`  
**Policy:** Local-first development. No intermediate pushes or incremental Draft PRs. One final consolidated GitHub delivery.

---

## 1. Ownership & Worktree Partitioning

| Role | Agent | Dedicated Worktree | Domain Responsibilities |
| :--- | :--- | :--- | :--- |
| **Backend & Systems Lead** | **Codex** | `rad_codex_master_47_20261018` | Supabase schema & migrations, RLS security policies, SECURITY DEFINER functions, AI orchestration & grounding, research ingestion, human-only feed publish triggers, CRM/notifications backend, payment sandbox, OCR backend, backend tests. |
| **Frontend & UI/UX Lead** | **Antigravity** | `rad_antigravity_flutter_e2e` | Flutter client application, Web and mobile routes, Admin UI, Persian RTL / English LTR, UI/UX polish, accessibility & keyboard navigation, form validation, widget tests, real-browser QA. |
| **Local Integration Hub** | **Joint / Integration Lead** | `rad_final_47_integration` | Local-only integration checkpoints, conflict resolution, full regression suites, single canonical master ledger maintenance, final consolidated release candidate assembly. |

---

## 2. API & Interface Contracts

1. **AI Quota & Grounding Contract:**
   - Frontend invokes Edge function `/ai-orchestrator`.
   - Backend evaluates `get_ai_daily_quota_status` and `get_ai_access_decision` with `auth.uid()`.
   - `knowledge_grounding.ts` returns `hasApprovedEvidence`, `sources` array, `hasConflicts`, and `uncertain` flags.
   - Frontend displays grounding uncertainty disclaimer when `uncertain == true` without breaking formatting.

2. **Consultation Submission Contract:**
   - Client calls `submit_consultation_request` RPC or inserts with `user_id = auth.uid()`.
   - Server trigger `private.guard_consultation_fields` protects `status` and `assigned_to` immutability.
   - Frontend prevents duplicate submits via early state lock (`_submitting`) and clears draft inputs upon success.

3. **Feed Editorial Publication Contract:**
   - Public feed items are read-only to client roles (`anon`, `authenticated`).
   - Publication is exclusively performed via `public.publish_content_draft` by users with `role IN ('admin', 'super_admin')`.
   - Client feed cards support pull-to-refresh in empty/error states and protect bookmark saves with stateful `_saving` guard locks.

4. **Document Generator Contract (`/documents/draft`):**
   - Offline-first deterministic plain-text generator for CV and Statement of Purpose.
   - Client exports UTF-8 `.txt` file or copies to clipboard. No server transmission or automated cloud storage.

---

## 3. Local Checkpoints Ledger

- **Checkpoint 1 (2026-10-18):** Merged PR #68 (Flutter UI/UX) + PR #69 (47-gate delivery ledger) + PR #70 (CV/SOP draft generator) onto `2739567` (HEAD: `3977712`).
- **Checkpoint 2 (2026-10-18):** Advanced Stage 10 FK covering indexes, 64-function SECURITY DEFINER search-path audit, protected route audit matrix (20 tests), grounded AI conflict evaluation, and cherry-picked `66c5820` audit test alignment (HEAD: `4b68d15`).
- **Checkpoint 3 (Current):** Established `rad_final_47_integration` worktree and local coordination contracts. Proceeding with remaining offline test matrices and verification gates.

---

## Codex supplemental handoff (4b9e0af)

# RAD local coordination ΓÇö 2026-10-18

User local-first policy supersedes incremental GitHub delivery. No intermediate push, PR, issue updates or production mutation.

Codex backend writer: /root, active in rad_codex_master_47_20261018 on feat/codex-master-47-execution-20261018. Owns Supabase/functions/tests, backend scripts, migrations and RAD_CODEX_BACKEND_PROGRESS.md. Frontend worktree and RAD_ANTIGRAVITY_FRONTEND_PROGRESS.md are Antigravity-owned.

Integration ownership: rad_final_47_integration already exists and an in-progress cherry-pick/conflict was observed. Preserve its active writer; do not edit or reset it. The existing integration writer alone should maintain canonical ledger and consume tested Codex commits. Coordinate by reading this backend record and committed handoff entries.

Backend queue: establish disposable local DB execution; harden/test document-intelligence using synthetic files; implement and test notification sandbox delivery, CRM invariants and payment sandbox integrity. Changes to frontend-facing contracts will be recorded here before implementation.

## OCR contract reservation ΓÇö Codex

Codex owns document-intelligence/index.ts, new document-intelligence/handler.ts and tests/document_intelligence_test.ts for this slice. Preserve existing success fields (job_id, extraction_id, status=review_required, field_count) and no-provider code. Failures use fixed safe codes; no raw provider diagnostics. File types remain PDF/JPEG/PNG and the private bucket's 10 MiB maximum. No frontend change is required. Use only synthetic files and mocked provider requests; real OCR credentials/consent remain external. Local database runtime will use its own project/container ID and ports 55320ΓÇô55329 to avoid the integration writer's stack.
