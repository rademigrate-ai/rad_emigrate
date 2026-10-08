# Auth OTP Production (Acceptance)

## Email
| Step | Status |
|------|--------|
| Send OTP | PRODUCTION-VERIFIED (HTTP 200) |
| Invalid code | PRODUCTION-VERIFIED (403 otp_expired) |
| Valid verify | BLOCKED — requires controlled inbox access to delivered OTP |

## SMS
| Step | Status |
|------|--------|
| Application path | IMPLEMENTED |
| E.164 | TESTED |
| Production send | BLOCKED — otp_disabled (provider/config not enabled) |
