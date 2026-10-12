# Security acceptance — 2026-10-12

This report separates the security state committed at current HEAD from the
read-only production snapshot. No migration, production SQL write, deployment,
or Feed publication was performed.

## Production snapshot

Project `inshddthftkhcdosoqcn` was inspected through read-only catalog queries.
The latest production migration is `20261007212140_stage9_security_grant_hardening`.
Migration `20261010010000_stage1_p0_security_completion.sql` is not present.

| Requirement | Current HEAD | Production | Acceptance |
|---|---|---|---|
| P0 completion migration | Migration replays successfully in disposable PostgreSQL | Version `20261010010000` absent | **FAIL** until reviewed migrations are applied through the authorized deployment process |
| Non-owner AI quota/entitlement RPC access | `get_ai_daily_quota_status` and `get_ai_access_decision` raise `42501` for another user; disposable regression S13 passes | Authenticated EXECUTE is granted and live function bodies have no `auth.uid() = p_user_id` check | **FAIL** in production; **PASS** at HEAD |
| Applicant access to `consultation_requests.admin_note` | Table-wide SELECT is revoked and applicant SELECT is column-scoped; disposable regression S14 receives `42501` for `admin_note` | `has_column_privilege(..., 'admin_note', 'SELECT') = true` | **FAIL** in production; **PASS** at HEAD |
| Storage UPDATE versus client upsert | Migration `20261012110945` adds UPDATE only for the private `documents` bucket when the first path segment equals `auth.uid()` in both `USING` and `WITH CHECK` | Only SELECT, INSERT and DELETE policies exist | **FAIL** in production; **PASS** at HEAD |
| Admin document download | No implemented Admin document-list/download action exists; Admin operations reads only a count. User document URLs are private, RLS-checked signed URLs with a 3,600-second default. No broad Admin Storage read was added. | Same implemented workflow scope | **PASS / not required by current workflow**. A future Admin download must use a role-checked server/Edge endpoint and a materially shorter signed URL. |
| Consultation abuse protection | Direct authenticated INSERT is revoked; RPC validates ownership and length, serializes submissions, and limits each user to 3/hour and 10/day | Direct authenticated INSERT remains available without a velocity limit | **FAIL** in production; **PASS** at HEAD |
| Upload abuse protection | Private owner folder, authenticated access, 10 MiB bucket/client cap, PDF/JPEG/PNG allowlist, and same-path upsert; no cross-owner UPDATE | Size/MIME/private/owner controls are live, but upsert-aligned UPDATE is absent | **PASS** for abuse bounds; operational replacement uploads remain blocked until the migration is deployed |
| Guest AI abuse protection | Service-role-only atomic guest RPC, per-key advisory lock, five lifetime requests, sixth denied; regression S17 passes | Same five-request server-side cap and service-only EXECUTE are present | **PASS**, with residual risk: a guest can reset a client-held identifier. Stronger device/network binding needs an approved privacy and edge-rate-limit design. |
| Role escalation and human Feed publication | Normal-user escalation returns `42501`; direct Feed writes are trigger-blocked for anon/auth/service; publish requires an approved draft and authenticated Admin actor | Profile role trigger exists, but human Feed guard triggers are absent and the deployed publish RPC predates approved-only enforcement | **FAIL** in production; **PASS** at HEAD |

## Regression evidence

- `test/acceptance/security_acceptance_test.dart`: source-contract checks for all
  acceptance requirements.
- `tools/stage3_pipeline_e2e/run_pipeline_e2e.sh`: disposable PostgreSQL
  scenarios S13–S17 exercise real roles, grants, SQLSTATEs, rate limits, and
  existing Feed/role guards.
- `tools/stage3_pipeline_e2e/E2E_RESULTS.txt`: generated full-run evidence.

## Deployment boundary

The production failures above are migration-state failures, not authorization
to deploy. They must remain release blockers until an authorized operator has
reviewed the migration sequence, backup/rollback evidence, and post-deployment
read-only verification plan.
