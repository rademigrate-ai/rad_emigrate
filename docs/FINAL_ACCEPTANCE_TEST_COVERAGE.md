# RAD Final Acceptance Test Coverage

**Test branch:** `test/final-acceptance-coverage`  
**Starting main SHA:** `2b5a24dcb957e329959752cd35ca1b453f8b9b1f`  
**Scope:** Test-only. No production behavior changes.

## Existing Coverage Inventory (main at start)

| Area | Existing tests | Notes |
|------|----------------|-------|
| Auth redirect | `test/core/auth_redirect_test.dart` | Protected routes, restoration, profile completion |
| Session manager | `test/core/session_manager_test.dart` | Restore / logout |
| Auth repository / resend | `test/auth/*` | Partial |
| UserSession entity | `test/auth_controller_test.dart` | |
| Profile entity | `test/profile/*` | Serialization |
| Applications status | `test/applications/*` | Status flow smoke |
| Documents | `test/documents/*` | Serialization + storagePath |
| AI unavailable | `test/ai_service_test.dart` | Single decline case |
| App config | `test/core/app_config_test.dart` | |
| Widget smoke | `test/widget_test.dart` | |
| Two-user RLS / Storage | `scripts/verify_local_auth_isolation.py` (CI) | Profiles, applications, documents, AI sessions/messages, MIME/size, logout |
| Clean schema / RLS | `scripts/verify_clean_schema.sh` (CI) | |
| Secret scan | CI `repository-keyword-scan` | |

## Tests Added (this branch)

| File | Requirement |
|------|-------------|
| `test/acceptance/admin_role_authorization_test.dart` | USER / ADMIN / SUPER_ADMIN access matrix; forged role rejection |
| `test/acceptance/ai_safety_grounding_test.dart` | No fabricated answers when AI unavailable; uncertainty; sources model |
| `test/acceptance/auth_redirect_acceptance_test.dart` | Full protected-route matrix including `/admin`; deep-link safety |
| `test/acceptance/application_status_acceptance_test.dart` | Status labels, owner update identity, serialization |
| `test/acceptance/document_acceptance_test.dart` | storagePath ownership; signed URL not deletion identity |
| `test/acceptance/pwa_manifest_smoke_test.dart` | Manifest exists; icons referenced and present on disk |
| `test/acceptance/pending_implementation_gates_test.dart` | Explicit PENDING gates for research/feed/providers/locale/etc. |

## Two-User Isolation Coverage

**Covered in CI (local disposable Supabase):** profiles, applications, documents metadata, AI sessions, AI messages, Storage read/sign/upload/delete, MIME rejection, size rejection, logout token revocation.

**Not yet in Dart unit tests (rely on CI script):** notifications, bookmarks, feed interactions — marked PENDING until tables/APIs land.

## AI / Provider / Fallback

- Unavailable service: covered.
- Provider management key non-exposure, model discovery, fallback chains: PENDING IMPLEMENTATION (no client production API to bind without inventing).

## Research → Review → Feed

PENDING IMPLEMENTATION — no public Dart models for research job state machine or feed publication rules on main at branch start.

## Localization / RTL

PENDING IMPLEMENTATION — no locale service under test yet.

## Admin Authorization

- Client `AdminSnapshot.canAccess` / `isSuperAdmin` unit-tested.
- Route `/admin` unauthenticated → login covered.
- Server-side RLS and role-change RPC remain CI/schema responsibility (do not weaken).

## Observations for Master Agent (not fixed here)

1. **PWA branding:** `web/manifest.json` still uses Flutter defaults (`name`/`short_name` = `rad_emigrate`, description "A new Flutter project.").
2. **`/admin` not in `_protectedRoutes`:** restoration of `/admin` deep-links falls back to `/dashboard`. Unauthenticated access still hits login. Confirm intentional.
3. **No verified admin profiles in production** (per PROJECT13 docs) — admin E2E against live data is blocked by design.

## Validation note

This environment has no Flutter SDK. CI on the PR will execute `dart format`, `flutter analyze`, `flutter test`, web build, schema, isolation, and secret scan.
