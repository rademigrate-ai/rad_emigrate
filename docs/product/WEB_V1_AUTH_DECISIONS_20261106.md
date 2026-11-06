# RAD Emigrate — Web V1 Authentication Product Contract

Status: **Approved product decisions; implementation NOT complete**.
Recorded: 2026-11-06. Parent code baseline: PR #89 at \`b2ebfd6b894fd006ac890a16743669e8782a9d9d\`.
This document does not authorize deployment, database modification, migration application, or merge.

## Approved user journey

1. Home and public browsing are available to guests. When a protected action requires sign-in, preserve its exact **known, internal** path, query, and meaningful fragment for post-auth continuation.
2. Present **mobile first** with email as an alternative. Sign-in and sign-up are **one unified entry flow**. Do not reveal account existence to an unauthenticated caller.
3. Both verified mobile and email may be used with **OTP** or with the **account's one password**, if set. Password sign-in normally needs no second OTP; sensitive operations require server-enforced reauthentication.
4. New accounts: **verify OTP first**, optionally offer password creation, then require **first and last name** before protected features. Other profile fields are optional.
5. The second communication method is optional. Connect it to the same stable auth user only after verifying current-account authority, new-channel ownership, and uniqueness. Never auto-merge two pre-existing accounts.
6. After sign-in, OTP, optional password setup, and required profile completion, return to the exact authorized original page/action. Fall back to \`/dashboard\` when no safe valid destination exists. Preserve form-specific pending action only with a safe, owner-bound continuation mechanism.
7. Account security includes changing credentials and contacts with reauthentication, safe recovery through verified channels, and a supported non-automatic recovery review process when all channels are lost.
8. Full device/session management: identify the current session, list genuinely known sessions with trustworthy metadata, revoke one selected session, revoke others, or revoke all. Avoid unverified geo/device labels.
9. Account deletion request: **immediately deactivate normal access**, allow **7 days to cancel** through a narrowly scoped authenticated path, then run controlled deletion/anonymization with auditable results. Legally mandated retention, active-case obligations, storage ownership, backups, and exact deletion timeline need legal/operational approval. Seven days is a cancellation window, not a guarantee that every backup disappears in seven days.

## Verified baseline gaps (2026-11-06)

- Login UI validates **email only**, and password is required on the password path; the OTP option also insists on email.
- Registration UI requires **email + phone + password**; mobile is passed as metadata rather than necessarily becoming a verified Auth identity.
- OTP screen and auth router originally rejected mobile identifiers; transport has a partial SMS implementation but service readiness is not verified.
- Supabase password login only provided email, despite documented support for phone/password.
- Profile completion currently takes \`fullName\` rather than two required fields.
- \`profiles.email\` and \`profiles.phone\` updates do not, by themselves, modify verified Supabase Auth identities.
- No confirmed complete per-session inventory/revocation UI and server authorization, seven-day deactivation/deletion worker, or safe no-channel recovery process.
- Exact Visa detail continuation was disallowed by return-destination allowlist, even though routes existed.

## This initial code change

- Adds mobile/email and OTP/password selection to unified Login Web UI, defaulting to mobile OTP. Register/signup URLs render this same unified entry screen; older RegisterPage remains in visual QA only.
- Backend accepts E.164 mobile/password and unified sign-up by OTP; **SMS delivery and live verification remain unverified**.
- OTP verification UI validates E.164 and Iran-local mobile identifiers in addition to email.
- Email sign-up requires a configured six-digit OTP email template; this branch does not enable or modify hosted configuration.

- Accept phone-shaped OTP route context without redirecting it to login.
- Preserve known nested Visa URLs as safe return destinations (with tests) while rejecting unknown and external return paths.
- **Not complete:** live SMS provider, complete email OTP template and delivery verification, optional post-OTP password onboarding, first/last-name profile split and storage, identity linking, session management, secure recovery, account deletion, legal/retention approvals, and end-to-end UAT.

## Acceptance gates for future implementation

- End-to-end verified email OTP, SMS OTP, email/password, phone/password with existing/new accounts and no duplicate/auto-merged identities.
- OTP limits, expiration, retries, enumeration protection, rate limiting; verified real provider and email template.
- User-scoped RLS/authorization and session-ID fences for sensitive operations; no service-role key in Web.
- Correct first/last names, optional other profile fields, protected route profile gate.
- Return to exact original action and restore protected state through login, OTP, refresh, and onboarding; reject external/unrecognized destinations.
- Device inventory and individual/global revocation backed by server checks, without promising immediately expired issued JWTs.
- Deactivation, cancellation, deletion, holds, storage, backups, legal reviews, and audit receipts.
- Web RTL/LTR, browser tests, accessibility, static analysis, clean-schema, and CI all passing on **one reviewed HEAD**.

No production write, migration, SMS provider activation, merge or deploy is authorized by this document.
