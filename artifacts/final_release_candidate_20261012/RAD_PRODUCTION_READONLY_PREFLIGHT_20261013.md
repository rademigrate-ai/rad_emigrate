# RAD production preflight and recovery readiness — 2026-10-13

**Decision: NO-GO.** Engineering sign-off here covers read-only inspection of
Supabase project `inshddthftkhcdosoqcn` and the already completed isolated
PostgreSQL 17.11 rehearsal. It is not owner/DBA approval, a production restore
test, or authorization to apply SQL. Source baseline: branch
`handoff/codex-stage1-stage2-20261010` at `f191dba809126d6a155f22acd1301dcd8cd507ee`.
No production write, migration, grant, Auth change, backup creation or restore
was attempted. Unrelated untracked files were left alone.

## Signed-off evidence matrix

| Gate | Status | Evidence / limit |
|---|---|---|
| Project and ledger | PASS, read-only | MCP `get_project`: active/healthy PostgreSQL `17.11.0.002`; MCP `list_migrations` and SQL: 47 entries, last `20261007212140`. No five pending versions are present. Observed `2026-10-12 22:16:31 UTC`. |
| Selected schema drift | PASS for inspected objects; full fresh diff NOT RUN | Current: 57 public/private tables, 47 functions, 117 policies; the pending Consultation RPCs, four CHECKs, Feed guards and Storage UPDATE policy are still absent. The prior 771 semantic/109 ACL baseline parity and full local post-migration diff are in `RAD_PROD_EQUIV_SCHEMA_DIFF_20261013.json`; a second full catalog replay was deliberately not repeated. Stop if a fresh pre-deploy snapshot differs. |
| Existing-data compatibility | PASS for current aggregate predicates | 682 AI models; zero violate the three pending numeric CHECKs. One document config has no endpoint URL; three providers have no IPv4-mapped host pattern. Zero consultation requests/Feed items; 15 drafts. Counts are point-in-time, not a row-by-row future guarantee. |
| AI, Feed, Consultation, Storage live privileges | FAIL, expected pre-migration | Both AI read RPCs are authenticated-executable `SECURITY DEFINER`, `search_path=public`, and their bodies contain no `auth.uid()` check. `publish_content_draft` remains authenticated-executable and lacks an `approved` prerequisite. Authenticated has Consultation INSERT and `admin_note` SELECT, Feed INSERT, draft UPDATE. Consultation RPCs absent; zero human-only Feed triggers; Storage has zero UPDATE policies. Document bucket is private, 10 MiB, PDF/JPEG/PNG. |
| Security advisor | FAIL pending change | Advisor still reports 14 externally callable `SECURITY DEFINER` functions and disabled leaked-password protection. The 14 warnings are not blanket proof of exploitation; prior function-by-function review found role guards in other admin mutators. [Advisor remediation](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). |
| Local production-ledger rehearsal and isolated logical restore | PASS, local only | `RAD_PROD_EQUIV_REHEARSAL_REPORT_20261013.md`: 47 historical statements + five security files, 52 preserved ledger entries; targeted security tests; isolated PostgreSQL 17.11 restore with 672/672 effective privilege checks, 95/95 table row-count/hash matches. |
| Actual backup inventory, retention, PITR window | BLOCKED | `supabase@2.119.0 backups list --project-ref inshddthftkhcdosoqcn --output-format json` returned `AccessTokenRequiredError`. Supabase MCP has no backup-list method; no authenticated dashboard tab was available. Neither plan tier nor PITR entitlement was attested. |
| WAL archiving signal | PASS as signal only | Read-only `pg_settings`: `archive_mode=on`, `archive_timeout=120`, WAL push configured; `pg_stat_archiver`: 602 archived, 0 failed, last archived `2026-10-12 22:11:45 UTC`. This does **not** prove usable backup files, retention, an eligible PITR window or a successful restore. |
| Production recovery-point restore | NOT RUN / owner-DBA gate | No authorized isolated restore from an actual production recovery point. A production recovery point cannot be independently verified from the access available in this session. |
| Owner/DBA deployment approval | BLOCKED | No production write authority was requested or inferred. |

