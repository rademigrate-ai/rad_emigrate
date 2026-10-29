# RAD EMIGRATE — CODEX WIP RECOVERY AND INTEGRATION REPORT
**Date:** 2026-10-28  
**Worktree Source:** `C:\Users\Mehrshad\.codex\.chatgpt-projects\g-p-6ac0d7441b788191a2bebe4046483d35\rad_content_worktree`  
**Target Worktree:** `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_pr86_worktree`  
**Branch:** `support/codex-phases1-4-20261028`

---

## 1. RECOVERY INVENTORY & PROVENANCE

Codex reached its usage limit while actively developing Phase 5 local QA tooling and reproducing the routing defect. The following files were preserved, inventoried, and transferred into `_pr86_worktree`:

| File Path | Status in Codex Worktree | Size (Bytes) | SHA-256 Checksum |
|---|---|---|---|
| `test/core/app_router_public_routes_test.dart` | Modified (Uncommitted) | 7,315 | `d4ae38c38870bb20a0104e76cb7161b6711ea1e80570c0657e3884783861bc5d` |
| `tools/final_acceptance/__init__.py` | Untracked | 82 | `4cfc38a5640aa16e8c2233ac2c9a6ae9daded6cf18f3ce5e113320338bb32ada` |
| `tools/final_acceptance/local_backend.py` | Untracked | 5,632 | `fe6b520030de5dd58d882f6742321a77c56b307c976861259fabaa5d35551d08` |
| `tools/final_acceptance/serve.py` | Untracked | 1,068 | `087b009c27ad684fc984fc4e8f255a79e3f94acf486b9f4a3027801c6da52fe3` |
| `_audit/.../preliminary/asset-review.json` | Untracked | 834 | `7e616f82bce3c1aa256ca93b71e0ee975fb77a316a9b6698a236a2b0bef6df34` |
| `_audit/.../preliminary/local-real-auth-rls.json` | Untracked | 2,561 | `61322bb7f753e6572814ad5af42406da408c0b9cb179834834e1b15161454b67` |
| `_audit/.../preliminary/local-start.json` | Untracked | 13,612 | `be6e3b288c70ea37127c8933bbeec4811a5fe8e66ae00420d6155c9957deef88` |

---

## 2. WORKTREE HYGIENE & SAFETY MEASURES

1. **Codex Worktree Untouched**:
   - The Codex worktree at `C:\Users\Mehrshad\.codex\.chatgpt-projects\g-p-6ac0d7441b788191a2bebe4046483d35\rad_content_worktree` was inspected in read-only mode using `-c safe.directory` overrides.
   - Zero files were deleted, cleaned, or reset in the Codex sandbox directory.
   - The active local SPA server process (PID 19052) was left running.

2. **Dedicated PR #86 Worktree Created**:
   - `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_pr86_worktree` was provisioned directly tracking `origin/support/codex-phases1-4-20261028` at commit `862b71483f81077cd542086a3a8db042c5dd9d54`.
   - Existing worktree `_stage7/worktree` (on `integration/stage7-unified-20261026`) and contributor worktrees remain completely intact.

3. **Confidentiality & Secret Prevention**:
   - `qa-accounts.private.json` and local temporary markers in `%LOCALAPPDATA%\Temp\rad_codex_final_20261028\` were excluded from git tracking.
   - All private credentials, passwords, or SID tokens remain outside repository commits.
