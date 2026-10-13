# Stage 5 final non-production engineering closure — 2026-10-13

Production remains **NO-GO**. No production write, migration, backup, Storage
export, Auth change, deployment, purchase, merge or public-site change occurred.
No DBA sign-off is claimed. All new identities, requests and Feed publications
below were synthetic fixtures in disposable local environments and were cleaned.

## Provenance and independent findings

Branch: `handoff/codex-stage1-stage2-20261010`. Starting remote/local HEAD:
`bbabe044e9c5a8a6b682d31eacc16a21d2f27545`.
Validated CI fixes: `1794f18fa52b73f8749e0d46d0b1e8d70cbebaa5`,
`5013341fc021043f3721d50912c76f9c92a9387e`.
Fetch initially succeeded, later hit a transient GitHub DNS failure, and then
succeeded again. No new branch, PR, forced push or audit-file overwrite occurred.

Read: Grok SEC-001–006 incorporation, post-audit matrix and
`outputs/QA_RELEASE_AUDIT_20261013.md`. The latter audited application sources at
`4f9993c`; later documentation/recovery commits did not change those sources.
Application files (`lib`, `test`, Android, migrations, Edge, pubspec) remain
unchanged in this closure. Canonical text-LF/binary-raw application fingerprint:
`295d6a7dacd6520b7532ccb406e8106797db4ebc7c329d3c4abfc214082e3976`
(327 files; `source_provenance_raw.json`). Engineering harness changes are
separately hash-pinned in `EVIDENCE_MANIFEST.json`; they are not represented as
application changes. Reports preserve previous tests as historical evidence.
`application_fingerprint_raw.txt` is an intermediate byte-normalization probe,
not the final text/binary-aware fingerprint above.

Local API/database: `127.0.0.1:56321` / named disposable
`supabase_db_rad-prod-equivalent-20261013`, PostgreSQL **17.11**, **52** ledger
entries through `20261012230000`: the previously verified **47 live-history +
five security** rehearsal, not the older 50-file database. New tests reused this
baseline rather than reconstructing production from matching columns. It has no
production credentials/data. Local cron command metadata contains no production
project reference (`local_environment_ledger_raw.txt`). Backup tests use separate
network-none clusters and purely synthetic data.

Flutter 3.47.6 / Dart 3.13.5, Windows host, actual installed Chrome via Playwright,
Python 3.14, Docker. CI uses Ubuntu/Supabase CLI 2.119.0/Deno 2.5.4.

## Executed acceptance matrix

