# RAD production-equivalent Supabase rehearsal — 2026-10-13

Engineering attestation: **PASS for the executed local rehearsal only**.
Release-owner and DBA sign-off: **not granted**. Production: **NO-GO**.
Source was `dc0a86892c18c1cc2afbeb29a4caf026d4f45e6b` on
`handoff/codex-stage1-stage2-20261010`; application and migration SQL were
unchanged during this rehearsal. All database writes were confined to named
disposable local PostgreSQL 17.11 environments. No production data, keys,
migrations, grants, Auth settings or content were written.

## Baseline and provenance

Read-only production `supabase_migrations.schema_migrations` supplied **47**
version/name/statement-array records through `20261007212140`. Their SQL was
replayed in a new local Supabase 17.11 stack, not in the existing 50-migration
stack. Two historical rows (`20261003235000`, `20261004190000`) store multiple
unterminated array elements; the first replay stopped at a syntax error, and
the successful replay joined those elements with SQL semicolons. The
[historical ledger manifest](RAD_PROD_EQUIV_HISTORICAL_LEDGER_20261013.json)
records all 47 versions, statement counts, bytes and local replay-file hashes.
The fresh local ledger matched all 47 live version/name pairs exactly.

Before pending security changes, **771/771** application columns/functions/
policies/triggers/RLS entries and **109/109** application ACL entries matched
the read-only live catalog. Constraints/indexes/defaults/extensions/buckets
were **760 live versus 776 local** with 18 explained platform/bucket entries:
production's public `LOGO` bucket and local Storage Iceberg internals. This is
catalog equivalence for inspected objects, **not** a production data or Auth
configuration clone. No production client rows were copied. Synthetic local
fixtures consisted of one valid AI provider/model, the migration seeds, and
disposable Auth identities created only for tests.

Read-only live compatibility counts: **0** AI model rows violate the three
pending CHECK predicates; **0** document processor endpoints fail the current
safe-URL predicate. Live counts at inspection: 682 AI models, one document
config, zero consultation requests, zero Feed items and 15 content drafts.
The one document config has no endpoint URL; three AI providers have no
IPv4-mapped host pattern in their configured base URLs (aggregate check only).
The synthetic AI model survived all five migrations. These aggregate checks
do not prove compatibility of every production row or future data changes.

## Five-file chronological rehearsal

The local Supabase CLI applied these files in ascending version order; the
original 47 ledger pairs remained intact and five new rows were appended,
ending at **52**. Hashes below are the **executed Windows file bytes**.

| Order | Migration version | Executed SHA-256 | Result |
|---:|---|---|---|
| 1 | `20261010010000` P0 security | `76a28a9aa6294f6a8ca8f108394b801a2ee85f85827104246324f69787610bd5` | PASS |
| 2 | `20261010055013` atomic AI quota | `51ab2b39fb63655fea7e67e1a7aef69bb1ba15297877bc39168b90b2b1c8b646` | PASS |
| 3 | `20261010070000` SSRF IPv4-mapped IPv6 | `b94878391d4fddb9887e74d9a2a1dc809360de46f989a3d599a5471cc7c42fc5` | PASS |
| 4 | `20261012110945` consultation/Storage | `9de2fdb764aae7068c9355b07cd3593823bd66b5da73448687693fe5cc535119` | PASS |
| 5 | `20261012230000` AI CHECK alignment | `303b6ba4382453ab682297f57336922050344ef5e800268cdb4cb221711d149` | PASS |

For file 5, the Git/LF-normalized hash is
`d4563930461176e6481df29cf587c9dca0eb7b4987395c05af2f613758452fbc`;
CRLF checkout bytes explain the different executed hash. The other four
worktree and LF hashes coincide. See
[`prod_equiv_security_migration_apply.log`](prod_equiv_security_migration_apply.log)
and [`prod_equiv_ledger.log`](prod_equiv_ledger.log).

The [machine-readable schema diff](RAD_PROD_EQUIV_SCHEMA_DIFF_20261013.json)
has **5** app-owned constraint/index additions, **13** semantic keys (six
changed and four new functions, one Storage policy, two Feed triggers), and
**18** ACL keys. Managed Storage exceptions remained unchanged. The three
AI CHECKs and the document endpoint CHECK are present and validated. No
historical alias row was rewritten or spuriously marked as applied. The
16 timestamp aliases and four live-only migration names are preserved in
their actual live-ledger positions; statement-by-statement equivalence of
the differently timestamped repository aliases remains a DBA review item.

## Behavioral acceptance

