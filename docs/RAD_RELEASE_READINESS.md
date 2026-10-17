# RAD Release Readiness — Delivery Cutover Gate (2026-10-18)

## Decision

**NO-GO for Production release, paid services, Store rollout and client signoff.** This is a deliberately evidence-gated stop, not a request to mark 47 gates complete. See [47-task ledger](RAD_47_TASK_MASTER_LEDGER.md), [Security/Migration](RAD_SECURITY_AND_MIGRATION_REPORT.md), [Feature Matrix](RAD_FEATURE_ACCEPTANCE_MATRIX.md) and [E2E QA](RAD_E2E_QA_REPORT.md).

| Gate | Evidence | Result |
|---|---|---|
| GitHub main | SHA `2739567cc0c228c0b190da177266de9df811be5a`, [CI #39072163776](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39072163776) | **PASS 7/7** engineering CI |
| Flutter UI patch (not integrated) | [Draft PR #68](https://github.com/rademigrate-ai/rad_emigrate/pull/68), own HEAD `f616078...`; code merges cleanly in scratch; Flutter analyzer pass, **515/515** full Flutter tests | **IMPLEMENTED candidate**, separate source; full current-HEAD E2E still OPEN |
| Production web version | Render live deploy `449cd3b6cb0a0b53e852015ad4a3648bd817ad65`, auto-deploy `off` | **BLOCKED**: stale deployed SHA vs main; no release permission granted |
| Production migrations | 47 recorded vs 52 repo, 16 version aliases, 4 live-only / 9 repo-only; 12 SQL mismatches + 2 multi-chunk histories | **NO-GO**; cannot replay/repair blindly |
| Live security | 57/57 public tables RLS enabled, but human Feed mutation trigger absent in Production; stage1 security still repo only | **NO-GO** for current security target |
| Backup and restore | Verified operator backup inventory, restore test and PITR window not provided in current evidence | **BLOCKED** |
| Authentication | PR #58 test code exists, active recovery allowlist mismatch mitigated only in new repo code, current Render outdated | **BLOCKED** live mailbox/password E2E |
| AI provider | 49 recorded user AI requests; 10 successes, 39 failures, 27 no_eligible_model; two credential-rejected providers, third degraded | **BLOCKED** provider operational acceptance |
| Visa and Feed regulatory | 22 destinations, 10 programs, 18 structured steps, 16 drafts, 0 published Feed; editorial source validity not accepted | **BLOCKED** legal/source review and publish UAT |
| Payment | No approved merchant, price list, production PSP configuration or verified sandbox webhook acceptance in reviewed scope | **BLOCKED**; no charges permitted |
| Native mobile | GitHub Android build passes; macOS/Xcode, signing credentials, physical devices and App Store/Play sign-off not validated | **BLOCKED** |
| Final client UAT | Only 3 of 47 individual acceptance gates VERIFIED_PASS in master issue | **BLOCKED** |

## Non-negotiable production release prerequisites

1. Obtain explicit fresh owner authorization specific to Release SHA and each target (Supabase DB, Edge Function, Render, signing/payment as applicable). The standing scope **does not authorize** any Production changes or merging shared branches.
2. Capture and validate current Production schema and migration-history SQL objects, policy and DML effects. Every alias and unmatched migration must have a verified semantic classification, including data changes, grants, cron and Storage.
3. Provide actual backup/PITR inventory and **successful restore rehearsal**, with declared RPO/RTO, DBA approval, deployment window, roll-forward/rollback command/owner.
4. Use an isolated Production-equivalent clone for ordered forward-only migration replay; run malicious two-user/anon/admin/service tests, concurrency, SSRF, Storage, Auth and Feed approval contract checks. CI's disposable clean database is **not equivalent** to the existing 47-version live lineage.
5. Order DB RPC changes / Edge Function / Flutter web client compatibly; document old/new RPC bridging and failure recovery. The currently deployed count-only quota RPC is incompatible with the new atomic quota reservation contract returning `request_id`.
6. Configure independently approved non-production AI credentials (no secrets in logs), and verify real user/admin request plus approved grounded source answer quality and five-question quota.
7. Complete official immigration content provenance and human review for all intended Visa and publishing entries. Never auto-publish Feed.
8. Run live sign-in and recovery with designated synthetic account, two-account cases/Documents Storage isolation, Admin review/publish, notifications sandbox, real-browser/mobile/iOS/accessibility tests.
9. Release a pinned immutable SHA with release manifest, monitoring and rollback exercises; gather written client UAT approval.

## Pre-release execution sequence (only AFTER separate owner/DBA authorization)

- **Freeze** approved Release A subset and Release SHA; record all affected workstreams and acceptable maintenance/failover window.
- **Backup** and verify successful restore of representative metadata + data into isolated project, then re-run redacted negative access tests.
- **Reconcile** current Production vs pinned semantic migration package, produce DBA-signed additive operation list; never claim equivalence based only on filenames.
- **Stage** database/Edge/client with a backward-compatible cutover tested end to end. Exercise old client + new DB; new client + old DB, observe safe failure.
- **Deploy** solely with explicit authorized owner actions and fresh preflight; do not treat this document as authorization.
- **Verify** build SHA via live endpoint and real user/admin workflows, monitor errors/quota/health, with rollback trigger thresholds and log redaction.
- **Handover** source/data approvals, signed app identities, incident runbook, verified UAT and support contacts.

## Outstanding external owners

- **Owner/DBA**: backups/PITR, Production schema migration repair decision, release authorization, downtime and rollback.
- **Operations**: AI provider key validation, SMTP/SMS/push provider approved test tenant, Render deployment review, secure admin bootstrap.
- **Legal/editorial**: RAD/official immigration claims, source freshness and bilingual content signoff, terms/privacy/licensing.
- **Commercial**: payment provider selection, merchant, pricing, taxes, sandbox webhook verification, refund/cancellation policy.
- **Mobile/client**: Android/iOS signing and store identities, physical-device UAT, client final acceptance.

## Explicit final gate

Do NOT mark production-dependent tasks VERIFIED_PASS simply because a PR merged or CI passed. Current confirmed ledger: **3/47 VERIFIED_PASS**, 44 gates still in IMPLEMENTED/IN_PROGRESS/BLOCKED/NOT_STARTED. `main` has not been deployed; the database migration ledger is not reconciled; client signoff is absent. Keep Master Task #57 open.
