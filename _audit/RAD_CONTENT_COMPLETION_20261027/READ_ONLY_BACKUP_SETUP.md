# Staging backup connection setup — Owner action required

No backup has started. This is a setup procedure, not a backup or restore receipt.
Target: **epolbumcfbohtmgvomki** only. Production is excluded.

## Existing configuration inspection

The read-only local inspection covered the RAD workspace and existing Desktop RAD project configuration names, the prior content-completion audit, and `D:\RAD_MASTER_EXECUTION_20261025`. It inspected file names and configuration key names without printing values or trying credentials. It found application API configuration, templates and local fixture tooling, but established no approved read-only hosted database connection. This is a scoped finding, not a claim that every file on the computer was searched.

A Staging `pg_roles` metadata query returned no nonstandard custom roles after excluding PostgreSQL/Supabase platform roles. No password hashes or role configuration values were retrieved. A request for role configuration values was rejected by automatic approval review because such values can contain secrets; the successful replacement selected only names and permission flags.

## Provisioning steps

**Existing-role option first:** subsequent non-sensitive inspection confirmed that the platform role `supabase_read_only_user` exists with LOGIN, BYPASSRLS and membership in `pg_read_all_data`, without superuser or role-administration capability. It can SELECT all 155 checked relations across the six scoped schemas, has no direct INSERT/UPDATE/DELETE/TRUNCATE privilege there, and cannot execute the editorial save/import routines. `existing-readonly-role-evidence.json` records the check. This is permission metadata, **not an approved or tested connection**. If an authorized operator already has an approved credential for this role, the Owner can approve that connection and supply the secure local manifest below; a new role might be unnecessary. Do not retrieve, guess or reset a managed role password, mint credentials, or modify its grants under this task's current authorization. If no approved credential is available, use the separately authorized dedicated-role procedure below.

1. An authorized Owner opens the **Staging** project Dashboard, verifies `epolbumcfbohtmgvomki` and opens **Connect**. Copy its direct connection or session-pooler endpoint privately. Do not use the transaction pooler for the dump. Do not copy an application API key as a database password.
2. Provision a dedicated login named `rad_content_backup_ro`, with a new password entered privately. Creating a role or granting privileges changes hosted metadata and is **not authorized for execution in this task yet**. An Owner must perform it or explicitly authorize the exact change separately. Do not reuse `postgres`, a service-role API key, or synthetic local credentials.
3. The initial grants below are a review template for the Owner. Verify that these schemas still exist before execution; resolve additional dependencies before declaring the scope complete. Grant no table mutation, sequence mutation, schema creation, role administration, replication or superuser privilege.

```sql
-- OWNER REVIEW ONLY: do not execute under the current no-hosted-writes instruction.
create role rad_content_backup_ro login inherit nosuperuser nocreatedb
  nocreaterole noreplication connection limit 2;
-- Set the password privately using psql \password rad_content_backup_ro,
-- or a secure Dashboard role form; never paste a password into this file/chat.
grant connect on database postgres to rad_content_backup_ro;
alter role rad_content_backup_ro set default_transaction_read_only = on;
grant usage on schema public, private, auth, storage,
  staging_preserved_20261025, supabase_migrations to rad_content_backup_ro;
grant select on all tables in schema public, private, auth, storage,
  staging_preserved_20261025, supabase_migrations to rad_content_backup_ro;
grant select on all sequences in schema public, private, auth, storage,
  staging_preserved_20261025, supabase_migrations to rad_content_backup_ro;
```

