# Deployment boundary / proposed runbook

This is **not execution authorization**. Before any future deployment: (1) name the release owner and exact source commit; (2) reconcile live schema and migration history; (3) attest an off-machine restorable backup; (4) rehearse migrations and rollback in staging; (5) approve maintenance window; (6) apply only reviewed migrations in order; (7) read-only verify grants, RLS, Feed triggers, consultation rate limits and Storage policy; (8) run authorized application smoke tests; (9) record go/no-go. No step was performed in production here.
