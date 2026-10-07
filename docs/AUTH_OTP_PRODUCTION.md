# Auth OTP Production

## Email OTP
- IMPLEMENTATION: present in AuthRemoteDataSource + OtpPage
- CONFIGURATION: relies on Supabase Auth email provider
- PRODUCTION VERIFICATION: password auth verified; live OTP send not mass-tested (abuse/rate limits)

## SMS OTP
- IMPLEMENTATION: phone field on register metadata only; verifyOTP requires email
- CONFIGURATION: phone auth provider not evidenced in product path
- STATUS: EXTERNAL/OWNER dependency — not PASS
