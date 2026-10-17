# RAD Security and Migration Report — 2026-10-18

**Project:** RAD Supabase `inshddthftkhcdosoqcn`. **Code:** `rademigrate-ai/rad_emigrate`, verified GitHub main SHA `2739567cc0c228c0b190da177266de9df811be5a`. **Mode:** Production read-only; no migration execution, user-data edits, reset, Auth/Vault/Edge deployment or migration-history repair.

## Security posture: confirmed facts vs remaining uncertainty

| Control | Current evidence | State / next proof |
|---|---|---|
| Row-level security | 57 public tables, 57 with RLS enabled (read-only catalog). | Individual role-specific policy correctness and live two-user exploitation negatives remain **unverified**. |
| SECURITY DEFINER | Supabase security advisor flags signed-in execution of multiple privileged functions; some are intentionally authenticated with internal admin guards. | Audit **each** function's privilege, search_path, owner check and spoofing denial; blanket revocation would break legitimate admin/user flows. See [Supabase linter](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). |
| Feed human-only publishing | `main` Stage1 SQL installs BEFORE triggers for feed + localization, and `publish_content_draft` checks approved status and sets actor token; [PR #67](https://github.com/rademigrate-ai/rad_emigrate/pull/67) adds rollback-only positive/negative tests. | **Production currently has 0 active feed human guard triggers**. Production Admin direct table writes are restricted by RLS but do **not** enforce approved-draft marker. Do not authorize AI/research auto-publication. |
| Client Storage and private documents | [PR #61](https://github.com/rademigrate-ai/rad_emigrate/pull/61) adds owner-bound signed document previews and cache scrubbing, CI passed. | Actual newly deployed owner isolation and two-user signed-URL expiry tests not verified. |
| Auth recovery | [PR #58](https://github.com/rademigrate-ai/rad_emigrate/pull/58) normalizes allowlisted hash callback to router path, URL regression tests passed. | Actual live mailbox/OTP expiry/password change has not been tested on latest deployed SHA. |
| AI quotas / SSRF / consultation | Stage 1 five migrations [PR #48](https://github.com/rademigrate-ai/rad_emigrate/pull/48), Edge [PR #56](https://github.com/rademigrate-ai/rad_emigrate/pull/56) and isolated DB tests merged to source control; CI 7/7. | No Stage 1 Production migration; count-only AI daily quota and old Edge deployed. Synchronized deployment, rollback and concurrency checks required. |
| Postgres extension schema | Supabase advisor `pg_net` in public. | Security WARN; evaluate extension move only after compatibility and restore rehearsal, [advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public). |
| FK index coverage | Revised catalog audit: 87 public foreign keys, 84 with valid covering left-prefix B-tree (17 supported by partial `IS NOT NULL` indexes), 3 uncovered. | Candidate FKs: `knowledge_claims.superseded_by`, `consultation_requests.assigned_to`, `consultation_requests.related_application_id`; production data small; measure query plans before an additive index change. [Advisor](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys). |

## Migration reconciliation — not equivalent

- **Production ledger:** 47 versions. **Repo:** 52 active SQL migrations at current main.
- **27** exact version-and-logical-name pairs, **16** same-name/version aliases, **4** live-only names, **9** repo-only names.
- Production-recorded SQL diagnostic fingerprints in `supabase/reconciliation/production_statement_fingerprints_20261018.json` compared by `scripts/verify_live_migration_sql_fingerprints.py`:
  - **29** single-chunk same-name SQL files have matching diagnostic hashes (normalized CRLF/end-of-file).
  - **12** same-name recorded SQL texts differ or were stored in a different textual format.
  - **2** entries comprise multiple saved SQL chunks (9 and 6), not comparable with the current simple file fingerprint.
  - **4** live records have no same-name Repository file.
- A diagnostic SQL hash is **not semantic catalog equivalence**. MD5 is for diagnostics, not secure attestation. The historical migrations may create policies/grants/columns/data that later SQL altered.
- `scripts/audit_migration_ledger_readonly.py` intentionally returns `NO_GO`; do not suppress it to make a build green.
- Supabase `list_branches` showed a default branch with `status=MIGRATIONS_FAILED` (last updated 2026-10-14) despite preview project health saying ACTIVE_HEALTHY. That metadata is a migration warning, **not evidence of current database outage**.
- **No supported reconciliation yet** for 16 timestamp aliases, all live-only/repository-only semantic changes and the historical data effects. Do NOT run `supabase migration repair`, blind `db push` or overwrite branch/history.

## Environment gates and sequence

1. Operator supplies an independently verified production backup inventory, restore/PITR rehearsal with RPO/RTO, and DBA sign-off. None were confirmed in the reviewed sources.
2. Collect fresh read-only live ledger and catalogs at release time (schema, grants, RLS, triggers, functions/RPC, indexes, Vault **references only**, cron, Storage policies, schema versions and data invariants).
3. For each historical alias and missing migration, compare original SQL + actual live effects to pinned repository manifest. Resolve every mismatch, including DML and Grant/Policy history, without changing original migrations.
4. Rehearse full forward-only migrations on a clone that matches Production's actual history and data. Execute JWT role isolation, atomic AI quota stress, SSRF, owner Storage, admin-only human Feed publishing, rollback of failure paths.
5. Approve atomic rollout order that keeps old/new Edge and DB RPC contracts compatible. Deploy only with explicit owner release authorization; run live negative checks and monitor with rollback triggers.
6. Manually verify Render immutable SHA, Auth email/OTP and two-role documents, research review/feed, AI provider calls and errors. Client UAT/signoff is independent.

## Read-only current Production operational snapshot

- Research: **16** findings, **16** drafts, **0** Feed items. This is not proof of regulatory correctness or of an actual live publishing journey.
- Visa: **22** destinations, **10** programs, **18** structured steps. Government-source/editorial accuracy remains unverified.
- AI: 49 recorded requests; **10 succeeded**, **39 failed**, **27 no_eligible_model**. Two providers have credential-rejected/offline health; a third is degraded. No secret value inspected.
- Render service: Auto Deploy **off**, active deployed SHA `449cd3b6cb0a0b53e852015ad4a3648bd817ad65`, which predates the current `main`.
- Current main and PR #68 tests do not establish live behavior against this schema.

**Decision: Production NO-GO.** Approval, independent DB review, backups and client acceptance are not fabricated or implied by code merges.
