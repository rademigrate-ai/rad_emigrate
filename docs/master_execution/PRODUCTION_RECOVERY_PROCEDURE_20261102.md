# Current Production recovery: exact operator procedure

Production is `inshddthftkhcdosoqcn`. This procedure and the local encrypted rehearsal authorize **zero hosted operations**. No current approved backup/profile has been confirmed. Historical preservation is not this release's checkpoint. Browser E2E remains owner-deferred.

The read-only observation on 2 November at 09:51 UTC records 18 legacy snapshots and 6 documents retaining NULL validation. Compared with the prior17-snapshot observation, one snapshot was added and three document row hashes changed; all 745 head/body/title/actor bindings are unchanged. The original17-snapshot seal remains historical. Use `release-final-20261102/current-forward-manifest.json` and`release_preflight_current.sql` with the current reconciliation baseline; never edit the old seal to disguise drift.

## Owner decision B1 — checkpoint and isolated restore

Approve a source connection **profile name/path only**, an independently identified empty recovery destination, the maintenance checkpoint, encrypted storage location, public encryption fingerprint/key custodian, retention and loss/restore objectives. The destination must be distinct from Production, Staging `epolbumcfbohtmgvomki` and Security `kojogjkasconksifxkdg`. Creating a paid project/branch is not authorized. A local synthetic destination cannot satisfy managed Auth/API acceptance.

Populate `profile.template.json` using secret references, identities and approval hashes, never passwords or service tokens. The template is deliberately invalid. Run from the active checkout:

```powershell
& '..\rad_full_content_v4\.venv\Scripts\python.exe' -B -X utf8 -m scripts.recovery_checkpoint --profile PRIVATE_APPROVED_PROFILE.json --snapshot EXPORTED_SNAPSHOT_ID --output NEW_OPERATOR_PLAN.json
```

The tool prepares commands only. Its result is `OPERATOR_PLAN_ONLY_NOT_RECOVERY_PROOF`, even with an approved-looking profile. Approval documents and hashes must be independently authenticated; a self-entered boolean/hash is not proof.

## 1. Bind identity, tools, credentials and isolation

Use version-matched PostgreSQL tools (installed PG17.11; first verify the actual source version is compatible). Resolve source/destination `PGSERVICEFILE` and `PGPASSFILE` references inside a private operator session. Service files must use `sslmode=verify-full` and an approved CA, expected database/role, the approved project-qualified hostname/username and connection mode. Avoid transaction poolers for snapshot ownership. Keep URLs/passwords out of process arguments, console, repository and ordinary receipts. Do not trust a project GUC or a service alias as endpoint identity.

Read `current_database()`, `current_user`, `version()`, server address/port, `pg_control_system().system_identifier` where authorized, and provider project identity. Match these to independently approved endpoint records. If system identity cannot be read, establish provider-supported identity evidence rather than relaxing the check silently. On the destination, inventory **all** schemas, tables, roles and extensions and require the reviewed empty managed baseline. Refuse an existing application schema, unknown data, or any shared project.

Before any restore connection, disable cron startup and all outbound networking/email/webhooks/workers at the destination through supported platform controls. Merely unscheduling after restore leaves an execution race. Record the controls, timestamps and independent checks. Resolve extension/version compatibility, managed-role conflicts and Vault/column encryption-root portability before restoration. No clone, new paid resource or Production setting change is authorized here.

## 2. Create one coordinated checkpoint

Freeze application, Auth, role/configuration and Storage writes under an approved maintenance window. Keep them frozen until the database, global roles/settings and every object byte are sealed. Without a freeze or independently complete change capture, an exported PostgreSQL snapshot cannot make database-plus-Storage atomic.

Capture read-only counts, full relation/FK inventories, owners, definitions/settings, policies/effective grants, publication/cron states and ordered row hashes. Include every non-extension relation, all `auth` tables (users, identities, sessions, refresh/MFA records as present), profiles and FK targets, Storage metadata/bucket settings, migration history, evidence/archive/quarantine rows and custom managed-schema objects. Use a restricted receipt store for private identities; ordinary evidence contains counts/hashes only.

