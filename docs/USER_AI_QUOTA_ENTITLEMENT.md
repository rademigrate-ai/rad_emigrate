# User AI Quota & Entitlement

## Anonymous

- Client: `AiGuestIdentity.getOrCreate()` → SharedPreferences
- Server: SHA-256(`rad-guest:`+key) in `ai_guest_quota`
- Limit: **5** lifetime via `consume_ai_guest_quota` (advisory lock)
- Exceeded: `anonymous_quota_exceeded` → login UX

## Authenticated

- `consume_ai_daily_quota` + `ai_usage_limits` by role
- User default 50 requests/day

## Stage 6

Paid entitlement not implemented.
