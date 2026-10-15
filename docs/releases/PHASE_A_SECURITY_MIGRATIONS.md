# Phase A — five security migrations, review only

Base main: `28154f1667ab4298cfa93c396e32b9fcb9662f2d`.
Verified remote source: `handoff/codex-stage1-stage2-20261010` at
`1809fb733f3924bf5295a4c7e2055ff3ae80030c`.
The similarly named **local** handoff worktree is ahead at `85908ca`; it is not
the transfer source. Only the explicit files below are selected, never a branch merge.

## Immutable migration inventory and order

Hashes are SHA-256 of **Git/LF blob bytes**, not Windows CRLF checkout bytes.
The fifth file's historical CRLF hash was `303b6ba4382453ab682297f57336922050344ef5e800268cd8b4cb221711d149`;
that is not a content discrepancy. The pinned source blobs are unchanged.

| Order | Version / filename | SHA-256 (Git/LF) |
| --- | --- | --- |
| 1 | `20261010010000_stage1_p0_security_completion.sql` | `76a28a9aa6294f6a8ca8f108394b801a2ee85f85827104246324f69787610bd5` |
| 2 | `20261010055013_stage1_atomic_ai_quota_reservation.sql` | `51ab2b39fb63655fea7e67e1a7aef69bb1ba15297877bc39168b90b2b1c8b646` |
| 3 | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` | `b94878391d4fddb9887e74d9a2a1dc809360de46f989a3d599a5471cc7c42fc5` |
| 4 | `20261012110945_stage1_security_abuse_storage_alignment.sql` | `9de2fdb764aae7068c9355b07cd3593823bd66b5da73448687693fe5cc535119` |
| 5 | `20261012230000_ai_models_check_constraints_alignment.sql` | `d4563930461176e6481df29cf587c9dca0eb7b4987395c05af2f613758452fbc` |

Main has 46 active migration files; this PR brings it to 51. The existing 25
authoritative + 21 additive reconstruction becomes 25 + 26. No prior migration,
historical alias, bootstrap snapshot or migration-history row is edited.

## Dependencies and expected effects

1. **P0 completion** depends on main's role helpers, profile escalation trigger,
   consultation schema, AI usage/entitlement tables, provider URL helper,
   document processor configuration, content drafts, Feed tables and audit log.
   It replaces existing function signatures without changing their return types,
   adds role-checked consultation admin RPCs and a private Feed guard, and adds
   two Feed triggers. Applicant table-wide SELECT becomes a public-column
   allowlist: `admin_note` and `assigned_to` are not selectable. Admins use the
   guarded RPC, not a broad grant. Draft/direct Feed writes are revoked from
   authenticated callers. `service_role` direct Feed writes are also trigger-
   blocked; publishing requires an authenticated DB-authorized Admin and an
   explicitly approved draft. Profile role changes still require the existing
   Super Admin path; trusted service bootstrap is audited. No role is promoted
   by the migration itself.
2. **Atomic quota reservation** depends on existing profiles, usage limits and
   `ai_requests`. It keeps the old `(uuid,text)` signature, ignores caller role
   inflation, serializes by user/UTC day and returns a newly persisted request
   ID. Only service_role can execute it. Request-count concurrency is protected;
   this is not a reservation of future output-token consumption.
3. **SSRF mapped IPv6** replaces the existing immutable public-HTTPS validator.
   It rejects mapped/compatible IPv6 private representations and unsafe literal
   ranges. It does not perform DNS resolution or make an outbound request; DNS
   rebinding and network egress protections remain separate controls.
4. **Storage/intake alignment** depends on step 1, `storage.foldername`, the
   documents bucket and existing own-path SELECT/INSERT policies. It adds one
   authenticated UPDATE policy with BOTH old-row USING and new-row WITH CHECK
   bound to bucket `documents` and caller's first path segment. It does not
   broaden read access, permit cross-owner moves, change MIME/size limits, or
   grant administrators unrestricted downloads. It adds the consultation
   `(user_id,created_at DESC)` index and `submit_consultation_request(text,text,uuid)`
   with owner identity, related-application ownership, input bounds and serialized
   3/hour, 10/day limits. Final direct INSERT grants, including column grants,
   are revoked. No Feed publication is performed by consultation intake.
5. **Model CHECK alignment** depends on the existing AI routing columns. It adds
   only absent named checks for nonnegative failures/latency and success rate in
   [0,1], using NOT VALID then VALIDATE. Main's historical routing alias already
   creates them; that path is a no-op. Historical production was missing them.
   A same-name wrong/unvalidated constraint is NOT repaired: preflight must stop.

## Duplicates, locks and non-idempotent effects

All five are additive/forward-only changes but **not purely read-only DDL**.
There is no DROP TABLE, DROP SCHEMA, TRUNCATE, DELETE of application rows,
default-ACL expansion, RLS disable, Auth/Vault/secret or Edge Function modification.
Named app policies/triggers and the OCR CHECK are deliberately dropped/recreated;
function bodies are replaced. Existing ACLs are narrowed/regranted explicitly.
The first migration temporarily permits specific consultation INSERT columns;
step 4 revokes them. Do not stop mid-chain and call final security acceptance PASS.

**Material data change:** step 1 disables existing unsafe OCR configurations and
sets their endpoint URL to NULL. Preserve that configuration securely before any
future authorized rollout. Reapplication is convergent but does not recover the
cleared value. Step 3's stricter URL function can also change the truth of an
existing URL CHECK; assess current rows against the FINAL validator, not only
the older deployed helper.

The model migration checks names, not semantic equivalence of pre-existing
definitions. The consultation CREATE INDEX IF NOT EXISTS likewise does not repair
a same-name wrong index. Verify definitions and validation flags, not just names.
ALTER TABLE locks and validation scans can block traffic. NOT VALID followed by
VALIDATE inside the SAME transaction is not a promise of a short exclusive lock;
locks can be held until COMMIT. Set approved lock/statement timeouts and a change
window. Migration 2 has no explicit BEGIN/COMMIT; the authorized migration runner
must supply its transaction. The other four contain their own transaction blocks.

## Historical production reconciliation — NOT a new live audit

The source's October 12–13 reports describe 47 live ledger entries ending at
`20261007212140`, including 16 timestamp aliases and four live-only names. They
found four missing functions, one Storage UPDATE policy, two Feed triggers,
three missing model CHECKs and one OCR endpoint CHECK, and weaker AI-owner guards.
Those are historical evidence, not certification of today's production state.

Sources at the pinned source SHA:
`artifacts/final_release_candidate_20261012/RAD_PRODUCTION_MIGRATION_RECONCILIATION_PLAN_20261012.md`
and `RAD_PRODUCTION_READONLY_PREFLIGHT_20261013.md` in the same directory.

Matching table columns does not establish equivalence. Do not use the repository's
51-file clean replay as a replacement for the actual production ledger/schema.
Do not replay historical aliases, run blind `supabase db push`, repair migration
history, or overwrite managed Storage objects/buckets. The live LOGO bucket and
service-owned Storage schema differences are not instructions to modify them.

## Confirmed application rollout dependencies — BLOCKED for production apply

This PR intentionally does NOT fix or deploy clients/Edge Functions:

- Main's `lib/features/consultation/presentation/pages/consultation_page.dart`
  directly INSERTs into `consultation_requests`; step 4 requires the submit RPC.
- Main's `lib/features/admin/presentation/pages/admin_consultations_page.dart`
  directly SELECTs internal fields/UPDATEs the table; the guarded admin RPCs must
  be integrated before that workflow can be accepted after rollout.
- Main's `supabase/functions/ai-orchestrator/handler.ts` ignores the returned
  reservation ID and separately INSERTs another request; it must reuse the
  reservation and fail closed on quota errors. Otherwise double counting and
  orphaned reservations are possible. Do not deploy an Edge change from this PR.
- Admin private-document download workflows need their separately reviewed,
  role-checked short-lived signed-URL mechanism; an owner-only Storage UPDATE
  policy does not solve administrative downloads.

These are explicit integration prerequisites, not reasons to weaken the five
verified SQL files. The owner's decisions that newly discovered AI models remain
disabled pending Admin approval and leaked-password protection be enabled only
after compatibility assessment remain preserved. This PR does not change model
discovery logic or Auth settings; any live discovery discrepancy is a separate gate.

## Regression and CI scope

Indispensable changes are limited to migration inventory/reconstruction checks,
the existing two-identity HTTP harness and SQL security tests. All eight existing
clean-schema fingerprint dimensions remain pinned; only the reviewed Storage
policy fingerprint/count changes. Loopback guards reject accidental remote test
targets. New tests cover source hashes/order, duplicate versions, replay inventory,
role/owner denials, three validated CHECKs and invalid values, both Feed guards,
Storage old/new path restrictions, consultation invalid input/direct INSERT and
3/hour + 10/day limits. The existing HTTP harness adds unique atomic reservations
under concurrency, real two-user ownership and explicit approval-to-Feed tests.
All test identities/content are synthetic in disposable databases; SQL fixtures
ROLL BACK. CI runs clean reconstruction, security/HTTP regressions, Flutter format/
analyze/full tests, Web/Android builds, routing and credential checks on the PR head.

Local raw logs live outside Git under `%LOCALAPPDATA%\RADPhaseASecurity-20261015`.
An offline PostgreSQL 17.11 scaffold rehearsal is distinct from actual CLI/Auth/
Storage HTTP acceptance in CI, and from production-equivalent or recovery testing.
Actual CI results must be read on the final PR head; no historical green status
or prior Flutter count is transferred to a different source state.

## Required production approvals and stop conditions

This PR is **review-ready only after its own CI is green**, never an apply/merge
authorization. Do not merge it in this task. The owner previously reported
Supabase Deploy to production OFF and Automatic branching OFF; this is owner-
provided dashboard evidence, not independent API verification. Keep both off;
do not rely on a skipped preview as proof that merging cannot deploy.

Before any separately authorized rollout, the owner/DBA must verify the current
ledger, full affected schema/ACL/function/trigger/policy definitions, existing-row
compatibility, the five hashes, runner transactions, backups and a real isolated
restore, secure rollback/recovery handling, client/Edge dependencies above, write
quiescence/change window and postflight probes after each file. STOP on unexpected
aliases, drift, duplicate/wrong-name objects, invalid rows, failed tests, lock
timeouts, missing recovery/approval, or any enabled automatic deployment.

Reverting this Git PR does not undo applied SQL. No automatic down migration or
grant broadening is supplied. A reviewed forward repair or approved grant-safe
restore is required after a failed/partial production change; the previously
observed 86 excess ACL restore grants must remain part of DBA recovery review.

No production SQL, ledger repair, Auth/Vault/secret/Edge change, Render deployment,
paid infrastructure or PR merge is performed. Phoenix and other shared work are
unchanged. Production remains **NO-GO** pending separate security and recovery gates.
