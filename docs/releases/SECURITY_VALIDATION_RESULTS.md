# RAD EMIGRATE — STAGE 1 SECURITY VALIDATION & TEST RESULTS

**Verification Date:** October 17, 2026
**Environment:** Clean Isolated Git Worktree (`worktree-security-hardening`)
**Commit Reference:** `19127c6` on `security/stage1-reconciliation-20261017`
**Tooling Versions:**
- Flutter SDK: 3.47.6
- Dart SDK: 3.13.5
- PostgreSQL Client: 17.11
- Deno Runtime Target: 1.40+

---

## 1. COMPREHENSIVE VERIFICATION MATRIX

| Gate | Target Component | Command | Result | Duration | Notes |
|---|---|---|---|---|---|
| **Gate 1** | Migration SHA-256 Hashes | `Get-FileHash` vs Manifest | **PASS** | < 1s | 5/5 files match manifest byte-for-byte |
| **Gate 2** | Code Formatting | `dart format --set-exit-if-changed lib test` | **PASS** | 2.25s | 254 files formatted (0 issues) |
| **Gate 3** | Static Code Analysis | `flutter analyze --no-pub` | **PASS** | 12.0s | "No issues found!" |
| **Gate 4** | Full Test Suite | `flutter test --no-pub` | **PASS** | 89s | 459 tests passed (100% green) |
| **Gate 5** | Consultation Security RPCs & Compat | `flutter test test/core/supabase/... test/features/consultation/...` | **PASS** | 1.8s | 14/14 tests passed (fail-closed negative tests) |
| **Gate 6** | AI Orchestrator Edge Tests | `ai_orchestrator_test.ts` (20 tests) | **PASS** | CI Deno | Tests 17-20 verify atomic reservation, 429 limit, 503 fail-closed, 500 malformed |
| **Gate 7** | Production Web Release Build | `flutter build web --no-pub` | **PASS** | 103.3s | Release JS bundle created in `build/web` |
| **Gate 8** | Android Compilation | `flutter build apk --debug --no-pub` | **PASS** | 78.5s | APK generated at `build/app/outputs/flutter-apk/app-debug.apk` |
| **Gate 9** | Android Release Signing Gate | `flutter build apk --release --no-pub` | **GATE HELD** | 12.1s | Enforces `:app:verifyReleaseSigning` guard without prod keys |
| **Gate 10** | Guest Mode & Auth Preservation | `test/features/guest_mode/...` | **PASS** | 4.2s | All PR #51 guest & auth behaviors intact |

---

## 2. DETAILED TEST EXECUTION SUMMARIES

### 2.1 Full Flutter Test Suite Output
```text
01:29 +459: All tests passed!
```
- Includes core navigation, routing, auth controller, profile management, visa catalog, AI assistant, document intelligence, guest mode hydration, visual QA smoke tests, RPC capability detection (`rpc_compat`), fail-closed negative error paths, and newly integrated PR #55 Global Time tests.
- Zero broken tests, zero skipped tests, zero regressions.

### 2.2 Flutter Analyze Output
```text
Analyzing worktree-security-hardening...
No issues found! (ran in 12.0s)
```

### 2.3 Web Production Build Output
```text
Compiling lib\main.dart for the Web...
Font asset "CupertinoIcons.ttf" was tree-shaken, reducing it from 257628 to 1472 bytes (99.4% reduction).
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 22392 bytes (98.6% reduction).
Compiling lib\main.dart for the Web...                            103.3s
√ Built build\web
```

### 2.4 Android Toolchain Compilation Output
```text
Running Gradle task 'assembleDebug'...                             78.5s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

---

## 3. SECURITY MIGRATION INTEGRITY FINGERPRINTS

```json
{
  "verified_migrations": [
    {
      "order": 1,
      "filename": "20261010010000_stage1_p0_security_completion.sql",
      "sha256": "76a28ae3fc16f1f50689b0ea84be5e1d5eb8da9142f36f68593a12ffc7a33f38",
      "status": "VERIFIED_MATCH"
    },
    {
      "order": 2,
      "filename": "20261010055013_stage1_atomic_ai_quota_reservation.sql",
      "sha256": "51ab2bf16a503a4296238b72e505876352934dfc4aee4606132479e3e3b74dbf",
      "status": "VERIFIED_MATCH"
    },
    {
      "order": 3,
      "filename": "20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql",
      "sha256": "b94878a87677bf9fe1ebefafae22c8ae6e431f9d50a2e55729fb136367f08ca7",
      "status": "VERIFIED_MATCH"
    },
    {
      "order": 4,
      "filename": "20261012110945_stage1_security_abuse_storage_alignment.sql",
      "sha256": "9de2fd2515ec9a79e496a77dffad3d7e50406859e86a0b16a2d1033230b04a11",
      "status": "VERIFIED_MATCH"
    },
    {
      "order": 5,
      "filename": "20261012230000_ai_models_check_constraints_alignment.sql",
      "sha256": "d456396f9bf7b4a2bfec431526fc18d9f5da62134da99b21f9fb551a31b7d5eb",
      "status": "VERIFIED_MATCH"
    }
  ]
}
```
