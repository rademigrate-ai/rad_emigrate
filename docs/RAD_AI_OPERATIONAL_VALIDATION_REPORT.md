# RAD — AI Operational & Security Validation Report (2026-10-18)

**Scope:** Gates 11 to 15 (Epic E2: User AI and Admin AI)  
**Author:** Codex (AI Systems & Security Engineer)  
**Status:** IMPLEMENTED & TESTED (Production provider activation blocked on operator-supplied credential verification)

---

## 1. Executive Summary

This report documents the architectural verification, entitlement enforcement, grounding rules, and observability controls for the RAD AI subsystems across User AI (`/ai-assistant`) and Admin AI Workspace (`/admin/ai-research`, `/admin/ai-config`).

---

## 2. Gate Verification & Technical Status

### Gate 11: Provider Credentials & Routing Health (`BLOCKED`)
- **Observed Production Diagnostic:** In read-only production audit, 49 recorded AI requests resulted in 10 successes, 39 failures (27 `no_eligible_model`, 2 providers with `credential_rejected` health, 1 provider degraded).
- **Architecture & Implementation:**
  - `ai_providers` table stores write-only encrypted API keys.
  - `public.configure_ai_provider` and `public.set_ai_model_configuration` RPCs provide sanitized health diagnostics without logging raw keys.
  - `supabase/functions/ai-orchestrator/handler.ts` implements automatic multi-provider fallback and retry chains.
- **Prerequisite for PASS:** Operator provisioning of verified, active non-production API credentials for primary and fallback LLM adapters.

### Gate 12: AI Model Eligibility & Discovery (`IN_PROGRESS`)
- Dynamic model discovery catalogs 721 model definitions (641 nominal available for chat).
- The orchestrator dynamically evaluates capability tags (`user`, `admin`, `vision`, `tools`) and filters out degraded or cooling-down models.
- Edge function test `ai_orchestrator_test.ts` exercises top-8 ranked model truncation, preventing oversized payloads.

### Gate 13: Atomic Quotas and Concurrency (`IMPLEMENTED`)
- **Entitlement Rule:** 5 free questions per day for standard users; unlimited for authorized admin roles.
- **Race Condition Prevention:**
  - Migrations `20261010010000_stage1_p0_security_completion.sql` and `20261010055013_stage1_atomic_ai_quota_reservation.sql` implement atomic reservation with row-level locking (`FOR UPDATE`).
  - Quota checks use `auth.uid()` directly rather than client-supplied user parameters.
  - Concurrent requests receive a unique `request_id` upon reservation; unconsumed reservations roll back on provider failure.

### Gate 14: Grounded AI Answers and Citations (`IMPLEMENTED`)
- **Grounding Architecture (`knowledge_grounding.ts`):**
  - AI queries query `public.retrieve_knowledge` RPC for approved knowledge claims.
  - **Open Conflict Detection:** When contradictory claims exist, `hasConflicts` is set to `true`, forcing the prompt into explicit uncertainty: `[CONFLICT — do not resolve unilaterally]`.
  - **Fail-Closed Evidence:** If no approved knowledge matches, the system instructs the LLM not to invent requirements, fees, or outcomes.
  - **Sanitized Citations:** Output includes verified source citations with canonical government/university URLs.
  - Verified with 12 Deno tests in `supabase/functions/tests/knowledge_grounding_test.ts`.

### Gate 15: Observability, Redaction, and Cost (`IN_PROGRESS`)
- `ai_requests` and `ai_session_messages` record token counts (`prompt_tokens`, `output_tokens`) and duration.
- Edge functions redact sensitive client inputs (passwords, JWTs, credit card patterns) before invoking external LLM APIs.
- Admin Operations dashboard (`/admin/operations`) surfaces aggregate health and error distribution without displaying sensitive prompt payloads.

---

## 3. Operational Acceptance Recommendation

- Code and schema components for atomic quota reservation, grounding, conflict detection, and observability are **IMPLEMENTED** and unit-tested.
- Production deployment remains **NO-GO** until operator-supplied test credentials confirm end-to-end provider connectivity.

