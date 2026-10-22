# Integration conflict forecast (do not merge yet)

## Incoming branches vs prep baseline `c611f2a` + format/compile fixes

### Codex — `fix/rad-c611-security-release-20261021` / `fix/rad-release-assurance-20261021`

Likely touch points:
- Privacy fencing for booking/appointment action state
- FX pair validation / unavailable-state tests
- AI catalogue pricing validation
- Research egress / provider catalogue validation
- Security documentation digests

Conflict risk: **HIGH** on `booking_controller.dart`, `appointment_controller.dart`, `fx_rate.dart`, AI service, privacy tests.

Integration order recommendation:
1. Land Codex verified security/assurance HEAD onto RC.
2. Re-apply or reconcile Grok family-provider UI consumers if Codex rewrites providers.
3. Re-run full CI.

### Freebuff — `feat/rad-new-features-ui` @ `9c6df77`

Adds booking, interview, cost calculator, comparison modules with route spreads:
- `...bookingRoutes()`
- `...interviewRoutes()`
- `...costCalculatorRoutes()`
- `...comparisonRoutes()`

Conflict risk: **MEDIUM–HIGH** with existing booking/interview pages already on RC.

Integration notes:
- Freebuff documents routes are **not wired** into `app_router.dart` from that branch.
- Prefer single ownership of booking/interview UI after Codex privacy fencing lands.

### Antigravity — `feat/antigravity-a003-flutter-implementation` @ `e80f106`

Contract adapters for visa search, FX, AI CopilotResult, CMS RPCs.

Conflict risk: **MEDIUM** on repositories and AI service.

## Suggested final integration commands (after agents deliver verified SHAs)

```bash
git fetch origin
git checkout -b feat/rad-final-integration origin/feat/rad-final-unified-release-candidate
# 1) Codex
git merge --no-ff <codex-verified-sha>
# 2) Grok prep (format + consumer fixes) if not ancestor
git merge --no-ff origin/feat/rad-grok-release-prep-20261021
# 3) Freebuff / Antigravity only after conflict plan reviewed
# Resolve, then:
dart format --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
# workflow_dispatch CI on the integration SHA
```

Do not force-push. Do not merge main in this phase.
