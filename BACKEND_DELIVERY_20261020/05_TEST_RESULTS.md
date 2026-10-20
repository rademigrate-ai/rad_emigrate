# Test results

Results refer to local synthetic environments, not production. Files under evidence/ retain counts, SQL hashes and replay manifests. Source HEAD at packaging: `9736540f567e9b5b88597a13d57b2e69025e0e40`; final delivery commit identities belong in the Git handoff. Final source manifest comparison is required when consuming this report.

| Check | Status / result |
|---|---|
| Deno | PASS — ok  /  122 passed  /  0 failed |
| Flutter analysis | PASS — No issues found! |
| Flutter suite | PASS — +731: All tests passed! |
| Final web build | PASS |
| Final Android debug build | PASS |
| HTTP Auth/RLS/quota | PASS — 28 checks |
| Clean SQL suite | {'PASS': 18} |
| Upgrade SQL suite | {'PASS': 15, 'NOT RUN': 3} |
| SQL wire validation | PASS — 62 actual request/response fixtures, also validated independently in Deno |
| Synthetic search p95 | {'clean': 364.529, 'upgrade': 217.232} ms; 10,000 sections, twenty warm samples per environment |
| Approved bilingual gold corpus | BLOCKED — no reviewed real corpus supplied |
| Live official-source/FX/model/external delivery acceptance | NOT RUN |
| Production migration/deploy | NOT RUN — prohibited |
| GitHub CI / secret scan | See final evidence/ci_status.json and evidence/secret_scan.json when present; absence means NOT RUN |

| Environment | SQL suite | Status |
|---|---|---|
| clean | supabase/reconciliation/security_regression.sql | PASS |
| clean | supabase/tests/phase_a_constraint_backfill.sql | PASS |
| clean | supabase/tests/phase_a_security.sql | PASS |
| clean | supabase/tests/stage2_knowledge_completion.sql | PASS |
| clean | supabase/tests/stage4_user_ai.sql | PASS |
| clean | supabase/tests/local47_crm_notifications.sql | PASS |
| clean | supabase/tests/local47_payment_sandbox.sql | PASS |
| clean | supabase/tests/local47_definer_acl.sql | PASS |
| clean | supabase/tests/local47_document_processing.sql | PASS |
| clean | supabase/tests/local47_observability.sql | PASS |
| clean | supabase/tests/rad_content_security.sql | PASS |
| clean | supabase/tests/rad_feed_currency_security.sql | PASS |
| clean | supabase/tests/rad_interactions.sql | PASS |
| clean | supabase/tests/rad_merge_provenance.sql | PASS |
| clean | supabase/tests/rad_official_evidence.sql | PASS |
| clean | supabase/tests/rad_privacy_security.sql | PASS |
| clean | supabase/tests/rad_quota_security.sql | PASS |
| clean | supabase/tests/rad_search_performance.sql | PASS |
| upgrade | supabase/reconciliation/security_regression.sql | PASS |
| upgrade | supabase/tests/phase_a_constraint_backfill.sql | PASS |
| upgrade | supabase/tests/phase_a_security.sql | PASS |
| upgrade | supabase/tests/stage2_knowledge_completion.sql | PASS |
| upgrade | supabase/tests/stage4_user_ai.sql | PASS |
| upgrade | supabase/tests/local47_crm_notifications.sql | PASS |
| upgrade | supabase/tests/local47_payment_sandbox.sql | NOT RUN |
| upgrade | supabase/tests/local47_definer_acl.sql | PASS |
| upgrade | supabase/tests/local47_document_processing.sql | NOT RUN |
| upgrade | supabase/tests/local47_observability.sql | NOT RUN |
| upgrade | supabase/tests/rad_content_security.sql | PASS |
| upgrade | supabase/tests/rad_feed_currency_security.sql | PASS |
| upgrade | supabase/tests/rad_interactions.sql | PASS |
| upgrade | supabase/tests/rad_merge_provenance.sql | PASS |
| upgrade | supabase/tests/rad_official_evidence.sql | PASS |
| upgrade | supabase/tests/rad_privacy_security.sql | PASS |
| upgrade | supabase/tests/rad_quota_security.sql | PASS |
| upgrade | supabase/tests/rad_search_performance.sql | PASS |

Earlier failures were retained in external logs, corrected, and superseded by final runs: runner transaction boundary; comment alias/check constraint; old preferences test bypassing the new RPC; explicit temporary-function grants under hardened defaults; a stray leading backtick in the consultation acceptance test. The initial search p95 was 15.8 seconds; narrow ranking/materialization reduced it substantially. An intermediate noisy shared-host run measured 579.870 ms; final values above are not a production capacity guarantee.

Optional payment/OCR/incident suites are NOT RUN in the production-shaped path when the captured schema lacks their approved dependencies. Their clean-lineage suites are still run. The mandatory standalone privacy test runs in both environments. No unavailable review, transport or test is described as passed.
