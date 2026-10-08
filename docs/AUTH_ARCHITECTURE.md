# Auth Architecture

## Identity lifecycle
anonymous → login/register → Email OTP (or password) → Supabase session → profiles row → app session → logout

## Channels
| Channel | Code | Config | Production-verified |
|---------|------|--------|---------------------|
| Email password | YES | YES (working) | YES (Stage 4/6 sessions) |
| Email OTP | YES (signInWithOtp, verifyOTP) | Supabase Auth email | PARTIAL (code path; uncontrolled live OTP send avoided) |
| SMS OTP | NO primary path (UI requires email) | Not configured | NO — external dependency |

## Profile
- Trigger `on_auth_user_created` → `handle_new_user` inserts profiles(id,email)
- role default `user`
- `prevent_profile_role_escalation` blocks non-super_admin role changes

## Routing
`auth_redirect.dart`: public routes, protected routes, profile-completion gate, admin deep-link restore without client privilege grant
