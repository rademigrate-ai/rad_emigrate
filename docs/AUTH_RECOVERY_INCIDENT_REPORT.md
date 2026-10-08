# Production Authentication Recovery Incident Report

**System:** RAD Emigrate

**Production application:** `https://rad-emigrate.onrender.com`

**Supabase project:** `inshddthftkhcdosoqcn` (RAD, `ACTIVE_HEALTHY`)

**Investigation baseline:** GitHub `main` and deployed `version.json` both report `0982926784a17968541cc0530b41879c50cbba9f`.

## Executive status

**Code remediation and automated validation are complete locally on `hotfix/production-auth-recovery-e2e`; the branch awaits review through a pull request.** No production database rows, Auth users, passwords, RLS policies, SMTP settings, Render settings, deployment, merge, or production data were changed during this investigation.

The repository and deployed bundle contain a confirmed recovery-redirect defect. The full live password-recovery flow, actual Supabase Auth URL settings, SMTP configuration, and successful production login remain **BLOCKED** pending authorized dashboard/Render access and a controlled test mailbox/account.

## Confirmed findings

### 1. Recovery redirect defect — confirmed

The deployed commit contains literal `\n` text inside a Dart `//` comment in `AuthRemoteDataSource.requestPasswordReset`. Because Dart treats the whole physical line as a comment, the `redirectTo = '$origin/#/reset-password';` assignment is commented out rather than executed.

**Effect:** `resetPasswordForEmail` receives a null `redirectTo`, so Supabase falls back to its project default Site URL. If that setting was previously localhost, the observed localhost recovery links follow directly from this defect.

### 2. PKCE/recovery-state handling was incomplete — confirmed

The app used Supabase Flutter `2.18.0`, whose GoTrue client defaults to PKCE, but did not explicitly configure that flow or record the required `PASSWORD_RECOVERY` event. The reset page allowed `updateUser(password: ...)` whenever there was any active session, without proving that the UI had been entered through a recovery event.

**Effect:** The UI could not reliably distinguish a valid recovery callback from direct navigation, expired links, or an ordinary authenticated session.

### 3. Current production bundle uses the intended Supabase project — confirmed

The deployed `main.dart.js` contains the expected project hostname `inshddthftkhcdosoqcn.supabase.co`; the app loads the current login view; and the deployed build identity reports the same SHA as GitHub `main`.

The browser had no controlling service worker during inspection. Cloudflare responses were cached for up to 300 seconds, but the checked bundle and `version.json` are from the cited hotfix SHA.

### 4. Existing accounts are structurally valid — confirmed, anonymized

| State | Result |
|---|---:|
| Auth users | 4 |
| Email-confirmed users | 4 |
| Active, not banned, not deleted | 4 |
| Users with non-empty password credentials | 4 |
| Email identities | 4 (`email`) |
| Users without identity | 0 |
| Users without profile | 0 |
| Profiles without Auth user | 0 |
| Case-insensitive duplicate email groups | 0 |
| Emails with outer whitespace | 0 |
| SSO or anonymous users | 0 |

The four users were created in two cohorts (2026-10-03 and 2026-10-07). Their Auth metadata and identity providers indicate the email provider. This evidence does **not** support a missing-password-credential, import-without-password, orphan-profile, duplicate-identity, email-confirmation, ban, or deletion root cause.

### 5. Profile bootstrap and RLS remain intact — confirmed

- `auth.users` has the enabled `on_auth_user_created` trigger calling `public.handle_new_user()`.
- All four users have matching profiles.
- `profiles` row-level policies restrict select/insert/update to the authenticated row owner (`auth.uid() = id`).
- Profile roles are present in the existing data (two `super_admin`, two `user`).

No RLS weakening or role change is required for this recovery remediation.

### 6. Fresh Auth log evidence separates localhost from Render traffic — confirmed

In the last 24-hour Supabase Auth log window, all observed `/token` attempts and recovery-rate-limit events have `http://localhost` referrers:

| Endpoint / outcome | Count | Referrer bucket |
|---|---:|---|
| `/token` 200 | 24 | localhost |
| `/token` 400 `invalid_credentials` | 16 | localhost |
| `/token` 500 `unexpected_failure` | 1 | localhost |
| `/recover` 200 | 2 | localhost |
| `/recover` 429 `over_email_send_rate_limit` | 5 | localhost |
| `/signup` 429 | 3 | localhost |
| `/otp` 429 | 1 | localhost |

