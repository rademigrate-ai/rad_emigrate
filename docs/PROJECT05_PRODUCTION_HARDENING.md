# PROJECT 05 — Production launch hardening

## Scope and baseline

- Repository: `rademigrate-ai/rad_emigrate`, branch `main` at the PROJECT 04
  checkpoint `4eeccb173fe06bb09bec38c3bd1a70797b2f57cf`.
- Project 04 architecture remains Flutter, feature-first layers, Riverpod,
  GoRouter, repositories, datasources, and Supabase.
- Local validation environment: Flutter 3.47.5, Dart 3.13.4.
- Supabase: RAD (`inshddthftkhcdosoqcn`), `eu-west-1`, PostgreSQL 17.11.0.002.
- The live domain tables were empty at audit time. The production-like database
  was not populated with fabricated users or records for this audit.

## Database audit and migrations

Live tables inspected: `profiles`, `applications`, `documents`, `ai_sessions`,
and `ai_session_messages`. All have RLS enabled. The actual signup trigger is
`auth.on_auth_user_created`; `public.handle_new_user()` is SECURITY DEFINER,
owned by `postgres`, inserts only a qualified `public.profiles` row, and now has
an empty `search_path`. Anonymous and authenticated execute privileges are
revoked from that function. No other public RPC functions or Edge Functions
were present.

The PROJECT 05 migrations applied to RAD and checked in here are:

- `20261001214952_project05_launch_hardening.sql`: minimize table grants,
  constrain document/application ownership, ensure AI messages belong to an
  authenticated user's session, clean duplicate legacy storage policies, and
  harden the signup function search path.
- `20261001215315_project05_storage_upload_limits.sql`: enforce a maximum
  10 MiB object size and the PDF/JPEG/PNG MIME allowlist in the authenticated
  Storage insert policy.
- `20261001215758_project05_minimize_table_privileges.sql`: remove direct
  authenticated DELETE grants from profiles, applications, and AI sessions.

The live migration history has 11 entries, including these three. The four
legacy SQL files in the repository do not reproduce the full set of eight
PROJECT 04 migration records on RAD. That pre-existing drift was retained
without rewriting prior production history; the PROJECT 05 SQL above is
versioned and matches its live migration versions.

Authenticated role grants now match needed operations: profiles/applications/
AI sessions SELECT/INSERT/UPDATE; documents SELECT/INSERT/UPDATE/DELETE; AI
messages SELECT/INSERT/UPDATE/DELETE. No `PUBLIC` or `anon` table grants remain
on these five tables. RLS policies bind each row to `auth.uid()` and AI messages
also require their parent session to have that owner. Documents with an
`application_id` must reference an application owned by the same user.

The Storage bucket `documents` is private. Policies are restricted to the
`authenticated` role and a first path segment equal to `auth.uid()`. Client
uploads use `user_id/<document>/<unique suffix>/<normalized filename>`, disable
overwrite, clean up a newly uploaded object if metadata persistence fails, and
best-effort delete the replaced object after metadata commit. Signed URLs are
created only on explicit request after verifying the authenticated user's path,
and expire after 10 minutes. Listing document metadata no longer creates a
signed URL per row; cached metadata never includes a signed URL.

**Remaining storage setup:** live bucket `file_size_limit` and
`allowed_mime_types` are both NULL. The connector used here cannot update bucket
settings, and Supabase advises treating Storage schema rows as read-only, so the
bucket settings were not altered with SQL. The storage RLS policy checks size
and MIME metadata, while the app independently validates size and extension.
Before public launch, set the bucket-level maximum to 10 MiB and allowed MIME
types to `application/pdf`, `image/jpeg`, and `image/png` in Supabase Storage
settings, then re-read the bucket values. Runtime upload tests with real user
tokens were not available.

The Supabase security advisor reported zero lints after the changes. The
performance advisor reported 10 unused indexes on empty tables (informational,
not removed without workload evidence). The previously missing message-owner
index was added. Cross-account runtime access tests were not run because no
isolated test JWT/account was available. Policy and grant inspection is not
represented as a runtime penetration test.

The eight remote PROJECT 04 migrations are named in the production history,
while only four differently numbered legacy SQL scripts are present locally.
The three new migration files correspond exactly to their remote names and
versions. This history mismatch remains documented rather than reconstructed.

## Authentication and profile lifecycle

One bootstrap provider initializes Supabase, restores the auth session, and
subscribes once to auth-state changes. It ignores the initial-session event to
avoid duplicate restore calls, uses a revision guard against stale async event
results, and cancels the subscription when disposed. Restored sessions read the
own profile's `full_name` so profile-completion routing survives app restarts.
Logout resets controller state even when the network operation errors. A
missing profile stays missing; the UI no longer invents a demo profile ID.

Production disables mock/offline auth, profile, application, and document
fallbacks. Sign-in takes an email and password. Signup routes to profile
completion when Supabase returns a session, otherwise to the email confirmation
code screen. Phone OTP is not implemented; the unsupported login OTP entry and
hard-coded demo credentials were removed. Supabase auth provider settings,
email confirmation behavior, redirect allowlists, password policy, and rate
limits could not be inspected through the available connector. They must be
checked in the project dashboard before launch.

No real-user sign-in, profile CRUD, or refresh-token expiry integration test was
performed. Those flows were reviewed in code; the database had no domain rows.

## Documents and AI persistence

Document selection now uses the platform file picker and bounded stream reads,
validates PDF/JPG/JPEG/PNG, rejects empty or greater-than-10-MiB files, normalizes
filenames, and uploads binary content through the repository/datasource/storage
boundary. The app persists only the private object path as metadata and displays
upload progress/errors. Binary upload code is REAL; a live authenticated upload
was not executed in this environment. There is no OCR, virus scanning, or
document processing.

