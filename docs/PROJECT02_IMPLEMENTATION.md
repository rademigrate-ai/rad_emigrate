# PROJECT 02 — Production Platform Foundation

**Status:** COMPLETE  
**Repository:** rademigrate-ai/rad_emigrate  
**Branch:** main  
**Based on PROJECT 01 commit:** `0df1dd4d23be77853d23b252008238aed6c734ad`

## Starting state

PROJECT 01 delivered feature-first Flutter architecture with:

- Riverpod + GoRouter
- Mock `AuthRepository`
- Placeholder `ApiClient` (Dio stub)
- `SessionStorage` via secure storage
- Feature modules: auth, dashboard, visa, applications, documents, profile, splash
- Passing analyze / test / web build gate

## Goals achieved

| Area | Status |
|------|--------|
| Production Network Layer | Done |
| Auth Production Boundary | Done |
| Session Management | Done |
| User Profile Domain | Done |
| Visa Application Domain | Done |
| Document Management Domain | Done |
| AI Service Foundation | Done |
| Environment Configuration | Done |
| Dependency Injection Update | Done |
| Expanded Tests | Done |
| Documentation | Done |

## Architecture decisions

### Decision: Keep AuthRepository contract; add Impl + datasources

- **Reason:** PROJECT 01 froze the repository interface used by `AuthController`.
- **Approach:** `AuthRepositoryImpl` coordinates `AuthRemoteDataSource` + `AuthLocalDataSource`.
- **Demo fallback:** Non-production environments fall back to offline demo auth when remote is unreachable so the app remains usable without a live API.
- **Alternatives considered:** Breaking the controller contract; rejected.

### Decision: Manual immutable models (not freezed codegen in this release)

- **Reason:** Zero-error release without requiring `build_runner` in CI for every change; freezed remains in pubspec for future adoption.
- **Approach:** Hand-written `copyWith`, `toJson`, `fromJson`, `==` / `hashCode` on domain entities.
- **Consequence:** Same serializability and immutability; freezed can be introduced later without API breaks.

### Decision: SessionManager owns restore lifecycle

- **Reason:** Single bootstrap path Application Start → Bootstrap → SessionManager.restore → Auth state → Router.
- **Approach:** `appBootstrapProvider` calls `SessionManager.restore()` then `AuthController.applySession`.
- **Alternatives:** Dual restore in controller and manager; rejected to avoid duplicate initialization.

### Decision: Dio only behind ApiClient

- Features never import Dio. Path: Repository → Datasource → ApiClient.

### Decision: No production secrets hardcoded

- `AppConfig` uses environment-named base URLs and feature flags. `APP_ENV` compile-time define selects config.

## Dependency changes

No new pub packages required beyond PROJECT 01 (`dio`, `flutter_secure_storage`, `riverpod`, etc.).

New internal modules:

```
lib/core/config/
lib/core/network/ (+ interceptors)
lib/core/session/
lib/core/services/ai/
lib/features/auth/data/datasources/
lib/features/auth/data/repositories/auth_repository_impl.dart
lib/features/profile/domain/entities/user_profile.dart
lib/features/applications/domain/entities/visa_application.dart
lib/features/documents/domain/entities/document.dart
```

## Testing

| Suite | Focus |
|-------|--------|
| `test/core/session_manager_test.dart` | restore authenticated/unauthenticated, logout |
| `test/auth/auth_repository_impl_test.dart` | network/config smoke |
| `test/profile/user_profile_test.dart` | serialization, equality |
| `test/applications/visa_application_test.dart` | serialization, status labels |
| `test/documents/document_test.dart` | serialization, labels |
| Existing PROJECT 01 tests | retained |

No real network calls in tests.

## Limitations

- Live backend endpoints are not yet available; remote calls fail closed to demo fallback outside production.
- Document upload / OCR / AI analysis are domain-ready only.
- Payments and CRM modules are out of scope (feature-flagged off).
- freezed code generation not enabled in this release.

## Future roadmap (not PROJECT 02)

1. Connect real auth/API backend and disable demo fallback in production builds.
2. Wire profile/applications/documents repositories to remote datasources.
3. RAG-backed AI service with RAD Knowledge Base.
4. Optional freezed migration for domain models.
5. Payment provider-agnostic module.

## PROJECT 01 records

Historical PROJECT 01 documentation under `docs/PROJECT01_*` is unchanged.