The aggregated log count includes 152 Auth entries, 48 error-related entries, 16 `invalid_credentials` entries, and 9 mail/OTP rate-limit entries.

**Interpretation:** Fresh evidence does not show a Render-originated password-login failure in this 24-hour window. The historical `invalid_credentials` and `over_email_send_rate_limit` events are confirmed local-test traffic, not evidence that production Render attempted the same calls. This does not prove Render login works; it means a controlled production test is still necessary before attributing password failures to deployed code or Auth data.

## Code remediation

The hotfix branch makes these focused changes:

1. Restores an executable password-recovery redirect with the precise hash route:
   `https://rad-emigrate.onrender.com/#/reset-password`.
2. Pins Supabase Flutter to `AuthFlowType.pkce`, matching the SDK-supported recovery-code exchange flow.
3. Records only `AuthChangeEvent.passwordRecovery` as a recovery marker and persists the marker only for the matching live Auth user, preserving a valid recovery flow across refresh while not treating it as authorization.
4. Refuses password-update UI on `/reset-password` unless that marker matches a live Supabase session; invalid or expired links receive a safe recovery message and route back to requesting a new link.
5. Clears the recovery marker on sign-out, ordinary sign-in, user update, failed session reconciliation, and after a successful password change.
6. Handles `over_email_send_rate_limit` safely, displays localized retry guidance in English and Persian, and imposes a 60-second client-side resend cooldown after a rate-limited response.
7. Adds unit/widget regression coverage for recovery redirect construction, rate-limit classification, persisted recovery-session gating, route behavior, and duplicate recovery-request blocking.

No user password is logged, stored by the application, transformed, trimmed, migrated, or reset by these changes.

## Authoritative implementation references

