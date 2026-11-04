# Final employer deploy readiness â€” 2026-11-04

**Decision: BLOCKED for full Production activation. PR #89 remains Draft. Stop before merge and frontend deployment; the owner performs both.** Employer acceptance is AFTER deployment, not a pre-deployment engineering gate. The infrastructure needed for that test must first be activated safely.

## A. Actual code state

Repository `rademigrate-ai/rad_emigrate`, PR [#89](https://github.com/rademigrate-ai/rad_emigrate/pull/89), remote branch `integration/full-content-v4-on-main-20261029`. Worktree `D:\RAD - Emigrate\rad_master_completion_20261029`, local branch `execution/master-completion-20261029`. Starting HEAD `18e39c86df7a75028638594c6a498f64c08e1196`; fetched base `0e8b8df206a3824d7a47f2c029e690ec072c6372` is an ancestor (0 commits behind, 25 ahead before this delivery). The GitHub connector's base_sha was stale; actual fetched/remote refs were checked. Other checkouts, including their unrelated dirty files, were preserved.

This report is versioned in the final candidate. Its own commit SHA cannot be embedded in itself. **Exact final HEAD, remote readback, complete changed-file hashes, final CI run URL and all job results are bound after commit in** `D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\employer-deploy-readiness-20261104\FINAL_EMPLOYER_DEPLOY_READINESS.json` **and in PR #89's description**. Verify `git rev-parse HEAD` and the remote PR HEAD against that receipt. Historical CI `41831907816` certifies only the starting commit, not these changes. A missing, mismatched or failed final receipt leaves release checks pending.

Implemented in this delivery:

- The source-review page resolves the signed-in user's own server profile and requires `admin`/`super_admin` before loading private proposals. User metadata cannot authorize it. Logout/account changes, pending role checks and role lookup errors fail closed, with retry UI.
- PostgreSQL 17 catalog capability checks now include MAINTAIN without granting it or weakening the real SHARE lock. Both capture/inverse and metadata use the same private helper.
- A new normal-Auth integration driver commits a review and CMS draft, signs out/in and reopens it through real local HTTP RPCs. CI runs it after schema reconstruction/Auth isolation.
- Deterministic RPC/migration inventory tooling exposes unresolved client API names rather than inventing signatures. Read-only preflight, exact dependency metadata and a provider request accompany this report.

Changed files: `.github/workflows/ci.yml`, `.gitattributes`, `lib/features/admin/presentation/pages/admin_source_content_page.dart`, `test/admin/source_content_review_page_test.dart`, `test/core/app_router_protected_routes_matrix_test.dart`, `scripts/verify_research_cms_persistence.py`, `scripts/employer_activation_inventory.py`, `scripts/tests/test_employer_activation_inventory.py`, `scripts/tests/test_no_restore_safety_ops.py`, `supabase/migrations/20261103120000_rad_no_restore_safety_ops.sql`, `supabase/tests/no_restore_safety_ops.sql`, `supabase/verification/employer_activation_preflight.sql`, this report, the two EMPLOYER inventory JSON files, provider request, and refreshed existing no-Restore approval MD/JSON. No frozen article or corpus body was edited.

## B. Backend state and exact contracts

Live read-only observation at `2026-11-04T13:31:52Z`: 72 migration records, 745 article heads, 747 revisions, zero published heads, 30 legacy research findings and 30 legacy content drafts. There are **zero Visa research proposals**; the legacy drafts are not proof of structured CMS review acceptance. Six enabled managed callbacks were independently inventoried at 13:33:51Z. Management access is not an editorial Admin session.

[RPC/migration inventory](EMPLOYER_RPC_MIGRATION_INVENTORY_20261104.json): 52 referenced compiled public signatures, **27 missing, 19 identical definitions, 6 different definitions**. Comparison uses schema/name/exact identity arguments and pg_get_functiondef SHA-256. Different definitions require review of metadata/owner/settings as well as body; this does not authorize overwriting them. The snapshot is explicitly dirty-candidate metadata; final file hashes are rebound in the final receipt. Grants, owner, SECURITY DEFINER/search_path, definition hashes, client references and last defining migration are in that JSON.

| Exact signature | Production classification | Last definition migration |
|---|---|---|
| `public.approve_visa_article_revision(p_request jsonb)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261019205040_rad_visa_cms_official_evidence.sql` |
| `public.approve_visa_source_inventory(p_request jsonb)` | MISSING | `supabase/migrations/20261020103648_rad_backend_integrity_completion.sql` |
| `public.cancel_rad_appointment(p_appointment_id uuid, p_reason text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261025095914_pr82_appointment_contract_adapter.sql` |
| `public.configure_ai_provider(p_slug text, p_display_name text, p_adapter text, p_base_url text, p_api_key text, p_enabled boolean, p_priority integer)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261007080001_ai_credential_failure_routing.sql` |
| `public.discover_official_authorities(p_request jsonb)` | MISSING | `supabase/migrations/20261019210423_rad_content_workflows.sql` |
| `public.enqueue_research_refresh(p_request jsonb)` | MISSING | `supabase/migrations/20261019210423_rad_content_workflows.sql` |
| `public.get_cms_article_draft(p_request jsonb)` | MISSING | `supabase/migrations/20261021210337_rad_cms_admin_draft_reads.sql` |
| `public.get_editorial_article(p_article_id uuid, p_locale text, p_preview boolean)` | MISSING | `supabase/migrations/20261028171424_full_content_v4_reader_media_and_library.sql` |
| `public.get_editorial_link_review(p_article_id uuid, p_locale text)` | MISSING | `supabase/migrations/20261026074904_editorial_link_review_contract.sql` |
| `public.get_editorial_reference_links(p_article_id uuid, p_locale text, p_preview boolean)` | MISSING | `supabase/migrations/20261026083048_editorial_reader_reference_maps.sql` |
| `public.get_editorial_source_snapshot(p_article_id uuid, p_snapshot_id uuid, p_revision_id uuid)` | MISSING | `supabase/migrations/20261025231449_editorial_review_evidence.sql` |
| `public.get_fx_quote(p_request jsonb)` | MISSING | `supabase/migrations/20261019205454_rad_currency_cache_alerts.sql` |
| `public.get_research_proposal(p_request jsonb)` | MISSING | `supabase/migrations/20261019210423_rad_content_workflows.sql` |
| `public.get_research_review_context_v2(p_proposal_id uuid)` | MISSING | `supabase/migrations/20261031152706_rad_bound_research_review_metadata.sql` |
| `public.get_visa_article(p_request jsonb)` | INSTALLED_DIFFERENT_DEFINITION | `supabase/migrations/20261025221239_editorial_consolidation_staging_contracts.sql` |
| `public.list_admin_consultations()` | INSTALLED_DIFFERENT_DEFINITION | `supabase/migrations/20261019180000_repair_admin_consultation_rpcs.sql` |
| `public.list_cms_articles(p_request jsonb)` | MISSING | `supabase/migrations/20261025221239_editorial_consolidation_staging_contracts.sql` |
| `public.list_country_visa_content(p_country_code text, p_locale text, p_preview boolean)` | MISSING | `supabase/migrations/20261102172853_visa_published_source_country_articles_20261102.sql` |
| `public.list_editorial_library(p_locale text, p_preview boolean, p_offset integer, p_limit integer)` | MISSING | `supabase/migrations/20261028171424_full_content_v4_reader_media_and_library.sql` |
| `public.list_editorial_review_queue(p_locale text, p_offset integer, p_limit integer)` | MISSING | `supabase/migrations/20261025221239_editorial_consolidation_staging_contracts.sql` |
| `public.list_my_booking_requests()` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261024140000_plan2_booking_request_contracts.sql` |
| `public.list_official_authorities(p_request jsonb)` | MISSING | `supabase/migrations/20261019210423_rad_content_workflows.sql` |
| `public.list_rad_appointments()` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261025095914_pr82_appointment_contract_adapter.sql` |
| `public.list_research_proposals(p_request jsonb)` | MISSING | `supabase/migrations/20261019213129_rad_contract_finalization.sql` |
| `public.list_service_catalog(p_locale text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261024140000_plan2_booking_request_contracts.sql` |
| `public.list_visa_article_revisions(p_request jsonb)` | MISSING | `supabase/migrations/20261019210423_rad_content_workflows.sql` |
| `public.list_visa_content_countries(p_locale text, p_preview boolean)` | MISSING | `supabase/migrations/20261102172853_visa_published_source_country_articles_20261102.sql` |
| `public.publish_content_draft(p_draft_id uuid, p_category text, p_slug text)` | INSTALLED_DIFFERENT_DEFINITION | `supabase/migrations/20261020111217_rad_restore_legacy_publish_privileges.sql` |
| `public.publish_visa_article_revision(p_request jsonb)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261019205040_rad_visa_cms_official_evidence.sql` |
| `public.reject_visa_article_revision(p_request jsonb)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261019205040_rad_visa_cms_official_evidence.sql` |
| `public.reschedule_rad_appointment(p_appointment_id uuid, p_start_utc timestamp with time zone, p_end_utc timestamp with time zone, p_time_zone text, p_notes text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261025095914_pr82_appointment_contract_adapter.sql` |
| `public.resolve_editorial_article_slug(p_country_code text, p_slug text, p_locale text)` | MISSING | `supabase/migrations/20261026093840_editorial_legacy_slug_resolution.sql` |
| `public.review_country_other_title(p_country_code text, p_article_id uuid, p_expected_revision integer, p_decision text, p_rank integer, p_request_key uuid)` | MISSING | `supabase/migrations/20261025221239_editorial_consolidation_staging_contracts.sql` |
| `public.review_editorial_relation(p_parent_id uuid, p_related_id uuid, p_expected_revision integer, p_decision text, p_rank integer, p_request_key uuid)` | MISSING | `supabase/migrations/20261025221239_editorial_consolidation_staging_contracts.sql` |
| `public.review_research_proposal(p_request jsonb)` | MISSING | `supabase/migrations/20261026193014_stage71_lossless_research_patches.sql` |
| `public.rollback_visa_article(p_request jsonb)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261019205040_rad_visa_cms_official_evidence.sql` |
| `public.save_research_review(p_request jsonb)` | MISSING | `supabase/migrations/20261026114637_stage7_research_review_contract.sql` |
| `public.save_structured_research_review(p_request jsonb)` | MISSING | `supabase/migrations/20261026193014_stage71_lossless_research_patches.sql` |
| `public.save_visa_article_draft(p_request jsonb)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261019205040_rad_visa_cms_official_evidence.sql` |
| `public.search_visa_articles(p_request jsonb)` | MISSING | `supabase/migrations/20261020112300_rad_crm_search_integration_hardening.sql` |
| `public.set_ai_model_configuration(p_model_id uuid, p_enabled boolean, p_runtime_scope text, p_priority integer, p_max_output_tokens integer)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261005102000_stage1_ai_research_completion.sql` |
| `public.set_content_draft_status(p_draft_id uuid, p_status text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261005120000_stage2_review_feed_publish.sql` |
| `public.set_research_finding_status(p_finding_id uuid, p_status text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261005120000_stage2_review_feed_publish.sql` |
| `public.set_research_source_configuration(p_source_id uuid, p_display_name text, p_enabled boolean, p_runtime_scope text, p_trust_class text, p_country_code text, p_topic text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261005102000_stage1_ai_research_completion.sql` |
| `public.submit_booking_request(p_service_id uuid, p_message text, p_preferred_start_utc timestamp with time zone, p_preferred_end_utc timestamp with time zone, p_time_zone text, p_idempotency_key text)` | INSTALLED_DIFFERENT_DEFINITION | `supabase/migrations/20261025195326_pr82_legacy_request_receipt_integrity.sql` |
| `public.submit_consultation_request(p_topic text, p_message text, p_related_application_id uuid)` | INSTALLED_DIFFERENT_DEFINITION | `supabase/migrations/20261019180000_repair_admin_consultation_rpcs.sql` |
| `public.submit_rad_appointment(p_title text, p_start_utc timestamp with time zone, p_end_utc timestamp with time zone, p_time_zone text, p_notes text, p_idempotency_key uuid)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261025095914_pr82_appointment_contract_adapter.sql` |
| `public.submit_visa_article_review(p_request jsonb)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261019205040_rad_visa_cms_official_evidence.sql` |
| `public.update_admin_consultation(p_consultation_id uuid, p_status text, p_admin_note text)` | INSTALLED_DIFFERENT_DEFINITION | `supabase/migrations/20261019180000_repair_admin_consultation_rpcs.sql` |
| `public.update_content_draft(p_draft_id uuid, p_title text, p_body text, p_language_code text, p_category text)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261005120000_stage2_review_feed_publish.sql` |
| `public.upsert_editorial_research_source(p_request jsonb)` | MISSING | `supabase/migrations/20261026114637_stage7_research_review_contract.sql` |
| `public.upsert_user_ai_profile(p_education text, p_field_of_study text, p_work_experience text, p_language_level text, p_preferred_destinations text[], p_interested_pathways text[], p_budget_range text, p_notes text, p_consent boolean)` | INSTALLED_SAME_DEFINITION | `supabase/migrations/20261028200000_user_ai_profile_checklist_reports.sql` |

Two additional literal API names, `list_interview_slots` and `schedule_interview`, used by `lib/features/interview_scheduling/data/interview_repository.dart`, have no compiled candidate definition. No signature was fabricated. The existing scheduling screen handles backend unavailability and offers consultation; working interview booking is **NOT TESTED/NOT PROVIDED by this CMS activation**.

118 repository migration files were compiled on an owned empty local stack; 27 filenames have versions recorded among Production's 72 records. Timestamp differences are not an execution list. Do not replay old migrations or repair the ledger from this comparison. The sealed forward closure targets current Production drift; no hosted SQL was installed during this delivery.

Real persistence test: **PASS, isolated Supabase normal Auth, synthetic evidence only.** An Admin creates an evidence-bound structured proposal and review; exact retries preserve one operation; another proposal is rejected and reloaded; accepted edits create exactly one unpublished CMS revision. Fresh password login reopens the persisted decisions/draft, ancestry and history. Ordinary user/anonymous read and mutation requests are denied; stale review and evidence hash mismatch refuse; even Admin cannot publish an unapproved draft. Original body/author/rich revision/other locale are preserved, with zero publication or Feed changes. This is committed local HTTP/Auth/RLS acceptance, not a mock or Production acceptance. See `research-cms-real-auth.log`. Fixtures remain local and are discarded with the owned test stack.

Production Edge metadata: `research-sync` v4 active (verify_jwt=false), `ai-orchestrator` v11 active (true), `document-intelligence` v3 active (true). `official-source-worker` is not deployed. Version metadata does not prove source equivalence to this branch. Source-fetch/AI end-to-end generation is **NOT TESTED** here: it requires the existing R1â€“R4 activation procedure, approved authorities/domain bindings, restricted egress, purpose-specific secure references and separately approved paid budget. See [research activation procedure](RESEARCH_ACTIVATION_PROCEDURE_20261102.md). Do not enable a default-off entrypoint or trigger paid research as part of deployment. Research never auto-publishes to Feed.

## C. Security and no-Restore decision

**Protected executor: BLOCKED.** Actual Production `postgres` is not superuser; pg_proc owner is `supabase_admin`; none of MAINTAIN/UPDATE/DELETE/TRUNCATE is available. The proposed seven-function capture/inverse therefore raises `provider_approved_catalog_lock_executor_required`. This blocks the mandatory pre-core safety step and inverse; it is not evidence that every ordinary CMS RPC needs a catalog lock. The candidate retains the real SHARE lock, independent authorization bindings, 2s timeout and immutability. Twenty native tests pass, including actual MAINTAIN-only locking without catalog write privileges. Those owned local grants are not Production authority.

**Complete no-Restore release: BLOCKED.** The seven-definition inverse and prior-NULL source-publication withdrawal are narrow mechanisms. They do not reverse 20 new tables, 76 new functions, three columns, 82 constraints, 12 indexes, 17 triggers, one policy, 25 ACL reviews, extension/provider callbacks, migration history or every application/dynamic SQL dependency. The closure additionally reviews 12 replaced function definitions/metadata (seven changed bodies) and two retained drifts. [Dependency map](EMPLOYER_ACTIVATION_DEPENDENCIES_20261104.json) lists exact roots, functions, tables, edges, changes and limits.

Independent PostgreSQL/security acceptance, Supabase callback/operator attestation, exact release-owner authorization and real editorial Admin operation receipts remain missing. The current guarded renderer still requires verified recovery evidence. There is **no accepted/implemented no-Restore alternative in that release mechanism**. Deferred Restore/recovery must not be restarted, fake evidence must not be supplied, and the guard must not be bypassed. A protected executor alone would not resolve this second gate. The [existing approval package](NO_RESTORE_OPERATIONAL_APPROVAL_PACKAGE_20261103.md) remains pending, execution_allowed=false, with blank reviewer fields. The [provider request](PROVIDER_CATALOG_LOCK_REQUEST_20261104.md) is prepared, not submitted or approved.

Import compensation refuses non-owned rows, fingerprints/catalog/FK drift and later writes/references. It is not a universal committed-DDL inverse. Source withdrawal restores only bounded prior-NULL publication pointers/search visibility and preserves catalog/history; it does not remove the migration. Failed transactions must abort; after uncertain commit/network failure, read immutable receipts and exact state before retry. Never rerun DDL blindly or issue ad hoc DROP/DELETE/role changes to recover.

Isolated security regressions passed: ordinary/anonymous denial, profile role escalation prevention, private drafts/evidence, stale/hash/version controls, exactly-once receipts, real Auth isolation, RLS and publication separation. Production advisors remain one INFO plus four WARN (extension schema, anon/authenticated SECURITY DEFINER execution advisories and leaked-password protection); no silent Auth, catalog or Storage setting changes were made. These findings require scoped review, not blanket grant revocation that breaks public APIs. Management SQL and Dashboard login do not attest editorial authorization. The user's manually completed Firefox login was preserved; browser cookies/tokens were not inspected. Real Production operation receipts remain unverified.

## D. Engineering and release checks

Current working-candidate checks: Dart format 504 files/zero changes; Flutter analysis clean; **1,213 full Flutter tests passed**; **431 Python tests passed**; **20 native catalog/safety tests passed** (included in Python); 12 selected SQL regressions plus new read-only preflight passed on the owned clean-schema stack. Source-review widget/actual route tests cover server roles, late logout, denial/error, citations/actions and desktop/mobile sizes. Full clean-schema reconstruction compiles all 118 migrations. All 1,077 compressed frozen articles, source/body hashes, held exclusion and malformed API fallback are covered by corpus regressions.

Final-commit checks and all eight CI job conclusions are recorded in the post-commit final receipt and PR description. Required jobs: `routing` (format/analyzer/Python/static contracts), `plan3-content`, `flutter`, `web-build`, `android-build`, `repository-keyword-scan`, `clean-schema` (Auth/SQL regressions), and `migration-reconstruction`. Use the actual job list in that receipt; do not infer success from old CI. The local Production-configured Web build must bind `version.json` to final HEAD and pass public-config/artifact scanning. Android CI debug output is not a signed Android production release. No actual deployed-browser CMS acceptance or Production draft write was attempted. Employer browser UAT remains a post-deployment activity.

## E. Readiness classification

| Area | Status | Evidence/action |
|---|---|---|
| Source package and frozen readers | READY | 1,100 operations, 44 batches, 1,077 candidates, 23 retained holds; hashes preserved |
| Research review â†’ persistent CMS draft | READY locally | Real normal-Auth committed/relogin/reopen test and CI driver; not installed Production acceptance |
| Engineering release candidate | Receipt-bound | Exact final HEAD/remote, CI 8/8, local Web build and hashes must agree |
| Production catalog safety executor | BLOCKED | Provider-supported protected execution and actual managed capture receipt absent |
| Full no-Restore release mechanism | BLOCKED | Independent full failure procedure/authorization plus accepted tested mechanism absent |
| Production CMS/source activation/import/publication | BLOCKED | Missing RPCs and preceding safety gates; zero real publication receipts |
| Paid research/source generation | NOT TESTED | R1â€“R4, approved budget/source/egress and worker deployment required |
| Production session refresh/Admin review operations | NOT TESTED | No supported real operation receipt; no session extraction |
| Employer deployed-browser acceptance | AFTER DEPLOYMENT | Owner-controlled deployment first, then checklist below |
| Signed Android release/interview booking | NOT TESTED | Debug build only; interview RPC definitions absent |

The package retains 56-country classification, 251 countryless Other Titles and 11 AE candidates. The original 27 publication holds comprise four resolved routing corrections (bodies unchanged) plus 23 still held. **355 incomplete-URL cases remain open**; they are not a complete three-site recovery claim and must not be published by inference. RADMohajer stays independently identifiable. Frozen asset availability is public read-only content delivery, not CMS approval or a functioning private backend.

## F. Exact activation and owner deployment sequence

**STOP BEFORE ANY HOSTED WRITE while either safety gate above is unresolved.** Preparation is complete enough to review; it is not executable authorization. No supported safe command currently completes activation without the missing approvals/mechanism. The owner/provider must resolve those concrete gates before this sequence can advance.

1. Owner obtains the independent decisions described in the provider request and existing approval package, bound to final commit, project, exact artifacts, actors and window. Establish and test an authorized release mechanism that preserves the existing guarantees without Restore. This is an outstanding implementation/authorization gate, not an instruction to weaken recovery validation.
2. Bind the supported database connection independently to `inshddthftkhcdosoqcn`; store credentials only in an approved local connection/service reference. The preflight emits only metadata, not secrets. With a preconfigured libpq service named `rad-production-readonly` (not yet created/approved by this task), run:

   ```powershell
   & 'C:\Program Files\PostgreSQL\17\bin\psql.exe' 'service=rad-production-readonly' -X -v ON_ERROR_STOP=1 -f supabase/verification/employer_activation_preflight.sql
   git rev-parse HEAD
   git ls-remote origin refs/heads/main refs/heads/integration/full-content-v4-on-main-20261029
   ```

   That connection service is an explicit missing secure reference, not a credential or claimed existing approval. Stop on binding/hash/ACL/owner/callback/head/migration drift. Reconcile against the final receipt and current live inventory; no migration history repair.
3. Only after approval, install the **pre-core safety bootstrap** `20261103120000_rad_no_restore_safety_ops.sql` (including review of its own DDL/callback effects). Establish a legitimate editorial Admin session through normal application Auth and verify the server role; perform exact seven-function capture and retain a real immutable receipt. A service-role/management connection is not that actor.
4. Apply the reviewed private core closure `D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\db_forward_review\forward_body.sql` (SHA `ec77fd4bba84b703a0d2994c3ce8da8112ca969a8f2a478de8061b500f675f69`), then `20261102101305_rad_cms_detached_revision_allocator.sql` (SHA `5f224ce6025ff43d02e078f51d147f0f9c7b63ce4cf7b42e0c383e6b3f6be4ca`). Do not replay 118 historical migrations. Compare exact dependencies, ACL/RLS, body/author/publication pointers and committed state before proceeding. Migration ledger recording is part of the independently accepted procedure, not authorized ad hoc repair.
5. Execute only the guarded, authorized corrected draft package at `D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\final-publication-readiness-20261103\corrected-package-v1`. Package SHA `4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282`. Review its `manifest.json` file-hash map, plan, mechanical decisions, source bindings and all 44 publication manifests. This corrected package uses `manifest.json`, whereas the legacy reconciliation CLI expects `artifact-seals.json`; it is not a drop-in CLI directory. The independently accepted release implementation must verify and bind the corrected manifest before invoking guarded rendering, without inventing seals or editing immutable inputs. The present `production_reconciliation_package.py render-approved-production` still refuses missing verified recovery evidence; there is deliberately no invented bypass command here. Keep imports draft/unverified, enforce package-owned journal/idempotency and perform exact source/body/author/head readback plus ordinary/anonymous denial.
6. **Only after import**, install `20261102192642_rad_source_faithful_editorial_release.sql` (SHA `0176bbb617c5075232e02197630ff0f6df0de492d4926a06b238475f054ef06e`), `20261103114340_rad_corrected_source_editorial_admission.sql` (SHA `577edecce2b0fe90bf2308c91add8a301976232b5a95d822374c7dae39c150b0`), then `20261103180754_rad_source_unpublish_safety.sql` (SHA `0cde295bbcbda93cad57230b2f637112fdcba2301305aa65af7b1378bcd0013a`). The safety bootstrap is intentionally earlier than its timestamp ordering; do not use a blanket db push as an ordered release substitute. Latest bootstrap/test hashes are in the refreshed approval JSON.
7. Real authorized Admin reviews eligible content and uses the installed source batch approval/publication contracts, bounded by exact manifest/head/source/revision bindings. Retain actual approval/publication receipts. Never fabricate 44 approvals or publish 23 holds, incomplete cases or unapproved research. Rerun read-only preflight, security SQL (`supabase/tests/security_regression.sql`, `editorial_content_security.sql`, `source_editorial_release.sql`, `corrected_source_editorial_holds.sql`, `no_restore_safety_ops.sql` only in their approved isolated test context) and **non-mutating Production API smoke tests**: anonymous eligible published read, held/private denial, countries/Other Titles/AE routing, server revision hashes and search visibility. Test scripts that insert fixtures belong only in isolation, never Production.
8. Establish R1â€“R4 research activation separately if employer generation is in scope; verify deployed Edge source/config and authenticated/purpose-scoped authorization. Local proposal fixtures alone do not certify real source generation. No Feed auto-publication.
9. After Production backend acceptance and final receipt/CI pass, owner reviews and merges PR #89. Codex does not merge it or deploy the frontend. Recheck base drift and rerun gates if the merge changes tested code.
10. Owner deploys the existing Render service **`srv-db0p4e9srm7s738jam10`**, actual name **`rad_emigrate`**, workspace `tea-daufcetg1s2s73cnkvo0`, repo `rademigrate-ai/rad_emigrate`, branch `main`, URL **https://rad-emigrate.onrender.com**. Verified autoDeploy=no/trigger=off and previews=off; keep automatic deployment off. Do not create a replacement service from the template's differing display name.

    Build command: `bash scripts/build_web_render.sh`. Publish directory: `build/web`. Set `APP_ENV=production`, `SUPABASE_URL=https://inshddthftkhcdosoqcn.supabase.co`, and the project's **public publishable key** through its approved configuration reference; no service-role/Vault/provider key in a client build. Actual hosted env values were not read or certified. Configure SPA rewrite `/* â†’ /index.html`, manually deploy the merged commit, and check `/version.json` matches that exact commit. Deep-link `/login`, `/visas`, and `/admin/source-content`; test normal login/logout/refresh without exporting sessions. Stop on a backend/API mismatch or wrong project; do not present fallback assets as working CMS.

Local verification commands (disposable local infrastructure only):

```powershell
python -m unittest discover -s scripts/tests
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
# In an already owned, reconstructed loopback Supabase stack:
python scripts/verify_local_auth_isolation.py
python scripts/verify_research_cms_persistence.py
```

The real-auth drivers resolve the local CLI stack and refuse hosted origins. Never point fixture SQL at Production. `bash scripts/build_web_render.sh` uses approved public environment values only, stamps the checked-out commit and scans artifacts. Clean-schema/SQL/security/Android checks are also enforced in CI.

## G. Employer acceptance AFTER owner deployment

1. Open https://rad-emigrate.onrender.com, verify the deployed commit, sign in normally with an authorized Admin account. Ordinary users must not enter source review.
2. Open the Research Assistant, then `/admin/source-content`. Inspect an eligible finding or run research only when R1â€“R4 and budget are activated. Confirm missing API/configuration errors are explicit and never reported as a successful save.
3. Select an existing article; inspect its current revision, original source identity/citations and proposed changes. Compare the suggestion to the current body. Reject one unsuitable suggestion; confirm rejection persists.
4. Accept/edit a source-backed suggestion; save an **unpublished CMS draft**. Navigate away, return, reload and sign out/in. The same saved draft and decisions must reappear, with original body/author/other locale intact and auditable revision/actor history.
5. Try the same save again: one result, no duplicate revision. A stale tab or changed source/hash must refuse rather than silently overwrite. Anonymous and ordinary-user sessions cannot read the private draft or mutate it.
6. Confirm unapproved research/drafts are absent from public content and Feed. Use the separate approval/publication workflow only with explicit authorization; do not publish held or incomplete content. Check real public readback and publication history after that authorized operation.
7. Record deployed commit, actor reference (no credentials), article/revision identifiers, outcomes and actual receipt references. Report failures before further writes. This practical employer test is post-deployment, not a prerequisite to completing independent engineering preparation.
