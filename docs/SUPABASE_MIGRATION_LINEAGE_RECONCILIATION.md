# Supabase migration lineage reconciliation

> SOURCE-CONTROL / REVIEW ARTIFACT ONLY. This document and the files under `supabase/reconciliation/` must not be executed against production.

Production project: `inshddthftkhcdosoqcn`

Audit date: 2026-10-04

## Safety boundary

No production DDL, migration-history repair, reset, Auth change, Vault secret read, or Edge Function deployment was performed. Production remains authoritative.

## Re-fingerprint result

The production migration history remains the same 25-row lineage previously audited, ending at `20261003223717_project15_observability`. A fresh read-only catalog summary returned 54 public/private tables, 54 public tables with RLS enabled, 110 public/storage policies, 139 public indexes, 15 public/private functions, 13 SECURITY DEFINER functions, and 3 cron jobs. AI provider/model/search-provider row counts remain 0.

This is consistent with the prior forensic audit. The prior audit established the security-sensitive live state that must be preserved: `profiles.role` restrictions, `private.has_role`, role-change auditing, private Storage bucket with owner-folder + MIME + 10 MiB/size predicate enforcement, research worker client deny, Vault-backed runtime references without provider credentials, document processor disabled/no secret, Projects 09-15 structures, publication trigger, privacy-redacting observability, and three active cron jobs.

## Canonical logical mapping

| Repository version | Logical migration | Production version | Status |
|---|---|---|---|
| missing | initial_rad_core_schema | 20261001191421 | production-only foundational lineage |
| missing | create_profile_trigger_and_storage_setup_v2 | 20261001191653 | production-only foundational lineage |
| missing | security_hardening_handle_new_user | 20261001194638 | production-only foundational lineage / later equivalent hardening |
| missing | add_rad_backend_indexes | 20261001194715 | production-only foundational lineage |
| 001 | security_hardening | 20261001195750 | semantic equivalent; version mismatch |
| 002 | rls_policies | 20261001195754 | semantic equivalent; version mismatch |
| 003 | storage_policies | 20261001195756 | semantic equivalent; version mismatch |
| 004 | ai_sessions_and_document_bootstrap | 20261001200202 | semantic equivalent; version mismatch |
| missing | project05_launch_hardening | 20261001214952 | production-only security lineage |
| missing | project05_storage_upload_limits | 20261001215315 | production-only security lineage; preserve stricter live predicate |
| missing | project05_minimize_table_privileges | 20261001215758 | production-only security lineage |
| 005 | profile_bootstrap_policy | 20261001225237 | semantic equivalent; version mismatch |
| 006 | storage_validation_policies | 20261001225632 | semantic equivalent; version mismatch |
| 007 | ai_message_ownership_policies | 20261001225634 | semantic equivalent; version mismatch |
| 008 | signup_trigger_search_path | 20261001233027 | semantic equivalent; duplicate/equivalent hardening |
| 009 | relationship_policies_and_indexes | 20261001233048 | semantic equivalent; version mismatch |
| 20261003102347 | restrict_documents_bucket_uploads | 20261003102347 | exact version match |
| 20261003195210 | project09_visa_catalog | 20261003210302 | semantic equivalent; version mismatch |
| 20261003211500 | project10_knowledge_research | 20261003211635 | semantic equivalent; version mismatch |
| 20261003212000 | project10_security_hardening | 20261003212339 | semantic equivalent; version mismatch |
| 20261003213000 | project11_ai_orchestration | 20261003213219 | semantic equivalent; version mismatch |
| 20261003214000 | project12_document_intelligence | 20261003214031 | semantic equivalent; version mismatch |
| 20261003215000 | project13_admin_operations | 20261003221324 | semantic equivalent; version mismatch |
| 20261003221000 | project14_feed_notifications | 20261003222909 | semantic equivalent; version mismatch |
| 20261003223000 | project15_observability | 20261003223717 | semantic equivalent; version mismatch |

