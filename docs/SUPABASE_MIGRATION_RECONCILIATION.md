# Supabase Migration Reconciliation

**Status: clean-project reconstruction assets added; RAD's deployed historical ledger is not rewritten.**

Audit baseline: RAD project `inshddthftkhcdosoqcn`, Supabase Postgres `17.11.0.002`, checked 2026-10-03. The live ledger was queried after the bucket restriction migration and contains 17 entries. The repository contains 10 SQL migration files: the pre-existing `001`–`009` files plus the new timestamped bucket-restriction migration.

## Why the counts differ

RAD's history uses timestamped migration IDs. The repository has a compact `001`–`009` series that captures later policy/security changes but omits the original core-schema SQL and several historical migration files. Several final effects are represented by later repository migrations, but the original operation boundaries and SQL cannot be recovered from the ledger names alone. The repository history does not establish why those historical source files were omitted.

The live ledger currently reports 17 versions while the repository migration directory has 10 files. **Do not run `supabase db push`, reset RAD, or repair the deployed ledger based on this count.** The source and deployed histories are not one-to-one.

## Reconciliation table

“Equivalent” means the current intended effect has a corresponding clean bootstrap or tracked SQL; it does not mean the tracked filename/version is the original deployed migration. Live records are listed in their applied order.

| Live Version | Live Name | Repo Equivalent | Status | Action |
| --- | --- | --- | --- | --- |
| `20261001191421` | `initial_rad_core_schema` | `supabase/bootstrap/clean_schema.sql` | Original migration absent; current table definitions reconstructed from live schema. | Use only to initialize a new empty Supabase project; do not apply to RAD. |
| `20261001191653` | `create_profile_trigger_and_storage_setup_v2` | Bootstrap function/trigger; `003_storage_policies.sql` | Final effect represented; original SQL absent. | Preserve live record; clean bootstrap creates the trigger, migration 003 creates the private bucket. |
| `20261001194638` | `security_hardening_handle_new_user` | `001_security_hardening.sql`, `008_signup_trigger_search_path.sql` | Final function hardening represented; original boundary absent. | Preserve deployed record. |
| `20261001194715` | `add_rad_backend_indexes` | `002_rls_policies.sql`, `004_ai_sessions_and_document_bootstrap.sql`, `009_relationship_policies_and_indexes.sql` | Indexes represented across current SQL; exact historical file absent. | Keep indexes; advisor notices are informational on empty tables. |
| `20261001195750` | `security_hardening` | `001_security_hardening.sql` | Function ACL/search-path effect overlaps; exact migration source unavailable. | Do not manufacture a historical file. |
| `20261001195754` | `rls_policies` | `002_rls_policies.sql` | Current owner policies represented. | Replayed after the clean bootstrap. |
| `20261001195756` | `storage_policies` | `003_storage_policies.sql` | Current owner path policies represented. | Replayed after the clean bootstrap. |
| `20261001200202` | `ai_sessions_and_document_bootstrap` | `004_ai_sessions_and_document_bootstrap.sql` | Current message table and document nullability represented. | Replayed after the clean bootstrap. |
| `20261001214952` | `project05_launch_hardening` | `001_security_hardening.sql`, `007_ai_message_ownership_policies.sql`, `009_relationship_policies_and_indexes.sql` | Final effects overlap; the complete original SQL is not tracked. | Keep deployed state; do not infer or recreate its historical record. |
| `20261001215315` | `project05_storage_upload_limits` | `006_storage_validation_policies.sql` and the new bucket restriction migration | RLS validation is tracked; the bucket row now has explicit restrictions. | Preserve original history; verify bucket settings separately. |
| `20261001215758` | `project05_minimize_table_privileges` | `supabase/bootstrap/clean_schema.sql` grants | Current least-privilege table grants are reflected in the clean bootstrap; historical forward SQL is absent. | Do not add a duplicate production grant migration without reviewing RAD ACLs. |
| `20261001225237` | `profile_bootstrap_policy` | `005_profile_bootstrap_policy.sql` | Equivalent policy is tracked. | Replayed after the clean bootstrap. |
| `20261001225632` | `storage_validation_policies` | `006_storage_validation_policies.sql` | Equivalent upload RLS check is tracked. | Replayed after the clean bootstrap. |
| `20261001225634` | `ai_message_ownership_policies` | `007_ai_message_ownership_policies.sql` | Equivalent session ownership policies are tracked. | Replayed after the clean bootstrap. |
| `20261001233027` | `signup_trigger_search_path` | `008_signup_trigger_search_path.sql` | Equivalent hardening is tracked. | Replayed after the clean bootstrap. |
| `20261001233048` | `relationship_policies_and_indexes` | `009_relationship_policies_and_indexes.sql` | Equivalent linked-document owner checks and indexes are tracked. | Replayed after the clean bootstrap. |
| `20261003102347` | `restrict_documents_bucket_uploads` | `20261003102347_restrict_documents_bucket_uploads.sql` | Exact new migration source is tracked and the live migration was applied. | Keep file/version paired; do not rename it. |

## Clean-project reconstruction

The current intended public schema is reconstructed in `supabase/bootstrap/clean_schema.sql`. It defines:

- `profiles`, `applications`, `documents`, `ai_sessions`, and `ai_session_messages`
- the live foreign keys and delete behavior, columns, defaults, and AI role check
- RLS enablement and least-privilege table grants
- the hardened signup trigger function and auth.users trigger

The checked-in SQL migrations then create the policies, indexes, bucket, and upload restrictions. The bootstrap has a guard that aborts if any RAD application table already exists. It assumes the Supabase platform has created the `auth`/`storage` schemas and roles.

`bash scripts/verify_clean_schema.sh` starts an isolated local Supabase stack with an empty migration directory, applies the bootstrap and then every tracked migration in lexical order, and verifies the resulting tables, RLS, policy count, trigger, and bucket restrictions. CI runs this replay. A hosted clean project can use the same bootstrap-first and forward-SQL sequence through a trusted database connection.

## Future production migration handling

- Do not rewrite, delete, fabricate, or mark old RAD migration records as applied.
- Do not use this repository against RAD with `supabase db push` until a dedicated production migration plan reconciles the existing history.
- Keep every future SQL migration in version control, use the Supabase-generated timestamp, and verify its live application result before committing the paired source file.
- Apply additive production changes through a reviewed migration. The documents bucket restriction change was applied using the live Supabase migration tool and is recorded as `20261003102347`.
- Test new SQL through the isolated clean-schema replay before applying it to a live project.