| Check | Result | Evidence / precise scope |
|---|---|---|
| GitHub CI, all seven jobs on one exact HEAD | PASS | SHA `5013341fc021043f3721d50912c76f9c92a9387e`, run **38389510371**; `ci_green_jobs.json` and seven redacted raw job logs. All jobs success, no skipped job. Final pushed-HEAD rerun is recorded by the post-commit Actions receipt, not inferred from this earlier SHA. |
| Format / analyze / complete Flutter suite | PASS | 231 files, 0 formatting changes; no analyzer issues; **325 passed / 4 explicitly skipped**, local raw logs and CI Flutter job. No application source changed afterwards. |
| Python / tooling regressions | PASS | Stage 3 **90**, recovery **11**, visual capture **3**, new CI inventory/harness regressions **5**; corresponding raw logs. |
| Full clean migration replay / reconstruction | PASS | CI rebuilt all **51 repository migrations**; authoritative 25 + 26 additives, metadata comparison and negative SQL checks. This is distinct from the 47+5 production-equivalent rehearsal. |
| Authenticated browser journeys | PASS | `browser_selfhosted/manifest.json`: **40 captures**, actual guest gates, valid/invalid login, logout, refresh, recovery, desktop/mobile Visa/Feed/Consultation/Profile/notifications/AI routes, ordinary-user Admin denial, Admin and Super Admin configuration restriction. Valid login POSTs were HTTP **200** with actual submitted fixture credentials checked; no credentials logged. Consultation actually submitted, not skipped. |
| Research → Draft → Review → Approval → Feed | PASS | `review_workflow_selfhosted/result.json`: actual ingestion RPC creates one review candidate, duplicate is idempotent, no pre-approval Feed write; Chrome performs edit/approve (204), then separate explicit publish (200), and renders the item in Feed; repeat publish returns the same ID. Synthetic non-immigration text only. |
| Research/workflow negative authorization | PASS | Anon ingest 401; ordinary-user ingest/approve/publish and service publish 403; unapproved Admin publish 400. Additional pipeline direct Feed writes by anon/authenticated/service all SQLSTATE 42501. No guard disabled for cleanup. |
| SECURITY DEFINER denials | PASS | **13** protected RPC denial probes, exact function signatures in raw log; ordinary caller denied, including both cross-owner AI RPCs. |
| AI quota ownership/concurrency | PASS | Real JWTs: cross-user quota/access HTTP 403; forged role ignored; 48 used + eight parallel calls → **2 allowed / 6 denied / total 50**. CI independently tested **50 accepted / 16 denied** with unique reservations. External paid inference NOT RUN. |
| Consultation RPC / privacy / abuse | PASS | Real Chrome POST **200**, UUID contract, anon/invalid input/direct INSERT/admin-note/cross-owner application and history negatives, no Feed publication; `consultation/result.json`. Additional daily/concurrent limits in `consultation_limits_verified_raw.txt`: 10 older daily rows deny the eleventh; eight parallel calls admit exactly three and deny five. Fixtures cleaned. |
| Storage HTTP isolation + Chrome workflow | PASS | Owner upload, role/owner-bound signed view and delete; cross-owner signed URL/upsert/path insert denied, invalid MIME denied. `storage_browser/result.json`, `storage_isolation_direct_cli_raw.txt`; CI also tests size/type restrictions. Storage HTTP outer 400 responses carry `AccessDenied`/`NoSuchKey`, not incorrectly reported as HTTP 403. |
| Notifications | PASS (REST + route) | Two real JWTs: owner read/mark-read succeeds, cross-user reads/updates affect zero rows, arbitrary client INSERT 403; `notifications_raw.txt`. Browser route captured. Push delivery is NOT RUN. |
| Accessibility | PASS automated only | Keyboard Email→Password and Topic→Message, input labels, 1280×800 / 390×844, English/Persian, no horizontal document scroll or console errors. `accessibility/result.json`. Actual screen reader **NOT RUN**: no available native/AT control surface; empty computer-use inventory. Not a WCAG/manual AT sign-off. |
| Web release build | PASS | `--release --no-pub --no-web-resources-cdn`, isolated URL/key, `WEB_SELFHOSTED_EXIT 0`; `web_release_selfhosted_raw.txt`. JS SHA **d9bc032e74d5a0116b4887e6c137c866ddd52294ef8c964dcd470629479ae74e**. Wasm dry-run warned about secure-storage dependencies; JavaScript release succeeds. Wasm support is not claimed. |
| Edge compatibility | PASS static/contracts; deployment parity FAIL | Deno format/lint, **31 tests**, type-check all three entrypoints exit 0; local RPC contracts/guards verified. Read-only retrieved deployed sources differ from candidate implementations: AI v9, research v2, document v1. Exact normalized source and deployed bundle hashes in `edge_source_comparison.json`. Bundle hash is not confused with source hash. No deploy or production invocation. |
| Android debug / release guard | PASS CI; device BLOCKED | CI debug arm64 build and opt-in signing/placeholder identity denial pass. SDK/emulator tools installed; WHPX usable. No device/AVD/system image; two official SDK install attempts failed to connect to repository. Raw SDK/acceleration logs retained. No device PASS. |
| Independent recovery | PASS synthetic only | PG17.11 encrypted dump→separate target restore, schema/ledger/data/constraints/effective ACL parity, byte-level Storage restore/inventory, tamper and data/sequence mutation detection. **7 tables / 6 rows / 546 effective privilege entries / 2 objects**. Naive overgrant detected, hardened restore matches. No real production recovery point/PITR attested. |
| Secrets/environment/release identity | PASS code checks; owner gates BLOCKED | CI high-risk credential scan green; new evidence scanned without secret patterns. Browser fixtures refuse hosted APIs; compiled local artifact guard added. Local/public client key only. Android release blocked with placeholder `com.example.rad_emigrate`; no ID/signing/domain/credentials invented. |

