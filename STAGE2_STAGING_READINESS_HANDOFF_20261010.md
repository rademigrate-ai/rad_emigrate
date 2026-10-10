# Stage 2 Staging Readiness Handoff — 2026-10-10

## Status

- Staging readiness: **BLOCKED — owner infrastructure and approvals required**
- Staging runtime: **NOT RUN**
- Production: **NOT AUTHORIZED**

The engineering handoff is ready, but no separate staging Supabase project, staging Render service, staging URL, staging credentials, or deployment authorization was provided. Nothing in this document claims that hosted staging has been provisioned or verified.

## Completed prerequisites

- Stage 2 local acceptance is GO at HEAD `271e43e7bc67bc6b1a87b2bdb4db72813ebb78a6` plus the staged candidate.
- Local browser, Flutter, document Storage/RLS, Auth isolation, Edge, SQL security, no-auto-publish, and cleanup evidence is recorded in `STAGE2_LOCAL_ACCEPTANCE_EXECUTION_20261010.md`.
- Flutter configuration fails closed when the public Supabase URL/key are absent.
- `scripts/build_web_render.sh` accepts `APP_ENV=staging` and builds with only the public URL and publishable key.
- SPA fallback configuration exists for protected/direct routes.
- The repository contains the three required Edge Functions: `ai-orchestrator`, `document-intelligence`, and `research-sync`.
- The migration lineage creates a private `documents` bucket, owner-path Storage policies, a 10 MiB limit, and PDF/JPEG/PNG MIME restrictions.
- Research and AI create review candidates only; explicit Admin publication is a separate guarded action.
- The local security advisor returned no error-level findings.

## Genuine blockers

1. The owner must create or designate a **separate Supabase staging project**. Production must not be reused.
2. The owner must create a **separate Render staging Static Site**. The production `rad-emigrate` service/branch configuration must not be reused unchanged.
3. The owner must provide the staging project reference, HTTPS site URL, public publishable key, permitted Auth callback URLs, and secret-management access.
4. The owner must approve migration dry-run/reconciliation, hosted migration application, Edge Function deployment, and any staging test identities.
5. A staging-safe browser runner/identity plan is required. `scripts/verify_stage2_browser_e2e.py` intentionally refuses non-loopback Supabase URLs and must not be pointed at hosted staging or changed to carry a service-role key into a browser workflow.

## Required staging topology

### Supabase staging

- A project distinct from production, with a recorded `<STAGING_PROJECT_REF>`.
- Auth Site URL set to the owner-provided Render staging HTTPS origin.
- Exact additional redirects for login/recovery, including the staging `/reset-password` route; no wildcard production reuse.
- Private `documents` bucket with the repository-defined owner policies, file-size limit, and MIME allow-list.
- All repository migrations reconciled against the staging migration ledger before application.
- Edge Functions deployed from one approved Git SHA.
- Supabase-managed `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` available only to Edge Functions.
- Research worker token and provider credentials stored only in staging secrets/Vault, never in Render, Flutter defines, Git, logs, or this handoff.

### Render staging

- A separate Static Site with an owner-chosen staging service name and staging branch/commit policy.
- Build command: `bash scripts/build_web_render.sh`
- Publish directory: `build/web`
- SPA rewrite: `/*` to `/index.html`
- Environment:
  - `APP_ENV=staging`
  - `SUPABASE_URL=<STAGING_SUPABASE_URL>`
  - `SUPABASE_PUBLISHABLE_KEY=<STAGING_PUBLIC_PUBLISHABLE_KEY>`
- Never set `SUPABASE_SERVICE_ROLE_KEY`, provider API keys, Vault values, or the research worker token on Render.

## Safe migration and schema reconciliation

Run only from a clean checkout of the owner-approved commit. Replace placeholders only after confirming the selected project is staging.

Read-only/preflight sequence:

```bash
git rev-parse HEAD
supabase link --project-ref <STAGING_PROJECT_REF>
supabase migration list --linked
supabase db push --linked --dry-run
```

Required review before any write:

- record the linked project reference and confirm it is not production;
- compare the hosted migration ledger with `supabase/migrations`;
- stop on renamed, missing, duplicated, out-of-order, or unexpectedly applied versions;
- review the dry-run SQL and expected object changes;
- back up staging and record the current schema/function/deployment versions;
- obtain explicit owner approval for the actual push.

Only after approval:

```bash
supabase db push --linked
```

Do not use `supabase db reset` on staging. Do not repair, rename, squash, or rewrite hosted migration history during this handoff. A mismatch is a blocker requiring a separately reviewed reconciliation plan.

## Edge Functions and secrets

After the database migration succeeds and the owner authorizes deployment:

