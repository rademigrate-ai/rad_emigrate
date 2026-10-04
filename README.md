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

## Features (PROJECT 01)

| Module | Status |
|--------|--------|
| Authentication (login / register / OTP / profile completion / logout) | ✅ |
| Session restore + secure storage | ✅ |
| Router guards (public / protected) | ✅ |
| Responsive shell (NavigationRail + NavigationBar) | ✅ |
| Dashboard + quick actions + AI entry | ✅ |
| Visa programs (countries, categories, details) | ✅ |
| Applications list + detail + statuses | ✅ |
| Documents checklist + status | ✅ |
| Profile + logout | ✅ |
| AI service foundation | ✅ |
| Reusable UI (loading / error / empty / cards) | ✅ |
| Unit tests (auth + session) | ✅ |

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

### Render staging (Flutter Web)

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
| `APP_ENV` | `staging` | Normal |

Full checklist: [docs/RENDER_STAGING.md](docs/RENDER_STAGING.md). Blueprint: [render.yaml](render.yaml).

### Authentication

Authentication requires a real RAD Emigrate account and a valid Supabase session. The demo credentials previously listed here are not supported.

## Documentation

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Render staging](docs/RENDER_STAGING.md)
- [PROJECT 01 Implementation](docs/PROJECT01_IMPLEMENTATION.md)

## Next (beyond PROJECT 01)

- Real backend API integration
- Knowledge Base + RAG for User AI
- Admin CMS + Admin AI Research Assistant
- Payments, CRM, notifications
- Full immigration profile forms
- Document upload + OCR
