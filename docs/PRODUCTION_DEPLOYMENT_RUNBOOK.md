# Production Deployment Runbook

## Pre-deploy
1. Confirm PR #27 CI green (format, analyze, test, web build job).
2. Confirm Feed count = 0.
3. Confirm no service-role key in Flutter defines.

## Database (additive only)
- Do NOT run blind `supabase db push` against production if historical migration ledger mismatches.
- Apply only new timestamped migrations not yet on production.
- Verify schema_migrations order.

## Edge
- Deploy from repository source matching intended HEAD.
- ai-orchestrator must remain verify_jwt=true.
- After deploy: smoke chat + Feed=0.

## Web (Render)
1. Set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY (public only).
2. buildCommand: bash scripts/build_web_render.sh
3. staticPublishPath: build/web
4. SPA rewrite: /* → /index.html

## Mobile
- Android: RAD_ANDROID_APPLICATION_ID + RAD_RELEASE_* then flutter build appbundle.
- iOS: Xcode archive with registered bundle ID.

## Rollback / forward-fix
- Web: redeploy previous Render deploy.
- Edge: redeploy previous function version.
- DB: prefer forward-fix; no destructive reset.
