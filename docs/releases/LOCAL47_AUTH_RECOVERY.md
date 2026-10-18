# Disposable mailbox authentication verification

2026-10-18; [machine report](local47_auth_recovery.json). `scripts/verify_local47_auth_recovery.py` passed five grouped backend flows against only owned Supabase API `127.0.0.1:55321` and Mailpit `127.0.0.1:55324`:

- Actual password signup creates a user profile and ignores a caller-supplied `super_admin` metadata role.
- Recovery email arrives in the local mailbox; the allowed reset redirect and account identity are preserved. Forged tokens, unauthenticated password changes and consumed-link replay are denied.
- A recovery session replaces the password: old credentials fail, new credentials work, session refresh preserves identity, and global logout revokes refresh.
- Ageing only a synthetic account's `recovery_sent_at` by two hours denies the expired recovery token. An unapproved redirect resolves to the local site and never an external host. Verification redirects are inspected without following them.
- Passwordless email verification binds the correct account and denies forged OTP and consumed-token replay.

Three synthetic users and three owned mailbox messages were removed. No credentials, tokens, message bodies, email addresses or real user data are persisted in the report. The runtime ownership marker and exact loopback target are checked before any request. No production Auth/configuration or external email service was changed.

The default local CLI disables email confirmation for signup. This test explicitly records that limitation; it does not establish confirmed-signup delivery, Flutter browser deep-link navigation, real-mailbox deliverability, SMS, native links or production session configuration. Those gates remain open. Accepted count remains **3/47**, release **NO-GO**.

Reproduce using installed native CLI/psql paths: `python scripts/verify_local47_auth_recovery.py --supabase <supabase.exe> --psql <psql.exe> --report <report.json>`. Sources checked: [Supabase password/recovery and local Mailpit](https://supabase.com/docs/guides/auth/passwords), [email passwordless](https://supabase.com/docs/guides/auth/auth-email-passwordless), [Auth REST schema](https://github.com/supabase/auth/blob/master/openapi.yaml), and [Mailpit API](https://mailpit.axllent.org/docs/api-v1/).