4. **Resolve RLS access explicitly.** SELECT grants alone do not guarantee a complete dump. PostgreSQL's default `pg_dump` rejects inaccessible RLS tables. A platform-authorized operator must establish complete read access, including forced-RLS content/editorial and required Auth tables; this may require a separately approved `BYPASSRLS` attribute that the managed project Owner cannot self-grant. Do not disable RLS, grant a write role, or use `--enable-row-security` to obtain a silently partial backup. If the platform cannot provide a suitably restricted login, stop and report that exact privilege requirement.
5. Audit the new role's direct and inherited privileges, owned objects and executable security-definer routines. `default_transaction_read_only` is a connection default, not an irrevocable security boundary. The backup process must itself use read-only transactions and call only catalog/read operations; do not claim that this default alone makes an otherwise privileged account safe.
6. Create a private folder **outside every Git checkout**, for example `%LOCALAPPDATA%\RAD\staging-backup`. Restrict its Windows ACL to the current user and SYSTEM before storing secrets. Save a libpq service file and password file there with restrictive ACLs; enter the password in a local editor without command history or a transcript. Follow libpq escaping for `:` and `\` in the password file. Never commit either file. Use `sslmode=verify-full` with the verified CA from the Dashboard, or resolve a certificate problem explicitly instead of disabling TLS validation.
7. Save a nonsecret manifest `connection.json` in the same private folder with these fields. Fill in **actual absolute paths**, the endpoint copied from this project's Connect dialog and the Owner approval reference; these example paths are not an existing connection.

```json
{
  "project_ref": "epolbumcfbohtmgvomki",
  "purpose": "read-only logical backup and isolated local restore",
  "approval_reference": "Owner confirmation of this exact role and scope",
  "database_role": "OWNER_APPROVED_READ_ONLY_LOGIN",
  "service_name": "rad_staging_backup_ro",
  "service_file": "ABSOLUTE_PRIVATE_PATH_TO_pg_service.conf",
  "password_file": "ABSOLUTE_PRIVATE_PATH_TO_pgpass.conf",
  "tls_ca_file": "ABSOLUTE_PRIVATE_PATH_TO_VERIFIED_CA.pem",
  "encryption_recipient_or_key_file": "ABSOLUTE_PRIVATE_PATH_TO_APPROVED_ENCRYPTION_CONFIGURATION"
}
```

The service entry must specify the actual host/port, `dbname=postgres`, the approved read-only login (session-pooler username includes the exact project suffix), TLS CA and `sslmode=verify-full`. The manifest contains no password. Send **only the absolute `connection.json` path** in chat when the role and files are approved and ready.

## Checks before any real dump

- Verify the file ACLs and encryption configuration without logging contents. Refuse Production, another project, an administrative login or an unapproved role. Verify server version, current role/attributes, exact disabled Staging import-target marker, effective read privileges and dependency closure using SELECT in read-only transactions. Do not test read-only capability with an attempted hosted write.
- Inventory the actual content/editorial tables, source references/snapshots, immutable revisions, approval/history data, sequences, types, functions, constraints, indexes, triggers, policies, grants and required Auth user relationships. Include the preserved schema and migration metadata when they participate in recovery. Record platform/extension dependencies and non-password role definitions separately. A table-only dump is not sufficient. If Vault-encrypted values participate in the recovery scope, a database dump without its required encryption material does not prove recovery; obtain a separately approved method.
- Use a consistent exported snapshot for the dump and verification counts/hashes. Do not compare independently changing live reads as if they were the same snapshot. Encrypt the archive and sensitive metadata as they are written; do not leave plaintext dumps in the repository or logs. Record UTC times, encrypted-file checksums, retention location and the decryption/recovery method without secrets.
- Restore **only into a new isolated local database** with no hosted endpoint or active outbound jobs. Recreate actual required platform dependencies; synthetic Auth placeholders cannot replace missing hosted data. Verify schema/constraints, every scoped table's counts and canonical row hashes, foreign-key relationships, sequences, immutable history, approvals, Auth references and representative complete rich readers. Record commands with credentials omitted. A successful import, local rollback or Git snapshot cannot satisfy this gate.

Storage object bytes and external platform configuration are separate from database metadata. Determine whether affected content depends on those objects and preserve them through an approved method before claiming recovery scope is complete. A logical database backup is not a complete Supabase project clone.

## Primary references

- [PostgreSQL pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html): consistency, dependencies, roles and RLS behavior.
- [Supabase backups](https://supabase.com/docs/guides/platform/backups): Free-plan export recommendation and Storage-object limitation.
- [Supabase logical backup/restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore): roles, managed-schema customizations and migration history.
- [Supabase platform-to-local restore](https://supabase.com/docs/guides/self-hosting/restore-from-platform): actual platform dependencies and Auth data.

**Gate status: NOT PASSED. No hosted backup, local restore of hosted data, hosted metadata change or content write was performed by this procedure.**
