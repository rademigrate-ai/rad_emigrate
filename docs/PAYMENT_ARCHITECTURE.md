# Payment Architecture

## Reality
No payment provider SDK, webhook, checkout, plan catalog, or price list exists in repository or production schema beyond empty `ai_entitlements` foundation.

## Safe state
- payment_available = false in access decision
- No fake checkout UI
- No client-granted paid entitlement
- Future integration: insert verified entitlement after server-side payment verification only
