# Payment Architecture

## Reality
No selected real payment provider SDK, checkout, plan catalog, price list or tax engine is implemented. Production commercial/payment acceptance remains open.

## Safe state
- payment_available = false in access decision
- No fake checkout UI
- No client-granted paid entitlement
- Future integration: insert verified entitlement after server-side payment verification only

## Local synthetic sandbox

`payment-sandbox` implements an explicitly synthetic HMAC event protocol, disabled by default and restricted to loopback Supabase targets. SQL also defaults the sandbox configuration to disabled. Separate sandbox event/subscription tables provide identity/currency binding, duplicate conflicts, sequence ordering and terminal cancellation/refund/chargeback behavior. They never grant canonical AI entitlements. This protocol is not Stripe, a store billing API, a licensed merchant integration or a financial settlement/tax specification. Real provider sandbox certification and owner-approved commercial rules are still required.
