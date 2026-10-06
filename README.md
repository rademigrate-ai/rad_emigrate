# RAD Emigrate

Flutter foundation for the **International Institute of RAD** immigration platform.

Targets: **Android · iOS · Web**

## Architecture

Feature-first Clean Architecture + Riverpod + GoRouter.

```
lib/
  app/           # App bootstrap, DI, routes
  core/          # Theme, routing shell, storage, network, widgets, services
  features/
    auth/
    splash/
    dashboard/
    visa/
    applications/
    documents/
    profile/
```

Each feature follows:

`presentation → domain → data`

## Product areas

Authentication, bilingual Visa catalogue, reviewed Feed, applications,
documents, grounded User AI, and role-gated Admin/Super Admin operations are
implemented against Supabase. Research and AI create review candidates only;
publishing to Feed is always an explicit Admin action.

## Getting Started

```bash
flutter pub get
flutter analyze
flutter test
```

### Supabase configuration

The app requires the public Supabase URL and publishable key at **build time**
(`lib/core/supabase/supabase_config.dart`):

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` (fallback: `SUPABASE_ANON_KEY`)

Never use a service-role key in Flutter or commit real keys to the repository.

For a local run, replace `<publishable-key>` with the **Publishable key** from
Supabase Dashboard → Project Settings → API:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://inshddthftkhcdosoqcn.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

For an Android APK, the same defines must be supplied while building:

```bash
flutter build apk --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://inshddthftkhcdosoqcn.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

If these values are omitted, the app intentionally shows
`supabase_not_configured` and cannot authenticate. The CI Android build only
validates compilation and does not contain production credentials.

Web builds use the same two Supabase defines.

### Render production (Flutter Web)

Static Site settings:

| Setting | Value |
|---------|--------|
| Build Command | `bash scripts/build_web_render.sh` |
| Publish Directory | `build/web` |
| Rewrite | `/*` → `/index.html` (Rewrite) |

Environment variables (available at **build** time):

| Name | Value | Type |
|------|--------|------|
| `SUPABASE_URL` | `https://inshddthftkhcdosoqcn.supabase.co` | Normal |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable or legacy **anon** public key from Supabase API settings | Normal |
| `APP_ENV` | `production` | Normal |

Full release, activation, rollback, and smoke-test procedure:
[Stage 5 production handover](docs/STAGE5_PRODUCTION_HANDOVER.md). Blueprint:
[render.yaml](render.yaml).

### Authentication

Authentication requires a real RAD Emigrate account and a valid Supabase session. The demo credentials previously listed here are not supported.

## Documentation

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Stage 5 production handover](docs/STAGE5_PRODUCTION_HANDOVER.md)
- [Migration lineage reconciliation](docs/SUPABASE_MIGRATION_LINEAGE_RECONCILIATION.md)
