# RAD independent recovery execution package

Engineering tooling and synthetic tests are ready for DBA review. **Actual
DBA review/sign-off is pending. Production remains NO-GO.** No production
data, private Storage object, credentials, backup or restore is included.
The unfilled approval example grants no authority. Its fields are procedural
checks; a JSON file does not authenticate an approver or replace access control.

## Scope and prerequisites

- Python 3.11+ (tested 3.14.7), PostgreSQL **17.11** clients/server, age 1.3.2,
  and tar; the authorized DBA download host also needs an existing approved
  rclone/S3 connection. Test tools use only Python's standard library.
- An approved direct/session PostgreSQL connection on port 5432, TLS
  `sslmode=verify-full`, an appropriate CA, and a protected passfile. Never use
  passwords or connection URLs in command arguments. Put `PGSERVICEFILE`,
  `PGPASSFILE`, the approval record, rclone config and all recovery artifacts
  outside the repository; restrict files to the operator (0600), directories
  to 0700, and use an encrypted volume or tmpfs for sensitive staging.
- Source account: minimum existing role able to read **all** required data,
  sequences/large objects and catalogs and bypass RLS for complete export.
  `pg_read_all_data` alone does not bypass RLS. Do not grant broad application
  access, create roles or change production to satisfy this package without
  separate authorization. If the managed service denies access to any required
  schema/large object, STOP; never silently omit Auth, Storage or ledger data.
- Target restore uses a DBA-controlled privileged role only in a **separate
  disposable PostgreSQL 17.11 cluster**, with network disabled/no published
  ports, matching reviewed Supabase role/extension bootstrap and storage
  service versions. Restored SQL can run functions/extensions. Keep Auth,
  cron, Edge, Realtime and outbound workers stopped until containment is
  checked. Do not restore into production or the source cluster.
- Verify the official age distribution before production use. Synthetic
  testing used the official Windows v1.3.2 asset with SHA-256
  `f48d8f8f9ebe903ab5027ed067652f2cc1db94bc206976430133b905dcd8e8c7`,
  checked against GitHub release asset metadata. Sigsum proof verification
  was not executed. This package contains no age binary or private identity.

