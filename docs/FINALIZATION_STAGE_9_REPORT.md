# Stage 9 — Security & Production Hardening

## RESULT: COMPLETE

## Starting HEAD
9c76217f62cbdf812b02f074838b60f486b1365e

## Stage 8 integration
- ARB + generated l10n getters for Stage 7/8 strings
- Admin hub → /admin/consultations
- SMS otp_disabled → smsAuthUnavailable mapping
- auth_redirect includes /admin/consultations

## Security tests executed
- Role PATCH profiles → denied
- set_user_role → forbidden
- Cross-user applications → empty
- Cross-user notifications → empty
- Consultation protected fields forced submitted/admin_note null
- Application status approved coerced to draft
- create_user_notification user → forbidden
- publish_content_draft user → forbidden
- Feed remains 0
- Orphan integrity 0

## Grant hardening
20261008020000_stage9_security_grant_hardening.sql applied production

## Advisors triaged
- anon SECURITY DEFINER grants: FIXED (revoked)
- ai_guest_quota no policy: FIXED (service policy)
- pg_net public schema: ACCEPTED (platform)
- leaked password protection: OWNER ACTION

## Feed
0

## Stage 3
OPEN
