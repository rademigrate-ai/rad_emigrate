# Independent recovery package — engineering acceptance, 2026-10-13

**Engineering synthetic acceptance: PASS. DBA review: BLOCKED/pending an
actual reviewer. Production: NO-GO.** The execution plan is
[`scripts/recovery/README.md`](../../scripts/recovery/README.md). It names
each operation requiring owner/DBA authorization and its commands. No
production data/backup, private Storage copy, production-point restore,
credential/Auth change, production migration, paid resource or deployment
was executed. The previous backup API investigation was not repeated.

## Recovered checkpoint and source provenance

Branch `handoff/codex-stage1-stage2-20261010`; starting local and owner-confirmed remote checkpoint
`4f9993c363c50ab70a187c79d7b52de8402b2f9c`. At resumption, tracked and staged
diffs were empty. The interrupted task had created only
`scripts/recovery/snapshot.py`, `scripts/recovery/storage_manifest.py`,
their ignored bytecode cache, and local `.work/recovery-synthetic-source.json`
and `.work/recovery-synthetic-restore.json`. Those files were recovered and
extended; all unrelated untracked files/evidence were preserved.

`EVIDENCE_MANIFEST.json` pins the final tested tooling bytes and normalized
Git/LF bytes. The final 11 unit tests, accepted synthetic rehearsal and full
local catalog smoke test used that same tooling state. Only evidence/report
files were added afterward. No application or migration source changed.

The first push found three newer same-branch documentation commits
(`9555153`, `c2e4c69`, `471c434`). The unpublished recovery commit was replayed
above those commits without conflicts or force-pushing. Their security-audit
documents were preserved unchanged; the tested recovery code and normalized
fingerprints remained identical. No new application acceptance is inferred
from those incoming documentation changes. An unrelated concurrent edit to
`tools/stage3_pipeline_e2e/E2E_RESULTS.txt` appeared afterward and was left
untouched and unstaged.
Tests were executed on Windows with Python 3.14.7, Docker Desktop and cached
Supabase PostgreSQL image `17.11.0.002`. Official age v1.3.2 ZIP bytes matched
the GitHub release asset SHA-256; no private identity or executable is committed.

## PASS / FAIL / BLOCKED / NOT RUN matrix

| Check | Result | Executed evidence and limits |
|---|---|---|
| Unit regression tests | PASS | **11/11**, `unit_tests_raw.txt`: approval/TLS and read-only guards; missing freeze; incomplete snapshot rejection; overgrant/data and byte/hash mismatch; duplicate Storage keys; inventory/size mismatch; partial-bundle rejection. |
| Tool syntax and structured evidence | PASS | Python compilation, JSON parsing and tooling/structured-file whitespace checks. Raw transcripts retain psql's original spacing and are excluded from whitespace formatting checks. |
| Encrypted logical backup and decrypt | PASS, synthetic | Three age-encrypted artifacts: custom-format database dump, password-free role reference and catalog/data digest snapshot. Actual PostgreSQL clients/server **17.11**. |
| Target isolation | PASS, synthetic | Two named separate clusters with Docker `network=none`; no published ports. Source and target names are in `synthetic_summary.json`. |
| Naive restore security | **FAIL, deliberately reproduced** | Comparator detected **26 extra individual ACL rights**, including anon function execution and authenticated `admin_note` access. Successful detection is PASS for the test. The earlier **86 application ACL-entry differences** were from the full local rehearsal; the numbers are different fixtures/units. |
| Target confirmation guard | PASS | Unconfirmed target default mutation rejected with psql exit 3. |
| Grant-safe restore | PASS, synthetic | Default privileges neutralized before restore. Strict source/target catalog and **546 effective privilege entries** matched, with no ignored differences. |
| Ledger/data/sequence integrity | PASS, synthetic | Exact ledger and schema/constraints/RLS; **7 tables / 6 rows** with SHA-256 digests; sequence state matched. Deliberate row + sequence changes produced FAIL; restoring those synthetic values produced PASS again. No large objects existed in this fixture, so nonempty large-object recovery remains NOT RUN. |
| Storage backup/encryption/decrypt | PASS, synthetic | **2 objects / 17 total bytes**, including binary bytes and an empty file. Restored byte SHA-256 manifests matched. |
| Storage metadata-to-byte coverage | PASS, synthetic | Both object keys and sizes matched the source database inventory, with no missing/extra/mismatched objects. |
| Ciphertext tamper handling | PASS | Bit-flipped age payload rejected on decrypt; no SQL restore ran from damaged output. Bundle byte hashes and incomplete files tested. |
| Full Supabase catalog compatibility | PASS, catalog capture only | Separate existing disposable stack: 52 ledger rows, **14 non-system schemas, 172 functions, 3,462 canonical ACL records, 15 non-system roles**. `full_local_catalog_raw.txt`. This is a query smoke test, not another production-equivalent backup/restore acceptance. |
| Initial implementation attempts | FAIL, resolved | Wrong argument ordering for `pg_dump --version`, then `pg_dumpall -d` used a bare database name instead of connection string. Corrected, successful reruns recorded; both initial raw logs retained. |
| Production source permissions/export | NOT RUN / authorization boundary | No production connection used by backup tooling. Existing backup role/managed-internal permissions require DBA review. |
| Supabase private Storage API/S3 read or upload | NOT RUN / authorization boundary | Local staged-byte tests only. Real credentials, least-privilege capability, target bucket/owner metadata and HTTP isolation must be attested when authorized. |
| Off-machine retention, signing, key recovery | BLOCKED / owner selection | Encryption tested; destination, retention/cost ceiling and authentic manifest signing/custody not configured. Minisign and Sigsum workflows not executed. |
| Auth/Vault/service functionality after production-point restore | BLOCKED / owner-DBA dependency | Configuration/key custody template prepared; no managed signing/encryption key export or production credential recreation occurred. |
| DBA sign-off and real production recovery point | BLOCKED | No actual DBA review/signature or authorized production-data restore. |

