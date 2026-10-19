# RAD Production Additive Migration Plan (2026-10-19)

**GitHub main:** `41a18105de2fac2ff383000a233095b74a8a0e7b`  
**Production ref:** `inshddthftkhcdosoqcn`  
**Live history last (2026-10-18 / ChatGPT 2026-10-19):** `20261007212140_stage9_security_grant_hardening` (47 records)  
**This document is an execution plan — not evidence of production apply.**

---

## Access status this session

| Channel | Result |
|---------|--------|
| GitHub / local repo | OK |
| Supabase connector | **User skipped / unavailable** |
| CLI access-token | None |
| Production writes | **0** |
| Disposable local staging DB (`supabase_db_rad_staging_preview`) | Synthetic only — phase24 applied; history now **59** |
| Edge Deno 2.5.4 tests | **116 passed** |

---

## Do not re-apply (timestamp aliases)

Live production already recorded many Stage1–Stage9 logical migrations under **different version IDs** than the current repository filenames. Re-running those SQL files risks `already exists` failures or double grants.

Examples of repo versions **absent from live version list** but **logically already applied** under alternate timestamps (fingerprint audit):

- `client_delivery_ai_scopes`, `stage1_ai_research_completion`, `stage2_review_feed_publish`, `stage2_visa_structured_steps`, `stage3_fk_covering_indexes`, `stage5_research_review_candidate_backfill`, `fix_profile_update_with_check_role_escalation`, `ai_dynamic_routing_architecture`, `ai_credential_failure_routing`, `research_atomic_review_candidate`, `stage2_knowledge_*`, `stage4_*`, `stage5_visa_editorial_summaries`, `stage6_entitlement_access_decision`, `stage7_ops_consultation_app_status`, `stage9_security_grant_hardening`

**Action:** object-level verify only; never blind re-run.

---

## Candidate additive sequence (post live `20261007212140`)

These repository versions are **after** the last recorded production migration and were **not** observed in the 47-row live history. They are the only forward candidates for a controlled production apply **after** backup + clone rehearsal + owner approval.

| Order | Version | File | Intent |
|------:|---------|------|--------|
| 1 | 20261010010000 | stage1_p0_security_completion | P0 security completion |
| 2 | 20261010055013 | stage1_atomic_ai_quota_reservation | Atomic AI quota |
| 3 | 20261010070000 | stage1_ssrf_ipv4_mapped_ipv6 | SSRF hardening |
| 4 | 20261012110945 | stage1_security_abuse_storage_alignment | Abuse/storage alignment |
| 5 | 20261012230000 | ai_models_check_constraints_alignment | AI model CHECKs |
| 6 | 20261017190000 | security_ai_entitlement_rpc_privacy | Entitlement RPC privacy |
| 7 | 20261018125432 | local47_crm_notification_outbox | CRM notification outbox |
| 8 | 20261018142313 | local47_payment_sandbox_integrity | Payment sandbox integrity |
| 9 | 20261018143455 | local47_notification_privilege_alignment | Notification privileges |
| 10 | 20261018152513 | local47_document_atomic_processing | Document atomic processing |
| 11 | 20261018154834 | local47_observability_privacy_and_triage | Observability privacy |
| 12 | 20261018210000 | stage10_covering_fk_indexes_completion | FK covering indexes |
| 13 | 20261018211645 | phase24_mock_checkout_and_crm_search | Mock checkout + CRM search |

**Precondition for each step:**

1. Current recoverable backup of production (Free plan: confirm actual backup product; PITR typically **not** on Free).
2. Isolated upgrade rehearsal succeeds on a **synthetic or authorized clone** (not production).
3. Explicit owner authorization for that step.
4. Verify expected objects after each apply; stop on unexpected error.

**Rollback:** reverse is not automatic; prefer restore from backup for severe failure. Prefer additive fixes over DROP.

---

## Free plan / branching notes

- Organization reported **Free** subscription.
- PITR / physical restore / unlimited development branches are **not** assumed available.
- Supabase Branching showed **MIGRATIONS_FAILED** on main branch metadata — investigate with live logs when connector available; do not reset production to clear branch status.
- Creating a chargeable branch requires **explicit cost approval** (not done).

---

## Isolated local rehearsal evidence

| Environment | Migrations | Notes |
|-------------|------------|-------|
| `supabase_db_rad_codex_phase24_20261019` | 59 | Full repo set |
| `supabase_db_rad_staging_preview` | 59 | Was 58; phase24 SQL applied 2026-10-19 (synthetic) |
| Clean disposable replay | 59/59 | Requires storage stubs + COMMIT handling |

This is **not** a production upgrade proof.

---

## Edge Functions deployment intent

| Function | Production today | Deploy when |
|----------|------------------|-------------|
| ai-orchestrator | v11 | Schema deps + regression green |
| document-intelligence | v3 | Same |
| research-sync | v4 `verify_jwt=false` | Only after caller auth confirmed |
| notification-dispatch | Not deployed | Explicit product decision |
| payment-sandbox | Not deployed | Sandbox-only; never real charges |

---

## Exact next approved operations (owner)

1. Re-enable Supabase access for this agent or run dashboard inventory yourself.
2. Confirm Free-plan backup snapshot exists **after** latest data changes.
3. Authorize (or decline) paid branch/upgrade if needed for clone rehearsal.
4. Approve ordered apply of candidate rows 1–13 one at a time with verification.
5. Authorize Edge Function deploys independently.