## Canonical baseline rule

The canonical baseline is the deployed Project-15 production state, not a blind concatenation of the current migration directory. A future executable baseline must be generated/reviewed from the live schema and must reproduce the production-only foundational and Project-05 security lineage above. It must preserve live Storage policy predicates exactly or more restrictively and must never contain Vault secret values.

The existing historical migrations must not be executed against production merely because their local versions differ from `supabase_migrations.schema_migrations`.

## Proposed history reconciliation (NOT EXECUTED)

No history operation is safe until an executable baseline has been reconstructed in an isolated Supabase/Postgres environment and deterministically compared with production.

After that proof, the minimum reconciliation must produce exactly one canonical lineage. The intended operation set is:

1. Keep all 25 currently recorded production versions as the authoritative deployed-history identifiers.
2. Do not add the mismatched local identifiers (`001`-`009`, `20261003195210`, `20261003211500`, `20261003212000`, `20261003213000`, `20261003214000`, `20261003215000`, `20261003221000`, `20261003223000`) to production history; doing so would create duplicate logical migrations.
3. Canonicalize repository migration filenames/content to the already-recorded production identifiers only after isolated reconstruction proves equivalence.
4. Therefore the preferred final state requires no production `migration repair` if the repository is rewritten to use the already-recorded remote identifiers. If repository constraints force a different canonical version scheme, any `migration repair` must be separately enumerated and reviewed before execution.

Rollback of a future history-only operation is history-only: restore the prior `applied`/`reverted` status. Never roll back live schema/data merely to repair history.

## Isolated reconstruction status

BLOCKED in this session. The available environment has no local `psql`, Docker, or Supabase CLI. Creating a Supabase development branch is a billable operation whose connector requires an organization identifier plus explicit cost confirmation. Those prerequisites were not available without a user cost-approval interaction. No unsafe substitute was used.

Because isolated reconstruction could not be completed, an executable canonical baseline migration was intentionally NOT fabricated and no PR was opened.

## Dry-run proof status

NOT PROVEN. Zero historical migrations pending can only be asserted after the canonical executable lineage is reconstructed and a safe isolated `migration list` / `db push --dry-run` equivalent shows no historical replay.

## Security regression gate

Any executable baseline/rewrite must prove all of the following before review:

- authenticated clients cannot update `profiles.role`;
- `private.has_role` and privileged RPC authorization remain hardened;
- Storage `documents` remains private;
- owner-folder, PDF/JPEG/PNG MIME and <=10 MiB upload enforcement remains intact, including the live RLS predicate;
- `research_worker_config` remains inaccessible to anon/authenticated clients;
- Vault secret values never appear in SQL/repository/client code;
- AI provider/model/search-provider infrastructure is reused, not recreated;
- document processing remains private/service-bound;
- research sources remain protected;
- observability sanitization/redaction remains active;
- existing cron/Edge Function dependencies are not duplicated.

## AI Finalization handoff

AI-01 must start only after reconciliation is proven. The highest production migration version is `20261003223717`. Use a fresh generated timestamp later than it, with naming:

`YYYYMMDDHHMMSS_ai01_<descriptive_name>.sql`

AI-01 must extend, never recreate: `ai_providers`, `ai_models`, `ai_provider_health`, `ai_requests`, `ai_usage_limits`, `search_providers`, `configure_ai_provider`, `get_ai_runtime_chain`, research/knowledge infrastructure, document intelligence, Feed/notifications, observability, Vault abstraction, and role architecture.

## Current disposition

**MIGRATION LINEAGE RECONCILIATION BLOCKED**

Exact unresolved proof obligation: create an executable canonical baseline from the authoritative production state, reconstruct it in a disposable isolated environment, compare tables/columns/constraints/indexes/RLS/policies/grants/functions/security/search_path/triggers/Storage SQL/cron/extensions against production, and demonstrate zero historical migrations pending after canonicalization. Production must remain untouched while doing so.

