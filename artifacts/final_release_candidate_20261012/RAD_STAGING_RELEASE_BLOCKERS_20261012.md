# RAD staging execution and remaining release blockers — 2026-10-12

Branch `handoff/codex-stage1-stage2-20261010`, source baseline
`bc60f377990737fec182525545778694fe2a7e09`. No application, Android,
or migration source changed. Production remains **NO-GO**.

## Isolated staging and browser

Reused the disposable local `rad_prepilot_codex_20261012` stack in the OS
temporary directory. A volume-preserving stop/start enabled Storage alongside
Auth, PostgREST, Kong and Mailpit. The restored PostgreSQL 17.11 database
still reports **50** applied repository migrations through `20261012110945`.
It has no production keys or data. At completion, `auth.users`,
`consultation_requests`, and `storage.objects` each had zero fixture rows.
This is a local staging environment, **not a hosted staging project**.
The local CLI startup log contains disposable development keys and is kept
ignored/uncommitted; the committed evidence excludes it.

The targeted real Chrome run used the existing release Web build compiled for
`http://127.0.0.1:55321`. Guest consultation routing required login; a
disposable user logged in; document upload, signed-view URL creation and
deletion returned Storage HTTP 200; browser console errors were zero. See
[`staging_storage_browser/result.json`](staging_storage_browser/result.json),
[`staging_storage_browser.log`](staging_storage_browser.log) and the
[`documents-after-upload-delete.png`](staging_storage_browser/documents-after-upload-delete.png)
viewport screenshot. This supplements—not reruns—the prior 41-route Chrome
capture, real consultation E2E, and accessibility observations. No public
service was deployed and no real client submission was made.

On 2026-10-13, targeted local Storage API denial checks also passed: a second
authenticated identity could neither create a signed URL for the owner's
object nor overwrite it or insert under the owner's path; unsupported MIME
was rejected. The owner upload returned HTTP 200; negative responses were
Storage `NoSuchKey`, `AccessDenied`, `AccessDenied`, and `InvalidMimeType`
(HTTP 400 envelopes). The uploaded object and both Auth fixtures were removed;
post-cleanup counts for `auth.users`, `consultation_requests` and
`storage.objects` were **0/0/0**. See `staging_storage_denials.log`. The prior
real Chrome consultation run already covered anonymous, invalid-field,
cross-owner, direct-INSERT, `admin_note`, hourly-limit and no-Feed failure
paths; see `prepilot_consultation/result.json`. These are local checks only.

The connected Supabase account exposes only the production `main` branch;
there is no existing hosted staging project/branch. No paid branch/project was
created. Hosted Chrome E2E is **BLOCKED** pending an owner-provided isolated
project or explicit cost/creation approval. It must not point at production.

## Android emulator — BLOCKED by artifact transfer

Observed host: Windows 10.0.22621, 16 GiB physical RAM, approximately 40 GB
free on C:, Android SDK emulator 37.1.11 and platform-tools 37.0.1.
`emulator -accel-check` reports WHPX installed and usable. Android Studio's
bundled JBR supplies Java; `JAVA_HOME` was initially unset. No system image,
AVD, or ADB device exists. The official stable Android 35 Google APIs x86_64
image is listed by the SDK manager. An install was attempted with Java set;
the 1.6 GB download reached only 6.1 MB and estimated roughly 32,000 seconds
remaining, so it was interrupted without disabling security checks. The
partial SDK download/cache was not destructively cleaned. See
[`staging_android_system_image_install.log`](staging_android_system_image_install.log).
The previously verified debug APK remains 184,267,440 bytes, SHA-256
`DC515F2D4B1878C6263A14AE28DEF573B79EF091C9C6C4071C696232B049CA5C`.
No install, device journey, device log or device screenshot occurred.