## Defects, failed attempts and splash investigation

- Confirmed CI defects fixed: Storage policy count/fingerprint still expected
  three policies; migration reconstruction omitted the last two files; Auth E2E
  still required a now-forbidden direct Consultation INSERT. Do not restore old
  permissions to satisfy stale tests. Regression coverage now requires exact
  additive inventory, owner UPDATE policy and RPC/INSERT denial checks.
- Browser harness repairs: wait for restoration to leave `/splash`; observe SPA
  DOM readiness rather than unrelated window-load downloads; use actual merged
  accessible labels for review/Feed cards; send inputs at realistic cadence and
  verify the actual Auth POST status/credential match without logging secrets.
- Retained failed browser attempts include selector misses, startup/navigation
  timeouts and missed ultra-rapid input. A separate prepilot REST attempt had
  Storage `DatabaseTimeout` HTTP 544; its two fixtures were explicitly cleaned.
  CI fresh-stack Auth/Storage then passed. A new limits-harness module-shadowing
  error was repaired, covered by AST regression, and rerun successfully.
- Default-CDN cold starts reached interactive login in roughly 9.7–14.8 seconds;
  the self-hosted-renderer observation was **7.798s desktop / 5.799s mobile**.
  Thus QA's t+5s splash observation is reproducible, but not evidence of a hang.
  These are observations on a loaded host, not a controlled percentile benchmark
  or native-device measurements. No arbitrary splash timeout or Auth bypass was
  added. Bootstrap awaits Supabase and timezone/boundary initialization (the
  boundary asset is 4,202,630 bytes); the loader's animation is not a route delay.
  Native startup/accessibility and an owner-approved performance budget remain
  unaccepted. The renderer flag was a local test-build option, not a deployment.

PowerShell labels native stderr as `NativeCommandError` even for successful
commands. Results above use test summaries, native exit evidence (e.g. Web 0),
JSON assertions and Actions conclusions, not that wrapper label alone. CI logs
redact local generated keys/tokens; raw non-secret test assertions are retained.

## SECURITY_ACCEPTANCE

| Requirement | Local/repository | Production |
|---|---|---|
| Exact five migration SQL hashes, no file modification | PASS — `five_migration_hashes_raw.txt`, replay CI | UNVERIFIED post-apply; not authorized/applied |
| AI ownership/quota atomicity | PASS — real JWT and concurrency logs | FAIL in recorded live preflight; fix pending |
| Approved, human-only Feed publication; role escalation guards | PASS — Chrome workflow, direct-write negatives, S7–S17 | FAIL in recorded pre-migration schema |
| Consultation privacy / RPC-only / hourly and daily limits | PASS — actual browser and negative/concurrent tests | FAIL in recorded pre-migration privileges |
| Narrow Storage UPDATE / owner isolation / signed view | PASS — four owner-scoped policies, real HTTP/Chrome | UNVERIFIED until authorized policy apply/postflight |
| Restore privileges and Storage byte integrity | PASS synthetic; prior full local grant-safe rehearsal preserved | UNVERIFIED real recovery point; DBA sign-off BLOCKED |
| No production mutation/export/deploy; no client secrets | PASS for this closure | Not a production security acceptance claim |