The official [Database Backups guide](https://supabase.com/docs/guides/platform/backups)
says daily backups depend on paid plan and PITR is an optional add-on; published
plan retention figures do **not** establish this project's entitlement or
actual recovery range. PITR, if enabled, replaces daily backups. Database
backups do not recover Storage object bytes. The
[restore-to-new-project option](https://supabase.com/docs/guides/platform/clone-project)
is a paid, database-only clone; Storage files/settings, Edge Functions, Auth
settings/API keys, Realtime settings, extensions/settings and replicas require
separate reconciliation. A same-project restore causes downtime. Do not rely
on either option until the owner and DBA verify its availability and exact
limitations for this project.

## Current read-only production findings

The live ledger is unchanged from the rehearsal baseline. The selected
catalog/privilege queries above also reproduce the expected pre-migration
state. The only Feed item trigger is `feed_publication_notifications`; the two
`trg_guard_human_feed_*` triggers are absent. Storage's three documents
policies are own-path SELECT, INSERT and DELETE, with no UPDATE. Current
`pg_default_acl` includes broad `supabase_admin` public-schema defaults for
future tables/functions. Actual existing-object grants are narrower; these
defaults caused the 86-overgrant naive-restore failure below. Do not treat
default ACLs alone as current effective privileges or change production
defaults in this preflight.

The current inspection does not prove full schema equivalence at deployment
time. Immediately before any approved change, the DBA must repeat the full
semantic, constraint/index/default, effective ACL and ledger comparison
against the frozen 47-migration baseline, not just table-column counts.
The historical 16 timestamp aliases and four live-only migration names must
remain in place. In particular, the live-only AI discovery function
auto-enables newly found chat models, unlike the repository 50-chain; this
product decision remains open. Neither `supabase db push` nor ledger rewriting
is an acceptable deployment shortcut.

## Exact five-file security path

These are SHA-256 hashes of the **current Windows checkout bytes**, verified
with `Get-FileHash` on 2026-10-13. The fifth file has CRLF checkout bytes;
its Git/LF blob hash is different. Compare the actual files on the DBA
execution host immediately before applying, recording both source commit and
host-byte hashes. The previous report and deployment manifest omitted one
hex digit in the displayed fifth *checkout* hash; this document and those
two displays correct that transcription error. No SQL changed.

| Order | File | Checkout SHA-256 |
|---:|---|---|
| 1 | `20261010010000_stage1_p0_security_completion.sql` | `76a28a9aa6294f6a8ca8f108394b801a2ee85f85827104246324f69787610bd5` |
| 2 | `20261010055013_stage1_atomic_ai_quota_reservation.sql` | `51ab2b39fb63655fea7e67e1a7aef69bb1ba15297877bc39168b90b2b1c8b646` |
| 3 | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` | `b94878391d4fddb9887e74d9a2a1dc809360de46f989a3d599a5471cc7c42fc5` |
| 4 | `20261012110945_stage1_security_abuse_storage_alignment.sql` | `9de2fdb764aae7068c9355b07cd3593823bd66b5da73448687693fe5cc535119` |
| 5 | `20261012230000_ai_models_check_constraints_alignment.sql` | `303b6ba4382453ab682297f57336922050344ef5e800268cd8b4cb221711d149` |

File 5 Git/LF SHA-256: `d4563930461176e6481df29cf587c9dca0eb7b4987395c05af2f613758452fbc`.
Exclude the separately gated Visa editorial migration and never rerun the
historical aliases. Apply one approved file/transaction at a time in the
order shown, verify its ledger entry and postconditions, then continue.

## Grant-safe recovery runbook — production-specific, NOT executed

1. **Before change, DBA + owner:** Obtain project-scoped evidence from
   Dashboard Database > Backups (Scheduled, Point in Time, Restore to New
   Project), or the read-only Management API backup listing. Record backup
   IDs/status/timestamps, actual earliest/latest PITR points, timezone,
   retention, plan/add-on eligibility, restore method, project size, RPO/RTO,
   and Storage-object backup location. A recent `pg_stat_archiver` row is not
   a substitute. Authorize any paid isolated clone explicitly. Perform a
   **real restore from an actual production recovery point into a separate,
   access-restricted project** and compare data/schema/grants before sign-off.
   If this cannot be completed, NO-GO.
2. **Snapshot read-only source state:** Export the exact 47-row ledger,
   schema definitions, `pg_default_acl`, explicit ACLs and effective
   `PUBLIC`/`anon`/`authenticated`/`service_role` rights for each function,
   table, column and schema (include `public`, `private`, `auth`, `storage`).
   Capture RLS/policies/triggers, validated constraints, bucket metadata,
   critical row counts/checksums and non-database Storage object inventory.
   Preserve encrypted artifacts with DBA-controlled access; do not commit
   production rows, secrets, backup files or token-bearing URLs.
3. **If using logical `pg_restore` into a disposable target:** Bootstrap
   matching PostgreSQL/Supabase roles and extensions in a fresh isolated
   cluster. Before restoring objects, neutralize the target's broad
   `supabase_admin` public-schema default grants for tables/functions to
   `anon`, `authenticated`, `service_role` and `postgres`, and its global
   function EXECUTE-to-`PUBLIC` default. This was the tested local mitigation;
   use only in the **disposable target**, never as a blanket production
   grant change. Restore once with error-stop into a fresh target. A naive
   fresh-cluster restore produced **86 excess application ACLs** (34
   function, 52 table); see
   `RAD_PROD_EQUIV_NAIVE_RESTORE_ACL_DIFF_20261013.json`. Do not blindly
   retry `--clean` in a partially restored cluster: the local retry hit a
   Realtime partition-constraint dependency.
4. **Grant parity, not blanket GRANT:** Diff source and target explicit ACLs
   and effective privileges for all relevant roles. Remove all *target-only*
   rights; add only rights demonstrably present in the source snapshot.
   Include `PUBLIC` inheritance and column privileges (`admin_note`). The
   local hardened restore needed five private and 23 Auth/Storage function
   rights restored after default-ACL neutralization; these are observations,
   **not** a hard-coded production grant list. Verify zero excess and zero
   missing rights. `scripts/verify_prod_equiv_restore.py` illustrates the
   local 672-check parity comparison but has hard-coded disposable container
   names and must be adapted/reviewed by the DBA for the authorized target.
5. **Integrity and service boundary:** Verify ledger, catalog and validated
   constraints, row counts and per-table checksums, Auth identities, critical
   RLS/SECURITY DEFINER denial probes, Storage metadata versus separately
   recovered object bytes, and required platform configuration. Keep the
   restored clone private; no outbound workers or public APIs until approved.
   A same-project restore or cutover requires a separate incident decision,
   planned downtime and fresh authorization. Do not treat local dump/restore
   as proof of production PITR.

## Owner/DBA approval and deployment stop conditions

- [ ] Owner grants explicit authority for a backup/PITR inspection and, if
  needed, paid **isolated** restore; DBA attests and tests a real production
  recovery point and Storage-object recovery. Record independent evidence.
- [ ] DBA signs the 47-row historical ledger/alias map, current full catalog
  and ACL baseline, existing-data CHECK compatibility and grant-safe restore
  runbook. Re-run those checks immediately before the maintenance window.
- [ ] Product/AI owner resolves discovery auto-enable behavior; Auth owner
  chooses/leads leaked-password protection change separately.
- [ ] Owner authorizes exactly the five hashes and a maintenance window;
  DBA owns one-at-a-time apply, immutable logs, traffic/worker controls and
  a named recovery operator. Visa editorial and Stage 3 baseline remain
  separate gates; Feed publication remains human-only.
- [ ] After each approved migration, verify ledger increment, object/grant
  delta, constraints, AI cross-user denial/quota atomicity, Consultation
  admin-note/direct-INSERT denial and abuse limit, Storage owner-path UPDATE
  only, approved-only Feed publication and human-only triggers. Re-run the
  security advisor and owner-approved HTTP probes with disposable identities.

**STOP before the first write** if backup availability/retention or tested
recovery point is unproven; if the ledger is not exactly the expected 47
entries; if a full catalog/ACL or data preflight differs; if any file hash
differs; if the AI owner decision or required approvals are missing; or if
maintenance/rollback operators are unavailable. **STOP between files** on
any failed transaction, unexpected ledger/object/grant delta, constraint
failure, privilege widening, or failed security probe. Preserve logs and
state; do not blindly reapply, manually mark migrations, reverse grants or
restore production without a separate DBA/owner decision.

### Exact outstanding owner/DBA actions

1. Provide project-level backup/PITR inventory and authorize an isolated
   production-point restore (and any cost) so a recovery point is actually
   verified; attest Storage-object recovery separately.
2. DBA approves the 86-ACL-safe restore procedure, historical alias/body
   reconciliation and fresh production full-schema/ACL/data preflight.
3. Product/AI owner decides model-discovery auto-enable semantics; Auth owner
   addresses leaked-password protection.
4. Release owner and DBA explicitly approve the five-file scope, hashes,
   maintenance window, operator, postchecks and stop/incident procedure.
5. Independently clear Visa editorial, Stage 3 baseline and human-only Feed
   release gates; none is implied by this security preflight.

**Production remains NO-GO.**
