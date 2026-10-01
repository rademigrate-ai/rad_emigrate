# RAD Emigrate Architecture

## Overview

RAD Emigrate uses a **feature-first Clean Architecture** on Flutter with Riverpod for state and GoRouter for navigation.

## Layers

```
Presentation  →  Domain  →  Data  →  External Services
```

- **Presentation**: pages, widgets, controllers (StateNotifier / providers)
- **Domain**: entities, repository contracts, use-case oriented methods
- **Data**: repository implementations, mock/API datasources, models
- **External**: secure storage, network client, AI service

## Structure

```
lib/
  app/
    app.dart
    dependencies.dart
  core/
    constants/
    errors/
    network/
    routing/          # GoRouter + AppShell
    services/         # AiService
    storage/          # SessionStorage
    theme/
    widgets/          # LoadingView, ErrorView, EmptyView, SectionCard
  features/
    auth/
    splash/
    dashboard/
    visa/
    applications/
    documents/
    profile/
```

## Authentication flow

```
App start → Splash → restore session
  ├─ authenticated → Dashboard (shell)
  └─ unauthenticated → Login

Login / Register → OTP → Profile completion (if needed) → Dashboard
Logout → clear storage → Login
```

Router uses `sessionNotifier` (`ValueNotifier<bool>`) as `refreshListenable` for redirect guards.

## AI foundation

`core/services/ai_service.dart` defines `AiService` + `PlaceholderAiService`.

Ready for:

- User AI chatbot (knowledge base + RAG)
- Admin AI research assistant (source monitoring, conflict detection, human approval)

## Extensibility

New modules should be added as independent features under `lib/features/` with the same layering. Business rules remain backend-configurable.
