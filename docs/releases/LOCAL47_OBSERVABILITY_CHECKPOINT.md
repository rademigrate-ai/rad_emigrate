# Local telemetry and incident rehearsal

2026-10-18. Proposal `20261018154834_local47_observability_privacy_and_triage.sql` was created by Supabase CLI and applied only to the owned disposable local stack. **3/47 VERIFIED_PASS; release NO-GO.**

## Confirmed privacy gap and change

A read-only probe of the previous runtime redactor retained `SYNTHETIC_NESTED_CANARY` under `diagnostic.nested_password`: it filtered only top-level key names. The replacement accepts bounded, explicitly named integer counters, booleans and enumerated status/channel/operation/error codes. Unknown keys are omitted, including names that themselves contain personal data. Nested objects/arrays, malformed types, excessive counters and oversized payloads cannot pass as telemetry. Already sanitized metrics remain unchanged on reprocessing. A redacted-field count records suppression without retaining the payload.

All operational-event writes now sanitize labels and metadata, including label-only updates. Unknown event labels/components become fixed `event.unspecified` / `unknown`; malformed user hashes become null. Component-health safe codes use a finite vocabulary and recognized HTTP error patterns; arbitrary provider errors are not stored as codes. This policy covers these machine telemetry fields, not every application log or deliberately entered human incident note. Existing historical telemetry is not silently rewritten; authorized deployment review must inventory and scrub any old unsafe data before claiming production privacy acceptance. Hashes are pseudonyms, not proof of anonymity or consent.

## Optional incident workflow

The existing service-only `record_component_health` signature remains unchanged. It validates sample bounds and known enabled components. A private alert policy is **disabled by default**, with a rehearsal template of two consecutive offline/degraded samples. Local tests enable it temporarily and restore it. The owner must approve operational thresholds, sampling cadence and response ownership before enabling it anywhere else.

When enabled, component-row locking deduplicates concurrent alerts. Healthy observations move an incident to `monitoring`; they do not resolve it. Unknown observations break consecutive-failure samples without claiming recovery. Relapse reuses an unresolved incident. Human admin resolution receives server-attributed identity/time; client-supplied opener/resolver timestamps cannot impersonate another person. Incident identity/component/start attribution remain stable. Append-only `incident_events` records actor and status history, visible only to admins. Exact internal Auth reference cleanup is supported without granting client history/raw-identity mutation.

No scheduler, external alert transport, production monitor or SLO is enabled by this proposal. The rehearsal proves local state transitions and privacy constraints only.

## Executed checks

- `supabase/tests/local47_observability.sql`: rollback-only synthetic redaction, malformed/oversized payload, unsafe labels, disabled defaults, threshold/dedup/recovery, ordinary-user denial, admin attribution, immutable audit history and Auth reference-cleanup assertions **PASS**.
- [Parallel-session report](local47_observability_concurrency.json): **32 failure samples → one incident and one opening event**; **20 healthy samples → one recovery event**; unknown-sample reset and relapse reuse **PASS**. Original policy restored, all allocated component/incident/event/health rows removed, zero external alerts.
- [Full local database suite](local47_observability_verify.json): core fingerprint, all security/Knowledge/AI/CRM/payment/OCR/observability SQL checks and real two-user Auth/Storage/human Feed checks **PASS** on the working proposal snapshot.
- [Runtime ACL inventory](local47_observability_definers.json): **63 active definers**, **zero PUBLIC EXECUTE**, no anon/authenticated public-schema CREATE. The deliberate private role helper remains callable for RLS; this is not a blanket audit of every business rule.
- Python regression suite **27 PASS**; both shell entrypoints syntax-checked. All three database runners now include the observability SQL fixture.

These reports explicitly mark dirty working-source provenance. There are now **58 proposed migration files**. Clean combined replay and final integrated-HEAD validation remain required; clean `cceebae` evidence proves the earlier 57-file checkpoint only. No production schema/data, Auth, Vault, Storage, Edge deployment, Feed publication, real provider or remote Git state was changed.

Reproduce `python scripts/verify_local47_observability_concurrency.py --psql <psql.exe> --report <report.json>` after starting the owned disposable stack with this proposal. SQL behavior consulted: [PostgreSQL 17 JSON](https://www.postgresql.org/docs/17/functions-json.html), [trigger behavior](https://www.postgresql.org/docs/17/trigger-definition.html), and [Supabase function privileges](https://supabase.com/docs/guides/database/functions).
