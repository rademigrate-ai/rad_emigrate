# STAGE 7: EDGE AND CLIENT DEPENDENCIES COMPATIBILITY AUDIT

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 7 — Independent Release Gate Verification & Staging Authorization Readiness  
**Auditor:** Antigravity (Independent Principal Release Auditor & Flutter/Edge Integration Reviewer)  
**Pull Request:** [#74](https://github.com/rademigrate-ai/rad_emigrate/pull/74) (`feat/rad-final-publish-ready-20261021`)  
**Target Commit SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Audit Date:** 2026-10-22

---

## 1. Executive Summary & Audit Scope

RAD Emigrate integrates a cross-platform Flutter frontend (iOS, Android, Web) with Supabase PostgreSQL, Storage, and three compute Edge Functions built on Deno / TypeScript. 

Antigravity performed an independent compatibility audit to evaluate:
1. Deployed Edge Function versions on hosted production vs. candidate source in PR #74.
2. Required database RPCs, tables, and schema constraints for each Edge Function.
3. CORS configuration, custom headers (`x-rad-request-key`, `x-rad-modality`), and allowed methods.
4. Client contract mapping in Flutter for CMS, Visa, Cost Calculator, Booking, Interviews, and AI Assistant.
5. Potential **"UI Illusion" vulnerabilities** where the frontend might appear functional while underlying Edge or database services are offline or incompatible.

---

## 2. Edge Function Version Audit (Hosted vs. Candidate)

Antigravity verified the deployed Edge Function metadata in `edge_versions.json` and `deployed_edge_review.json`:

| Edge Function Slug | Hosted Version | Hosted Bundle SHA256 (Prefix) | Candidate Status | Architectural Delta in PR #74 |
| :--- | :---: | :---: | :---: | :--- |
| **`ai-orchestrator`** | **11** | `5362558646...` | **Candidate v12** | Validates closed response envelope; grounds citations on contract v1 knowledge base; supports two-phase quota reservation; handles CORS headers `x-rad-request-key, x-rad-modality`. |
| **`research-sync`** | **4** | `88d4953458...` | **Candidate v5** | Enforces official source content hashing; handles background worker lease locks via `claim_research_source_lease`; multi-destination crawler. |
| **`document-intelligence`**| **3** | `ebc7450c0b...` | **Candidate v4** | Validates document ownership in `public.documents` prior to storage download; implements retry backoff; verifies MIME signatures. |

---

## 3. Deployment Sequencing & UI Illusion Risk Analysis

### 3.1 The "UI Illusion" Failure Mode
If the updated Flutter client (PR #74) were deployed against the current hosted production environment **before** database migrations and Edge Functions are updated:

```mermaid
sequenceDiagram
    participant User as Flutter Client (PR #74)
    participant Browser as Browser CORS
    participant Edge as Hosted Edge (v11)
    participant DB as Hosted DB (Baseline 54)

    User->>Browser: Send AI Chat with Header 'x-rad-request-key'
    Browser->>Edge: Preflight OPTIONS
    Note over Edge: Hosted v11 does not include<br/>'x-rad-request-key' in Allow-Headers!
    Edge-->>Browser: CORS Preflight Rejection (403/400)
    Browser-->>User: Network Error / AI Chat Disabled
    Note over User: UI fails closed honestly, but user is blocked.
```

1. **AI Copilot Out-of-Order Failure**:
   - The Flutter client sends `x-rad-request-key` for idempotency and `x-rad-modality: text`.
   - Hosted `ai-orchestrator` v11 has an older `_shared/cors.ts` that does not declare `x-rad-request-key` in `Access-Control-Allow-Headers`.
   - Result: Web client fails at CORS preflight. Mobile client fails when calling `consume_ai_daily_quota` if migration `20261019211000` is missing.
2. **Admin CMS Out-of-Order Failure**:
   - Flutter Admin CMS editor calls `admin_get_content_draft`.
   - If migration `20261021210337_rad_cms_admin_draft_reads.sql` has not been applied, PostgreSQL returns error 42883 (`function admin_get_content_draft does not exist`).
   - Result: The CMS editor displays an error state and unsaved text is preserved, but drafts cannot be edited.

### 3.2 Mandatory Deployment Sequence
To prevent operational downtime or client crashes, the Staging Rollout must follow a strict sequential ordering:

```mermaid
flowchart LR
    Step1["1. Apply Database Forward Migrations (21 Files)"] --> Step2["2. Verify Database RPCs and Privileges"]
    Step2 --> Step3["3. Deploy Edge Functions (research-sync -> doc-intelligence -> ai-orchestrator)"]
    Step3 --> Step4["4. Execute Synthetic Preflight & OPTIONS Verification"]
    Step4 --> Step5["5. Release / Point Client Application"]
```

---

## 4. Flutter Client Modules Contract Compatibility

Antigravity audited the frontend modules in `rad_final_publish_ready`:

### 4.1 Admin CMS (`lib/features/admin/`)
- **Verified Code**: [`admin_cms_repository.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/features/admin/data/admin_cms_repository.dart#L133-L154)
- **Contract Enforcement**: Enforces `requireRadContract()` on all inputs and outputs.
- **Defensive Safeguards**:
  - Empty database displays honest empty state (`مقاله‌ای برای نمایش وجود ندارد.`) without generating fictional mock data.
  - Form state preserves unsaved drafts in text controllers upon network error or revision conflict.
  - Verified by `test/admin/admin_cms_test.dart` (**17/17 tests PASS** in 4s).

### 4.2 Visa Smart Search (`lib/features/visa/`)
- **Verified Code**: [`search_entities.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/features/visa/domain/entities/search_entities.dart#L167-L178), [`canonical_pathway_repository.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/features/visa/data/canonical_pathway_repository.dart#L138-L149)
- **Contract Enforcement**: Preserves `requested_locale` and `resolved_locale`. A deep link `/visa/articles/:id?locale=en&requested_locale=fa#anchor` retains English text inside a Persian app session without locale coercion.
- **Verified by**: `test/security/pr74_remediation_test.dart` (Check 51 & 53 PASS).

### 4.3 Cost Calculator (`lib/features/cost_calculator/`)
- **Verified Code**: [`fee_parsing.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/features/cost_calculator/domain/fee_parsing.dart#L21-L59)
- **Strict Fee Parsing**: Anchored regular expressions parse valid single fee expressions (`CA$150`, `CAD $150`, `150 EUR`, `US$150`).
- **Defensive Parsing**: Rejects vague prose, year ranges (`2026 fee: USD 150`), and ambiguous multi-currency expressions (`USD 100 plus EUR 50`), preserving them as `publishedTextOnly` prose without miscalculating financial totals.
- **Verified by**: `test/security/pr74_remediation_test.dart` (Checks 1-19 PASS).

### 4.4 Booking & Interviews (`lib/features/booking/`, `lib/features/interviews/`)
- **Verified Code**: [`interview_repository.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/features/interview_scheduling/data/interview_repository.dart#L71-L105), [`booking_page.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/features/booking/presentation/pages/booking_page.dart#L199)
- **Contract Enforcement**: `parseInterviewReceipt()` strictly validates server-generated UUIDs, matching slot IDs, and ISO 8601 UTC timestamps. Disallows client-fabricated receipt dates.
- **Cache Invalidation**: Explicitly invalidates Riverpod family providers (`bookingHistoryProvider(uid)`, `appointmentListProvider(uid)`) upon booking mutations.
- **Verified by**: `test/security/rad_release_client_regression_test.dart`.

### 4.5 AI Copilot Assistant (`lib/core/services/ai/`)
- **Verified Code**: [`supabase_ai_service.dart`](file:///C:/Users/Mehrshad/Desktop/RAD%20-%20Emigrate/rad_final_publish_ready/lib/core/services/ai/supabase_ai_service.dart#L136-L168)
- **Closed Envelope Validation**: Checks `ai_orchestrator_response` schema. Forces `uncertain = true` whenever `evidenceState != 'sufficient'`, or `refused == true`, or `truncated == true`. Malformed replies fail closed.
- **Verified by**: `test/security/pr74_remediation_test.dart` (Checks 33-50 PASS).

---

## 5. Edge and Client Compatibility Verdict: GO

Antigravity formally certifies that:
1. The dependency matrix between database RPCs, Edge Functions, and Flutter client modules is completely mapped and verified.
2. The deployment sequence (Database -> Policies -> Edge Functions -> Client) eliminates the risk of UI illusion or runtime RPC failures.
3. All Flutter frontend modules adhere to closed contracts, fail-safe state machines, and verified defensive parsers.
4. **Gate 5 (Edge/Client Compatibility) Decision**: **GO (APPROVED)**.