- **PASS:** 13 ordinary-user SECURITY DEFINER denial probes.
- **PASS:** both AI access/quota read RPCs rejected cross-user calls (HTTP 403);
  a caller-supplied `super_admin` role still yielded the actual `user` limit
  of 50. With 48 synthetic requests preseeded, eight simultaneous service
  reservations admitted **2**, denied **6**, produced two distinct IDs and
  left exactly **50** rows. All were subsequently removed.
- **PASS:** Consultation anonymous, invalid input, direct INSERT and
  cross-owner related-application calls were rejected; three submissions
  succeeded, the fourth hit the hourly limit, owner read isolation and
  `admin_note` denial held, and Feed count remained zero. Fixtures cleaned.
- **PASS:** An Admin could not publish `draft` or `review`; an `approved`
  synthetic draft produced one Feed row inside a rolled-back transaction.
  Persisted Feed count remained zero. Human-only guard triggers were present.
- **PASS:** Storage HTTP owner upload and short-lived signed URL returned 200;
  cross-owner signed view, upsert, foreign-path insert and unsupported MIME
  were rejected. Fixtures cleaned.
- **BLOCKED owner decision:** the live-history `ingest_ai_model_catalogue`
  auto-enabled a newly discovered chat model in a rolled-back local test;
  the existing repository 50-chain left the same model disabled. This
  functional divergence is real and was not silently changed.

Raw outputs: [`prod_equiv_definer_guards.log`](prod_equiv_definer_guards.log),
[`prod_equiv_rpc_acceptance.log`](prod_equiv_rpc_acceptance.log), and
[`prod_equiv_storage_http.log`](prod_equiv_storage_http.log).

## Backup and restore — local proof, not production PITR

A custom-format dump of the 52-row disposable source was **847,872 bytes**,
SHA-256 `6bb29bf7a638189f99b8ae741e6dfc1c73bcfb395f50d8e10125c6628e4a85b1`.
The target was a separate PostgreSQL 17.11 container with `--network none`;
its copied archive hash matched. A second database in the same cluster could
not install `pg_cron`, so that attempt was retained as a failure case.

A plain full restore in a fresh cluster also **failed security parity**:
Supabase creation-time default privileges added 86 application ACL grants
not present in the source; the exact source/target ACL comparison is in
[`RAD_PROD_EQUIV_NAIVE_RESTORE_ACL_DIFF_20261013.json`](RAD_PROD_EQUIV_NAIVE_RESTORE_ACL_DIFF_20261013.json).
This makes naïve `pg_restore` an unsafe recovery recipe. On a new,
network-isolated target, the tested sequence was:

1. Initialize the same PostgreSQL 17.11 image and create its two missing
   local Supabase roles (`supabase_functions_admin`,
   `supabase_realtime_admin`).
2. Before restore, revoke `supabase_admin`'s default public-schema table and
   function grants to `anon`, `authenticated`, `service_role` and `postgres`,
   and its global default function EXECUTE grant to `PUBLIC`.
3. Run `pg_restore --clean --if-exists -e` once as `supabase_admin` into its
   `postgres` database. It exited 0. Do not retry `--clean` blindly against
   a partially restored database: an attempted retry hit an inherited
   Realtime partition-constraint dependency.
4. Compare source/target effective privileges and grant only the missing
   source-existing function rights on the disposable target (five private
   and 23 Auth/Storage functions in this run). No extra target-only right
   remained. This parity step is required because archive restore alone
   does not reproduce implicit/default EXECUTE rights exactly.

Final verification **PASS**: 52 identical ledger entries, **781** catalog
entries, **778** semantic entries, **427/427** validated constraints,
**672/672** effective function/table privilege checks, and exact row counts
and per-table data hashes for **95/95** tables (**428** rows total). The
source and target also matched schema usage rights. Raw initial failure logs
are retained; the successful
[`prod_equiv_restore_verification.log`](prod_equiv_restore_verification.log)
was rerun after removing nine identified audit rows generated by a later
synthetic test rerun (eight Auth audit rows and one Admin role-change row);
no client or production rows were affected. It is reproducible using
`scripts/verify_prod_equiv_restore.py`. No production
backup, off-machine recovery point or PITR restore was accessed or attested.

## Sign-off and remaining gates

The [evidence matrix](RAD_PROD_EQUIV_EVIDENCE_MATRIX_20261013.json) is signed
off as **Codex engineering local verification** only. A production GO still
requires: DBA attestation and test of a production backup/PITR recovery point;
DBA approval of the historical alias/data-effects map and a restore runbook
that checks grants; a current production data preflight immediately before
change; AI/product owner decision on discovery auto-enable semantics; Auth
owner action on leaked-password protection; explicit owner authorization
for the ordered production security migrations and post-apply checks; and
separate Visa editorial, Stage 3 baseline, and human-only Feed release gates.
No hosted staging or production behavior has been claimed from this local
rehearsal. **Production remains NO-GO.**
