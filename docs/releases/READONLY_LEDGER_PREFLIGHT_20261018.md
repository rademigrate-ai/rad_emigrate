# RAD live migration history — fail-closed read-only preflight

Parent: [ONE MASTER TASK #57](https://github.com/rademigrate-ai/rad_emigrate/issues/57), E1-02. Data was retrieved READ ONLY from RAD Supabase project `inshddthftkhcdosoqcn` on 2026-10-18.

## Observations

The attached JSON file `supabase/reconciliation/rad_live_migrations_observed_20261018.json` contains only Supabase migration history version/name metadata. No secrets, user records, Auth identities or SQL contents were exported.

As captured:
- 47 Production history entries.
- 47 tracked migration files on main at `b77c29192e149324f1be5638e11ef732ab9d99ae` (this includes a newer unapplied AI entitlement hardening migration).
- 27 exact version and name matches.
- 16 same-name/different-version aliases.
- 4 names present only in Production.
- 4 names present only in the current Repository.

**Matching total counts is not migration equivalence.** Even exact version/name matches do not prove original SQL text equals a repository file.

## Read-only command

```bash
python3 scripts/audit_migration_ledger_readonly.py \
  --live supabase/reconciliation/rad_live_migrations_observed_20261018.json \
  --repo-root . \
  --baseline supabase/reconciliation/rad_live_migrations_observed_20261018.json
```

Expected result is `status: NO_GO` with exit code **2**, never a forged green pass. If applying it to a more recent, separately collected read-only migration export, substitute the `--live` file; the `--baseline` input rejects unexpected live-ledger changes. The utility never opens a database connection, never executes SQL, never repairs migration history, and never writes output files. It simply compares identifiers in a supplied JSON export with tracked SQL filenames.

## CI

```bash
python3 -m unittest discover -s scripts/tests \
  -p test_audit_migration_ledger_readonly.py -v
```

The GitHub `migration-reconstruction` job runs these tests before its disposable clean-schema tests, ensuring the drift alarm remains non-mutating and that future additive migration files do not silently reinterpret historical aliases.

## Release restrictions

- Do NOT use `supabase migration repair`, `supabase db push`, or `psql -f` to make this report appear green.
- To advance E1-02, compare the actual Production catalog effects and historic originals against the repository SQL, including grants/RLS, Storage, SECURITY DEFINER, cron, Vault references and seed data.
- Validate an authorized isolated clone and an owner-approved backup/PITR rollback plan before any real migration.
- This fixture is a historical observation; it is not a substitute for a fresh live read immediately before an approved release.

No Production mutation, Auth/Vault edit, Edge deployment, branch merge or Feed publication was carried out by this preflight.
