# RAD EMIGRATE — MIGRATION RECONCILIATION MATRIX

**Scope:** Full Chronological Inventory of Repository Migrations vs Production Supabase Ledger (`inshddthftkhcdosoqcn`)  
**Repository Branch Baseline:** `main` (46 migrations) + PR #48 (5 Stage 1 migrations) = 51 migrations  
**Historical Production Ledger:** 47 recorded versions ending at `20261007212140`  
**Classification Date:** October 17, 2026  

---

## 1. RECONCILIATION LEGEND & SAFETY POLICIES

- **MATCH:** Migration timestamp and name exist in both Repository and Production ledger, with schema effects active in live database.
- **ALIAS (16 entries):** Historical migration applied to Production with an alternate timestamp or name. **NEVER REPLAY OR TOUCH IN PRODUCTION.**
- **LIVE-ONLY (4 entries):** Schema modifications applied directly to Production during historical setup. Recorded in ledger; not present as standalone files in clean repo.
- **PENDING STAGE 1 (5 files):** Newly verified P0/P1 security migrations in PR #48. Verified in synthetic isolated environments; awaiting DBA deployment sequence.
- **NEVER RUN `supabase db push`:** Automatic schema push tools attempt to reconcile aliases by dropping or recreating objects, leading to immediate database corruption or downtime.

---

## 2. COMPREHENSIVE 51-MIGRATION INVENTORY MATRIX

