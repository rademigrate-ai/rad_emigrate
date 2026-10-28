# RAD Emigrate — Live Supabase Alignment Report
**Observed:** 2026-10-23  
**Repository:** `rademigrate-ai/rad_emigrate`  
**Production project:** `inshddthftkhcdosoqcn`  
**Observed main SHA:** `16810a583ad4544d87f289bd16984c0e758a1515`

## Executive decision

- GitHub main is integrated at the SHA above. Main CI run [39864024570](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39864024570) is **7/7 successful**.
- The live Render `/version.json` still reports **`ccf041a`**, which is behind current main. The current deployment therefore does not contain the latest PR #75/#76 changes.
- Supabase Production is **not aligned** with current main. No Production migration, grant change, Edge deploy, or data write was performed in this audit.
- Production migration execution remains **NO-GO** until the exact forward manifest is signed and a managed backup/PITR recovery point plus restore readiness are verified.
- Render deployment remains owner-operated; this report does not trigger a deployment.

## Live migration reconciliation

| Measure | Observed |
|---|---:|
| Current repository migration files on main | 83 |
| Production `supabase_migrations.schema_migrations` entries | 54 |
| Latest Production ledger version | `20261019171732` |
| Repository migration names matching live ledger names after timestamp-prefix normalization | 50 |
| Matching logical names whose recorded version differs from the repository filename timestamp | 23 |
| Repository filenames without an exact normalized live-ledger name | 33 |
| Live ledger names without an exact normalized repository filename | 4 |

**These counts are not a safe pending-migration count.** Previous migrations were applied through a path that recorded execution timestamps different from their filename timestamps. Do not run `db push`, replay all 83 files, or repair history based on version numbers alone.
## Migration classification — do not execute until the recovery gate is met

The prior signed/hashed Stage 8 manifest covers 21 forward migrations plus the two PR #76 follow-ups. Two additional repository migrations also need explicit inclusion/review before the Production manifest is considered complete:

- `20261007220000_stage5_visa_editorial_summaries.sql` — only fills blank editorial summaries; local schema-only rehearsal ran, but contained no destination/program data, so **the production data effect is not yet verified**.
- `20261018210000_stage10_covering_fk_indexes_completion.sql` — idempotent index completion; local rehearsal ran and reported existing indexes already present.

### Legacy names that must not be blindly replayed

- `20261007180001_stage2_knowledge_promote.sql` maps to live ledger name `stage2_promote_knowledge_fn`; the migration comment records it as previously applied under that name.
- `20261007180002_stage2_knowledge_retrieve_conflict.sql` maps to live ledger name `stage2_retrieve_and_conflict_fn`; the migration comment records it as previously applied under that name.
- Live-only `ai_discovery_auto_enable_chat` is superseded by `rad_ai_discovery_fail_closed`; apply the current fail-closed follow-up, not the historical migration.
- Live-only `stage4_guest_quota_advisory_lock` needs function-level comparison against `rad_legacy_quota_budget_compatibility`. Do not replay or repair its ledger entry until equivalence is proven.

### Excluded from the current Production candidate set

The following six files are **not approved for Production execution** in this run:

- `20261018125432_local47_crm_notification_outbox.sql` — explicitly marked local-first; requires separate release approval.
- `20261018143455_local47_notification_privilege_alignment.sql` — tested only on disposable local stacks; requires separate release approval.
- `20261018142313_local47_payment_sandbox_integrity.sql` — payment sandbox foundation.
- `20261018152513_local47_document_atomic_processing.sql` — local document-processing lease foundation.
- `20261018154834_local47_observability_privacy_and_triage.sql` — local operational-events/incidents foundation.
- `20261018211645_phase24_mock_checkout_and_crm_search.sql` — combines mock checkout with CRM search; split/review before any Production use.