Raw accepted command transcript: `synthetic_rehearsal_raw.txt`. The committed
`synthetic_source_snapshot.json` and `synthetic_restore_snapshot.json` can be
compared directly with `snapshot.py compare`; they contain synthetic catalog
and digest evidence only. No production row values or credentials are present.

## SECURITY_ACCEPTANCE

**PASS (executed locally):** read-only/TLS/approval controls, encrypted
streaming, ciphertext tamper rejection, protected-column overgrant detection,
strict restore privilege parity and Storage byte/inventory coverage.
**FAIL (deliberate negative test):** the naive target restore widens privileges.
**UNVERIFIED:** production recovery, real private Storage HTTP isolation,
nonempty large-object recovery, actual key/service restoration and independently
authenticated off-machine custody. **BLOCKED:** actual owner/DBA approval.
Existing role/ownership, AI and human-only Feed guards were not altered.

## Authorization-ready execution sequence

1. **Actual DBA review plus owner sign-off:** approve the exact tooling
   fingerprints; source read role and full RLS/large-object/catalog access;
   TLS/passfile and Storage credential scope; Auth/Vault/service dependencies;
   frozen maintenance window; encrypted staging, public recipients, key and
   signature custody; retention/cost ceiling. Fill approval references
   outside the repo. The templates themselves grant no authority.
2. **Authorize source export/read:** scope A–C in the README covers encrypted
   source catalog/data digests, a complete consistent logical dump and role
   reference, and separate Storage listing/download/byte verification. Freeze
   all approved writers, capture before/after source fingerprints and repeated
   Storage byte sets, and stop on any difference or denied/incomplete schema.
3. **Authorize retention:** scope D covers encrypted service configuration,
   signed master hash inventory, off-machine transfer and independent retrieval
   verification. Select the provider and billing ceiling; no paid setup is
   implied. See the cost formula and last measured size estimate in the plan.
4. **Authorize isolated production-point recovery:** scopes E–G cover
   production-data decryption on the private target, target-only defaults and
   restore, source-versus-target comparisons, Storage uploads/owner metadata
   reconciliation and functional Auth/Storage denial checks. Require zero
   unexplained grant/data differences and complete bytes/key dependencies.
5. **Keep incident recovery/release separate:** production restore/cutover,
   migrations, credentials/Auth changes and deployment need their own approval.
   Independent logical snapshots do not establish PITR or preserve writes
   after the selected snapshot. Visa editorial, Stage 3 and human-only Feed
   publication gates remain separate.

Owner decisions are preserved in the plan and service template: newly
discovered AI models remain disabled until administrator approval, and
leaked-password protection is enabled after compatibility assessment. Neither
production alignment/change is authorized or executed by this package.

## Exact changed files

Tooling under `scripts/recovery/`:
`README.md`, `approval.example.json`, `service_configuration.example.json`,
`encrypted_backup.py`, `snapshot.py`, `storage_manifest.py`, `verify_bundle.py`,
`neutralize_target_defaults.sql`, `synthetic_fixture.sql`,
`rehearse_synthetic.py`, `test_recovery_tools.py`.

Evidence under `artifacts/independent_recovery_20261013/`:
`RECOVERY_ACCEPTANCE.md`, `EVIDENCE_MANIFEST.json`, `unit_tests_raw.txt`,
`synthetic_rehearsal_raw.txt`, `synthetic_summary.json`,
`synthetic_source_snapshot.json`, `synthetic_restore_snapshot.json`,
`full_local_catalog_raw.txt`, `initial_version_probe_failure_raw.txt`,
`initial_roles_connection_failure_raw.txt`.

Local-only artifacts remain under `.work/independent-recovery-rehearsal-*`
and `.work/recovery-tools-age-1.3.2/`; the named synthetic containers are
retained. These include only synthetic keys/data and previous failed attempts.
No destructive cleanup occurred. Production remains **NO-GO**.