| # | Filename | Version | Purpose & Dependencies | Expected DB Effects | Prod Ledger Status | Live Schema Status | Safe to Replay? | Reconciliation Action |
|---|---|---|---|---|---|---|---|---|
| 1 | `20261001191421_initial_rad_core_schema.sql` | `20261001191421` | Core RAD tables, enum types, UUID extensions | Creates profiles, visas, cases | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 2 | `20261001191653_create_profile_trigger_and_storage_setup_v2.sql` | `20261001191653` | Auth signup hook and storage buckets | Profile sync trigger, avatars bucket | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 3 | `20261001194638_security_hardening_handle_new_user.sql` | `20261001194638` | Search path and security definer hardening | Hardens handle_new_user trigger | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 4 | `20261001194715_add_rad_backend_indexes.sql` | `20261001194715` | Performance indexes on core foreign keys | Indexes on profiles, cases | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 5 | `20261001195750_security_hardening.sql` | `20261001195750` | Role enum checks, profile escalation guard | Role trigger, profile immutability | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 6 | `20261001195754_rls_policies.sql` | `20261001195754` | RLS enablement across public tables | Strict SELECT/UPDATE/DELETE RLS | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 7 | `20261001195756_storage_policies.sql` | `20261001195756` | Storage upload/download policies | User-bound storage path RLS | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 8 | `20261001200202_ai_sessions_and_document_bootstrap.sql` | `20261001200202` | AI chat session tables, documents bucket | ai_sessions, documents tables | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 9 | `20261001214952_project05_launch_hardening.sql` | `20261001214952` | PostgREST public schema permissions | Grant tightening | Recorded (Alias) | Active | NO (Preserve alias) | Historical Alias |
| 10 | `20261001215315_project05_storage_upload_limits.sql` | `20261001215315` | MIME type checks, upload size constraints | Storage validation trigger | Recorded (Alias) | Active | NO (Preserve alias) | Historical Alias |
| 11 | `20261001215758_project05_minimize_table_privileges.sql` | `20261001215758` | Revoke default PUBLIC table privileges | Tighten authenticated role | Recorded (Alias) | Active | NO (Preserve alias) | Historical Alias |
| 12 | `20261001225237_profile_bootstrap_policy.sql` | `20261001225237` | Permissive first-write profile bootstrap | Self-registration INSERT policy | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 13 | `20261001225632_storage_validation_policies.sql` | `20261001225632` | Storage object extension whitelist | PDF, JPEG, PNG restriction | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 14 | `20261001225634_ai_message_ownership_policies.sql` | `20261001225634` | Scoped message reads to conversation owner | ai_messages RLS | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 15 | `20261001233027_signup_trigger_search_path.sql` | `20261001233027` | Set search_path = '' on auth triggers | Path vulnerability hardening | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 16 | `20261001233048_relationship_policies_and_indexes.sql` | `20261001233048` | Join indexes and relational RLS | Covering foreign keys | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 17 | `20261003102347_restrict_documents_bucket_uploads.sql` | `20261003102347` | Documents bucket 10MB limit enforcement | Storage size check | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 18 | `20261003210302_project09_visa_catalog.sql` | `20261003210302` | Visa catalog schemas, country classifications | visa_catalog, visa_categories | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 19 | `20261003211635_project10_knowledge_research.sql` | `20261003211635` | Knowledge base, research sources, drafts | knowledge_items, content_drafts | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 20 | `20261003212339_project10_security_hardening.sql` | `20261003212339` | Research review gates and role protection | Status validation | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 21 | `20261003213219_project11_ai_orchestration.sql` | `20261003213219` | Dynamic AI routing, provider registries | ai_providers, ai_models | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 22 | `20261003214031_project12_document_intelligence.sql` | `20261003214031` | OCR and document verification pipelines | document_processor_config | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 23 | `20261003221324_project13_admin_operations.sql` | `20261003221324` | Admin audit logging, role evaluation | admin_audit_logs, has_role() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 24 | `20261003222909_project14_feed_notifications.sql` | `20261003222909` | Official feed, notifications, bookmarks | feed_items, user_notifications | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 25 | `20261003223717_project15_observability.sql` | `20261003223717` | Security telemetry, latency monitoring | system_health_logs | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 26 | `20261003235000_ai_base_url_ssrf_hardening.sql` | `20261003235000` | SSRF prevention function on base_url | is_safe_public_https_url() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 27 | `20261004190000_fix_profile_update_rls_recursion.sql` | `20261004190000` | Break infinite recursion on profile update | Optimized profile policy | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 28 | `20261004203000_client_delivery_ai_scopes.sql` | `20261004203000` | Scoped provider visibility (user/admin) | runtime_scope enum | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 29 | `20261005102000_stage1_ai_research_completion.sql` | `20261005102000` | Atomic research candidate promotion | promote_research_candidate() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 30 | `20261005120000_stage2_review_feed_publish.sql` | `20261005120000` | Draft-to-Feed human publication RPC | publish_content_draft() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 31 | `20261005130000_stage2_visa_structured_steps.sql` | `20261005130000` | Visa process step ordering and schema | visa_steps | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 32 | `20261005190000_stage3_fk_covering_indexes.sql` | `20261005190000` | Covering indexes for cascade locks | FK performance optimization | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 33 | `20261006132931_stage5_research_review_candidate_backfill.sql` | `20261006132931` | Backfill review candidates from drafts | Data reconciliation | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 34 | `20261006180000_fix_profile_update_with_check_role_escalation.sql` | `20261006180000` | WITH CHECK role escalation block | Prevent self-promotion to admin | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 35 | `20261007080000_ai_dynamic_routing_architecture.sql` | `20261007080000` | Dynamic provider routing engine | get_ai_runtime_chain() | Recorded (Alias) | Active | NO (Preserve alias) | Historical Alias |
| 36 | `20261007080001_ai_credential_failure_routing.sql` | `20261007080001` | Circuit breaker on credential rejection | record_ai_provider_outcome() | Recorded (Alias) | Active | NO (Preserve alias) | Historical Alias |
| 37 | `20261007080002_research_atomic_review_candidate.sql` | `20261007080002` | Atomic deduplication on candidate intake | Candidate upsert RPC | Recorded (Alias) | Active | NO (Preserve alias) | Historical Alias |
| 38 | `20261007180000_stage2_knowledge_completion.sql` | `20261007180000` | Knowledge base search path hardening | Hardened knowledge RPCs | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 39 | `20261007180001_stage2_knowledge_promote.sql` | `20261007180001` | Atomic knowledge promotion workflow | promote_knowledge_item() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 40 | `20261007180002_stage2_knowledge_retrieve_conflict.sql` | `20261007180002` | Conflict retrieval for dual statements | get_knowledge_conflicts() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 41 | `20261007210000_stage4_user_ai_quota_grounding.sql` | `20261007210000` | Daily request quotas per user role | ai_usage_limits table | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 42 | `20261007212000_stage4_limit_ai_runtime_chain.sql` | `20261007212000` | Limit failover depth to max 5 models | Bounded chain resolution | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 43 | `20261007220000_stage5_visa_editorial_summaries.sql` | `20261007220000` | Editorial visa summary columns | Bilingual summaries | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 44 | `20261007230000_stage6_entitlement_access_decision.sql` | `20261007230000` | AI entitlement decision engine | get_ai_access_decision() | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 45 | `20261008010000_stage7_ops_consultation_app_status.sql` | `20261008010000` | Consultation requests table bootstrap | consultation_requests table | Recorded | Active | NO (Already applied) | Pinned Baseline |
| 46 | `20261008020000_stage9_security_grant_hardening.sql` | `20261008020000` | Revoke dangerous default API grants | Minimal surface grants | Recorded | Active | NO (Already applied) | Pinned Baseline |
| **47** | `20261010010000_stage1_p0_security_completion.sql` | `20261010010000` | Stage 1 P0: Consultation confidentiality, human Feed guards | Column grants, admin RPCs | **PENDING** | **ABSENT** | **YES (Apply Step 1)** | **Apply via DBA Runbook** |
| **48** | `20261010055013_stage1_atomic_ai_quota_reservation.sql` | `20261010055013` | Atomic AI quota reservation with locks | Advisory lock quota RPC | **PENDING** | **ABSENT** | **YES (Apply Step 2)** | **Apply via DBA Runbook** |
| **49** | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` | `20261010070000` | SSRF hardening for IPv4-mapped IPv6 | Dual-stack SSRF regex | **PENDING** | **ABSENT** | **YES (Apply Step 3)** | **Apply via DBA Runbook** |
| **50** | `20261012110945_stage1_security_abuse_storage_alignment.sql` | `20261012110945` | Storage RLS upsert & consultation rate limit | submit_consultation_request | **PENDING** | **ABSENT** | **YES (Apply Step 4)** | **Apply via DBA Runbook** |
| **51** | `20261012230000_ai_models_check_constraints_alignment.sql` | `20261012230000` | Validate AI model numeric CHECK constraints | Non-blocking CHECK validate | **PENDING** | **ABSENT** | **YES (Apply Step 5)** | **Apply via DBA Runbook** |

---

## 3. KEY RECONCILIATION FINDINGS & GUIDELINES

1. **No Migration History Alteration:** The Production ledger's existing 47 records must remain untouched. Do not run `supabase migration repair` to rename aliases or reconcile timestamps.
2. **Strict Forward Application:** The 5 pending migrations must be applied strictly in order (47 -> 48 -> 49 -> 50 -> 51) during an authorized DBA change window.
3. **Additive & Safe:** None of the 5 pending migrations drop existing application tables or destroy existing data.
4. **Transient Column Grant Behavior:** Migration 47 temporarily grants specific insert columns on `consultation_requests`, which Migration 50 subsequently revokes in favor of `submit_consultation_request()`. For this reason, the full chain 47–51 must be executed to completion.
