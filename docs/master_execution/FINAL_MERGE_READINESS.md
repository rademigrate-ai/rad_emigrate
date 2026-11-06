# Final merge-readiness review

Review date: 2026-11-06 (Asia/Tehran). **NO-GO pending final security,
feature, integration and exact-head verification.** This document is not merge
or deployment authorization. Keep [PR #89](https://github.com/rademigrate-ai/rad_emigrate/pull/89)
open, Draft and unmerged.

## Repository and integration

An earlier engineering run started from a clean `execution/master-completion-20261029`
checkout at `0d66f761dd745ed0997c9575e427f23bde4587c5`, matching
the PR HEAD. **That original worktree was later deleted during an unrelated,
unauthorized cleanup.** The current continuation uses the separately recovered,
detached checkout at `_audit/RAD_RELEASE_SOURCE_RECOVERY_20261106`.
The surviving `rad_emigrate` checkout at `154c87629dd44acd165b09c1614eb0538246e233`
was not reset or reused. The initial seven modified and four untracked recovery
files were preserved and reviewed before this continuation.

The inspected `origin/main` merge base was
`0e8b8df206a3824d7a47f2c029e690ec072c6372`; GitHub reported PR #89
mergeable, zero commits behind main, and eight successful CI jobs at the
historical PR HEAD. Re-fetch remote refs immediately before final readiness.
Several old local worktree metadata entries remain prunable: their original
directories must **not** be represented as intact or repaired by pruning.

These are starting observations. The final external attestation must bind the
final local/remote/PR SHA, fetched target, clean-tree state, all eight final CI
jobs, packaged file hashes and executed staging receipts. Recheck the target
immediately before an owner-authorized merge.

## Required checks and GitHub controls

The eight required jobs remain `clean-schema`, `migration-reconstruction`,
`routing`, `flutter`, `web-build`, `android-build`, `plan3-content`, and
`repository-keyword-scan`. CI runs on PRs, main pushes and manual dispatch.
Deployment configuration and image changes now also match its path filters.

The only repository workflow is `.github/workflows/ci.yml`. Inspection found
read-only contents permission, no Production environment attachment, no secret
expression, no privileged `pull_request_target` trigger, no OIDC write grant,
and no deployment or hosted migration step. Web compilation accepts public
configuration only. Local/CI migration scripts require disposable loopback
targets; this review did not run a hosted migration.

The GitHub branch-protection endpoint returned **403 Resource not accessible by
integration**. The visible repository ruleset collection was empty. This does
not prove that branch protection is absent or correctly configured. A repository
administrator must verify required checks/reviews, bypass actors, force-push
prohibition and environment/secret policies before merge. No secret values or
administrative settings were accessed or changed.

`scripts/tests/test_release_change_controls.py` guards the manual Render
deployment setting, both CI path filters, and the inspected workflow boundaries.
It complements source review; it is not a universal workflow-security parser.

## Read-only Render audit

The owner explicitly authorized only the **Rad** workspace and the RAD service.
The service `rad_emigrate` (`srv-db0p4e9srm7s738jam10`) is a static site linked
to this repository's `main` branch. At inspection:

- `autoDeployTrigger=off`, `autoDeploy=no`; PR previews are off.
- Build: `bash scripts/build_web_render.sh`; publication directory: `build/web`.
- The service is not suspended. The latest five recorded deployments were manual.
- The latest live deployment is `dep-dbd5794ipgvc73e51si0`, built from
  `ccf041a371baf029ba5a5bccc01cabf394628a43` on 2026-10-22.
- Anonymous GETs to the public root and `/version.json` returned HTTP 200;
  the version file matches that deployed SHA, not this candidate.
- CPU, RAM, request-count and latency metric arrays were empty. They are
  unavailable measurements, not zero usage. The one returned bandwidth sample
  was 0.006164551 MB at 2026-11-05 21:00 UTC; it is not a load benchmark.

Merging this PR would **not currently trigger Render auto-deployment** under
the inspected settings. Recheck that state before merge. The Blueprint now
explicitly sets `autoDeployTrigger: off` so new services do not inherit an
automatic default. Existing live settings were not changed.

The connector has no read-only environment-variable listing capability, and the
available dashboard browser redirected to login. Actual live variable names
remain **UNVERIFIED**. No values were read, revealed or modified. The repository
expects public `APP_ENV`, `SUPABASE_URL`, and `SUPABASE_PUBLISHABLE_KEY` (or legacy
`SUPABASE_ANON_KEY`); that list is not an inventory of the live service.
An authenticated owner must verify names and confirm that no service-role,
provider, database or other privileged secret is attached to this static build.

No Render setting, deploy, restart, environment variable or secret was changed.
The dated JSON receipt and public health hashes are retained outside Git in
`D:/RAD - Emigrate/_audit/RAD_RELEASE_REMEDIATION_20261106/`.

## Migration and data safety

The 121 original migration files have a separately retained SHA-256 inventory.
This continuation adds only an additive, owner-scoped status-history migration,
bringing the candidate to 122; native SQL, empty-install and upgrade verification
must pass on its **new** PR HEAD before it can be considered verified.
Historical migration bytes must remain unchanged. The three protected local
Supabase volumes survive; some earlier disposable acceptance/restore stacks
and their volumes were deleted during the separate cleanup incident.
Do not substitute fresh-install success for managed Production reconciliation,
recovery authorization or data acceptance. Database rollback must use a
separately authorized, tested recovery procedure, never blind image downgrade
or migration-history edits.

## Owner-controlled merge sequence

1. Close mandatory engineering/security gaps or obtain explicitly authorized,
   evidence-specific dispositions; complete the all-47 scope/acceptance review.
2. Review the final exact-head CI, source, staging, migration, image and package
   receipts. Re-fetch the target and recheck conflicts and repository controls.
3. Confirm Render auto-deploy/previews remain off, no deployment hook or new
   workflow was added, and static-build variable names have been verified.
4. Obtain the owner's explicit authorization for the specific PR head and merge
   method. The agent must not merge on the owner's behalf during this task.
5. After the owner's merge, identify the actual immutable merge/release SHA.
   Wait for its main-branch CI and rebuild/version-bind release artifacts to
   that SHA. A PR-head artifact is not automatically a merge-commit artifact.
6. Follow `PRODUCTION_DEPLOYMENT_RUNBOOK.md` only after separate deployment
   authorization, approved backup/recovery, target readiness and secret setup.
   Merging and deploying remain separate decisions.

References: [Render Blueprint auto-deploy behavior](https://render.com/docs/blueprint-spec#autodeploytrigger),
[Supabase coordinated self-hosted updates](https://supabase.com/docs/guides/self-hosting/docker#updating).
