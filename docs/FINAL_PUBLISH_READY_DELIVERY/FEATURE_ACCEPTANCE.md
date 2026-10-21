# Feature Acceptance (integrated product)

Routes wired in `app_router.dart`:
- `/consultation`, `/booking`, `/booking/service/:serviceId`
- `/interview-scheduling`, `/interviews`
- `/calculator/cost`
- `/compare/pathways`, `/compare/universities`
- `/universities`

Dashboard quick actions expose: Consultation, Booking, Interviews, Cost calculator, Compare, Documents.

Security invariants retained from Codex:
- Identity-bound booking/appointment caches + session fencing
- FX fail-closed (no invented offline quotes)
- Human-only Feed publication path
- AI text-only contract headers
- Cross-account private cache isolation

Unavailable backend RPCs remain explicit unavailable states (no fabricated booking receipts).
