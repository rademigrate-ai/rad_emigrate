# Isolated staging web configuration

The previous guide used production Supabase values under a staging label. Those examples are removed. A staging label alone does not isolate a database. No staging project or host is provisioned by this guide.

Use the blank [.env.staging.example](../.env.staging.example) as a specification for owner-supplied settings. Set `APP_ENV=staging`, `RAD_DEPLOYMENT_KIND=staging`, an explicit non-production `RAD_STAGING_PROJECT_REF`, the canonical HTTPS Supabase API URL for that same project, an owner-selected HTTPS staging site origin, and exactly one publishable/legacy anon key. Production project `inshddthftkhcdosoqcn` and the known production web host are denied by the validator.

Validate configuration without network access:

```text
python scripts/staging_environment.py --env-file <private-staging-public-settings-file> --scope public-build
```

Do not commit populated settings. Environment parsing treats values as data; it does not execute shell substitution. Backend/provider secrets belong in a separate secret environment, never the public build environment. Legacy JWT role/ref claims are checked without claiming signature verification. Opaque publishable keys require an owner-run staging Auth smoke test to establish their binding; the local guard cannot certify a real key.

For an owner-authorized Render staging Static Site, the build command is `bash scripts/build_web_render.sh`, publish directory `build/web`, and SPA rewrite `/*` to `/index.html`. Provide the validated settings as build environment variables. The build script runs the guard before Flutter/dependency installation whenever staging intent is declared. Missing, mismatched, production, privileged or ambiguous settings fail before the build. A build does not deploy anything through this script.

Flutter receives only `APP_ENV`, `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. The backend service key, CLI access token and provider credentials must never become Dart defines. Do not copy production Auth redirects into a staging project. After provisioning approval, the owner must configure only approved staging site/reset/native redirect origins in the isolated project's Auth settings.

Activation remains **BLOCKED_BY_OWNER** until the real staging project, host, public-key binding, redirects, deployment permission and smoke accounts are supplied/approved. No deployment success is asserted. Required post-activation checks include immutable release SHA, signup/login/recovery, refresh/logout, two-account database/Storage isolation, role denial and SPA deep links against actual staging URLs.