PostgreSQL [pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html)
provides a consistent snapshot of one database. A single custom archive is
the database source of truth; separate CLI schema/data dumps without a shared
snapshot are not interchangeable. Raw pg_dump includes platform internals;
Supabase [documents permission/compatibility differences](https://supabase.com/docs/guides/self-hosting/restore-from-platform).
A DBA must review the full archive TOC and target bootstrap. Do not treat
this as an automatic migration into a hosted Supabase project.

## Consistency and encrypted retention

The database, roles/catalog reads, sequence values and Storage API have no
shared atomic snapshot. **Owner-approved write quiescence is required** for
this package: application writes/uploads/deletes, Auth/background writes,
DDL/role changes, cron, research/AI/Edge workers and integrations must be
controlled for the entire capture window. An operator flag does not freeze
writes. Record controls and UTC start/end; capture catalog/data digests before
and after the archive and independently download Storage bytes twice during
the same window. A differing digest or inventory invalidates the consistency
claim. If a complete freeze cannot be established, STOP and choose a reviewed
alternative snapshot/versioning strategy. Supabase S3 currently lacks object
versioning; later downloads cannot reconstruct a deleted earlier object.

The wrapper streams database, role-reference and catalog output into age
public-recipient encryption. Plain database archives never touch the backup
host's filesystem. Storage files are staged only on tmpfs/encrypted media;
tar and the byte manifest are separately encrypted. On producer/encryption
failure, `.partial` files remain and no successful bundle manifest is written.
Outputs refuse reuse/overwrite. All stderr is suppressed inside the encryption
pipeline to avoid leaking sensitive values; failure reports identify the
artifact and process exit codes. The DBA can authorize encrypted diagnostics
separately if needed.

Use approved age **public recipients** on the capture host; keep private
identities offline/on the restricted restore host with independent custody.
Multiple age recipients mean any one recipient can decrypt; this is not
threshold cryptography. Store ciphertext in two independent off-machine
locations, with immutable retention/versioning and audited limited access.
Authenticate each ciphertext manifest with the organization's existing
artifact-signing process, and keep its signed digest independently. Hashes
and age's authenticated encryption detect corruption, but a replaceable
unsigned manifest does not prove who created a bundle. Signature verification
and off-machine transfer are pending owner selection and were not tested.

Proposed policy for approval: a pre-change snapshot, daily snapshots during
pilot, 30 days of retained daily copies and periodic restore drills. A daily
schedule gives up to 24 hours of database loss, plus any separate Storage
capture lag. Retention/RPO/RTO are owner decisions, not accepted defaults.

## Exact production commands requiring owner/DBA authorization

These commands are **prepared, not executed against production**. Examples
use a DBA Linux shell with `set -euo pipefail` and `umask 077`. Replace paths
using approved protected files. The unapproved example record must be replaced
outside the repo with signed review references and operations
`metadata_snapshot`, `database_backup` and `storage_backup`. Production
restore and service/credential changes require **additional** explicit scope.

```bash
set -euo pipefail
umask 077
export PGSERVICEFILE=/secure/config/pg_service.conf
export PGPASSFILE=/secure/config/pgpass
# [rad_prod_backup] in pg_service.conf: host/user identify inshddthftkhcdosoqcn,
# port=5432, dbname=postgres, sslmode=verify-full, sslrootcert=approved CA.
# No password in pg_service.conf; no secret values in shell history.

# AUTHORIZATION A: frozen-window metadata/data-digest export, encrypted.
test ! -e /secure/cipher/source-before.json.age
python scripts/recovery/snapshot.py capture --service rad_prod_backup \
  --project-ref inshddthftkhcdosoqcn --approval-file /secure/approved-recovery.json \
  --all-user-schemas --data-hashes --writes-frozen |
  age -R /secure/public-recipients.txt -o /secure/cipher/source-before.json.age

# AUTHORIZATION B: complete production logical backup + password-free role
# reference + post-dump catalog/digests. New output directory must not exist.
python scripts/recovery/encrypted_backup.py database --service rad_prod_backup \
  --project-ref inshddthftkhcdosoqcn --approval-file /secure/approved-recovery.json \
  --writes-frozen --recipients /secure/public-recipients.txt \
  --output-dir /secure/cipher/database
python scripts/recovery/verify_bundle.py --root /secure/cipher/database
```

The role export uses `pg_dumpall --roles-only --no-role-passwords`. It is an
encrypted **reference**, never blindly applied: managed roles already exist
and membership/default grants must be reconciled. Custom database-role
passwords are deliberately absent and need an approved target credential
plan. Auth users' password hashes, sessions/tokens and business data remain
inside the encrypted database archive and are sensitive production data.

```bash
# AUTHORIZATION C: list/read actual source Storage objects. No S3 credential
# creation or S3 enablement is authorized by these commands. Use an existing
# approved connection, or seek separate approval for one. Supabase S3 keys can
# be project-wide; do not describe them as bucket-only/read-only without proof.
# Use the bucket list from the frozen source snapshot. LOGO is an example;
# include every approved source bucket, including documents when applicable.
rclone --config /secure/config/rclone.conf copy rad_prod:LOGO \
  /secure/tmpfs/storage/LOGO --transfers 1 --checkers 2 --retries 3
rclone --config /secure/config/rclone.conf copy rad_prod:LOGO \
  /secure/tmpfs/source-check/LOGO --transfers 1 --checkers 2 --retries 3
python scripts/recovery/storage_manifest.py capture --root /secure/tmpfs/storage \
  --output /secure/tmpfs/storage-first.json
python scripts/recovery/storage_manifest.py capture --root /secure/tmpfs/source-check \
  --output /secure/tmpfs/storage-second.json
python scripts/recovery/storage_manifest.py compare \
  --source /secure/tmpfs/storage-first.json --target /secure/tmpfs/storage-second.json
python scripts/recovery/encrypted_backup.py storage \
  --root /secure/tmpfs/storage --project-ref inshddthftkhcdosoqcn \
  --approval-file /secure/approved-recovery.json --writes-frozen \
  --recipients /secure/public-recipients.txt --output-dir /secure/cipher/storage
python scripts/recovery/verify_bundle.py --root /secure/cipher/storage
```

Download original bytes, not thumbnails/transformed images. Storage byte
manifests preserve bucket/key, byte count and SHA-256; size/ETag/database
metadata alone is insufficient. Compare manifest keys/counts/sizes against
the frozen `storage.objects` inventory as well. Copying only one selected
bucket is not a complete backup. Encrypt and include the manually completed
`service_configuration.example.json` inventory with secret **custody
references**, never credentials in the repo. The DBA records Auth versions,
redirects, JWT/API/SMTP/OAuth/MFA settings, Vault/pgsodium key dependencies,
Edge code/config, Realtime/replication state, Storage backend/bucket settings,
network/DNS/CORS and all outbound schedules. Managed encryption keys may not
be exportable; lack of a tested key-recovery/credential-recreation path is a
functional recovery blocker even when row hashes match.

**AUTHORIZATION D:** sign manifests, transfer encrypted bundles and service
inventory to the approved off-machine stores, verify downloaded ciphertext
hashes from both stores, and approve retention/cost. No destination/cloud
resource is configured by this package. Only then may the capture be accepted;
release the approved freeze according to the maintenance plan.

The master inventory must include source-before, service configuration and
every bundle, not just the database files. Prepared Linux examples, using an
existing owner-approved signer (minisign workflow was NOT RUN here):

```bash
age -R /secure/public-recipients.txt -o /secure/cipher/service-config.json.age \
  /secure/tmpfs/completed-service-config.json
cd /secure/cipher
find . -type f -name '*.age' -print0 | sort -z | xargs -0 sha256sum > master.sha256
minisign -S -s /offline/artifact-signing.key -m master.sha256
# On the independent retrieval/restore host, before decrypting:
minisign -Vm master.sha256 -p /approved/artifact-signing.pub
sha256sum -c master.sha256
```

## Isolated restore commands and grant comparison

**AUTHORIZATION E:** create/choose the explicitly named offline target and
handle/decrypt production data there. Verify the signed manifests, then run
`verify_bundle.py` on the retrieved ciphertext directories. Decrypt **fully**
into protected tmpfs before executing SQL; a failed age authentication must
never be piped into a committing restore.

```bash
age -d -i /offline/private-identity.txt -o /secure/tmpfs/database.dump \
  /retrieved/database/database.dump.age
age -d -i /offline/private-identity.txt -o /secure/tmpfs/source-after.json \
  /retrieved/database/catalog.json.age
age -d -i /offline/private-identity.txt -o /secure/tmpfs/source-before.json \
  /retrieved/source-before.json.age
python scripts/recovery/snapshot.py compare --source /secure/tmpfs/source-before.json \
  --target /secure/tmpfs/source-after.json
age -d -i /offline/private-identity.txt -o /secure/tmpfs/roles-reference.sql \
  /retrieved/database/roles-reference.sql.age
pg_restore --list /secure/tmpfs/database.dump > /secure/tmpfs/archive-toc.list
# DBA reviews bootstrap schema/extension conflicts, owners, role prerequisites,
# full data coverage and outbound code. Preserve the original TOC and signed
# review of any selected restore list. Never auto-strip Auth/storage/ledger.
```

**AUTHORIZATION F:** target-only creation-default changes and restore. The
provided SQL is for the tested `supabase_admin` restore operator; a different
operator requires an adapted review. On the verified new isolated target:

```bash
PGOPTIONS='-c rad.recovery_target_confirmed=yes' psql -X \
  'service=rad_isolated_restore' --single-transaction -v ON_ERROR_STOP=1 \
  -f scripts/recovery/neutralize_target_defaults.sql
pg_restore --dbname='service=rad_isolated_restore' --exit-on-error \
  --single-transaction --use-list=/secure/tmpfs/reviewed-toc.list \
  /secure/tmpfs/database.dump
# Only for a separately approved empty target with reviewed drop scope could
# --clean --if-exists be added. Never retry --clean in a partial restore.
```

The prior full local rehearsal demonstrated **86 extra application ACLs**
after a naive restore. The current small fixture reproduces the mechanism
with 26 extra individual rights; these counts measure different fixtures.
Neutralize creation-time public table/function/sequence grants and global
PUBLIC function EXECUTE on the **target** before objects are created. After
restore, capture a full target snapshot (approved target service with its own
project/host identity, or `--docker-container` on the network-none offline
target) and compare it with the source:

```bash
python scripts/recovery/snapshot.py capture --docker-container rad-recovery-approved-target \
  --all-user-schemas --data-hashes --writes-frozen --output /secure/tmpfs/restore.json
python scripts/recovery/snapshot.py compare --source /secure/tmpfs/source-after.json \
  --target /secure/tmpfs/restore.json
```

Require exact ledger/version/name/statement hashes; schema/RLS/policies,
owners, function/search-path hashes, views/types/constraints/indexes, role
memberships and default ACLs; canonical explicit ACLs (including PUBLIC and
grant option) and effective database/schema/table/column/function/sequence/
type privileges for **all non-system roles**; row counts and ordered SHA-256
row digests, sequence state and large-object hashes. No client row values
leave the database in catalog snapshots. Large table digest scans/sorts can
be expensive; the DBA must budget time, memory and per-query timeout.
The comparator is strict and has no automatic allowlist. Source-only implicit
function rights may need target restoration; remove every target-only right
and grant **only** source-existing rights using a DBA-reviewed per-object
delta. Do not use `GRANT ALL`, ignore platform differences, or assume a
previous 672-check local pass attests every future target. A changed default
ACL/membership is a review finding even when current application rights match.

**AUTHORIZATION G:** decrypt Storage into protected staging, create/reconcile
matching target buckets and upload through the Storage API/S3, then download
target objects again and compare their byte manifests. Supabase
[requires API/S3 transfer for platform-to-self-hosted objects](https://supabase.com/docs/guides/self-hosting/copy-from-platform-s3);
direct file placement into its internal volumes is not a supported recipe.
For approved bucket `LOGO`, a target-only transfer example is:

```bash
age -d -i /offline/private-identity.txt -o /secure/tmpfs/storage.tar \
  /retrieved/storage/storage.tar.age
age -d -i /offline/private-identity.txt -o /secure/tmpfs/storage-first.json \
  /retrieved/storage/storage-manifest.json.age
tar -tf /secure/tmpfs/storage.tar
# DBA verifies paths and link entries, then extracts into a NEW protected tree.
mkdir -m 0700 /secure/tmpfs/storage
tar -xf /secure/tmpfs/storage.tar -C /secure/tmpfs/storage
python scripts/recovery/storage_manifest.py capture --root /secure/tmpfs/storage \
  --output /secure/tmpfs/decrypted-storage.json
python scripts/recovery/storage_manifest.py compare --source /secure/tmpfs/storage-first.json \
  --target /secure/tmpfs/decrypted-storage.json
python scripts/recovery/storage_manifest.py reconcile \
  --database-snapshot /secure/tmpfs/source-after.json \
  --storage-manifest /secure/tmpfs/storage-first.json
rclone --config /secure/config/rclone.conf copy /secure/tmpfs/storage/LOGO \
  rad_isolated_restore:LOGO --ignore-times --transfers 1 --checkers 2
rclone --config /secure/config/rclone.conf copy rad_isolated_restore:LOGO \
  /secure/tmpfs/restore-check/LOGO --transfers 1 --checkers 2
python scripts/recovery/storage_manifest.py capture --root /secure/tmpfs/restore-check \
  --output /secure/tmpfs/restored-storage.json
python scripts/recovery/storage_manifest.py compare --source /secure/tmpfs/storage-first.json \
  --target /secure/tmpfs/restored-storage.json
```

API uploads can change `storage.objects` IDs/timestamps/owner metadata. First
verify exact database restore parity while services are stopped; then record
each expected upload delta, preserve/reconcile owner access and bucket/path/
MIME/size semantics, and rerun RLS/ACL and cross-owner HTTP denial checks.
The strict database comparator will report altered metadata; any exception
requires a signed per-field/object DBA mapping, not a broad ignored table.
Matching file hashes with lost user ownership is a failed restore.

## Dry-run review checklist and stop conditions

- [ ] Owner and actual DBA sign scope, frozen window, credentials/data handling,
  output locations, target identity, artifact recipients/signing, retention,
  cost ceiling and restoration scope. Templates remain unapproved here.
- [ ] Verify 17.11 tools, schemas/TOC completeness, all role and Auth/key
  dependencies, permissions/TLS, free staging capacity and source write
  controls. Freeze approval includes any production worker/Auth controls.
- [ ] Run the synthetic rehearsal and review raw evidence; test signature,
  off-machine download and key recovery independently before production.
- [ ] Capture pre/post source digests and repeated Storage bytes; require
  stable inventory/digests. A partial/denied export or different source
  digest invalidates the backup. Preserve incomplete encrypted artifacts.
- [ ] Restore offline, require strict catalog/data/grant parity; reconcile
  explicitly approved platform/Storage metadata deltas and prove functional
  Auth/Storage owner access before releasing target services.
- [ ] Owner separately authorizes a production incident recovery/cutover,
  downtime, credential rotation, post-snapshot data-loss acceptance and all
  release gates. This package never authorizes a production cutover.

Independent logical backup has no PITR/WAL replay proof and cannot recover
writes after its snapshot. Sequence/Storage consistency depends on the
freeze; credentials and managed services can need recreation. Restore success
does not justify reversing security grants or deploying pending migrations.
Source failures, unknown key dependencies, unexplained ACLs, incomplete
Storage or unsafe outbound behavior are explicit STOP conditions.

Costs: no paid resources were created. Last read-only size estimate before
the interruption was **18,486,963 database bytes** plus **95,420 Storage
metadata bytes / one object**; this is not a measured logical-export size or
verified object download. Thirty full copies would be roughly **0.52 GiB**
at that baseline before growth/metadata/compression. Price depends on the
owner-selected off-machine storage rate, request/egress/minimum charges,
retention, signing/key custody and DBA/host time. Use
`retained encrypted GiB × approved $/GiB-month + transfer/request/host costs`;
obtain a quote and ceiling before any spend. Local/off-machine recovery does
not require a paid Supabase clone, but it does require approved data handling.

Owner decisions remain: newly discovered AI models are disabled until
administrator approval; leaked-password protection is enabled after
compatibility assessment. Live discovery alignment and the Auth setting
change still require separate authorized implementation. Visa editorial,
Stage 3 reconciliation and human-only Feed publication remain separate gates.

## Reproduce the executed local tests

```powershell
python -m unittest discover -s scripts\recovery -p test_recovery_tools.py -v
python scripts\recovery\rehearse_synthetic.py --age-dir '<verified age binary directory>' `
  --work-dir '<new local synthetic work directory>' --suffix '<new local suffix>'
```

The rehearsal creates two network-none clusters from the already cached
Supabase PostgreSQL 17.11 image, synthetic rows and a temporary synthetic age
identity. It checks naive versus hardened restores, ledger/catalog/grant/data
parity, mutation detection, byte-for-byte Storage recovery and age tamper
rejection. All artifacts/containers are retained; no automatic deletion is
performed. Do not reuse its synthetic identity for production.