## Exact owner/DBA gates and handoff

1. **Recovery:** actual DBA review/sign-off of `scripts/recovery/README.md`,
   approval IDs, freeze scope, least-privilege exporter and separate Storage
   copier, age/signing-key custody, approved encrypted off-machine retention,
   cost cap, isolated real-point restore. Authorize export/copy/restore separately;
   none is authorized here. Free-plan backup/PITR investigation is closed.
   Synthetic tests do not prove production PITR or zero-data-loss recovery.
2. **DB deployment:** approve only the five ordered security files, their exact
   raw/LF hashes, live ledger/catalog/invalid-row/grant preflights, backup
   attestation and postflight negatives. Stop on any mismatch, unauthorized
   ledger alias, failed restore/constraint or privilege diff. Never blind-push
   the whole directory, repair history, or fold in Visa/knowledge aliases.
3. **AI discovery/Auth:** preserve the owner's decisions: new discoveries stay
   disabled until Admin approval; enable leaked-password protection only after
   compatibility assessment and separate Auth authorization. The historical
   live auto-enable discovery function still differs after the five-file path;
   DBA-reviewed forward alignment and a disabled-first test are a separate gate.
   Approved provider credentials/inference canary require secure owner handling.
4. **Release:** separately authorize three Edge deployments and Web rollout from
   one green SHA; verify runtime version/contract and security smoke after apply.
   Approve canonical HTTPS host, exact Auth recovery redirects, Android package
   ID, signing/certificate custody and deep-link allow-lists. No credentials in
   chat/git. `docs/STAGE5_PRODUCTION_HANDOVER.md` now removes unsafe generic pushes.
5. **Hardware/AT:** supply a test device or an official Android 35 x86_64 image
   and repository connectivity. Host has WHPX and 16GB RAM but around 2GB free
   during tests; free at least 4GB for emulator + browser and reserve 8GB disk.
   Reproduce: official `android.exe sdk install 'system-images;android-35;google_apis;x86_64'`,
   `avdmanager create avd -n rad_acceptance -k 'system-images;android-35;google_apis;x86_64'`,
   boot with `emulator -avd rad_acceptance`, verify `adb devices -l`, build an
   isolated debug variant for emulator host `10.0.2.2:56321` with local public
   key, install via `adb install -r`, run login/guest/Visa/Feed/Consultation/Profile/logout
   with test identities, record logcat/screenshots. Do not install an old,
   unconfigured APK and call authenticated journeys PASS. Run actual NVDA or
   VoiceOver acceptance with an available control/audio surface.
6. **Content/operations, separate gates:** Visa official/editorial verification,
   Stage 3 baseline reconciliation before ingestion, human-only Feed enforcement,
   and the existing 14-item Manus operations handoff remain distinct. No public
   Radmohajer/WordPress, Radvisa or Digivisa form was changed/submitted here;
   their unexecuted mobile/actual-submission statuses are preserved. A Flutter
   test is not a fix for the external WordPress `Invalid Input` finding.

Rollback: keep prior approved Web/Edge versions, freeze writes on failed
postflight, prefer an authorized forward DB correction, and never undo ownership
or human-approval guards to recover application behavior. Isolated restore must
neutralize target defaults **before** object creation, retain explicit archive
ACLs and require exact effective-privilege parity (previous naive full restore:
**86 excess grants**). Storage bytes/config/Auth dependencies are separate.
Restoration loses later writes; cutover and any reverse transfer need separate
DBA/owner authorization. See the existing grant-safe recovery runbooks; do not
execute them from this task.

All safely executed automated gates above have evidence; device, actual AT,
hosted staging, real provider canary, production recovery/apply and editorial
acceptance are **BLOCKED/NOT RUN**, not fabricated PASS. No unified production
acceptance is claimed. Use the final Actions run on the pushed HEAD for final
CI provenance; older CI and old APK hashes are explicitly historical.
