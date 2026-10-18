# Local backend test commands

Run from the current Codex checkout with Docker running, native Supabase CLI 2.119.0 and PostgreSQL 17 psql available. Pass the actual executable paths using `--supabase` and `--psql` if they are not on PATH. No command links to a hosted project.

```powershell
python scripts/verify_local_stack.py start --supabase <supabase.exe> --psql <psql.exe>
python scripts/verify_local_stack.py verify --supabase <supabase.exe> --psql <psql.exe> --report <outside-checkout-report.json>
python scripts/verify_local47_ops_concurrency.py --psql <psql.exe> --report <outside-checkout-concurrency.json>
python scripts/verify_local_stack.py start --lineage historical --supabase <supabase.exe> --psql <psql.exe>
python scripts/verify_local_stack.py verify --lineage historical --supabase <supabase.exe> --psql <psql.exe> --report <outside-checkout-reconstruction.json>
python scripts/compare_local47_catalogs.py --psql <psql.exe> --report <outside-checkout-catalogs.json>
python -m unittest discover -s scripts/tests -v
npx --yes deno@2.5.4 test --allow-env supabase/functions/tests
```

Each runtime directory has a source/project/port identity marker. Existing unmarked or differently owned directories are refused. Canonical ports are 55320–55329; reconstruction ports are 57320–57329. The runner copies normalized SQL into an external disposable runtime and never moves the checkout's migration directory. `stop` affects only the selected marked project and uses `--no-backup` because its contents are synthetic fixtures.

Use `apply --proposal supabase/migrations/<proposal>.sql` only while iterating on a new local proposal. This deliberately does not claim a migration-ledger deployment. After proposals stabilize, replay a fresh canonical stack so every migration is applied through the CLI in order. Historical verification first checks all 25 captured baseline versions and catalog groups, proves no pending historical SQL through a loopback-only dry run, then applies the ordered forward proposals. It is not proof that the separate recorded 47-entry Production history is reconciled.

The concurrency script is intentionally restricted to the canonical local port. It creates random synthetic users, restores the sandbox-enabled flag, and removes only its own fixtures. It refuses to consume an outbox with other pending work. It tests leases, receipt acknowledgement, optimistic CRM revisions and payment ordering through actual concurrent PostgreSQL sessions.

Use external report paths for final candidate validation so generated evidence does not dirty a tested HEAD. Intermediate reports under `docs/releases/local47_*.json` explicitly identify their dirty working snapshot; do not relabel them as final-HEAD acceptance.

## Optional client-facing additions

- `transition_admin_consultation(p_consultation_id, p_status, p_expected_revision, p_admin_note)` returns status/revision; stale revisions fail with SQLSTATE 40001. Existing update RPC stays compatible.
- `assign_admin_consultation(p_consultation_id, p_assignee_id, p_expected_revision)` permits admin/super-admin assignees or null; returns revision/assigned. Normal users cannot call either operation successfully.
- Owner-safe `consultation_request_events` columns are id, consultation_id, event_type, from_status, to_status, revision and created_at. Actor IDs and internal note text are not exposed by these grants.
- `queue_notification_delivery(p_notification_id, p_channel)` accepts email/SMS/push only after opt-in and returns a sandbox-labelled delivery ID or a preference-disabled reason. `time_zone` is an explicit IANA zone with UTC default; callers should save the user's chosen zone before using quiet hours.
- Notification claim/finish are service-only. A false finish result means stale or revoked work; workers must not count it as delivered.
- Payment sandbox events use a separate synthetic schema and protocol. `x-rad-sandbox-signature` is `t=<Unix-seconds>,v1=<HMAC-SHA256-hex>` over `<timestamp>.<raw UTF-8 body>`, with a five-minute transport window. Unknown payload fields are rejected. Deployment is disabled by default and hosted Supabase targets are refused. Real merchant adapters must be separately selected, approved and tested.
