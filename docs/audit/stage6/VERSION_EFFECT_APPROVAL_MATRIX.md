# RAD EMIGRATE — STAGE 6: VERSION-TO-EFFECT APPROVAL MATRIX

**Document ID:** `VERSION_EFFECT_APPROVAL_MATRIX`  
**Date:** 2026-10-22  
**Role:** Principal Database Architect & Migration Forensics Specialist (Codex)  
**Repository:** `rademigrate-ai/rad_emigrate`  
**Target Candidate SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Scope:** 54 Hosted Baseline Migrations + 21 Forward Additions  

---

## 1. Approval Authority Definitions

* **[OWNER]:** Project Owner (Requires administrative confirmation in writing / Supabase Dashboard action).
* **[ARCHITECT]:** Principal Database Architect / Lead Security Engineer (Automated via signed migration script and rehearsal evidence).
* **[OPERATIONS]:** Release Operations Engineer (Requires scheduled maintenance execution).

---

## 2. Complete Approval & Catalog Effect Matrix

### Part I: The 54 Baseline Hosted Migrations (Status on `inshddthftkhcdosoqcn`)

| Hosted Version | Recorded Migration Name | SQL Statement Fingerprint (MD5) | Primary Catalog Effects | Applied Status | Required Approval |
|:---:|:---|:---:|:---|:---:|:---:|
| `20261001191421` | `initial_rad_core_schema` | `b451f1d98173ace6ea9d7d5ae81f7a20` | Core tables (`profiles`, `cases`, `documents`, `audit_events`) | Applied | [ARCHITECT] |
| `20261001191653` | `create_profile_trigger_and_storage_setup_v2` | `5f45a36ffdaaa44555bea781894bbb6d` | `handle_new_user()` trigger, Storage bucket creation | Applied | [ARCHITECT] |
| `20261001194638` | `security_hardening_handle_new_user` | `b03873c096d9df2637104cd6b68caf0b` | `search_path=''` on auth triggers | Applied | [ARCHITECT] |
| `20261001194715` | `add_rad_backend_indexes` | `ee98e5f91b84a1bc582e33ce23d7d377` | B-tree indexes on `profiles(id)`, `cases(user_id)` | Applied | [ARCHITECT] |
| `20261001195750` | `security_hardening` | `df5a0b5cb372efe6fa91a6dd3bc0f872` | Definer hardening on core helpers | Applied | [ARCHITECT] |
| `20261001195754` | `rls_policies` | `c37153a7353fad40fc13a174fc973513` | Initial RLS policies on `profiles`, `cases` | Applied | [ARCHITECT] |
| `20261001195756` | `storage_policies` | `d4e07909cba3b2744e1e4cebe934dd04` | Initial storage bucket RLS | Applied | [ARCHITECT] |
| `20261001200202` | `ai_sessions_and_document_bootstrap` | `61237207dc79e43af2d477740b35f05b` | `ai_conversations`, `ai_messages` tables | Applied | [ARCHITECT] |
| `20261001214952` | `project05_launch_hardening` | `5544b9910d32aa0765be410f78a4bb84` | Case status enums, foreign key cascades | Applied | [ARCHITECT] |
| `20261001215315` | `project05_storage_upload_limits` | `65f2ff5848c24cde17fc2db2da0ec661` | Storage file size checks (10MB limit) | Applied | [ARCHITECT] |
| `20261001215758` | `project05_minimize_table_privileges` | `f599f57ebbf7a4e69bc5eb45788e0258` | Initial REVOKE on public tables | Applied | [ARCHITECT] |
| `20261001225237` | `profile_bootstrap_policy` | `378ea9f1ad48ba1cc9d68c98c199589c` | Fallback insert policy for profile bootstrap | Applied | [ARCHITECT] |
| `20261001225632` | `storage_validation_policies` | `2623d6a2a07504a796e6a14ecb2fa796` | Storage MIME validation | Applied | [ARCHITECT] |
| `20261001225634` | `ai_message_ownership_policies` | `213ff170997bc5b206ce59828ec535bf` | AI conversation user-isolation policies | Applied | [ARCHITECT] |
| `20261001233027` | `signup_trigger_search_path` | `2f9f1092aaae5a5394ef37d10c010620` | Fixed search path on signup | Applied | [ARCHITECT] |
| `20261001233048` | `relationship_policies_and_indexes` | `5a5d8b76c5b61bc46e45ba6c3b999a4c` | Relationship indexes on document ownership | Applied | [ARCHITECT] |
| `20261003102347` | `restrict_documents_bucket_uploads` | `dbbc9bc4ad21b8cce6779ee7bfb0cc37` | Strict document upload restrictions | Applied | [ARCHITECT] |
| `20261003210302` | `project09_visa_catalog` | `9b3ebf2ad0e43d1a89270df8c9f55e09` | `visa_programs`, `countries`, `categories` | Applied | [ARCHITECT] |
| `20261003211635` | `project10_knowledge_research` | `3df4ba62b9f0294b9bc975e5332f91eb` | Knowledge base tables and citation links | Applied | [ARCHITECT] |
| `20261003212339` | `project10_security_hardening` | `031e40ebad8d67ee847847c23bc9ee46` | Knowledge base RLS and read-only views | Applied | [ARCHITECT] |
| `20261003213219` | `project11_ai_orchestration` | `1daaa08a9cc22b64a181156e7aa7c300` | `ai_models`, `ai_model_telemetry` | Applied | [ARCHITECT] |
| `20261003214031` | `project12_document_intelligence` | `8c4f9da7ad2a84a282f6e5e9b8970420` | OCR extraction jobs, document parse cache | Applied | [ARCHITECT] |
| `20261003221324` | `project13_admin_operations` | `a3978bb1adcc8ca3cfb1da199c922572` | Admin audit ledger, `private.has_role()` | Applied | [ARCHITECT] |
| `20261003222909` | `project14_feed_notifications` | `1ef9d27bf9f7d24268a7356c9a6225ff` | `feed_items`, `notifications` tables | Applied | [ARCHITECT] |
| `20261003223717` | `project15_observability` | `9153a7e4b93f6087da2551cf4402633d` | Telemetry logs and error trace tables | Applied | [ARCHITECT] |
| `20261003235000` | `ai_base_url_ssrf_hardening` | `3429beaa3d2426c59b6b7cf4cbcf99b2` | URL pattern constraint on AI provider base URLs | Applied | [ARCHITECT] |
| `20261004190000` | `fix_profile_update_rls_recursion` | `c505eaec822eb111da334a1aa74cb73f` | Fixed circular RLS evaluation on profiles | Applied | [ARCHITECT] |
| `20261005123027` | `client_delivery_ai_scopes` | `5c84dfc89d261eefaa9baee857b2a609` | AI authorized data scopes array validation | Applied (Alias) | [ARCHITECT] |
| `20261005123202` | `stage1_ai_research_completion` | `bb5b67adbb687b1c4bfa64115f5d34ad` | Research candidate tables & review helpers | Applied (Alias) | [ARCHITECT] |
| `20261005123255` | `stage2_review_feed_publish` | `5c9f130b912c9826372d8e48b8b39864` | `publish_feed_item()` with admin check | Applied (Alias) | [ARCHITECT] |
| `20261005180215` | `stage3_fk_covering_indexes` | `5dfb52e379ffea435adfb34c672d5f7b` | Covering foreign key indexes across schema | Applied (Alias) | [ARCHITECT] |
| `20261006144235` | `stage2_visa_structured_steps` | `3fae9e802ef6e91bf95ad4ea55755ba9` | Structured pathway steps JSONB schema | Applied (Alias) | [ARCHITECT] |
| `20261006144246` | `stage5_research_review_candidate_backfill` | `ee30f81a702b85fa1989c9ccba204554` | Review backfill helper functions | Applied (Alias) | [ARCHITECT] |
| `20261006161823` | `fix_profile_update_with_check_role_escalation` | `3a5a8f4c4bc475ce989c450eb938b8dc` | `WITH CHECK` role guard on profile updates | Applied (Alias) | [ARCHITECT] |
| `20261006221616` | `ai_dynamic_routing_architecture` | `0507a6fc7e0c45aaeb170d196425977a` | Model capability routing matrix | Applied (Alias) | [ARCHITECT] |
| `20261007075108` | `ai_credential_failure_routing` | `283738be789f6b5b50d890b501f2f814` | Provider failure backoff tracking | Applied (Alias) | [ARCHITECT] |
| `20261007075110` | `research_atomic_review_candidate` | `ad6eb0b8a3e75e92591605ecb725ce96` | Atomic review transaction function | Applied (Alias) | [ARCHITECT] |
| `20261007142614` | `ai_discovery_auto_enable_chat` | `d707fa4b560a4222886686f22a7edaa5` | `is_chat_enabled = true` on initial models | Applied | [ARCHITECT] |
| `20261007171212` | `stage2_knowledge_completion` | `ba1e3ba65da9e2eead812f6a91ae3ea0` | Knowledge citation verification states | Applied (Alias) | [ARCHITECT] |
| `20261007171310` | `stage2_promote_knowledge_fn` | `003921eb4855bf5186ed9e8e541cdc50` | `promote_knowledge_candidate()` RPC | Applied | [ARCHITECT] |
| `20261007171341` | `stage2_retrieve_and_conflict_fn` | `3d5a70c90c7e8b6236a2a459363004a6` | `retrieve_knowledge_and_detect_conflicts()` | Applied | [ARCHITECT] |
| `20261007183840` | `stage4_user_ai_quota_grounding` | `261ad7a5beadfcb7c7b5d1e2612a83e0` | User quota bucket checks & daily limits | Applied (Alias) | [ARCHITECT] |
| `20261007185216` | `stage4_guest_quota_advisory_lock` | `0fb30e2309485642a388de0ffcbd82ee` | Advisory xact lock on guest hash | Applied | [ARCHITECT] |
| `20261007192522` | `stage4_limit_ai_runtime_chain` | `b6805b565d75d2728f322cb2fa874cf0` | Maximum recursion limit on AI tool calls | Applied (Alias) | [ARCHITECT] |
| `20261007202907` | `stage6_entitlement_access_decision` | `3890250bb00fb01b80d0d8beeb936166` | Entitlement RPCs for feature access gates | Applied (Alias) | [ARCHITECT] |
| `20261007205734` | `stage7_ops_consultation_app_status` | `e2a149b5c210d6a4570075d9e50a9ee7` | Consultation request appointment status | Applied (Alias) | [ARCHITECT] |
| `20261007212140` | `stage9_security_grant_hardening` | `3309a96e95ce2ef13715c0e1a141aa91` | Revoke EXECUTE on private functions | Applied (Alias) | [ARCHITECT] |
| `20261019130911` | `20261010010000_stage1_p0_security_completion` | `bb16b8dafc6e7efc9e7845f7c3c5443e` | Strict definer search_path enforcement | Applied (Prefix) | [ARCHITECT] |
| `20261019131205` | `20261017190000_security_ai_entitlement_rpc_privacy` | `34e062eb142e22c095c52c67b2ff1f4c` | Private definer checks for AI entitlements | Applied (Prefix) | [ARCHITECT] |
| `20261019131224` | `20261010055013_stage1_atomic_ai_quota_reservation` | `ea89b1d9bf0d750c18d18442be4b6008` | `reserve_ai_quota()` and `settle_ai_quota()` | Applied (Prefix) | [ARCHITECT] |
| `20261019131243` | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6` | `3a5a3a7924619ee945ba4927f8045610` | SSRF regex rejecting IPv4-mapped IPv6 | Applied (Prefix) | [ARCHITECT] |
| `20261019131312` | `20261012110945_stage1_security_abuse_storage_alignment` | `5eef9115fa34e6c99c277ee710776bdf` | Storage path owner prefix enforcement | Applied (Prefix) | [ARCHITECT] |
| `20261019131319` | `20261012230000_ai_models_check_constraints_alignment` | `e2a3c7b74681f21aa42d88bb5d7da00f` | Model temperature & token bound constraints | Applied (Prefix) | [ARCHITECT] |
| `20261019171732` | `repair_admin_consultation_rpcs` | `432d5e2365bbad7f3bc5239a04ad5323` | Admin consultation list/update RPCs | Applied (Alias) | [ARCHITECT] |

---

### Part II: The 21 Forward Additions (To be Applied in Staging Rehearsal)

| Step | Candidate Version | Migration Name | SHA-256 (LF) | Dependencies | New Catalog Objects / Alterations | Required Approval |
|:---:|:---:|:---|:---:|:---|:---|:---:|
| 1 | `20261019204906` | `rad_security_contract_foundation` | `3f6fb779b2b39202f1ad9a254a1cdb952903f3a1cfb9670d642434459f4667dd` | Baseline (54) | Revokes `INSERT(role)` on `profiles`; `private.rad_require_admin()` | **[ARCHITECT]** |
| 2 | `20261019205040` | `rad_visa_cms_official_evidence` | `86f063682a53ae7de40ff9547cfb50790f8c4051ed3e20e68eb38f5d9ca2557d` | Step 1 | `visa_articles`, `visa_article_revisions`, `evidence_snapshots` | **[ARCHITECT]** |
| 3 | `20261019205454` | `rad_currency_cache_alerts` | `f5dd28555fd2a391b3b45b1c87a96531753f6d9c0375b4b6329c82df48450884` | Step 1 | `currency_rates`, `currency_alerts`, `get_exchange_rate()` | **[ARCHITECT]** |
| 4 | `20261019205459` | `rad_feed_notifications_search` | `4eecd6634e3501ac10eebf8d17d50116999353ec848b1af025061377e1e0c42e` | Step 2 | `search_visa_articles()` RPC, feed search indices | **[ARCHITECT]** |
| 5 | `20261019205502` | `rad_copilot_scoped_reservations` | `9dc47563d265e7783702ec7330fef2290a4482862cf9b03e83d60f7d240d748b` | Step 1 | Scoped quota reservations table and claim RPCs | **[ARCHITECT]** |
| 6 | `20261019210000` | `g002_content_architecture_scaffolding` | `f5fc08f64fd22efa914cc46c58ceb692ca347cae5a9a09702929e0d0095f8994` | Step 2 | Structured pathway steps and requirement types | **[ARCHITECT]** |
| 7 | `20261019210423` | `rad_content_workflows` | `807875ea31b7098d1f520a70fdc4d914fb132aaad6b514ab9ae194324e305e3d` | Step 6 | Editorial workflow state machine triggers | **[ARCHITECT]** |
| 8 | `20261019211000` | `security_quota_owner_and_publish_approved` | `672148a8a51ad33eff61ea1f4b68f09317c69166ab4c7f88490958f6211b16fa` | Step 5, 7 | Human publication authorization trigger guard | **[ARCHITECT]** |
| 9 | `20261019211908` | `rad_feed_delivery_contracts` | `55f2560b4e46c342c306782c1246c6fb310814d1e384c070c40e72cc478babcc` | Step 4 | Feed delivery closed JSON schema validators | **[ARCHITECT]** |
| 10 | `20261019212615` | `rad_source_jobs_merge_enforcement` | `d417e2b35b4a05190fd22d8da22c2179be44370fb9a0a246e864394fad88b160` | Step 7 | Official source crawler job state tables | **[ARCHITECT]** |
| 11 | `20261019213129` | `rad_contract_finalization` | `e21c565f2f377f2f3b2201b33031b2fa7a7f140b65f8b449e4e2eb85a83cc5fb` | Step 1-10 | Registers all canonical JSON schemas in database | **[ARCHITECT]** |
| 12 | `20261019214411` | `rad_legacy_quota_budget_compatibility` | `7d65098001f2dbecc52ad74ff46f262d69efb9638e217346e16c20225a0834ad` | Step 5 | Legacy quota consumption backward adapter | **[ARCHITECT]** |
| 13 | `20261020103648` | `rad_backend_integrity_completion` | `ac86171d4aa63e27c113efa811035be00c383be855b80a3e539bfdfd5767fd47` | Step 1-12 | Foreign key integrity triggers and cleanup | **[ARCHITECT]** |
| 14 | `20261020105854` | `rad_search_aliases_currency_history` | `1f6440f176a1333da2bebc3b5ae1ecdc84af4e378040552467edfa0c0046b985` | Step 3, 4 | Search query synonym dictionary and FX log | **[ARCHITECT]** |
| 15 | `20261020111217` | `rad_restore_legacy_publish_privileges` | `8cd83db51feb86bbe40b2ea5e325a93ddaf642b534f056eda0fa39139870d981` | Step 8 | Admin role grants for publishing RPCs | **[ARCHITECT]** |
| 16 | `20261020112300` | `rad_crm_search_integration_hardening` | `de82f8350f330cdb3bb5dc5a2978353824ed8bab7637b2c6f89ce36455b7f0b6` | Step 4 | Consultation search index and sanitization | **[ARCHITECT]** |
| 17 | `20261020114612` | `rad_transport_contract_registry_alignment` | `8ae61793f441ade43a7bfc9fb37f22ff1817a2fd6014c9c8d0a1e152cd1b81f4` | Step 11 | `x-rad-contract-version` assertions in PostgREST | **[ARCHITECT]** |
| 18 | `20261020115539` | `rad_leased_research_base_contract` | `8c13fa85d06a6f57d28c90bc676a5cab57ad6da3e7f19fcad50c054973238129` | Step 10 | Distributed crawler lease acquisition locks | **[ARCHITECT]** |
| 19 | `20261020123523` | `rad_explicit_service_profile_bootstrap` | `569ac10dc29dc1cec17b45b3ab885f4d728fc202c99b165f394aaa228d4344d4` | Step 1 | Service role user profile bootstrap optimization | **[ARCHITECT]** |
| 20 | `20261020192732` | `rad_revoke_client_nonrow_table_privileges` | `5d7dfc6f38181431ed4203c1529fbb9b8764d0f89234891c5ab41e5c05e510f3` | Step 1-19 | **REVOKE ALL NON-ROW:** Eliminates 48 table capabilities and 100 column REFERENCES | **[OWNER] + [ARCHITECT]** |
| 21 | `20261021210337` | `rad_cms_admin_draft_reads` | `63bb109c7b7d1ae57a4fdcf2c8394828601644004d94fe032705a33d3cc2b021` | Step 2, 11 | **PR #74 CMS:** Defines `list_cms_articles()` and `get_cms_article_draft()` | **[ARCHITECT]** |

---

## 3. Pre-Approved Execution Order

To execute the forward additions safely in staging:
```bash
# Verify checksum of the forward sequence file
sha256sum PR74_REMEDIATION_20261022/prospective_forward_order.json
# All 21 files must be executed within a single transactional block or sequential check-stop loop
```
