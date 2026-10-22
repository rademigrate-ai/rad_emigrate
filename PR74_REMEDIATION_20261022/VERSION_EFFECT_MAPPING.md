# Hosted migration version-to-effect review inputs

These are text/name candidates, not approved executable migrations. Review text differences and multipart entries against captured catalog effects.

| Hosted version | Recorded name | Repository effect/name candidates |
|---|---|---|
| 20261001191421 | `initial_rad_core_schema` | `supabase/migrations/20261001191421_initial_rad_core_schema.sql` |
| 20261001191653 | `create_profile_trigger_and_storage_setup_v2` | `supabase/migrations/20261001191653_create_profile_trigger_and_storage_setup_v2.sql` |
| 20261001194638 | `security_hardening_handle_new_user` | `supabase/migrations/20261001194638_security_hardening_handle_new_user.sql` |
| 20261001194715 | `add_rad_backend_indexes` | `supabase/migrations/20261001194715_add_rad_backend_indexes.sql` |
| 20261001195750 | `security_hardening` | `supabase/migrations/20261001195750_security_hardening.sql` |
| 20261001195754 | `rls_policies` | `supabase/migrations/20261001195754_rls_policies.sql` |
| 20261001195756 | `storage_policies` | `supabase/migrations/20261001195756_storage_policies.sql` |
| 20261001200202 | `ai_sessions_and_document_bootstrap` | `supabase/migrations/20261001200202_ai_sessions_and_document_bootstrap.sql` |
| 20261001214952 | `project05_launch_hardening` | `supabase/migrations/20261001214952_project05_launch_hardening.sql` |
| 20261001215315 | `project05_storage_upload_limits` | `supabase/migrations/20261001215315_project05_storage_upload_limits.sql` |
| 20261001215758 | `project05_minimize_table_privileges` | `supabase/migrations/20261001215758_project05_minimize_table_privileges.sql` |
| 20261001225237 | `profile_bootstrap_policy` | `supabase/migrations/20261001225237_profile_bootstrap_policy.sql` |
| 20261001225632 | `storage_validation_policies` | `supabase/migrations/20261001225632_storage_validation_policies.sql` |
| 20261001225634 | `ai_message_ownership_policies` | `supabase/migrations/20261001225634_ai_message_ownership_policies.sql` |
| 20261001233027 | `signup_trigger_search_path` | `supabase/migrations/20261001233027_signup_trigger_search_path.sql` |
| 20261001233048 | `relationship_policies_and_indexes` | `supabase/migrations/20261001233048_relationship_policies_and_indexes.sql` |
| 20261003102347 | `restrict_documents_bucket_uploads` | `supabase/migrations/20261003102347_restrict_documents_bucket_uploads.sql` |
| 20261003210302 | `project09_visa_catalog` | `supabase/migrations/20261003210302_project09_visa_catalog.sql` |
| 20261003211635 | `project10_knowledge_research` | `supabase/migrations/20261003211635_project10_knowledge_research.sql` |
| 20261003212339 | `project10_security_hardening` | `supabase/migrations/20261003212339_project10_security_hardening.sql` |
| 20261003213219 | `project11_ai_orchestration` | `supabase/migrations/20261003213219_project11_ai_orchestration.sql` |
| 20261003214031 | `project12_document_intelligence` | `supabase/migrations/20261003214031_project12_document_intelligence.sql` |
| 20261003221324 | `project13_admin_operations` | `supabase/migrations/20261003221324_project13_admin_operations.sql` |
| 20261003222909 | `project14_feed_notifications` | `supabase/migrations/20261003222909_project14_feed_notifications.sql` |
| 20261003223717 | `project15_observability` | `supabase/migrations/20261003223717_project15_observability.sql` |
| 20261003235000 | `ai_base_url_ssrf_hardening` | `supabase/migrations/20261003235000_ai_base_url_ssrf_hardening.sql` |
| 20261004190000 | `fix_profile_update_rls_recursion` | `supabase/migrations/20261004190000_fix_profile_update_rls_recursion.sql` |
| 20261005123027 | `client_delivery_ai_scopes` | `supabase/migrations/20261004203000_client_delivery_ai_scopes.sql` |
| 20261005123202 | `stage1_ai_research_completion` | `supabase/migrations/20261005102000_stage1_ai_research_completion.sql` |
| 20261005123255 | `stage2_review_feed_publish` | `supabase/migrations/20261005120000_stage2_review_feed_publish.sql` |
| 20261005180215 | `stage3_fk_covering_indexes` | `supabase/migrations/20261005190000_stage3_fk_covering_indexes.sql` |
| 20261006144235 | `stage2_visa_structured_steps` | `supabase/migrations/20261005130000_stage2_visa_structured_steps.sql` |
| 20261006144246 | `stage5_research_review_candidate_backfill` | `supabase/migrations/20261006132931_stage5_research_review_candidate_backfill.sql` |
| 20261006161823 | `fix_profile_update_with_check_role_escalation` | `supabase/migrations/20261006180000_fix_profile_update_with_check_role_escalation.sql` |
| 20261006221616 | `ai_dynamic_routing_architecture` | `supabase/migrations/20261007080000_ai_dynamic_routing_architecture.sql` |
| 20261007075108 | `ai_credential_failure_routing` | `supabase/migrations/20261007080001_ai_credential_failure_routing.sql` |
| 20261007075110 | `research_atomic_review_candidate` | `supabase/migrations/20261007080002_research_atomic_review_candidate.sql` |
| 20261007142614 | `ai_discovery_auto_enable_chat` | No same-name candidate; semantic review required |
| 20261007171212 | `stage2_knowledge_completion` | `supabase/migrations/20261007180000_stage2_knowledge_completion.sql` |
| 20261007171310 | `stage2_promote_knowledge_fn` | No same-name candidate; semantic review required |
| 20261007171341 | `stage2_retrieve_and_conflict_fn` | No same-name candidate; semantic review required |
| 20261007183840 | `stage4_user_ai_quota_grounding` | `supabase/migrations/20261007210000_stage4_user_ai_quota_grounding.sql` |
| 20261007185216 | `stage4_guest_quota_advisory_lock` | No same-name candidate; semantic review required |
| 20261007192522 | `stage4_limit_ai_runtime_chain` | `supabase/migrations/20261007212000_stage4_limit_ai_runtime_chain.sql` |
| 20261007202907 | `stage6_entitlement_access_decision` | `supabase/migrations/20261007230000_stage6_entitlement_access_decision.sql` |
| 20261007205734 | `stage7_ops_consultation_app_status` | `supabase/migrations/20261008010000_stage7_ops_consultation_app_status.sql` |
| 20261007212140 | `stage9_security_grant_hardening` | `supabase/migrations/20261008020000_stage9_security_grant_hardening.sql` |
| 20261019130911 | `20261010010000_stage1_p0_security_completion` | `supabase/migrations/20261010010000_stage1_p0_security_completion.sql` |
| 20261019131205 | `20261017190000_security_ai_entitlement_rpc_privacy` | `supabase/migrations/20261017190000_security_ai_entitlement_rpc_privacy.sql` |
| 20261019131224 | `20261010055013_stage1_atomic_ai_quota_reservation` | `supabase/migrations/20261010055013_stage1_atomic_ai_quota_reservation.sql` |
| 20261019131243 | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6` | `supabase/migrations/20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` |
| 20261019131312 | `20261012110945_stage1_security_abuse_storage_alignment` | `supabase/migrations/20261012110945_stage1_security_abuse_storage_alignment.sql` |
| 20261019131319 | `20261012230000_ai_models_check_constraints_alignment` | `supabase/migrations/20261012230000_ai_models_check_constraints_alignment.sql` |
| 20261019171732 | `repair_admin_consultation_rpcs` | `supabase/migrations/20261019180000_repair_admin_consultation_rpcs.sql` |