- [Supabase password-based Auth documentation](https://supabase.com/docs/guides/auth/passwords) requires a configured `redirectTo` value that targets a public reset route, does not reveal whether an account exists, and requires an authenticated session before `updateUser` changes a password.
- [Supabase redirect URL documentation](https://supabase.com/docs/guides/auth/redirect-urls) states that Site URL is used when `redirectTo` is absent, production redirect paths should be exact, and custom email templates using `redirectTo` may need `{{ .RedirectTo }}` rather than `{{ .SiteURL }}`.
- [Supabase PKCE documentation](https://supabase.com/docs/guides/auth/sessions/pkce-flow) states that an authorization code is single-use, valid for five minutes, and must be exchanged on the same browser/device that initiated the flow.

## Configuration matrix

| Layer | Verified current state | Intended requirement | Status |
|---|---|---|---|
| GitHub `main` | `0982926784a17968541cc0530b41879c50cbba9f` | Hotfix PR based on current `main` | Verified |
| Render deployed build | Public `version.json` reports the same SHA and Flutter 3.47.6 | Deploy only validated PR merge/commit | Verified SHA; no new deployment performed |
| Render build command | Repository blueprint: `bash scripts/build_web_render.sh` | Use script so Dart defines are injected at Flutter build time | Repository verified; live dashboard unverified |
| Render environment | Repository requires `APP_ENV`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | Non-empty build-time values only; no service-role key | Live dashboard blocked |
| Deployed Flutter bundle | Contains the intended Supabase project hostname and reset route; no controlling service worker | Intended production project and hash routing | Verified |
| Supabase project | `inshddthftkhcdosoqcn`, `ACTIVE_HEALTHY` | Intended production project | Verified |
| Supabase Site URL / redirect allow-list | Not accessible in this sandbox | Production Site URL and approved production recovery redirect | Blocked |
| Supabase email templates / SMTP | Not accessible in this sandbox | Production-safe templates and mail capacity configured for expected usage | Blocked |

## Required authorized operator configuration review

No dashboard setting should be changed blindly. The authorized operator should inspect and, where needed, correct the following in **Supabase Dashboard → Authentication**:

1. **URL Configuration**
   - Site URL: `https://rad-emigrate.onrender.com`
   - Allowed redirect URLs: retain only required development entries and the exact production callback route `https://rad-emigrate.onrender.com/#/reset-password`. Do not retain a broad production wildcard unless another documented flow genuinely requires it.
2. **Email templates**
   - Review recovery and confirmation templates for hard-coded localhost values.
   - Confirm that template redirect handling uses the configured production Site URL/allowed redirect mechanism. If a custom template must honor `redirectTo`, verify its use of `{{ .RedirectTo }}` rather than blindly hard-coding `{{ .SiteURL }}`.
   - Do not expose recovery tokens in page content, logs, or analytics.
3. **Authentication settings**
   - Confirm email/password provider is enabled and the project’s recovery flow is compatible with PKCE.
   - Enable leaked-password protection unless a documented compatibility reason prevents it; the current Supabase advisor flags it as disabled.
4. **Email delivery**
   - Inspect default-provider limits, recovery resend cooldown, delivery/bounce data, and sender authentication.
   - If expected password-recovery volume exceeds the platform’s default email capability, configure a supported custom SMTP provider with verified SPF/DKIM/DMARC. Keep SMTP credentials in the dashboard only—never in this repository, Flutter defines, logs, or CI.
5. **Render static-site build settings**
   - Confirm `bash scripts/build_web_render.sh`, `build/web`, and `/* → /index.html` rewrite.
   - Confirm `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `APP_ENV=production` are build environment values. Flutter `String.fromEnvironment` does not read runtime-only variables after compilation.

## Completed automated validation

| Check | Result |
|---|---|
| `flutter analyze` | Passed with no issues |
| Full `flutter test` suite | Passed: 202 tests |
| New targeted recovery regression coverage | Passed: redirect construction, throttling classification/cooldown, recovery-session gate state, persistence, and route behavior |
| Release script web build | Passed with `APP_ENV=staging`, the intended Supabase project URL, and a non-secret placeholder publishable key |
| Generated web artifacts | `index.html`, `main.dart.js`, and `version.json` are present and non-empty; local HTTP checks returned 200 for each |
| Localization source JSON | English and Persian ARB files parsed successfully |
| Diff whitespace validation | Passed (`git diff --check`) |
| Android build | Not run: Android SDK is absent from this sandbox; no APK/AAB claim is made |

The web build emitted existing WebAssembly dry-run compatibility warnings from `flutter_secure_storage_web`; these do not prevent the JavaScript web build and are outside this authentication remediation.

## Validation plan before release

Use a new controlled mailbox and controlled test accounts only. Do not use or request customer passwords.

| Scenario | Evidence required before PASS |
|---|---|
| Existing authorized regular account | Correct password signs in from Render, session persists after refresh, role-appropriate route loads |
| Existing authorized admin account | Correct password signs in from Render and authorized Admin route loads |
| New controlled registration | Account, Auth identity, and profile trigger are created correctly; email confirmation is received and completed |
| Recovery request | One controlled request is accepted without leaking account existence; rate-limit message and cooldown are clear when triggered |
| Recovery email | Actual controlled mailbox receives a production-domain link with no localhost destination |
| Recovery callback | Link opens `https://rad-emigrate.onrender.com/#/reset-password`; PKCE session is established and refresh survives |
| Password change | New password works; old password fails; recovery state clears afterward |
| Negative recovery paths | Direct reset route and expired/used link show a safe actionable error and cannot submit a new password |
| Logout/session | Logout clears the client session; protected direct links redirect appropriately |
| RTL/LTR and mobile | Persian RTL and English LTR recovery screens, plus mobile web/Android supported paths, behave correctly |

## Rollback

This hotfix contains no database migration. If a post-merge build fails or a regression is detected, redeploy the previous Render build at SHA `0982926784a17968541cc0530b41879c50cbba9f` or revert the hotfix commit, then repeat the controlled authentication smoke tests. Do not reset production Auth data or alter password hashes as a rollback mechanism.

## Outstanding blockers

1. Render connector authorization was declined, so the live service configuration, deploy logs, and build environment cannot be independently inspected.
2. The Supabase dashboard is not authenticated in the sandbox; the MCP access available for this task does not expose Site URL, redirect allow-list, email templates, SMTP, or provider configuration.
3. No controlled mailbox or authorized test credentials were supplied. A real recovery email, correct-password login, admin login, replacement-password login, and old-password rejection therefore cannot be verified without a narrowly approved controlled test plan.
4. Android build validation depends on Android SDK/keystore availability and remains to be reported separately from web-auth validation.
