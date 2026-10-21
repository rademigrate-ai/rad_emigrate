# CI and local build commands

## Trigger CI on a feature branch

Workflow file: `.github/workflows/ci.yml`  
Push/PR triggers only apply to `main`. Feature branches use **workflow_dispatch**:

```bash
gh workflow run ci.yml --ref feat/rad-grok-release-prep-20261021
```

Jobs: routing, flutter, web-build, android-build, repository-keyword-scan, clean-schema, migration-reconstruction.

## Local verification sequence

```bash
dart format --set-exit-if-changed lib test
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
# optional Deno (requires Deno 2.5.4):
deno test --allow-env --allow-read=. supabase/functions/tests
```

## Web

```bash
flutter build web --no-pub \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
```

## Android debug

```bash
flutter build apk --debug --no-pub --target-platform android-arm64
```

## Artifact checksum pattern (after a successful build)

```bash
# Linux/macOS example
sha256sum build/app/outputs/flutter-apk/app-debug.apk > artifacts-sha256.txt
sha256sum build/web/main.dart.js >> artifacts-sha256.txt
```

Windows PowerShell:

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-debug.apk -Algorithm SHA256
```

Do not publish artifacts from placeholder application IDs.
