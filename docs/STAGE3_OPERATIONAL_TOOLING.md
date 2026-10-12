# Stage 3 operational tooling

These workflows are local-first and read-only with respect to Production. They
do not approve claims, publish Feed items, execute ingestion SQL, or run
migrations.

## Editorial review exchange

Create the P0 exchange:

```powershell
python tools/stage3_content_migration/review_workflow.py export `
  --out artifacts/stage3_operational_readiness_20261012/reviewer_exchange
```

The export contains source evidence, official URLs, discrepancy descriptions,
duplicate-source groups, an explicit decision object, and a hash binding each
decision to its source record. The decision schema is
`tools/stage3_content_migration/schemas/review_decision.schema.json`.

Reviewers may set `status` to `unreviewed`, `in_review`, `needs_research`,
`approved`, `rejected`, or `unresolved`. Any status after `unreviewed` requires
reviewer ID/name and a timezone-aware timestamp. Final decisions require a
rationale. Approval additionally requires at least one exported official URL
in `official_evidence_checked`.

Import returned decisions:

```powershell
python tools/stage3_content_migration/review_workflow.py import-decisions `
  --exchange artifacts/stage3_operational_readiness_20261012/reviewer_exchange `
  --input C:\path\to\reviewer-decisions.jsonl
```

Import is all-or-nothing. It creates/updates local `CURRENT_DECISIONS.jsonl`,
appends immutable events to `REVIEW_AUDIT.jsonl`, and routes rejected,
unresolved, and needs-research decisions to
`REJECTED_OR_UNRESOLVED.jsonl`. Re-importing an unchanged decision is
idempotent. Every output remains explicitly non-publishable.

## Visa evidence validation

```powershell
python tools/stage3_content_migration/validate_visa_drafts.py `
  --out artifacts/stage3_operational_readiness_20261012/visa_validation
```

The validator covers all 165 drafts and emits a per-program correction queue.
It checks official evidence, mapping, descriptions, requirements, process
steps, cost/time language, guarantees, conflicts, provenance, and review
status. It never supplies a missing immigration fact.

## Production preflight

First capture `PRODUCTION_LIVE_CHECK.json` using authorized **SELECT-only** SQL.
The snapshot must use schema `rad-production-live-check-v1` and include current
table counts, the batch-marker count, required-table RLS state, required RPC
grants/security settings, publication-gate status, and review-trigger status.

Then run:

```powershell
python tools/stage3_content_migration/operator_preflight.py `
  --live-check artifacts/stage3_operational_readiness_20261012/PRODUCTION_LIVE_CHECK.json `
  --expected-head <release-commit-sha> `
  --external-backup-attestation C:\secure\rad-backup-attestation.json `
  --out artifacts/stage3_operational_readiness_20261012/PREFLIGHT_RESULT.json
```

The command returns 0 only for `GO`, and 3 for `NO-GO`. Missing evidence is a
failure. It verifies Git branch/HEAD/remote/cleanliness, package and SQL hashes,
canonical dataset consistency, baseline drift, batch collision, live RLS/RPC/
trigger gates, the local backup checksum, and an independent backup
attestation. It only reads SQL files; it never executes them.

The external backup attestation must contain:

```json
{
  "schema_version": "rad-external-backup-attestation-v1",
  "archive_sha256": "<64 lowercase hex characters>",
  "verified_at": "<ISO-8601 timestamp>",
  "storage_location": "<independent/off-machine location>",
  "verified_by": "<operator identity>"
}
```

Do not create this attestation until the independent copy has actually been
verified.