AI persistence remains a session/message foundation only. Session creation and
message history use Supabase; the message RLS checks session ownership. The app
does not connect to an AI provider and does not provide generated AI answers.
No live AI persistence test was performed.

## Environments, secrets, and errors

`AppConfig.fromBuildEnvironment()` is the single environment source. Debug
defaults to development; release defaults to production; unknown values throw.
Pass `APP_ENV=development|staging|production` explicitly for deployments.
Supply `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define`; these are the
public client URL/key. Never define a service-role key, database password, or
private server key in a Flutter build. `.env.example` is a reference template,
not a file that Flutter loads automatically. No secrets were added.

Remote Auth, PostgREST, and Storage errors map to generic user-facing messages.
Network logs contain method/status/type only, omit request URLs and bodies, and
are disabled in production. There is no paid telemetry provider. For future
monitoring, attach a privacy-reviewed Flutter error reporter at the app-level
error boundary and scrub user, token, and document fields first.

## Performance, web, accessibility, and CI

Remote application/document lists are bounded to 100 rows. Duplicate auth
restoration is avoided. Document list reads no longer make per-row signed URL
requests. HTTP debug logging omits URLs that might carry identifiers.
Upload/auth form errors use live-region semantics; upload buttons show progress
and become disabled while work is in progress. Flutter Web builds to the
provider-neutral `build/web` directory. No hosting provider was selected, and no
deployment was performed.

`.github/workflows/ci.yml` checks Flutter 3.47.5 on pull requests and pushes to
main: dependency resolution, formatting, analysis, tests, web build, and diff
whitespace. It contains no credentials. To deploy, configure the three public
dart-defines in the chosen host's build environment and publish `build/web` with
SPA fallback to `index.html`; add the host origin to Supabase Auth redirect
allowlists after selecting that host.

## Dependency and migration notes

`file_picker 11.0.3` was added to support real uploads with stream reads. Existing
Flutter/Riverpod/GoRouter/Supabase major versions were not mass-upgraded.
`flutter pub outdated` is informational only; incompatible/newer major versions
are deferred pending a separate compatibility review.

## Ten audit categories

1. **Architecture/dependency direction — PASS.** Upload UI calls controller,
   repository, datasource, and storage service; frozen architecture remains.
2. **Auth/session lifecycle — REVIEWED; live token scenarios unverified.** One
   auth owner/listener, initial restore, signed-out state, and revision guard are
   implemented. No live expired-token test was possible.
3. **Database/RLS — POLICY REVIEW PASS; runtime isolation unverified.** Grants,
   RLS predicates, policies, function, and advisor were inspected. No separate
   user JWT identities were available for adversarial reads/writes.
4. **Storage/upload — CODE/POLICY REVIEW PASS; live access unverified.** Private
   bucket and owner path policies confirmed; live bucket size/MIME values remain
   unset and require dashboard configuration before launch.
5. **Profile/application/document integrity — REVIEWED; live CRUD unverified.**
   Missing data is no longer fabricated, owner checks are in place, queries are
   bounded; RAD domain tables contained zero rows.
6. **Routing/state/races — CODE REVIEW PASS.** Bootstrap controls splash/guards,
   profile completion is restored from the profile row, and stale auth event
   results are suppressed. No browser auth-session integration test.
7. **Environment/secrets — PASS.** Release defaults to production and unknown
   environment names fail; secret scan was reviewed and no server keys added.
8. **Tests/failure paths — UNIT TESTS PASS; integration gaps remain.** 24
   deterministic tests pass, including upload validation and config behavior.
   No live Supabase JWT/storage integration tests.
9. **Performance/accessibility/web — PARTIAL.** Bounded reads, no list-time
   signed-URL fanout, keyboard-usable native controls, feedback semantics; web
   build can be verified locally. No manual multi-browser or screen-reader run.
10. **Release/docs/repository — REVIEWED.** CI/deployment instructions and this
    audit are present. Remote publication and tag verification are reported in
    the release record, not assumed here.

## Validation evidence and current limits

On the Windows workstation, Flutter 3.47.5 and Dart 3.13.4 are installed.
`flutter pub get` resolves and downloads dependencies but exits nonzero because
this Windows environment has plugin symlink support disabled (Developer Mode
is off). Analysis, tests, and web build can run with the resolved package
configuration using `--no-pub`. GitHub Actions uses Ubuntu and executes the full
`flutter pub get` gate. Android command-line tools/ADB and Visual Studio desktop
build tools are absent; web is the target validated here.

Final local validation on the release candidate:

| Check | Result |
| --- | --- |
| `flutter clean` | PASS |
| `flutter pub get` | FAIL in this Windows environment: plugin symlink support requires Developer Mode; dependency resolution and downloads completed |
| `dart format --set-exit-if-changed lib test` | PASS, 107 files checked, 0 changed on final run |
| `flutter analyze --no-pub` | PASS — No issues found |
| `flutter test --no-pub` | PASS — all 24 tests passed |
| `flutter build web --no-pub --dart-define=APP_ENV=production` | PASS — `build/web` created; secure-storage WebAssembly dry-run notices remain |
| `git diff --check` | PASS — no whitespace errors |
| Supabase security advisor | PASS — zero lints after all three migrations |
| Supabase performance advisor | INFO — 10 unused indexes on the currently empty domain tables |

The Windows `flutter pub get` issue is environment-specific; CI runs on Ubuntu
and performs the full dependency-resolution gate. Android SDK command-line
tools/ADB and Visual Studio desktop build tools are absent, so Android and
Windows desktop builds were not verified. The `project-05-final` Git tag,
remote commit, and published CI result are recorded only after GitHub verifies
them.
