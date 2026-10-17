# RAD Emigrate — Migration reconciliation matrix (current index)

> **SUPERSEDED / DO NOT EXECUTE historical rows from the earlier matrix.**
>
> The earlier 51-entry inventory misrepresented repository migration version identifiers as if they were exactly recorded in the live Supabase ledger, and described some unverified semantic aliases as proven. It also treated the repository-only `stage5_visa_editorial_summaries` as already applied. These were not supported by direct Production verification.

The **authoritative current read-only evidence**, containing all **47** observed Production migration entries and their closest matching repository paths, is:

**[LIVE_MIGRATION_RECONCILIATION_20261017.md](LIVE_MIGRATION_RECONCILIATION_20261017.md)**

The corrected release and cutover runbook is:

**[SAFE_DEPLOYMENT_RUNBOOK.md](SAFE_DEPLOYMENT_RUNBOOK.md)**

As of 2026-10-17, live Production contains **47** migration versions while `main` has **46** migration files; **27** version/name exact matches, **16** same-name/different-version entries, **4** live-only and **3** repo-only names. PR #48 proposes 5 **new** unapplied migrations.

**NO-GO:** Do not replay historical repository migration files, call `supabase db push`, repair the ledger, run DDL, or deploy PR #56 Edge until semantic reconciliation, verified recovery backups, and a safe synchronized cutover pass the release gate. No Production changes were made as part of this document correction.

Earlier matrix contents are retained in Git history for forensics, not as an executable source of truth.
