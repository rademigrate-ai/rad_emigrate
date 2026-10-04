# Supabase reconciliation artifacts

These files are forensic/review artifacts. They are deliberately outside `supabase/migrations` so Supabase CLI cannot mistake them for pending production migrations.

## Hard safety rules

- Never execute historical RAD migrations against production to fix history.
- Never run `supabase db reset --linked` on production.
- Never use `migration repair` until isolated reconstruction equivalence and zero-pending dry-run are proven.
- Never include Vault secret values in snapshots, SQL, logs, fixtures, or commits.
- Preserve the live Storage upload owner/MIME/size predicate and private bucket.

## Required proof before canonical migration rewrite

1. Capture production with `production_fingerprint.sql` (metadata only).
2. Generate an executable baseline from authoritative live schema without data/secrets.
3. Reconstruct on disposable local/branch Postgres/Supabase.
4. Normalize and diff production vs reconstruction for tables, columns, constraints, indexes, RLS, policies, grants, functions/security/search_path, triggers, Storage SQL, cron and required extensions.
5. Run security regression checks.
6. Simulate canonical migration history and prove zero historical migrations pending.
7. Only then rename/replace migration lineage and prepare a history-only production reconciliation plan.

Until all seven pass, reconciliation is NO-GO and AI-01 must not be added.

