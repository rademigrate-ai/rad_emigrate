# AI Entitlement Contract

## Precedence
1. Anonymous: `consume_ai_guest_quota` limit 5 (Stage 4) — server-side only
2. Authenticated base: `consume_ai_daily_quota` via `ai_usage_limits` by role (user 50/day)
3. Paid entitlement: `ai_entitlements` status=active (none currently) — would extend when owner configures

## Canonical decision
`get_ai_access_decision(p_user_id, p_guest_key_hash)` returns identity, role, plan, paid flag, payment_available=false, quota status, reason.

## Client rules
Flutter must not trust local plan/role/quota. Edge Function enforces consumption RPCs.
