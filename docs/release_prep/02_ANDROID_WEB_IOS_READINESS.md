# Android / Web / iOS readiness matrix

Baseline: `c611f2ac` + prep compile/format fixes.

## Android

| Item | State | Evidence |
|------|-------|----------|
| Package / applicationId (debug) | Placeholder | `com.example.rad_emigrate` in `android/app/build.gradle.kts` |
| Release applicationId gate | Enforced | `verifyReleaseSigning` rejects blank or placeholder ID |
| versionName / versionCode | From Flutter | `flutter.versionName` / `flutter.versionCode` ← pubspec `1.0.0+1` |
| minSdk / targetSdk / compileSdk | Flutter defaults | Via Flutter Gradle plugin |
| Java / Kotlin | 17 | `sourceCompatibility` / `jvmTarget` 17 |
| Release signing | Opt-in env only | `RAD_RELEASE_STORE_FILE/PASSWORD/KEY_ALIAS/KEY_PASSWORD` |
| CI debug APK | Was FAIL on c611 | Root cause RP-02; retest after prep push |
| AAB procedure | Documented only | See commands below; requires owner ID + signing |

### Reproducible commands (no credentials)

```bash
flutter build apk --debug --target-platform android-arm64
# Release packaging intentionally blocked without env:
./android/gradlew -p android :app:verifyReleaseSigning   # expected FAIL on placeholder
# After owner supplies env:
# export RAD_ANDROID_APPLICATION_ID=com.rad.emigrate   # owner-approved value
# export RAD_RELEASE_STORE_FILE=...
# flutter build appbundle --release
```

Never commit keystores or passwords.

## Web

| Item | State | Evidence |
|------|-------|----------|
| base href | Flutter token | `<base href="$FLUTTER_BASE_HREF">` in `web/index.html` |
| manifest | Present | `web/manifest.json` linked |
| CI build | Was FAIL on c611 | Same compile error as Android |
| Non-prod dart-defines | CI uses placeholders | `SUPABASE_URL` / `SUPABASE_ANON_KEY` example values |
| CSP / security headers | Hosting-owned | Not enforced in Flutter build |

```bash
flutter build web --no-pub \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
```

## iOS

| Item | State | Evidence |
|------|-------|----------|
| Bundle identifier | Placeholder | `com.example.radEmigrate` in `project.pbxproj` |
| Signing / capabilities | Not audited on Windows | Requires macOS + Xcode |
| Privacy manifests | Inventory pending | Needs Xcode inspection |
| Build success claim | **Not claimed** | No macOS runner used in this task |

### macOS readiness checklist (owner)

1. Replace `com.example.radEmigrate` with permanent bundle ID.
2. Configure development team and provisioning profiles.
3. Review Info.plist permission strings (camera, photos, etc. if any).
4. Add Privacy Manifest if required by App Store policy.
5. Archive on Xcode matching Flutter 3.47.6 / Dart 3.13.5.
