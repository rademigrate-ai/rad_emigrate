# Release blocker matrix (independent of agent security work)

Priority key: **P0** blocks any green CI on RC; **P1** blocks store/staging packaging; **P2** documentation/ops readiness.

| ID | Priority | Area | Status | Owner | Notes |
|----|----------|------|--------|-------|-------|
| RP-01 | P0 | Dart format | FIXED on prep branch | Grok | `dart format --set-exit-if-changed lib test` passes locally |
| RP-02 | P0 | Riverpod family consumers | FIXED on prep branch | Grok | interviews/booking pages watch `current*` providers |
| RP-03 | P0 | Web compile | PENDING retest | Grok | Was fail on c611 due to RP-02 |
| RP-04 | P0 | Android debug compile | PENDING retest | Grok | Same root cause as RP-02 |
| RP-05 | P0 | Full Flutter test suite | PENDING | Grok | Blocked until analyze/tests run after fix |
| RP-06 | P1 | Android release applicationId | BLOCKED (owner) | Owner | Placeholder `com.example.rad_emigrate`; needs `RAD_ANDROID_APPLICATION_ID` |
| RP-07 | P1 | Android release signing | BLOCKED (owner) | Owner | Requires `RAD_RELEASE_STORE_*` env; CI correctly fails closed |
| RP-08 | P1 | iOS bundle id | BLOCKED (owner) | Owner | `com.example.radEmigrate` still in Xcode project |
| RP-09 | P1 | Version metadata | OPEN | Grok/Owner | `pubspec` is `1.0.0+1`; no release train version policy documented |
| RP-10 | P1 | CI trigger surface | OPEN | Grok | Feature branches need `workflow_dispatch` or PR to main; no auto CI on push to feature |
| RP-11 | P2 | Web CSP/headers | OPEN | Ops | Hosting headers not verified in-repo |
| RP-12 | P2 | Service worker / offline | OPEN | Flutter | Default Flutter web SW behavior; no custom policy audit |
| RP-13 | P0 | Codex security integration | EXTERNAL | Codex | Not integrated in this parallel task |
| RP-14 | P0 | Freebuff feature modules | EXTERNAL | Freebuff | Routes exported, not wired |
| RP-15 | P0 | Hosted migration reconciliation | EXTERNAL | Owner/Codex | Production NO-GO until authorized |

Do not treat GREEN local format as Production GO.
