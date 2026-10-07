# User AI Quota & Entitlement

## Anonymous

- Payload `guest_key` (16–128 chars)
- Server stores SHA-256(`rad-guest:` + key) in `ai_guest_quota`
- **5** lifetime questions via `consume_ai_guest_quota`
- Exceeded → `code=anonymous_quota_exceeded` (auth/payment funnel)

## Authenticated

- `ai_usage_limits` by role (`user` 50 req/day default)
- Checked via `consume_ai_daily_quota` before inference
- Exceeded → `daily_limit_reached`

## Stage 6

Paid subscription/credits **not** implemented in Stage 4. Do not invent premium bypasses.
