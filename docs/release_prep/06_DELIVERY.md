# Grok release-prep delivery

## Branch

`feat/rad-grok-release-prep-20261021`

## Baseline

`c611f2ac039079c0d3381f5e9cea23185c2f91f6` (`feat/rad-final-unified-release-candidate`)

## Code changes (independent of agent merges)

1. **Format gate** — applied `dart format` to offenders introduced by identity-bound providers.
2. **Compile fix** — UI now uses session-bound convenience providers:
   - `currentAppointmentListProvider` in `interviews_page.dart`
   - `currentBookingHistoryProvider` in `booking_page.dart` / `booking_service_page.dart`
3. **AI scopes typing** — `authorized_data_scopes` accepts only `List`, explicit cast for `List.from`.

## Documentation added

- `docs/release_prep/00_BASELINE.md`
- `docs/release_prep/01_BLOCKER_MATRIX.md`
- `docs/release_prep/02_ANDROID_WEB_IOS_READINESS.md`
- `docs/release_prep/03_INTEGRATION_FORECAST.md`
- `docs/release_prep/04_RELEASE_CHECKLIST.md`
- `docs/release_prep/05_CI_AND_BUILD_COMMANDS.md`
- `docs/release_prep/06_DELIVERY.md`

## Local verification

| Check | Result |
|-------|--------|
| `dart format --set-exit-if-changed lib test` | PASS |
| Targeted compile root-cause (family providers) | FIXED in source |
| Full `flutter analyze` | Run under heavy concurrent agent load; re-run on CI |
| Full `flutter test` | Deferred to CI `workflow_dispatch` |
| Web/Android build | Deferred to CI after push |

## External dependencies (not integrated here)

- Codex `fix/rad-c611-security-release-20261021` / `fix/rad-release-assurance-20261021`
- Freebuff `feat/rad-new-features-ui`
- Antigravity contract adapters beyond RC baseline
- Owner Android/iOS permanent identity and signing secrets
- Hosted migration authorization

## Gates

Integration review: ready for agent handoffs on this prep branch.  
Staging: **NO-GO**.  
Production: **NO-GO**.
