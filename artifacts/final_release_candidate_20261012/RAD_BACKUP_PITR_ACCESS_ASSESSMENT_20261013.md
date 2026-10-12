# RAD managed-backup/PITR access and recovery assessment — 2026-10-13

**GO/NO-GO: NO-GO.** Read-only review of production project
`inshddthftkhcdosoqcn` on branch
`handoff/codex-stage1-stage2-20261010`, starting at
`d8c4c8e0f401c13ad4e47f4664238f91b6c74e5c`. No production writes,
backup creation, restore, paid resource, Auth setting or deployment occurred.
This update supersedes the earlier *plan-tier unknown* finding; it does not
claim an enumerated backup inventory or a tested production recovery point.

## What the authenticated access actually established

| Question | Finding | Evidence / status |
|---|---|---|
| Account/project | RAD Supabase connector is authenticated for project and organization reads. Project is `ACTIVE_HEALTHY`, PostgreSQL 17.11. | MCP `get_project` and `get_organization`: organization `qghduudkmzjyubrwsfzl`, **plan `free`, tier `tier_free`**. PASS. |
| Managed daily-backup entitlement | **Not included on the current Free plan.** Supabase documents automatic daily backups for Pro, Team and Enterprise; Free projects should maintain their own off-site export. Do not infer that an archived WAL constitutes an enabled backup product. | [Database Backups](https://supabase.com/docs/guides/platform/backups). Entitlement assessment PASS; actual inventory UNVERIFIED. |
| PITR entitlement/window | PITR is a paid-plan add-on requiring at least Small compute. The current Free plan is ineligible. Earliest/latest selectable recovery timestamps and retention for this project **cannot be read from the available connector**; no PITR window is verified. | Same [backup guide](https://supabase.com/docs/guides/platform/backups). Entitlement assessment PASS; actual window UNVERIFIED. |
| Actual backup IDs, status, schedule | **UNVERIFIED.** No backup-list or backup-schedule method exists in the connected Supabase toolset. CLI `backups list` returned `AccessTokenRequiredError`. Direct read-only GETs for `/database/backups`, `/database/backups/schedule` and `/restore` each returned HTTP **401** `No access token provided`. The computer/browser inventory had no browser surface; Chrome and IAB providers were unavailable. | No 200 inventory response, and importantly no 403. This is an **authentication-path/tool exposure gap**, not proven missing account permission. |
| Exact authorization to inspect | A Management API bearer token from an account with project access is needed in the CLI/HTTP environment. For a scoped PAT, **Backups: Read** covers `List all backups` and `Get backup schedule`; **Project Settings: Read** covers `List available restore versions`. Existing MCP OAuth access cannot be exported to those commands by any exposed tool. Do not send a token in chat. | [PAT permission matrix](https://supabase.com/docs/guides/platform/personal-access-tokens), [backup-list endpoint](https://supabase.com/docs/reference/api/v1-list-all-backups), [restore-version endpoint](https://supabase.com/docs/reference/api/v1-list-available-restore-versions). A later HTTP 403 with valid auth would justify investigating the role/scope; no such test occurred. |
| WAL signal | `archive_mode=on`, two-minute archive timeout, `pg_stat_archiver` 602 archived/0 failed, last archived `2026-10-12 22:11:45 UTC`. | SQL rechecked at `2026-10-12 22:25:25 UTC`. WAL activity alone proves neither a retained base backup nor a recoverable point. |
| Production ledger | 47 migrations, last `20261007212140`; five security migrations still pending. | Read-only SQL at `2026-10-12 22:25:25 UTC`. PASS for this observation. |
| Storage recovery | One `LOGO` object, metadata size 95,420 bytes; `documents` bucket has zero objects at inspection. `LOGO` is public and `documents` private. | Read-only `storage.objects`/`storage.buckets` aggregates. Database backups contain Storage metadata, **not object bytes**; the one logo must have a separate verified object copy. Counts can change. |
| Real production-point restore | **NOT RUN.** No backup ID/recovery timestamp was verified, and no authorized isolated restore exists. | A local logical restore of synthetic/replayed data previously passed; it is not production recovery evidence. |

The owner’s assertion that agents have Supabase access is supported for the
MCP project/organization/database reads. It does not itself supply a bearer
token to the separate Management API backup-list endpoint, and the connector
does not implement that endpoint. **Do not call the connector's
`restore_project` operation to discover backups**; it is a mutation.

## Feasibility, price and scope of an isolated production-point restore

1. **Managed Restore to a New Project:** Currently **not available on this
   Free-plan project under the documented eligibility rules**. It requires
   a paid plan and physical backups enabled on the source, plus a real listed
   backup or PITR point. A restore creates an independent project in the same
   region, with mirrored compute/disk attributes. Supabase presents a
   project-specific price before confirmation; the clone incurs additional
   monthly compute/usage costs. The [feature is beta and database-only](https://supabase.com/docs/guides/platform/clone-project).
   Storage files/settings, Edge Functions, Auth settings/API keys, Realtime
   settings and other service configuration need separate reconciliation.
   Extensions with outbound behavior (e.g. `pg_net`, `pg_cron`) could run on
   a clone; the DBA must plan containment before any authorized restore.
2. **Costs requiring owner approval:** Published Pro base price is about
   **$25/month**; after paid upgrade, daily backup retention is documented
   as **7 days on Pro**, 14 on Team, up to 30 on Enterprise. PITR is optional
   and non-retroactive: published add-on prices are about **$100/$200/$400
   monthly** for 7/14/28-day retention, plus at least **Small compute**
   (published about $15/month). [PITR pricing](https://supabase.com/docs/guides/platform/manage-your-usage/point-in-time-recovery),
   [compute pricing](https://supabase.com/docs/guides/platform/manage-your-usage/compute).
   Exact invoice/proration and clone price must be confirmed in the owner’s
   billing UI before any purchase. The connector's read-only `get_cost`
   returned **$0/month for a new Free-plan project** and **$0.01344/hour for
   a branch**; neither is a quote for an eligible physical-backup restore.
3. **Alternative DBA-controlled logical recovery:** With separate owner
   authorization, make a consistent, encrypted, off-machine production
   logical backup and separate Storage-object copy, then restore into a
   private, isolated PostgreSQL 17.11 target and verify it. This is not PITR
   and gives only the export snapshot's recovery time. No such production
   dump or restore was performed in this turn. Upgrade/physical-backup
   eligibility cannot retroactively create a recovery point before its
   activation.

## Grant-safe isolated restore procedure (prepared, not executed)

The prior local naive `pg_restore` into a fresh Supabase PostgreSQL 17.11
cluster added **86 application ACLs** absent from the source (34 function,
52 table). Source production currently has broad public-schema
`supabase_admin` default grants for *future* objects, while existing-object
privileges are narrower. Preserve an exact source ACL/effective-privilege
snapshot immediately before any approved backup. This is the source of truth,
not the target's defaults or a blanket `GRANT ALL` recipe.

1. Keep the target network-isolated, same major PostgreSQL/Supabase roles and
   compatible extensions; disable or contain outbound workers before making
   a restored clone reachable. Do not alter production defaults.
2. For a **logical restore to a fresh disposable target only**, neutralize
   `supabase_admin`'s public-schema default table/function grants to `anon`,
   `authenticated`, `service_role` and `postgres`, and global default
   function EXECUTE to `PUBLIC`, *before* restoring objects. This sequence
   was tested locally; a managed physical clone uses a different mechanism,
   so still verify its grants instead of assuming the same correction.
3. Restore once with error-stop; do not blindly rerun `--clean` in a partially
   restored cluster. The earlier local retry encountered a Realtime
   partition-constraint dependency.
4. Diff source versus target explicit ACLs and **effective** privileges for
   schemas, functions, tables and columns across `PUBLIC`, `anon`,
   `authenticated`, `service_role` and relevant platform roles. Remove all
   target-only rights and add only source-existing rights. The local hardened
   restore needed five private and 23 Auth/Storage function rights restored;
   these numbers are not a hard-coded production grant list. Require zero
   extra and zero missing rights, including `consultation_requests.admin_note`.
5. Compare migration ledger, catalog, validated constraints, RLS/policies,
   function bodies, row counts/checksums, Auth data and Storage metadata
   against separately verified object bytes. Re-run least-privilege denial
   probes on the **isolated target**. The local verification script
   `scripts/verify_prod_equiv_restore.py` has disposable-container names;
   adapt and review it for any authorized production-point clone.

If the target has any unexplained overgrant, constraint/data mismatch, absent
Storage bytes, or outbound integration activity, **STOP**; do not expose it
or treat it as a successful recovery test. The local 672/672 privilege and
95/95 table-hash checks prove only that local rehearsal.

## Confirmed owner decisions and remaining checklist

- **DECIDED — AI models:** newly discovered models remain **disabled until
  administrator approval**. The live-only discovery migration currently
  auto-enables newly found chat models, so this decision is *not yet enforced
  in production*. Engineering/DBA must prepare, review and separately
  authorize a compatible change; do not silently change production now.
- **DECIDED — Auth:** leaked-password protection **should be enabled after
  compatibility assessment**. The advisor still reports it disabled. Auth
  owner must assess existing login/signup/password-reset impact, then seek
  separate authorization and verify after the setting change.
- **OWNER/DBA — backup access:** inspect Dashboard Database > Backups
  (Scheduled, Point in Time, Restore to New Project) using an authorized
  session, or run read-only Management API `GET .../database/backups` and
  `GET .../restore` using an approved scoped token with Backups Read and
  Project Settings Read. Keep tokens in a secret manager/agent environment,
  **not chat or repository**. Record sanitized 200 response, backup IDs,
  creation/completion status, retention and exact earliest/latest UTC
  recovery points; if 403, resolve account membership/token scopes. This
  may simply confirm no backups on Free.
- **OWNER — recovery strategy and spend:** choose paid managed backup/PITR
  and approve costs, or approve a DBA-produced off-machine logical+Storage
  backup. In either case separately authorize a private isolated restore and
  its data handling. Wait for a real eligible post-enablement backup; never
  claim an older point exists retroactively.
- **DBA — execute and attest when authorized:** use the grant-safe procedure,
  record zero excess/missing privileges and data/Storage integrity, then
  update this evidence matrix. The remaining five security migrations stay
  prohibited until a tested production recovery point, fresh preflight,
  owner/DBA deployment approval and all release gates are satisfied.

**Current backup inventory: UNVERIFIED. Current Free-plan managed-backup/PITR
eligibility: FAIL. Isolated production-point restore: NOT RUN. Production:
NO-GO.**
