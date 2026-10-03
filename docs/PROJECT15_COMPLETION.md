# Project 15 — Observability and Retention

Project 15 adds a privacy-safe operational plane for component health, redacted operational events, dead-letter job tracking, and incident records.

## Data layer

- `system_components` — catalog of critical and non-critical services (database, auth, storage, research, AI, document intelligence, notifications).
- `component_health_checks` — timestamped health samples with optional latency and safe status codes.
- `operational_events` — severity-tagged events with correlation IDs and automatically redacted metadata (secrets, emails, prompts, document content never stored in clear form).
- `dead_letter_jobs` — bounded failure records for research, document processing, AI requests, and notifications.
- `incidents` — admin-managed incident lifecycle with public and internal-safe notes.

All tables have RLS enabled. Authenticated non-admins cannot read operational data. Only `service_role` may write health and events. Admin/Super Admin may manage incidents.

## Retention

A scheduled job (`rad-observability-retention`) purges:

- health checks older than 90 days
- non-critical operational events older than 30 days
- all operational events older than 365 days
- expired research and document-processing worker leases

No personal document contents, AI prompts, or provider secrets are retained in these tables.

## Production verification

- Branch SHA includes migration `20261003223000_project15_observability.sql`.
- Live migration applied to project `inshddthftkhcdosoqcn`.
- Seeded seven system components.
- No client exposure of credentials or PII through operational surfaces.
