# Stage 6 Security Evidence

| Test | Result |
|------|--------|
| Normal user INSERT ai_entitlements | DENIED 403 RLS |
| Normal user role → super_admin | DENIED |
| Cross-user profile SELECT | empty / denied |
| Guest quota same-hash 1–5 allow, 6–8 deny | PASS |
| Guest Edge Q6 anonymous_quota_exceeded | PASS |
| Guest AI inference Q1 | PASS (provider, grounding) |
| get_ai_access_decision auth | payment_available=false, paid=false, quota allowed |
| Feed | 0 |
