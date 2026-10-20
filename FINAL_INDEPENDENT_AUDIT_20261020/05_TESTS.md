# Independent test evidence

Every application test below uses immutable `1fe44f63d179263c5e719578bf7ebad0e17868d1`. Native local verification and GitHub CI are separately recorded. Raw logs remain at `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_final_independent_evidence_20261020` with byte counts/SHA-256 in `external_evidence_manifest.json`; sanitized machine reports are committed beside this document. Later report commits do not change tested application source.

| Check | Local result | Exit | Count / limitation |
| --- | --- | --- | --- |
| Formatting | PASS | 0 | 394 files, 0 changed |
| Flutter analysis | PASS | 0 | No issues |
| Full Flutter tests | FAIL | 1 | 834 pass / 1 fail (mobile interview overflow) |
| Local web release build | PASS | 0 | non-production configuration |
| Local Android debug build | PASS | 0 | arm64; non-production configuration |
| Deno lint | FAIL | 1 | 37 findings / 37 files; native Deno 2.9.7 |
| Deno with CI flags | FAIL | 1 | 122 pass / 10 permission failures |
| Python unittest | PASS | 0 | 43 pass |
| Recovery redirect check | PASS | 0 | normalization assertions |
| Deno with scoped read | PASS | 0 | 132 pass / 0 fail; does not repair CI |
| Actual handler loopback HTTP | PASS | 0 | 4 checks; Auth → reservation → no-evidence result; external net denied |
| Auth/RLS/RPC HTTP | PASS | 0 | 28 real local checks |
| Mixed quota concurrency | PASS | 0 | two runs, ten concurrent calls each, two admitted and persisted |
| Clean SQL suites | FAIL | see per-suite JSON | {'FAIL': 5, 'PASS': 9}; includes one newer external NULL regression |
| Upgrade SQL suites | FAIL | see per-suite JSON | {'FAIL': 8, 'PASS': 6}; includes absent optional foundations and newer NULL regression |
| Snapshot immutability probe | FAIL | 3 | privileged mutation accepted; rolled back |
| Runtime fallback regression | FAIL | 1 | 0 pass / 3 fail; FX/canonical/search synthetic trust reproduced without network |
| Pinned Gitleaks | FINDINGS | scanner 1/1; wrapper 0 | 8 snapshot + 23 history; independent manual noncredential review PASS |

CI run: [39471824017](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017) — final **failure** at `1fe44f63d179263c5e719578bf7ebad0e17868d1`.

| Job | GitHub conclusion | Link |
| --- | --- | --- |
| flutter | failure | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797557879 |
| migration-reconstruction | failure | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797557906 |
| clean-schema | failure | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797558004 |
| web-build | success | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797558023 |
| routing | failure | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797558085 |
| android-build | success | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797558120 |
| repository-keyword-scan | success | https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017/job/118797558332 |

Reproduced failures: Flutter interview 390px overflow; Deno missing --allow-read; clean-schema trigger fingerprint mismatch; migration reconstruction lost human-publish marker. Additional SQL failures are preserved individually, including privilege allowlist/test-contract mismatches. Optional production-shaped payment/OCR/incident suites were attempted and failed due absent foundations; this audit does not relabel those attempts as passes.

Exact native commands, timestamps, durations, exits and log digests are in `commands.json`. SQL runner invocation and every source/test file digest are recorded in `canonical_sql.json`, `upgrade_sql.json`, canonical/upgrade manifests and copied reproduction tools. Platform tools: local Flutter 3.47.6 / Dart 3.13.5; Deno 2.9.7; native Supabase 2.121.0 / PostgreSQL client 17; GitHub workflow pins Flutter 3.47.6, Deno 2.5.4, Supabase 2.119.0. Do not attribute a native-tool PASS to a different CI toolchain.

Representative reproducible application checks in a separate checkout of the candidate:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
flutter build apk --debug --no-pub --target-platform android-arm64 --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
deno lint supabase/functions
deno test --allow-env supabase/functions/tests
deno test --allow-env --allow-read=supabase/functions supabase/functions/tests
python -m unittest discover -s scripts/tests -v
```

`tools/` contains the exact local audit adapters. They deliberately bind to this workspace, immutable source SHA and owned runtime markers; do not remove those guards to run in shared/hosted environments. Original candidate helper hardcodes another checkout's runtime, so it was not used to mutate it. The newer external harness source SHA is recorded. Recreate new disposable identities and review adaptations if moving the workspace.

NOT VERIFIED: production provider success, external source egress/root proof, push/email delivery, live payment settlement, real booking/interview scheduling, factual immigration/tuition/fee data, search gold/capacity corpus, physical Android/iOS/assistive device testing, Android signed release, full Flutter-to-hosted-v1 E2E. Mocked handler/source-inspection tests do not constitute those gates.
