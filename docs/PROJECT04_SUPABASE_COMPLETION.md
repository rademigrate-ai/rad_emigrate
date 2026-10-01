# Project 04 — Supabase Backend Completion

**Repository:** `rademigrate-ai/rad_emigrate`  
**Branch:** `main`  
**Supabase project:** `RAD` / `inshddthftkhcdosoqcn`  
**Region:** `eu-west-1`

## Architecture changes

- Added `supabase_flutter`.
- Added compile-time `SUPABASE_URL` and `SUPABASE_ANON_KEY` configuration.
- Added guarded Supabase client initialization during app bootstrap.
- Added private Storage service and Riverpod providers.
- Connected auth, profile, application, and document datasources to Supabase while preserving repository/controller interfaces.
- Added AI session/message persistence foundation without implementing an AI model.
- Preserved Riverpod, GoRouter, feature separation, existing UI, and design system.

## Database and storage

- Preserved existing `profiles`, `applications`, `documents`, and `ai_sessions` tables.
- Added `ai_session_messages` for durable assistant history.
- Added supporting ownership/time indexes.
- Created or verified the private `documents` bucket.
- Added owner-scoped read/upload/delete Storage policies.

## Security changes

- Hardened `public.handle_new_user()` with `search_path = public`.
- Revoked exposed execute permissions from `anon` and `authenticated` while preserving signup-trigger execution.
- Replaced broad owner policies with explicit operation-specific RLS policies.
- Applied owner checks to profiles, applications, documents, AI sessions, and AI messages.
- No service-role secret is present in the repository.

## Environment setup

Run with public client configuration supplied at runtime/build time:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key>
```

See `docs/PROJECT04_IMPLEMENTATION.md` and `.env.example`.

## Deployment notes

- Supabase migrations are stored under `supabase/migrations/`.
- Do not commit `.env` files or service-role keys.
- Production uses Supabase-only behavior through `AppConfig.isProduction`.
- Development may retain the existing local fallback when no Supabase configuration is supplied.

## Known limitations

- The current document UI still uses a simulated mark-uploaded action because no binary picker was part of the preserved presentation contract. The private Storage service is ready for the next UI step.
- AI responses remain placeholders; only session and message persistence was added.

## Validation target

- `flutter analyze` — no issues found
- `flutter test` — all tests passing
- `flutter build web` — successful build
- Git working tree — clean after commit and push
