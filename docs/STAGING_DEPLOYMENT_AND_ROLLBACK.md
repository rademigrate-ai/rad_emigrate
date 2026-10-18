# Staging deployment and rollback handoff

Client date: 2026-10-19. **PLAN ONLY. Provisioning/deployment is BLOCKED_BY_OWNER.** Production project `inshddthftkhcdosoqcn` is read-only. No cloud resource, credential, backup or deployment result is invented here.

The release candidate starts from `2e0d089781ef3de582143421a59817094e57ca78`. Use the final tested backend commit specified in the handoff, together with Freebuff's approved combined release. Work in a new owner-controlled deployment checkout; never reuse another agent's worktree or an implicitly linked CLI project.

Before activation, the owner supplies an isolated staging project/ref and host, public/backend keys for that same project, allowed redirects and smoke accounts, a direct/session database URI, a verified staging backup/restore record, a previous release or first-deployment rollback artifact, and explicit authorization. Populate the separate blank public/backend templates outside Git. The database URI must target the explicit staging ref, use port 5432 and TLS, and must not come from a generic `DATABASE_URL` fallback. Opaque key binding requires an actual staging Auth check; local syntax/claim checks cannot certify it.

Run local configuration checks and produce a reviewable plan from a clean checkout:

```text
python scripts/staging_environment.py --env-file <private-public-settings> --scope public-build
python scripts/staging_environment.py --env-file <private-backend-settings> --scope backend-plan
python scripts/prepare_staging.py --env-file <private-backend-settings> --output <path-outside-checkout>/staging-plan.json
```

The plan pins the immutable source SHA and canonical-LF migration hashes. Its commands are argv descriptions for review, contain only environment references, and are never executed by the generator. Preparing a plan does not confer deployment permission. Do not archive a populated environment file or put a backend key into the public build environment.

After separate owner authorization, the deployment operator performs this order against only the validated staging target:

1. Verify the checkout SHA and migration hashes against the approved plan, confirm the staging backup/restore record and rollback artifact, and rerun both target guards with the actual private environment. Record the actual project, operator, UTC time and approved authorization reference.
2. Preview migrations using `supabase db push --db-url "$RAD_STAGING_DB_URL" --dry-run`. Inspect the exact pending chain and stop on unexpected history/content. Never use migration-history repair or a production connection. Do not add `--include-all` to bypass drift.
3. Only after the preview/backup review is approved, apply `supabase db push --db-url "$RAD_STAGING_DB_URL"`. The explicit guarded URI replaces reliance on CLI linked-project state. Capture the actual exit and migration list without logging the URI/password.
4. Deploy each eligible reviewed function with `supabase functions deploy <function-name> --project-ref <validated-staging-ref>`. Retain JWT verification and handler authorization. The plan excludes the current loopback-only `payment-sandbox`; it is not a hosted merchant integration. Optional OCR/Research/notification/provider activation remains disabled until its distinct contract/secrets/consent is approved. Platform-injected Supabase keys are not copied into frontend settings.
5. Configure only the approved staging Auth site/reset/native redirects; use synthetic smoke users. Build the web artifact with `bash scripts/build_web_render.sh` in the validated public environment and publish only to the explicitly approved staging host. Record the actual immutable `version.json` SHA.
6. Run clean schema/migration integrity, cross-role/cross-account RPC and Storage denial, signup/login/confirmation/recovery/refresh/logout, ordinary-user admin denial, worker/webhook malicious/retry/idempotence tests and the combined client smoke suite against the real staging target. Distinguish these new results from disposable-local evidence.

Rollback is scoped to that isolated staging project:

1. Stop staging smoke writes and disable optional workers/provider activation through the owner-controlled staging configuration. Do not touch production or issue real charges.
2. Redeploy the exact approved previous web/function artifacts by SHA and verify `version.json`, Auth/session and basic read flows. For a first deployment, use the approved maintenance/disabled artifact recorded before activation.
3. Retain compatible additive migrations. Never edit applied files, reset migration history or automatically drop user data. If the schema is incompatible with the rollback artifact, keep staging writes stopped and use the owner-verified staging backup/restore procedure and recorded backup ID. No real backup ID or platform restore action is available in this mission; that portion remains BLOCKED_BY_OWNER.
4. Re-run the target guards, role/Storage negative tests and artifact identity smoke before enabling staging again. Record actual results and any data-loss window. A disposable local replay is not evidence of a production or hosted staging restore.

CLI 2.119.0 `link`, `db push` and `functions deploy` help was inspected locally before preparing these command forms. No command above has been executed against a remote project by this mission.