Hold a dedicated source connection open:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT pg_export_snapshot();
-- Keep this connection open until every snapshot consumer completes.
```

With the returned token, the generated plan's producer is:

```text
pg_dump --format=custom --no-password --lock-wait-timeout=30s --snapshot=TOKEN --dbname service=rad_prod_readonly
pg_dumpall --roles-only --no-password --database service=rad_prod_readonly
```

Pipe **each** producer directly to GPG using the approved public fingerprint. `scripts.recovery_checkpoint.checked_export` checks both exit codes, fsyncs ciphertext and exclusively promotes a new `.gpg` file only after success; failed partial exports are removed. It never connects by itself. Roles contain password hashes and need the same encryption. Global roles/settings are outside the database snapshot and remain protected by the same write freeze. Close the snapshot holder only after producers succeed. Do not substitute separately timed schema/data/Auth dumps.

Before acceptance, decrypt the archive's TOC in the restricted operator session and compare every required relation/object to the captured inventory. Review all managed-schema supplements and custom triggers/policies/grants explicitly. The archive must not silently exclude Auth, Storage, migration history, custom owners or encrypted data. Save a hashed, reviewed TOC dependency list for the approved managed destination. `--no-owner`, `--no-privileges`, blind error suppression, `--clean` and global trigger disabling are not authorized shortcuts.

## 3. Capture Storage bytes and platform configuration

Use the approved read-only Storage/S3 connection, not database metadata as an object backup. Enumerate every public/private bucket and its configuration. List objects with full pagination and recursive prefixes, preserving literal Unicode bucket/key names, object IDs/owners/references, metadata, content type, size and version/ETag where available. Include zero-byte objects. Download the original bytes through the supported authenticated object API, stream immediately to encryption, and record SHA-256 of the original byte stream and ciphertext. Do not use signed URLs in ordinary receipts; they are credentials.

For the Storage REST API, the operator's private client uses the approved project base URL and Authorization header: bucket inventory `GET /storage/v1/bucket`; recursive listing `POST /storage/v1/object/list/{bucket}` with `prefix`, `limit`, `offset` and stable name ordering; file download `GET /storage/v1/object/authenticated/{bucket}/{encoded-key}`. Preserve `/` key separators and percent-encode each segment. Descend folder entries rather than treating them as byte objects. Iterate until exhausted; refuse duplicate/missing IDs or metadata changes. Vendor S3 listing/download may be used instead with equivalent full pagination, byte and metadata proof. Keep the write freeze through a second full manifest comparison.

Capture Auth providers/redirects, SMTP/MFA/CAPTCHA, API/signing configuration, functions by exact source/deployment hashes, secrets by references, Realtime/publications, custom roles, cron commands/active states and egress controls separately. Do not export decrypted Vault or signing values to public evidence. Record unsupported key portability as a failed gate.

Seal the ciphertext manifest, bucket/object byte hashes, snapshot/checkpoint identifiers, relation/role/config inventories, source identity, timings and operator signature/approval. Verify decryption with the designated custodian. Do not retain a plaintext Auth/database dump in the repository or shared audit directory.

## 4. Restore and verify before forward DDL

Recheck destination identity/isolation/empty managed baseline. Restore reviewed global roles/custom managed dependencies in approved order; treat an error as failure. Decrypt the archive in a pipe into:

```text
pg_restore --exit-on-error --single-transaction --no-password --use-list REVIEWED_MANAGED_RESTORE_TOC.list --dbname service=rad_isolated_restore
```

Require both GPG and pg_restore exit codes to be zero. Do not emit plaintext to disk or mark success because the last pipeline command succeeded. Preserve failed logs privately. A failed external API restore requires a separately approved empty destination or an explicit recovery plan, never deletion/reset of a shared database.

Restore object bytes using the supported Storage/S3 API, preserving bucket/key and required metadata; reconcile object IDs/owners and application references according to the reviewed provider workflow. Direct SQL insertion into `storage.objects` does not restore bytes. Retrieve **every** restored object and compare SHA-256, including zero-byte files.

Compare the complete pre-forward catalog, effective ACL/RLS, definitions/settings, triggers/validated FKs/checks, ordered row hashes, actor UUIDs/timestamps/NULLs, migration history and every Storage byte. At the pinned content checkpoint: 745 existing heads have hash `3ca6ad9fddb4dbb71993a5aa7774016b` under the exact expression in the sealed preflight, and six legacy documents retain NULL validation. Counts/hash expectations must be freshly captured for the approved checkpoint; do not force a changed source to match old observations.

Use an owner-approved **existing** test account through the actual isolated Auth service to test preserved credentials/provider, refresh and own-record access. Test another authorized account and anonymous denial. No user recreation, impersonation, synthetic JWT or password reset may substitute for this evidence. Native `auth.users` fixtures do not prove real Auth.

## 5. Rehearse the exact approved forward and additive package

On the proven restored destination, bind the current checkpoint, schema-forward SHA, reconciliation-package SHA, actual Admin actor and independent endpoint identity. Run the exact core forward transaction, verify all original rows/Storage/51 outside heads plus other existing heads remain unchanged, roll back and compare the entire checkpoint. Exercise guarded failure/timeout and retry. Apply the additive reconciliation only with accepted exact per-case decisions; create unverified drafts, preserve all existing head/actor/publication pointers, never publish. Verify actual role-checked Admin queue/full-body readers and anonymous/non-Admin denial. Seal successful retry/idempotence and rollback evidence.

Before hosted schema/import/undo DDL, independently review enabled database event callbacks and bind an explicit policy to the exact project, package, actor and callback descriptors. `db_forward_review/production-event-callback-metadata-20261102.json` records identity/configuration/hash evidence only. The current enabled managed `extensions.pgrst_ddl_watch()` callback is not approved by its name or hash. Automatic approval review rejected exporting full Production callback source as potentially sensitive code; secure owner/operator review remains required. Blank callback policy never authorizes a hook, and neither import nor undo may use manual hook disabling as a shortcut.

The independent managed-restore receipt must include exact input/output hashes, endpoint, real Auth/Storage acceptance, timings, actual errors/limitations and owner acceptance. Only that receipt can satisfy the real recovery gate. Production execution then requires a **separate**, exact hosted-write authorization; neither this procedure nor a generated plan grants it.

## Completed local evidence

`synthetic-encrypted-restore-final-v4/rehearsal-receipt.json` records a fresh owned loopback PG17 cluster on 64940, one exported snapshot, streaming GPG encryption, decrypt/restore, seven table hashes, preserved FK/RLS/policy and NULL/head fields, private and zero-byte object bytes, and enforced orphan rejection. The cluster stopped cleanly. Focused regressions also reject failed producer/encryptor pipelines, corrupted ciphertext, snapshot-export timeout and failed shutdown. `production_backup_proof=false`, `real_auth_acceptance=false`: these are deliberately distinct from the required real recovery proof.

References: [Supabase logical backup/restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore), [database backups and Storage limitations](https://supabase.com/docs/guides/platform/backups), [Storage list endpoint](https://supabase.com/docs/reference/self-hosting-storage/search-for-objects-under-a-prefix), [authenticated object downloads](https://supabase.com/docs/guides/storage/serving/downloads), [PostgreSQL pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html).
