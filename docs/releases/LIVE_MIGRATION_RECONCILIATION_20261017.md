# RAD Supabase — independently observed live migration ledger reconciliation

**Checked:** 2026-10-17 (production read-only query via linked Supabase project **RAD**, id `inshddthftkhcdosoqcn`).
**Repository baseline:** `main` `449cd3b6cb0a0b53e852015ad4a3648bd817ad65`.
**Master delivery:** [#57](https://github.com/rademigrate-ai/rad_emigrate/issues/57).
**Integration probe:** [PR #59](https://github.com/rademigrate-ai/rad_emigrate/pull/59), 7/7 GitHub CI jobs green on SHA `2d367c2a1d5bb6cedcd968f039d6c427be94300f`.
**Status:** Ledger discrepancy **confirmed**; historical SQL/source equivalence **NOT PROVEN**; Production schema migration **NO-GO**.

## Measured counts and interpretation

| Field | Verified |
|---|---:|
| Recorded live `supabase_migrations.schema_migrations` entries | **47** |
| Tracked `main/supabase/migrations/*.sql` files | **46** |
| Same filename meaning: exact version **and** name | **27** |
| Same logical migration name but different timestamp/version | **16** |
| Only in live ledger by name | **4** |
| Only in repository by name | **3** |
| Stage 1 pending migrations proposed by PR #48 | **5**, all **not recorded live** |
| Combined branch's migration files (main 46 + Stage 1 5) | **51** |

**CRITICAL:** A name-match or timestamp alias is **not proof** that the original SQL equals the repository SQL. The live migration-history table stores versions/names, not complete original SQL. A clear reconstruction requires comparison of actual schema, function definitions, grants, RLS, Storage, cron and data. Do not mark any remote versions as applied or replay aliases based on this report.

## Full live ledger and corresponding repository files

| # | Applied production version | Production migration name | Name-matching repository path | Classification |
|---:|---|---|---|---|
| 1 | `20261001191421` | `initial_rad_core_schema` | `supabase/migrations/20261001191421_initial_rad_core_schema.sql` | EXACT |
| 2 | `20261001191653` | `create_profile_trigger_and_storage_setup_v2` | `supabase/migrations/20261001191653_create_profile_trigger_and_storage_setup_v2.sql` | EXACT |
| 3 | `20261001194638` | `security_hardening_handle_new_user` | `supabase/migrations/20261001194638_security_hardening_handle_new_user.sql` | EXACT |
| 4 | `20261001194715` | `add_rad_backend_indexes` | `supabase/migrations/20261001194715_add_rad_backend_indexes.sql` | EXACT |
| 5 | `20261001195750` | `security_hardening` | `supabase/migrations/20261001195750_security_hardening.sql` | EXACT |
| 6 | `20261001195754` | `rls_policies` | `supabase/migrations/20261001195754_rls_policies.sql` | EXACT |
| 7 | `20261001195756` | `storage_policies` | `supabase/migrations/20261001195756_storage_policies.sql` | EXACT |
| 8 | `20261001200202` | `ai_sessions_and_document_bootstrap` | `supabase/migrations/20261001200202_ai_sessions_and_document_bootstrap.sql` | EXACT |
| 9 | `20261001214952` | `project05_launch_hardening` | `supabase/migrations/20261001214952_project05_launch_hardening.sql` | EXACT |
| 10 | `20261001215315` | `project05_storage_upload_limits` | `supabase/migrations/20261001215315_project05_storage_upload_limits.sql` | EXACT |
| 11 | `20261001215758` | `project05_minimize_table_privileges` | `supabase/migrations/20261001215758_project05_minimize_table_privileges.sql` | EXACT |
| 12 | `20261001225237` | `profile_bootstrap_policy` | `supabase/migrations/20261001225237_profile_bootstrap_policy.sql` | EXACT |
| 13 | `20261001225632` | `storage_validation_policies` | `supabase/migrations/20261001225632_storage_validation_policies.sql` | EXACT |
| 14 | `20261001225634` | `ai_message_ownership_policies` | `supabase/migrations/20261001225634_ai_message_ownership_policies.sql` | EXACT |
| 15 | `20261001233027` | `signup_trigger_search_path` | `supabase/migrations/20261001233027_signup_trigger_search_path.sql` | EXACT |
| 16 | `20261001233048` | `relationship_policies_and_indexes` | `supabase/migrations/20261001233048_relationship_policies_and_indexes.sql` | EXACT |
| 17 | `20261003102347` | `restrict_documents_bucket_uploads` | `supabase/migrations/20261003102347_restrict_documents_bucket_uploads.sql` | EXACT |
| 18 | `20261003210302` | `project09_visa_catalog` | `supabase/migrations/20261003210302_project09_visa_catalog.sql` | EXACT |
| 19 | `20261003211635` | `project10_knowledge_research` | `supabase/migrations/20261003211635_project10_knowledge_research.sql` | EXACT |
| 20 | `20261003212339` | `project10_security_hardening` | `supabase/migrations/20261003212339_project10_security_hardening.sql` | EXACT |
| 21 | `20261003213219` | `project11_ai_orchestration` | `supabase/migrations/20261003213219_project11_ai_orchestration.sql` | EXACT |
| 22 | `20261003214031` | `project12_document_intelligence` | `supabase/migrations/20261003214031_project12_document_intelligence.sql` | EXACT |
| 23 | `20261003221324` | `project13_admin_operations` | `supabase/migrations/20261003221324_project13_admin_operations.sql` | EXACT |
| 24 | `20261003222909` | `project14_feed_notifications` | `supabase/migrations/20261003222909_project14_feed_notifications.sql` | EXACT |
| 25 | `20261003223717` | `project15_observability` | `supabase/migrations/20261003223717_project15_observability.sql` | EXACT |
| 26 | `20261003235000` | `ai_base_url_ssrf_hardening` | `supabase/migrations/20261003235000_ai_base_url_ssrf_hardening.sql` | EXACT |
| 27 | `20261004190000` | `fix_profile_update_rls_recursion` | `supabase/migrations/20261004190000_fix_profile_update_rls_recursion.sql` | EXACT |
| 28 | `20261005123027` | `client_delivery_ai_scopes` | `supabase/migrations/20261004203000_client_delivery_ai_scopes.sql` | NAME-MATCH / VERSION-MISMATCH |
| 29 | `20261005123202` | `stage1_ai_research_completion` | `supabase/migrations/20261005102000_stage1_ai_research_completion.sql` | NAME-MATCH / VERSION-MISMATCH |
| 30 | `20261005123255` | `stage2_review_feed_publish` | `supabase/migrations/20261005120000_stage2_review_feed_publish.sql` | NAME-MATCH / VERSION-MISMATCH |
| 31 | `20261005180215` | `stage3_fk_covering_indexes` | `supabase/migrations/20261005190000_stage3_fk_covering_indexes.sql` | NAME-MATCH / VERSION-MISMATCH |
| 32 | `20261006144235` | `stage2_visa_structured_steps` | `supabase/migrations/20261005130000_stage2_visa_structured_steps.sql` | NAME-MATCH / VERSION-MISMATCH |
| 33 | `20261006144246` | `stage5_research_review_candidate_backfill` | `supabase/migrations/20261006132931_stage5_research_review_candidate_backfill.sql` | NAME-MATCH / VERSION-MISMATCH |
| 34 | `20261006161823` | `fix_profile_update_with_check_role_escalation` | `supabase/migrations/20261006180000_fix_profile_update_with_check_role_escalation.sql` | NAME-MATCH / VERSION-MISMATCH |
| 35 | `20261006221616` | `ai_dynamic_routing_architecture` | `supabase/migrations/20261007080000_ai_dynamic_routing_architecture.sql` | NAME-MATCH / VERSION-MISMATCH |
| 36 | `20261007075108` | `ai_credential_failure_routing` | `supabase/migrations/20261007080001_ai_credential_failure_routing.sql` | NAME-MATCH / VERSION-MISMATCH |
| 37 | `20261007075110` | `research_atomic_review_candidate` | `supabase/migrations/20261007080002_research_atomic_review_candidate.sql` | NAME-MATCH / VERSION-MISMATCH |
| 38 | `20261007142614` | `ai_discovery_auto_enable_chat` | _no same-name repository file_ | LIVE-ONLY |
| 39 | `20261007171212` | `stage2_knowledge_completion` | `supabase/migrations/20261007180000_stage2_knowledge_completion.sql` | NAME-MATCH / VERSION-MISMATCH |
| 40 | `20261007171310` | `stage2_promote_knowledge_fn` | _no same-name repository file_ | LIVE-ONLY |
| 41 | `20261007171341` | `stage2_retrieve_and_conflict_fn` | _no same-name repository file_ | LIVE-ONLY |
| 42 | `20261007183840` | `stage4_user_ai_quota_grounding` | `supabase/migrations/20261007210000_stage4_user_ai_quota_grounding.sql` | NAME-MATCH / VERSION-MISMATCH |
| 43 | `20261007185216` | `stage4_guest_quota_advisory_lock` | _no same-name repository file_ | LIVE-ONLY |
| 44 | `20261007192522` | `stage4_limit_ai_runtime_chain` | `supabase/migrations/20261007212000_stage4_limit_ai_runtime_chain.sql` | NAME-MATCH / VERSION-MISMATCH |
| 45 | `20261007202907` | `stage6_entitlement_access_decision` | `supabase/migrations/20261007230000_stage6_entitlement_access_decision.sql` | NAME-MATCH / VERSION-MISMATCH |
| 46 | `20261007205734` | `stage7_ops_consultation_app_status` | `supabase/migrations/20261008010000_stage7_ops_consultation_app_status.sql` | NAME-MATCH / VERSION-MISMATCH |
| 47 | `20261007212140` | `stage9_security_grant_hardening` | `supabase/migrations/20261008020000_stage9_security_grant_hardening.sql` | NAME-MATCH / VERSION-MISMATCH |

## Repository-only names (do NOT replay pending migrations based solely on the filename)

- `supabase/migrations/20261007180001_stage2_knowledge_promote.sql` — no same-name live ledger record.
- `supabase/migrations/20261007180002_stage2_knowledge_retrieve_conflict.sql` — no same-name live ledger record.
- `supabase/migrations/20261007220000_stage5_visa_editorial_summaries.sql` — no same-name live ledger record.

## Live-only names (preserve!)

- `20261007142614_ai_discovery_auto_enable_chat` — exists in production history, no same-name repository SQL.
- `20261007171310_stage2_promote_knowledge_fn` — exists in production history, no same-name repository SQL.
- `20261007171341_stage2_retrieve_and_conflict_fn` — exists in production history, no same-name repository SQL.
- `20261007185216_stage4_guest_quota_advisory_lock` — exists in production history, no same-name repository SQL.

## Investigated effects on live schema — read-only

- Stage 2 knowledge production functions exist: `promote_knowledge_from_evidence`, `register_knowledge_conflict`, and `retrieve_knowledge`. Repository sources for the first two repo-only names explicitly say they were applied as `stage2_promote_knowledge_fn` / `stage2_retrieve_and_conflict_fn`, but **complete source-body equality is still unverified**.
- Live `destination_localizations.summary`, `visa_program_localizations.summary`, and `visa_program_localizations.description` columns exist. However a column existing does **not** prove the repository's `stage5_visa_editorial_summaries` UPDATE/content backfill ran. Do NOT execute this repository-only data migration on Production without source review and editorial evidence.
- `consume_ai_guest_quota(text,integer)` exists, but its SQL body has not been compared with the live-only `stage4_guest_quota_advisory_lock` effects.
- Live `consume_ai_daily_quota(uuid,text)` is a count-only SECURITY DEFINER function without an atomic `request_id` reservation. New PR #56 Edge code requires the reserved `request_id` and **must not be deployed before its new quota migration**.
- Two Stage 1 consultation RPCs are **absent** on Production: `submit_consultation_request`, `list_admin_consultations`.
- Three new AI model numeric constraint names are **absent**: `ai_models_consecutive_failures_check`, `ai_models_measured_latency_ms_check`, `ai_models_recent_success_rate_check`; live checks found **0** invalid rows in the 721 model rows for these numeric predicates.
- `consultation_requests` currently contains zero rows and `authenticated` has table-level INSERT, SELECT and UPDATE grants, still subject to RLS.

## Exact safest reconciliation procedure (not executed)

1. Preserve the 47 live ledger entries, the actual live schema, user data, Auth, private Storage and cron. Export and verify backup/PITR with authorized operator, **without** copying secrets into source control.
2. Recover original SQL for the **4 live-only** migrations from trusted deployment/backups/operator history, where possible. Compare their actual effects and the **3 repository-only** SQL files object-by-object against the live catalog. Diff all 16 timestamp-alias names by **catalog effects**, not naming.
3. Restore reproducible live-equivalent baseline in a disposable local/CI-only project, with snapshot comparisons for grants, column-level privileges, SECURITY DEFINER search paths, policies, triggers, Storage bucket predicates, functions, data expectations, cron, constraints, indexes and extensions. Must preserve human-only Feed publishing.
4. Choose explicit, reviewed one-to-one version reconciliation that leaves **all existing 47 live versions unchanged**; ensure historical repository files are not inadvertently queued for execution. Show a **zero historical replay** migration-list/dry-run proof against **an isolated clone**, never assume `db push` is safe.
5. Validate all five new PR #48 migrations on a production-equivalent clone using pre/post catalog fingerprints and negative authenticated/anon role tests. Verify the App/Edge release sequence in the corrected runbook.
6. Only after authorized owner/DBA approval, verified backup/PITR and a controlled release window, run forward-only additive migration operations using a ledger-aware procedure that records **new** versions exactly once. Require post-deploy canary evidence and rollback plan.

**NOT EXECUTED:** No SQL DDL/DML, history repair, migration push, database reset, merge, Render deploy, Edge deploy, or Auth/Vault mutation.

**Official CLI behavior:** [Supabase db push](https://supabase.com/docs/reference/cli/supabase-db-push) skips applied **version identifiers** and offers `--dry-run`; it does not infer equivalence from matching migration names.
