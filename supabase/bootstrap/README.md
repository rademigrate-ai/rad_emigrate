# Clean Supabase bootstrap

This bootstrap reconstructs the current RAD public schema in a **new, empty Supabase project**. It is deliberately separate from the live production migration ledger.

## Safety

- Never run `clean_schema.sql` against RAD or any database with existing application tables. A guard aborts if any RAD table exists.
- Do not run `supabase db push` against the RAD project using this repository's migration directory. The checked-in historical filenames do not match RAD's timestamped migration ledger.
- Do not repair or rewrite RAD's deployed history to make the version counts match.
- The file assumes a Supabase project has already created the `auth` and `storage` schemas and roles.

## Rebuild and verify

From a clean Supabase CLI development stack, run:

```bash
bash scripts/verify_clean_schema.sh
```

The script applies `clean_schema.sql`, then the checked-in forward SQL in lexical order, and verifies tables, RLS, policies, the signup trigger, and the private documents bucket. The normal CI path starts the local stack itself.

For a new hosted Supabase project, use its SQL editor or a trusted Postgres client to apply `clean_schema.sql` once, then apply each `supabase/migrations/*.sql` file in lexical order. Configure the project URL/keys separately. This bootstrap is for clean reconstruction; it is not a replacement for reconciliation of RAD's existing production history.

The script temporarily hides the tracked migration directory while starting the local stack because `supabase start` automatically applies migrations. It restores the directory before running the guarded bootstrap and replay.
