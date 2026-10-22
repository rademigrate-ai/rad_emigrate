# Security Verification

Codex release-assurance controls are the base of this RC:
- Booking/appointment action state fenced by actor
- Private list providers keyed by auth uid + same-session checks
- FX rejects malformed/offline invention
- Research egress and provider catalogue validation
- AI malformed catalogue pricing rejection
- Human-only Feed; immutable evidence path preserved in Edge/tests

Local disposable clean-schema job passed on CI (Auth/RLS/Storage two-JWT checks).

Hosted Production still requires independent verification — local green does not prove hosted ACL remediation.
