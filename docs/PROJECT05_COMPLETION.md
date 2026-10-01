# PROJECT 05 COMPLETE — RAD Emigrate Production Backend Release

**Repository:** `rademigrate-ai/rad_emigrate`  
**Branch:** `main`  
**Supabase project:** `RAD` (`inshddthftkhcdosoqcn`)  
**Region:** `eu-west-1`

## Implemented features

Project 05 completes the production backend integration without changing the Riverpod architecture, repository pattern, GoRouter structure, or RAD UI design system. Supabase is now the only runtime authentication path. Login, signup, logout, email OTP verification, session restoration, auth state changes, and profile completion flow through the Supabase datasource and existing controller layer.

Fake authentication and fabricated demo identities were removed from runtime code. Profile loading now requires a real authenticated user ID and safely recreates a missing owner profile through an RLS-protected insert. Applications and documents keep genuine local cache support but no longer seed demo records or claim simulated remote success.

## Supabase changes

Existing tables and relationships were preserved. The final schema contains `profiles`, `applications`, `documents`, `ai_sessions`, and `ai_session_messages`, with foreign keys to `auth.users` and the existing application/document relationships intact. Documents can be created before application linkage, which supports the real upload flow.

The private `documents` Storage bucket remains private. Uploads use a user-scoped path of `user_id/document_id/file_name`, write metadata to `documents.file_path`, and retrieve files through expiring signed URLs. The Flutter layer validates PDF/JPG/JPEG/PNG types and a 10 MB limit before upload; the Storage service and Storage RLS policy repeat those checks server-side. Uploads use upsert semantics, making retries safe for the same path.

## Security changes

RLS is enabled on all application tables. Profiles, applications, documents, AI sessions, and AI messages use explicit owner policies based on `auth.uid()`. AI messages additionally verify that the referenced session belongs to the same authenticated user. Storage read, upload, and delete policies require an authenticated user and the user UUID as the first path segment.

`handle_new_user()` remains `SECURITY DEFINER` and is hardened with an empty search path. Exposed anonymous/authenticated execute access is revoked. A least-privilege profile insert policy allows an authenticated user to recreate only their own missing profile. No service-role key or secret is committed.

## Migrations

The migration set is under `supabase/migrations/`:

| Migration | Purpose |
|---|---|
| `001_security_hardening.sql` | Harden signup trigger execution and search path. |
| `002_rls_policies.sql` | Apply explicit owner RLS policies and indexes. |
| `003_storage_policies.sql` | Keep the documents bucket private and enforce owner paths. |
| `004_ai_sessions_and_document_bootstrap.sql` | Add AI message history and permit pre-application documents. |
| `005_profile_bootstrap_policy.sql` | Allow owner-only recreation of a missing profile. |
| `006_storage_validation_policies.sql` | Enforce allowed MIME types and the 10 MB limit in Storage RLS. |
| `007_ai_message_ownership_policies.sql` | Bind AI messages to their authenticated owner session. |

All required migrations have been applied safely to the RAD Supabase project. No user data was deleted.

## Auth status

Supabase Auth is wired through `AuthRemoteDataSource`, `AuthRepositoryImpl`, `AuthController`, and existing GoRouter guards. Signup supports email confirmation by returning an unauthenticated pending session rather than fabricating a logged-in user. Session restoration uses the Supabase session, and local storage is used only as a verified session snapshot cache.

## Application and profile status

Application listing, creation, and status updates use Supabase with owner scoping. Profile reads and updates use `profiles`; missing profiles are created using the authenticated user’s actual ID and account contact data. Development and production no longer use fabricated identity records.

## Document status

The document UI retains its current presentation structure but now opens the native/web file picker. It validates file presence, supported extension, content type, and size, uploads bytes to private Supabase Storage, persists metadata, and refreshes the document with a signed URL. Upload failures are surfaced to the user and do not mark a document uploaded.

## AI session foundation

The existing AI provider abstraction remains unchanged. `AiSessionRepository` now creates sessions, lists the authenticated user’s sessions, persists user and assistant messages, updates question counts, and restores the latest session history. The AI provider itself remains a placeholder because Project 05 does not select or hardcode an AI vendor.

## Validation

The final release validation target is:

- `dart format .` — completed on changed Dart files.
- `flutter analyze` — **PASS: No issues found.**
- `flutter test` — **PASS: all tests passing.**
- `flutter build web` — **PASS: successful production build.**
- `git diff --check` — **PASS.**
- Supabase security advisors — **no findings.**
- Supabase tables — RLS enabled and relationships verified.
- Storage — private bucket and owner policies verified.

## Known limitations

The AI response service remains a provider placeholder; only session and message persistence is production-ready. OCR and document analysis are not implemented. Visa catalog content remains application-owned static content because Project 05 does not introduce a new visa catalog schema. Flutter WebAssembly dry-run notices from `flutter_secure_storage_web` may remain, but they do not affect the standard web build.
