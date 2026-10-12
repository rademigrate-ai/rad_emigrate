# RAD pre-pilot acceptance — 2026-10-12

Source baseline: `d5797591e812fd920df2a7708534e95f0633e5a9` on
`handoff/codex-stage1-stage2-20261010`. No Flutter application or migration
source was changed during this acceptance run. Production remains **NO-GO**.

## A. Consultation — local real E2E

An isolated `rad_prepilot_codex_20261012` Supabase project was created under
the OS temporary directory. Its migration files were copied byte-for-byte
from the repository (50 files, zero mismatches) and `supabase start` applied
all 50 in timestamp order, ending at `20261012110945`. The repository migration
was not edited or applied to production. Postgres 17, Supabase CLI 2.119.0,
API `http://127.0.0.1:55321`, and Chrome 154 on Windows were used. The web
release candidate was compiled with only this local API URL and its public
client key. No production account or form was used.

Live database introspection: `submit_consultation_request(p_topic text,
p_message text, p_related_application_id uuid)` is SECURITY DEFINER,
executable by `authenticated`, not `anon`; `consultation_requests` has RLS
enabled and `authenticated` has no direct table INSERT privilege. The
targeted Chrome run made exactly one browser POST to
`/rest/v1/rpc/submit_consultation_request` and received HTTP 200 with a UUID.
The submitted row was visible to its owner and invisible to a second user.
Anonymous RPC, direct INSERT, owner `admin_note` SELECT, malformed topic and
message, and cross-owner related-application attempts were denied. The
fourth request within an hour returned `consultation_rate_limited`; the Feed
item count stayed zero before and after. Disposable Auth identities were
deleted, and local consultation rows returned to zero. Browser console errors:
none. No direct client INSERT or Feed auto-publication was observed.

Evidence: [raw Chrome/API result](prepilot_consultation/result.json),
[run log](prepilot_consultation.log),
[database checks](prepilot_db_checks.txt),
[before screenshot](prepilot_consultation/consultation-before-submit.png),
[after screenshot](prepilot_consultation/consultation-after-submit.png), and
[web build log](prepilot_web_build.log). The reusable verifier is
[`scripts/verify_prepilot_consultation.py`](../../scripts/verify_prepilot_consultation.py).

## B. Android device — BLOCKED

The existing debug APK is 184,267,440 bytes with SHA-256
`DC515F2D4B1878C6263A14AE28DEF573B79EF091C9C6C4071C696232B049CA5C`.
`adb devices -l` found no connected device; `emulator -list-avds` and
`flutter emulators` found no AVD. Therefore APK install, login, guest
navigation, Visa, Feed, Consultation, Profile, logout, device logs and device
screenshots are **NOT RUN / BLOCKED**. The earlier debug build PASS is not a
device acceptance PASS. See [device probe](prepilot_android_device_probe.log).

## C. Accessibility — automated Chrome PASS, assistive technology UNVERIFIED

Focused Chrome testing at 1280×800 and 390×844 found labelled Email and
Password inputs, Email→Password Tab focus, English↔Persian language switching,
and a desktop RTL mirrored heading. On the authenticated 390px consultation
page, labelled Topic and Message fields were present and Topic→Message Tab
focus worked. Console errors: none. The mobile heading is centered in both
directions, so equal x coordinates there are not evidence of a failed mirror.
No consultation was submitted in this accessibility pass. The Flutter
semantics overlay can enlarge a *full-page screenshot* beyond 390px while
document horizontal-scroll extent remains zero; the final mobile screenshot
is viewport-only. No controlled screen-reader session was available, so
screen-reader announcements, rotor/landmark order and spoken errors are
**NOT RUN**, not claimed as PASS. See
[observations](prepilot_accessibility/result.json),
[run log](prepilot_accessibility.log), and
[mobile consultation screenshot](prepilot_accessibility/consultation-mobile-390.png).

## D. Release configuration — owner decisions required

`android/app/build.gradle.kts` retains the placeholder namespace and default
application ID `com.example.rad_emigrate`; a release package requires a
non-placeholder `RAD_ANDROID_APPLICATION_ID` and all four
`RAD_RELEASE_STORE_FILE`, `RAD_RELEASE_STORE_PASSWORD`,
`RAD_RELEASE_KEY_ALIAS`, `RAD_RELEASE_KEY_PASSWORD` values. None were present
in this process. Release signing is wired to `verifyReleaseSigning` for release
package/bundle tasks. No release keystore was found under `android/`. The main
manifest has Internet permission and launcher intent, but no Android App Link
intent filter. Supabase URL and public client key are build-time Dart defines,
not committed production values. Password recovery supplies a redirect only
on Web; Android recovery/deep-link behavior needs an owner-approved design
and device verification.

Before release, owner must approve (1) permanent package ID and store listing,
(2) signing key creation/custody and CI secret handling, (3) production
Supabase URL/public key and Auth redirect allowlist/deep-link behavior,
(4) release distribution route and actual Android test device/AVD, and
(5) whether Android password recovery is in pilot scope. No identifier,
credential, signing key, production environment or deployment was changed.

## E. Provenance and gate

The historical 41-route Chrome capture, 325 Flutter tests, 90 Stage 3 Python
tests, S1–S17 local pipeline and debug APK build are preserved as prior-run
evidence; they were not rerun because application source did not change. This
turn ran targeted consultation and accessibility browser checks, Python
verifier compilation, live local migration/permission checks, and a new
loopback web build. `build/web/main.dart.js` SHA-256 is
`4931B2B29F493177BED529004C1ED2194F70434DC439D7EC018FA2E1AC4070D4`.
The local build is evidence-only, not a production deployment.

Source tree fingerprint at execution: `lib`
`2cee12716059190af8c38ddc3a4a4ad153b6933d`, `android`
`4763695cab80515b0430dd6b91458f8ab0d50281`, `supabase`
`8b9ad1c8a5d5fa0899a63a700404aea953702123` (Git tree IDs); tracked
diff from baseline across these trees was empty. Targeted Flutter tests
(`consultation_form_journey_test.dart`, `app_shell_navigation_test.dart`,
`auth_redirect_test.dart`) passed 15/15. Both Python verifiers compiled.

Remaining gates: production migration/application and live security checks;
real Android device acceptance; approved release identity/signing/config;
screen-reader testing; real production pilot submissions only after explicit
authorization. Stage 3 ingestion readiness is a separate blocker track and
is not implied by this local consultation PASS. Production **NO-GO**.
