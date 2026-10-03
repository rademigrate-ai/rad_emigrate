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
flutter run
flutter build web
```

### Authentication

Authentication requires a real RAD Emigrate account and a valid Supabase session. The demo credentials previously listed here are not supported.

## Documentation

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [PROJECT 01 Implementation](docs/PROJECT01_IMPLEMENTATION.md)

## Next (beyond PROJECT 01)

- Real backend API integration
- Knowledge Base + RAG for User AI
- Admin CMS + Admin AI Research Assistant
- Payments, CRM, notifications
- Full immigration profile forms
- Document upload + OCR
