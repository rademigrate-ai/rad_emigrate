# PROJECT 03 — RAD International Institute

**Status:** COMPLETE  
**Repository:** rademigrate-ai/rad_emigrate  
**Branch:** main  
**Starting checkpoint:** `d4e1467d0351a5e12bcb5313038de0f1b3a4abed`

## Mission

تکمیل جریان واقعی کاربر از ورود تا مدیریت پرونده مهاجرتی  
Complete the real user flow from login through immigration case management.

## Product scope

### Implemented

- Profile completion (production flow + edit/save)
- Visa application dashboard & status tracking
- Document upload flow (offline-simulated mark-as-uploaded)
- Application status tracking
- AI assistant interface (full page + session free-question limit)

### Explicitly out of scope

- Payment gateway
- Real immigration decision engine
- External AI provider (abstraction + placeholder only)

## Architecture constraints (preserved)

- Feature-first Flutter structure
- Riverpod state management
- GoRouter ownership
- Repository pattern
- Dependency direction: Controller → Repository → Datasource → Network
- No Dio inside features
- No duplicated lifecycle ownership

## Phases delivered

| Phase | Work |
|-------|------|
| 1 Profile production flow | Local/remote datasources, `ProfileRepositoryImpl`, `ProfileController`, editable profile UI |
| 2 Application management | Application datasources/repo, controller, list/detail, status chips, new draft |
| 3 Document workflow | Document datasources/repo, controller, checklist UI, simulated upload |
| 4 AI assistant UI | `/ai-assistant` chat UI, `AiService.complete`, configurable free question count |

## Backend boundary

- **No live backend.** Contracts only.
- Remote datasources call existing `ApiClient` paths (`/users/.../profile`, `/applications`, `/documents`).
- Offline fallback to local (`SharedPreferences`) when remote fails (non-production).
- No fabricated success rates, guarantees, or official decisions.

## Routing changes

- Authenticated users with incomplete profile redirected to `/profile-completion`.
- New route: `/ai-assistant` inside shell.
- Dashboard links to applications, documents, profile, AI; shows case overview stats.

## Files changed (major)

```
lib/features/profile/data/datasources/
lib/features/profile/data/repositories/profile_repository_impl.dart
lib/features/profile/presentation/providers/profile_controller.dart
lib/features/profile/presentation/pages/profile_page.dart
lib/features/applications/data/
lib/features/applications/presentation/providers/application_controller.dart
lib/features/applications/presentation/pages/applications_page.dart
lib/features/documents/data/
lib/features/documents/presentation/providers/document_controller.dart
lib/features/documents/presentation/pages/documents_page.dart
lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart
lib/core/routing/app_router.dart
lib/features/dashboard/presentation/pages/dashboard_page.dart
test/profile/profile_repository_test.dart
test/applications/application_status_flow_test.dart
docs/PROJECT03_IMPLEMENTATION.md
```

## Validation

Required gate (run with private repo clone):

```bash
flutter pub get
flutter analyze
flutter test
flutter build web
```

Domain unit tests for profile/application models extended under `test/`.

## Audit summary (10 cycles)

1. **Architecture** — feature isolation retained; repositories own datasources.
2. **Dependency** — features use ApiClient via datasources only.
3. **State** — Riverpod controllers per domain; no duplicate bootstrap.
4. **Routing** — auth + profile-complete guards; AI route registered.
5. **Security** — no payment, no external AI keys, local prefs only for offline cache.
6. **Performance** — list screens load once; refresh actions explicit.
7. **Test** — model/status flow tests added.
8. **Code quality** — no merge markers; simulated upload labeled clearly.
9. **Documentation** — this file.
10. **Release** — final commit message per project rules.

## Limitations

- Upload is **simulated** (status change only); no binary file transfer.
- AI answers remain **placeholder** until Knowledge Base / RAG.
- Remote APIs are contracts; offline seed data used without live server.
- Free AI question limit is in-memory session counter (not server-enforced).

## Future (not PROJECT 03)

- Real file storage + OCR
- Server-backed AI usage metering
- Payment / subscription modules
- Live immigration rule engine (never auto-publish without human approval)