```bash
supabase functions deploy research-sync --project-ref <STAGING_PROJECT_REF>
supabase functions deploy ai-orchestrator --project-ref <STAGING_PROJECT_REF>
supabase functions deploy document-intelligence --project-ref <STAGING_PROJECT_REF>
```

Set staging-only secrets through the Supabase Dashboard or an owner-controlled secret file/process. Do not paste values into Git, reports, chat, Render, browser storage, or command output. Provider credentials remain write-only in Vault through the guarded Super Admin flow.

Before acceptance, verify:

- ordinary users cannot invoke Admin/Super Admin operations;
- `research-sync` worker authorization is configured and browser Admin authorization still works;
- provider and OCR base URLs pass public-HTTPS/SSRF validation;
- function responses/logs expose no provider key, service role, worker token, signed URL, or upstream secret text.

## Staging build and deployment sequence

1. Owner approves the exact staged Git candidate and authorizes commit/push.
2. Owner selects the resulting immutable commit SHA for staging.
3. Create/configure separate Supabase and Render staging resources.
4. Record current staging backup, migration ledger, function versions, and Render deployment.
5. Run the read-only migration commands above and review the dry run.
6. Owner separately authorizes migration application and function deployments.
7. Configure exact staging Auth Site URL and redirects.
8. Configure the Render staging variables and deploy the selected SHA.
9. Confirm `build/web/version.json` reports that SHA.
10. Run the staging acceptance below with owner-authorized disposable staging identities and clean them up.

## Staging acceptance

Pre-deploy build checks from the approved SHA:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
APP_ENV=staging SUPABASE_URL=<STAGING_SUPABASE_URL> SUPABASE_PUBLISHABLE_KEY=<STAGING_PUBLIC_PUBLISHABLE_KEY> bash scripts/build_web_render.sh
```

Post-deploy HTTP checks, after substituting the owner-provided staging URL:

```bash
curl --fail --show-error --silent <STAGING_WEB_URL>/version.json
curl --fail --show-error --silent <STAGING_WEB_URL>/login
curl --fail --show-error --silent <STAGING_WEB_URL>/reset-password
curl --fail --show-error --silent <STAGING_WEB_URL>/dashboard
```

Hosted browser acceptance must use a staging-specific safe runner or a documented manual/Playwright workflow with owner-authorized disposable accounts. It must not use a service-role key in the browser, and it must verify:

- public routes and direct-route SPA fallback;
- valid/invalid login, logout, refresh, and password recovery callbacks;
- English/Persian switching and real RTL/LTR layout behavior;
- user desktop/mobile routes, Admin desktop/mobile routes, and Super Admin-only configuration;
- ordinary-user Admin denial;
- document upload/delete, database ownership, private Storage lifecycle, and cross-user denial with two staging users;
- Consultation submission/history;
- error/retry states;
- research creates one review candidate and no Feed item;
- only explicit Admin publish changes Feed, and repeated publish is idempotent;
- browser console/network has no secret, mixed-content, asset, or unexpected error flood;
- all disposable users, rows, messages, and Storage objects are removed.

Record the exact staging SHA, commands, exit codes, screenshots/manifests, created fixture IDs, and cleanup result. Local manifests are historical evidence, not proof of hosted staging behavior.

## Rollback strategy

- Render: redeploy the recorded previous known-good staging commit.
- Edge Functions: redeploy the recorded previous staging function bundle for the affected function.
- Database: do not reset or destructively roll back data. Prefer a reviewed forward corrective migration; stop traffic/features if needed.
- Auth: restore the recorded prior staging Site URL/redirect set, then retest login and recovery.
- Storage: preserve objects and policies while diagnosing; do not bulk-delete. Correct policy/schema defects additively.
- Secrets: rotate only the affected staging credential, update Vault/Function secret storage, validate, then revoke the previous value.
- Research/Feed: disable the staging research schedule/worker if needed; leave review candidates unpublished and never bulk-publish during rollback.

## Explicit owner approvals required

- Commit approval for the staged seven-file Git candidate.
- Separate push/remote-delivery approval.
- Selection/provisioning of the Supabase staging project.
- Selection/provisioning of the Render staging service and staging URL.
- Staging Auth URL/redirect configuration approval.
- Migration dry-run review and separate approval for actual hosted migration application.
- Edge Function deployment approval.
- Staging secret/Vault configuration approval.
- Creation and cleanup of disposable staging identities/data.
- Approval to run hosted staging acceptance.
- Any later production activity requires a new, explicit production authorization.

## Next action

The immediate next action is owner review of the staged Git candidate. After commit/push authorization, the owner must supply the separate staging project/service details and approve the read-only migration preflight. Until then, staging readiness remains **BLOCKED** and staging runtime remains **NOT RUN**.