Reproducible continuation, once a reliable official artifact transfer or
owner-provided test device is available (PowerShell):

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$sdk = 'C:\Users\Mehrshad\AppData\Local\Android\sdk'
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" 'system-images/android-35/google_apis/x86_64'
& "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd -n RAD_Pilot_API35 -k 'system-images/android-35/google_apis/x86_64' --device 'pixel_6'
& "$sdk\emulator\emulator.exe" -avd RAD_Pilot_API35 -no-snapshot-load
& "$sdk\platform-tools\adb.exe" wait-for-device
& "$sdk\platform-tools\adb.exe" install -r 'build\app\outputs\flutter-apk\app-debug.apk'
```

Then confirm APK hash and execute/capture guest, login, Visa, Feed,
Consultation, Profile and logout on-device. Do not claim device PASS until
screenshots, `adb logcat` and result matrix exist. The AVD needs the official
image download plus extraction space, usable WHPX, and enough free RAM while
Docker is running; the host currently has disk but the transfer was not
practical.

An additional 2026-10-13 attempt used the smaller official Android 35 AOSP
ATD x86_64 image. The official package was **658.4 MB**; after about a minute
it had reached **2.6 MB** with an SDK-manager ETA of roughly **16,866 seconds**.
That download was interrupted; its cache was preserved. The SDK still lists
no AVD, and ADB lists no connected device. See `staging_android_atd_install.log`.
The transfer rate, not WHPX or disk, remains the demonstrated blocker. A
reliable official artifact mirror or an owner-provided test handset/AVD image
is needed; do not claim Android device acceptance from the debug APK alone.

## Accessibility and release identity

The prior automated Chrome pass covered keyboard focus, labels, 390/1280px
viewports and Persian RTL/English LTR. Windows Narrator is installed, but no
controlled screen-reader session or audible-output verification was available;
NVDA/JAWS were not detected. **Actual assistive-technology acceptance remains
NOT RUN.** A qualified tester must verify spoken labels, errors, focus order,
route changes and language switching on a released build.

Owner decisions before Android release:

1. Approve permanent `RAD_ANDROID_APPLICATION_ID` instead of default
   `com.example.rad_emigrate`, associated store identity and versioning.
2. Define who creates/custodies the release keystore and supplies
   `RAD_RELEASE_STORE_FILE`, `RAD_RELEASE_STORE_PASSWORD`,
   `RAD_RELEASE_KEY_ALIAS`, `RAD_RELEASE_KEY_PASSWORD` through CI secrets.
   No keystore or credentials were created here.
3. Approve production Supabase URL/public client key as release build-time
   `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` values, Auth redirect allowlist,
   Android app-link/deep-link domain or scheme, and whether Android password
   recovery is in pilot scope. Current manifest has only launcher intent;
   password-recovery redirect is explicitly supplied on Web, not Android.
4. Choose Play internal testing or another controlled distribution channel,
   pilot devices, owners, and acceptance evidence. No release signing or
   production APK was attempted.

## Exact remaining blockers (separate gates)

| Gate | Status | Release-owner action |
|---|---|---|
| Production migration/history reconciliation | BLOCKED | Resolve 16 timestamp aliases, four live-only names and the AI discovery behavior divergence; approve rehearsal, backup and controlled migration plan |
| Live security | FAIL | Deploy already-tested owner/Feed/security migrations only after authorization, then verify grants, owner denial and advisor findings; enable leaked-password protection by Auth owner |
| Hosted staging | BLOCKED | Provide isolated non-production project/branch or approve stated cost; no production test identities |
| Android device | BLOCKED | Provide real test device or reliable official 1.6 GB image transfer; install and run device matrix |
| Local Storage negative paths | PASS | Cross-owner signed URL/upsert/path and MIME rejection passed; fixtures cleaned |
| Android release configuration | BLOCKED | Approve app ID, signing custody, Auth redirects and distribution |
| Screen reader | NOT RUN | Assign controlled Narrator/NVDA/VoiceOver/TalkBack acceptance |
| Visa editorial | OPEN, separate | Editorial/legal approval of destination and program text; do not apply Stage 5 data UPDATE yet |
| Stage 3 ingestion baseline | OPEN, separate | Reconcile approved 5/5 baseline with live 6/14 inventory before ingestion readiness claim |
| Human-only Feed publication | FAIL production, separate | Deploy and verify approved-only RPC and direct-write triggers; never auto-publish |
| Backup/rollback | UNVERIFIED | DBA attest off-machine restore/PITR and rehearse recovery |

See [`RAD_LIVE_DEFINER_REVIEW_20261012.md`](RAD_LIVE_DEFINER_REVIEW_20261012.md)
and [`RAD_PRODUCTION_MIGRATION_RECONCILIATION_PLAN_20261012.md`](RAD_PRODUCTION_MIGRATION_RECONCILIATION_PLAN_20261012.md).
