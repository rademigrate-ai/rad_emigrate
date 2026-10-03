# Project 04 — RAD Emigrate Supabase Implementation

## Scope

Project 04 moves the existing RAD Emigrate Flutter application from mock/API-shaped transport boundaries to a Supabase production foundation. The presentation layer, Riverpod state management, GoRouter, repository interfaces, and existing design system remain unchanged.

Supabase project: **RAD** (`inshddthftkhcdosoqcn`) in `eu-west-1`.

## Architecture

```text
Flutter UI
  ↓
Riverpod controllers
  ↓
Domain repositories
  ↓
Feature datasources
  ↓
Supabase Auth / Postgres / Storage
```

Local storage caches a verified Supabase session snapshot. Missing Supabase configuration or remote authentication failures surface as errors; the current runtime has no local/demo identity fallback.

## Flutter setup

The official `supabase_flutter` SDK is used. Configuration is compile-time only:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key>
```

Only a public publishable/anon key is supported. A service-role key must never be shipped to Flutter or committed to the repository. See `.env.example` for the variable names.

Key files:

- `lib/core/supabase/supabase_config.dart` — compile-time environment values
- `lib/core/supabase/supabase_client.dart` — guarded client initialization
- `lib/core/supabase/supabase_storage.dart` — private document bucket boundary
- `lib/core/supabase/supabase_providers.dart` — Riverpod service providers

## Database structure

Existing tables were preserved:

- `profiles` — one row per `auth.users` record
- `applications` — user-owned visa applications
- `documents` — user-owned document metadata and private storage path
- `ai_sessions` — user-owned assistant session counters

Project 04 adds `ai_session_messages` for durable assistant history. Existing foreign keys and indexes remain in place; additional ownership/time indexes were added.

## Migrations

- `001_security_hardening.sql` — sets the signup trigger search path and revokes public execute access.
- `002_rls_policies.sql` — replaces broad owner policies with explicit operation-specific policies.
- `003_storage_policies.sql` — creates/keeps the private `documents` bucket and owner path policies.
- `004_ai_sessions_and_document_bootstrap.sql` — adds message history and permits document metadata before application linkage.

The migrations are also applied to the RAD Supabase project.

## Authentication

`AuthRemoteDataSource` now supports Supabase email/password sign-in, sign-up, sign-out, session restore, email OTP verification, and profile completion. `AuthRepositoryImpl` and `AuthController` remain the public contracts consumed by the existing UI. Supabase session restoration runs during app bootstrap through `currentSession`.

## Feature repositories

- **Profile:** reads/upserts `profiles` with `full_name`, email, phone, and country.
- **Applications:** lists/inserts/updates `applications` with owner scoping and maps database statuses to the existing domain enum.
- **Documents:** reads/upserts document metadata and resolves private `file_path` values through signed URLs.
- **AI sessions:** exposes create session, save message, and history methods; the placeholder AI service remains intentionally unchanged.

## Security rules

- RLS is enabled on every application table.
- Every public-table policy uses `auth.uid()` ownership checks.
- Users cannot read or mutate another user's profile, application, document, session, or message.
- The `documents` bucket is private.
- Storage paths must begin with the authenticated user's UUID.
- `handle_new_user()` keeps its signup-trigger behavior, uses `search_path = public`, and is no longer executable through exposed anonymous/authenticated RPC access.
- No service-role key or secret is stored in source control.

## Local development

1. Copy `.env.example` values into your local run configuration, not into Git.
2. Run `flutter pub get`.
3. Start with the three `--dart-define` values above.
4. Use the existing development fallback when intentionally running without Supabase credentials.
5. Run `flutter analyze`, `flutter test`, and `flutter build web` before pushing.

## Known limitations

- The existing document screen still presents a simulated “mark uploaded” interaction because the product UI does not currently provide a binary file picker. The Storage service and private bucket are ready for the next UI-authorized upload step.
- The AI response service remains a placeholder; Project 04 only persists session/message history.
- Email confirmation and password-reset UX remain dependent on Supabase Auth project settings and are not redesigned in this backend-only project.
