# AUTH-REDIRECT-01 — production recovery callback reconciliation

**Baseline:** 2026-10-17, `main` 449cd3b6cb0a0b53e852015ad4a3648bd817ad65.
**Umbrella tracking:** #57 (47 acceptance gates).

## Owner-verified Supabase Auth URL configuration
- Site URL: `https://rad-emigrate.onrender.com`.
- Only permitted Redirect URL: `https://rad-emigrate.onrender.com/#/reset-password`.
- The previously deployed app generated `https://rad-emigrate.onrender.com/reset-password`, which did not match the supplied allowlist.
- These settings were reported by the authorized owner, **not independently read** through the Supabase connector.

## Scoped remediation (no dashboard change)
1. Build recovery `redirectTo` as the exact currently allowlisted `/#/reset-password` URL, based on the browser origin.
2. Before Flutter bootstraps path-based GoRouter and Supabase PKCE detection, convert **only** a `#/reset-password` link into `/reset-password` using `history.replaceState`.
3. Preserve PKCE `?code` whether it appears before or after the legacy hash, plus legacy fragment tokens. Do not log or store tokens.
4. Keep other routes and the path URL strategy unchanged.

## Local evidence
- `node scripts/check_password_recovery_redirect.cjs`: 8 positive/negative scenarios PASS.
- `flutter test test/core/password_recovery_test.dart`: 4 tests PASS.
- `git diff --check`: PASS.
- GitHub CI on the PR HEAD, browser/real-mail end-to-end testing, and Render rewrite confirmation remain release gates.

## Not verified or authorized
- No Supabase Auth allowlist, SMTP/template, database, Auth user, or Render change was made.
- Tests do **not** establish that a production recovery email delivers successfully, a PKCE session is created from a live email link, or a password is actually changed.
- Before deployment, verify Render rewrite `/* → /index.html`, test a controlled mailbox through the end-to-end recovery flow, and verify used/expired links are safely rejected.
- Long-term simplification is possible by separately allowing the canonical `/reset-password` URL in Supabase and removing the legacy shim only after all existing emailed links have expired.