The intended forward set is therefore **25 candidate migrations** (the 21-file sequence, two PR #76 follow-ups, and the two extra migrations above), but it is **not yet signed or executable**. The old report’s 21+2 manifest must be amended with hashes, dependency ordering, explicit exclusions, and owner approval before any hosted write.
## Production security and contract findings

### Confirmed live database controls

- Public tables: **57**; RLS enabled: **57**; RLS disabled: **0**.
- All 57 public tables are owned by `postgres`.
- `anon` and `authenticated` each have effective `TRUNCATE`, `REFERENCES`, `TRIGGER`, and `MAINTAIN` privileges on these six tables: `admin_case_notes`, `admin_saved_views`, `admin_tasks`, `ai_entitlements`, `application_status_history`, and `consultation_requests`. That is **48 effective non-row table capabilities** across both roles.
- Effective column-level `REFERENCES` is present on **50 columns per role** (100 role/column capabilities total; the check includes privileges inherited from table-level REFERENCES).
- `authenticated` has effective `INSERT` privilege on `public.profiles.role`; it does not have effective UPDATE on that column. RLS is enabled on `profiles`, but the INSERT privilege still needs the reviewed profile-role hardening path.
- `pg_net` is installed in schema `public`; the current Security Advisor also flags six SECURITY DEFINER functions executable by `authenticated`. These functions require individual role-check review; the advisor flag alone is not proof that each function is exploitable.
- Auth leaked-password protection remains reported OFF and requires a supported Auth configuration change.

### RPC and Edge compatibility

Production currently lacks these client-expected RPCs:

- `search_visa_articles` — defined by the current repository migration sequence but absent from the live schema.
- `list_service_catalog` and `submit_booking_request` — no defining migration exists on current main. Dynamic service booking is not implemented in the repository migration set; keep the UI fail-closed and do not invent catalog entries.
- `list_interview_requests`, `submit_interview_request`, `reschedule_interview_request`, and `cancel_interview_request` — no defining migration exists on current main. Interview requests must remain explicitly unavailable until a reviewed backend contract is added.

Live Edge Functions: `ai-orchestrator` v11, `research-sync` v4, and `document-intelligence` v3. Repository production candidates also include `currency-refresh`, `notification-dispatch`, `official-source-worker`, and `visa-content-ingest`, which are not currently deployed. `payment-sandbox` must remain undeployed in Production. No Edge deployment was performed.

### Separate rehearsal project warning

The separate Supabase project `rad-security-rehearsal` is **not a safe staging target** in its current state: all 12 observed public tables have RLS disabled and the Security Advisor reports six SECURITY DEFINER execution warnings. No changes were made to that project. Do not use it for client testing until proper policies and access controls are verified.
## Local rehearsal evidence from this session

All rehearsal work was performed on disposable local Docker databases; no hosted project was changed.

- `20261020192732_rad_revoke_client_nonrow_table_privileges.sql`: passed `supabase/tests/rad_client_table_privileges.sql` on a schema-only local clone after injecting representative legacy table/column grants. Postconditions: **0 effective non-row table privileges** and **0 effective column REFERENCES capabilities** for `anon` / `authenticated`.
- `20261023010000_rad_ai_discovery_fail_closed.sql` and `20261023010001_radmohajer_source_seed_parity.sql`: both applied on the local clone; `supabase/tests/corrective_routing_research.sql` passed after the test harness restored the expected restricted EXECUTE ACLs omitted by a schema-only dump.
- `20261007220000_stage5_visa_editorial_summaries.sql`: replayed successfully. The clone had no destination/program data, so it updated zero rows; this is not proof of the Production data backfill result.
- `20261018210000_stage10_covering_fk_indexes_completion.sql`: replayed successfully; target indexes already existed in the local clone.
- Limitation: this was a schema-only clone of a local 54-ledger rehearsal stack (72 public tables), not a dump of live Production (57 public tables). It is useful regression evidence, **not** a Production backup or exact schema clone.

## Required gates before Production writes

1. Owner verifies a managed backup/PITR recovery point in Supabase and records the timestamp/identifier. A verified restore path is required. The connected Supabase tools do not expose a backup creation/status action, so this could not be completed or verified from this session.
2. Finalize and sign the current 25-candidate migration manifest, including SHA-256 hashes, dependency order, exclusions, and the two legacy-name equivalences.
3. Run the ordered migration set one migration at a time, stopping on the first error. Do not replay the two already-applied Stage 2 aliases, the historical auto-enable migration, or the local-first/excluded migrations.
4. Verify the profile-role INSERT fix, zero prohibited table capabilities, zero effective column REFERENCES, RLS, key RPC signatures, and migration ledger after each relevant migration.
5. Deploy the current approved Edge code only after required secrets/provider readiness are verified; keep `payment-sandbox` disabled.
6. Recheck live Render `/version.json` and have the owner redeploy current main only after backend readiness. Current live version is still `ccf041a`.

## Final gates

| Gate | Decision |
|---|---|
| GitHub main + CI | **GO** — main `16810a5`, 7/7 |
| Local security/follow-up migration rehearsals | **PASS with stated scope limits** |
| Production migration execution | **NO-GO** — backup/PITR and signed current manifest not verified |
| Authenticated full-product testing against Production | **NO-GO** — missing RPCs and Edge drift |
| Production release | **NO-GO** |

No Production data, grants, migration history, Auth settings, Vault, Storage, or Edge Functions were changed.
