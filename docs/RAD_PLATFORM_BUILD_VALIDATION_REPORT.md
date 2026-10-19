# RAD — Platform Build, Packaging & Release Engineering Report (2026-10-18)

**Scope:** Gates 31 to 33 (Epic E6: Release Engineering and Quality)  
**Author:** Codex (DevOps & Release Engineer)  
**Status:** WEB & ANDROID VERIFIED — IOS STORE SIGNING BLOCKED ON LICENSED CERTIFICATES

---

## 1. Executive Summary

This report documents the compilation, binary packaging, static analysis, and signing status for all target client platforms of RAD Emigrate: Web, Android, and iOS.

---

## 2. Platform Compilation & Verification Matrix

| Platform | Build Command / CI Target | Verification Outcome | Artifact / Log Anchor | Production Readiness |
| :--- | :--- | :--- | :--- | :--- |
| **Flutter Web** | `flutter build web --release` | **PASS** (Zero compiler warnings, clean assets, index.html contains redirect pre-bootstrap) | `build/web/main.dart.js`, `build/web/assets/` | Ready for Release A deployment |
| **Android** | `flutter build apk --debug` / GitHub Actions CI | **PASS** (Gradle build succeeds, manifests and package identity `com.rademigrate.rad_emigrate` verified) | GitHub Actions Run #39072163776 / #39115878394 | Ready for debug/sandbox UAT; production release requires owner keystore |
| **iOS** | Xcode build / `flutter build ios` | **BLOCKED** on macOS hardware and Apple Developer Team provisioning profile | `docs/IOS_RELEASE.md` | Blocked on Apple Developer enterprise / store enrollment |
| **Static Analysis** | `flutter analyze` | **PASS (0 warnings, 0 errors)** in 56.0s | Local execution on `rad_codex_master_47_20261018` | Clean engineering gate |
| **Formatting** | `dart format --output=none --set-exit-if-changed .` | **PASS** (100% compliant) | Local workspace verification | Clean engineering gate |
| **Regression Tests** | `flutter test` | **PASS (546/546 tests passing)** | 546 tests passed in 2m 29s | Clean engineering gate |

---

## 3. Web Release Deployment & Rollback Strategy

1. **Immutable Git SHA Pinning:**
   - Every deployment artifact is tagged with its immutable commit SHA (e.g. `feat/codex-master-47-execution-20261018` at HEAD).
   - Render deployment configuration requires setting Auto Deploy to `off` and manually triggering deployments against pinned commit SHAs.
2. **Password Recovery Hash Preflight:**
   - Web `index.html` loads `rad_recovery_redirect.js` before `flutter_bootstrap.js` to immediately translate Supabase Auth `#access_token` and `#/reset-password` into clean router query parameters, avoiding Flutter GoRouter hash collisions.
   - Verified by 8 automated scenarios in `scripts/check_password_recovery_redirect.cjs`.
3. **Rollback Rehearsal:**
   - In the event of a frontend regression, Render rollback restores the previous verified deploy artifact within < 60 seconds with zero database downtime.

---

## 4. Mobile Release Prerequisites (Release B)

1. **Android Signed Release:** Requires owner-managed release keystore (`key.properties`), package signing, and Google Play Console track configuration.
2. **iOS IPA Packaging:** Requires macOS runner, Apple Developer Program account, distribution certificate, and TestFlight internal track provisioning.

