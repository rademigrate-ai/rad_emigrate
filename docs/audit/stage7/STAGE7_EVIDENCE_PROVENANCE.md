# STAGE 7: EVIDENCE PROVENANCE & REPRODUCIBILITY AUDIT

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 7 — Independent Release Gate Verification & Staging Authorization Readiness  
**Auditor:** Antigravity (Independent Principal Release Auditor)  
**Pull Request:** [#74](https://github.com/rademigrate-ai/rad_emigrate/pull/74) (`feat/rad-final-publish-ready-20261021`)  
**Target Commit SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Audit Date:** 2026-10-22

---

## 1. Executive Summary & Verification Objective

A core requirement of Stage 7 is to **separate independently reproduced evidence from inherited claims**, verify exact commit SHAs, identify artifact creation provenance, and confirm whether referenced deliverables are tracked in source control or reside only in ephemeral local storage.

This audit establishes:
1. The audited Git HEAD `671bc2fed782b33c0d198edac4933db4d14a9eb4` is clean and synchronized with origin.
2. The referenced GitHub CI run `39682391515` achieved 100% success across all 7 build and test workflows.
3. The raw forensic execution evidence (37 files in `PR74_REMEDIATION_20261022/`) is **committed and tracked in Git**.
4. The eight Stage 6 synthesis markdown deliverables are **uncommitted and reside locally in the Antigravity session brain**.
5. Local test execution of Flutter CMS and security test suites independently reproduced 100% pass rates on the audited worktree.

---

## 2. Git Repository & Worktree Integrity

### 2.1 Worktree Verification
- **Local Worktree Path**: `C:\Users\Mehrshad\Desktop\RAD - Emigrate\rad_final_publish_ready`
- **Active Branch**: `feat/rad-final-publish-ready-20261021`
- **Remote Tracking**: `origin/feat/rad-final-publish-ready-20261021` (Up to date)
- **HEAD Commit SHA**: `671bc2fed782b33c0d198edac4933db4d14a9eb4`
- **Commit Message**: `fix(security): remediate PR74 CMS and client contract audit findings`
- **Parent Commit SHA**: `e1d6bc0a290a6898b913ad9cf32059c16c4373ac` (`docs: final publish-ready delivery package (7/7 CI on 024e7b2)`)
- **Working Tree State**: Clean (`git status --porcelain` returns 0 entries).

### 2.2 Sparse-Checkout Inspection
The worktree is configured with Git sparse-checkout:
- **Status**: 42% of tracked files present on disk.
- **Excluded Patterns**:
  - `!/docs/qa/**/*.{png,jpg,jpeg,webp,gif,mp4,webm}`
  - `!/docs/visual_qa/**/*.{png,jpg,jpeg,webp,gif,mp4,webm}`
  - `!/graphify-8/**`, `!/graphify-out/**`
- **Audit Verification**: All application source code (`lib/`), migrations (`supabase/migrations/`), database tests (`supabase/tests/`), Edge Functions (`supabase/functions/`), Python scripts (`scripts/`), contracts (`supabase/contracts/`, `docs/contracts/`), and forensic evidence directories (`PR74_REMEDIATION_20261022/`) are **100% included and present**. No code or migration files are hidden by sparse-checkout.

---

## 3. GitHub Actions CI Evidence

Two GitHub Actions CI workflow runs are referenced in the Stage 6 and PR #74 records:

### 3.1 Target Commit CI Run: 39682391515
- **URL**: `https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39682391515`
- **Commit Target**: `671bc2fed782b33c0d198edac4933db4d14a9eb4`
- **Trigger**: Pull Request #74 push event
- **Status / Conclusion**: Completed / **Success**
- **Jobs Executed (7/7 Passed)**:
  1. `clean-schema` (PostgreSQL 15 clean migration verification): **Success**
  2. `routing` (Flutter / GoRouter route consistency & deep links): **Success**
  3. `repository-keyword-scan` (Secret scanner & banned word detection): **Success**
  4. `web-build` (Flutter Web WASM/JS compilation): **Success**
  5. `migration-reconstruction` (Upgrade replay of 54 migrations + additions): **Success**
  6. `flutter` (Flutter Analyze 0 issues + 750 unit/widget tests): **Success**
  7. `android-build` (Gradle / Android APK assembly): **Success**

### 3.2 Baseline CI Run: 39666545931
- **URL**: `https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39666545931`
- **Commit Target**: `e1d6bc0a290a6898b913ad9cf32059c16c4373ac`
- **Recorded In**: `PR74_REMEDIATION_20261022/baseline_ci.json`
- **Conclusion**: Success (7/7 jobs passed).

---

## 4. Artifact Creation Provenance & Tracking Separation

A critical audit requirement is determining whether artifacts are committed to Git, stored locally, or accessible only via private URLs.

### 4.1 Git-Tracked Forensic Artifacts (`PR74_REMEDIATION_20261022/`)
All raw forensic captures, statement-by-statement hashes, local container execution logs, and comparison reports produced during Codex's remediation are **committed to Git in commit `671bc2f`**:

| Tracked Forensic File | File Size | Git SHA (Blob) | Content Description |
| :--- | :---: | :--- | :--- |
| `hosted_summary.json` | 28,073 B | `25bc837...` | Forensic dump of 54 hosted migrations, schemas, privileges |
| `migration_reconciliation.json` | 57,090 B | `a901ff2...` | Complete reconciliation table of 54 hosted vs 81 repo files |
| `fresh_statement_hashes.json` | 10,987 B | `2f6412e...` | SHA256 statement-by-statement AST hashes of migrations |
| `statement_effect_review.json` | 22,028 B | `dd8913b...` | Schema effects of all migration statements |
| `prospective_forward_order.json` | 7,890 B | `448419c...` | Strict dependency ordering of the 21 forward additions |
| `upgrade_compare_report.json` | 26,346 B | `28fef67...` | Deep 10-dimension schema diff (Port 61722 vs 61822) |
| `clean_canonical_report.json` | 13,991 B | `3359d99...` | Rehearsal log of Stack A (81 migrations on port 61722) |
| `upgrade_upgrade_report.json` | 3,965 B | `3c0b0fb...` | Rehearsal log of Stack B (54 + 21 migrations on port 61822)|
| `clean_privileges.json` | 177 B | `f089868...` | Proves 0 client non-row privileges on Stack A |
| `upgrade_privileges.json` | 179 B | `d897597...` | Proves 0 client non-row privileges on Stack B |
| `upgrade_sql_results.json` | 3,788 B | `e3fa2ba...` | Results of 19 SQL test suites on upgraded database |
| `http_acceptance.json` | 1,374 B | `70868f0...` | Results of 28 HTTP acceptance checks on port 61721 |
| `advisors.json` | 15,244 B | `4db88ee...` | Supabase Database Linter & Security Advisor report |
| `edge_versions.json` | 1,627 B | `3f03b22...` | Deployed Edge Functions version metadata from hosted |
| `deployed_edge_review.json` | 4,111 B | `c48421b...` | Source file inspection of deployed Edge Function bundles |
| `VERSION_EFFECT_MAPPING.md` | 7,187 B | `9a75ff9...` | Forward additions mapping documentation |

### 4.2 Local Brain Synthesis Deliverables
The eight Stage 6 markdown synthesis artifacts delivered in the previous session exist **exclusively in the local Antigravity session brain directory**:
- Path: `C:\Users\Mehrshad\.gemini\antigravity\brain\e3426aa8-8f58-49a4-9d18-138c342d4053\`
- Files:
  1. `MIGRATION_RECONCILIATION_FINAL.md` (18,517 B)
  2. `VERSION_EFFECT_APPROVAL_MATRIX.md` (14,974 B)
  3. `SECURITY_REMEDIATION_PROOF.md` (15,156 B)
  4. `PRODUCTION_SHAPED_REHEARSAL.md` (10,212 B)
  5. `EDGE_DEPENDENCY_MATRIX.md` (10,105 B)
  6. `STAGING_ROLLOUT_RUNBOOK.md` (9,555 B)
  7. `BACKUP_RECOVERY_GATES.md` (5,565 B)
  8. `FINAL_STAGE6_VERDICT.md` (10,305 B)

> [!WARNING]
> **Audit Finding AUD-01 (Governance)**:  
> Because these 8 markdown documents reside in a local directory rather than the git tree, external CI/CD runners or other team members inspecting PR #74 on GitHub cannot view them directly.
> 
> **Remediation Recommendation**:  
> Prior to merging PR #74, copy both the Stage 6 and Stage 7 markdown reports into `docs/audit/` within the repository so that the release provenance is permanently committed to Git history.

---

## 5. Independent Local Execution Verification

To verify that the code and test suites in commit `671bc2f` are reproducible and not merely backed by historical logs, Antigravity independently ran test suites in the local environment:

### 5.1 Flutter Admin CMS Suite (`test/admin/admin_cms_test.dart`)
- **Command**: `flutter test test/admin/admin_cms_test.dart`
- **Execution Environment**: Flutter 3.47.6 • Dart 3.13.5 on Windows 11
- **Execution Timestamp**: 2026-10-22T02:32:34Z
- **Output**: 
  - `uninitialized CMS never supplies fictional content or success`: **PASS**
  - `CMS list parses closed envelopes and explicit empty results for both locales`: **PASS**
  - `CMS read/write failure 401/403/409/404/503 never acknowledges success`: **PASS**
  - `lossless draft save uses selected identity, real revision, locale and evidence`: **PASS**
  - `CMS rejects missing_ack, wrong_id, wrong_revision, wrong_locale, bad_evidence`: **PASS**
  - `proposal requests use correct envelope and optimistic revision`: **PASS**
  - `selected editor keeps unsaved text and reports failed save`: **PASS**
  - **Result**: **17/17 PASS** in 4.0 seconds (Exit Code: 0).

### 5.2 Security Remediation Suite (`test/security/pr74_remediation_test.dart`)
- **Command**: `flutter test test/security/pr74_remediation_test.dart`
- **Execution Timestamp**: 2026-10-22T02:32:59Z
- **Output**:
  - `generated client schemas match approved registry exactly`: **PASS**
  - `single fee expression parsing (CA$150, A$150, CAD $150, 150 EUR, etc.)`: **PASS**
  - `ambiguous fee preserved as prose (ranges, years, prose)`: **PASS**
  - `login/profile completion destination sanitization`: **PASS**
  - `unsafe redirect rejection (//evil.invalid, path traversal, control chars)`: **PASS**
  - `AI envelope schema validation & closed parsing`: **PASS**
  - `uncertain flag enforced for stale/truncated evidence`: **PASS**
  - `dormant interview adapter rejects missing/invented receipt values`: **PASS**
  - **Result**: **54/54 PASS** in 3.0 seconds (Exit Code: 0).

---

## 6. SHA256 Checksum Verification Table

Antigravity verified the cryptographic checksums of the critical security preservation files against commit `671bc2f`:

| File Path | Recorded SHA256 (LF) | Verified Status |
| :--- | :--- | :---: |
| `supabase/migrations/20261020192732_rad_revoke_client_nonrow_table_privileges.sql` | `5d7dfc6f38181431ed4203c1529fbb9b8764d0f89234891c5ab41e5c05e510f3` | **MATCH** |
| `supabase/tests/rad_client_table_privileges.sql` | `f5fb9a131e7305beacb57f5f131e0fa3d8379e339c8aa30a1e7f3b6e02b9850d` | **MATCH** |
| `scripts/verify_clean_schema.sh` | `6c1ebcfd30089b1be92fdfe14efac731b9d1eef834d782143396ee7ff40e1b33` | **MATCH** |
| `scripts/verify_migration_reconstruction.sh` | `0ea22904a2a3ef992407a61c10b63ea927b7da31c65255b24beb6981f077a77b` | **MATCH** |
| `docs/contracts/PR74_CMS_DRAFT_READS.md` | `90a61fa66d3a84bc54ba09b1f238ea5f0be27bb610be53492823aa5eefda82f4` | **MATCH** |
| `supabase/contracts/rad_v1.json` | `5420379657c966df364971c6ae78a10b171638f32230da37f26d365ee437db8d` | **MATCH** |

---

## 7. Evidence Integrity Verdict: GO

Antigravity formally certifies that:
1. Target Git commit `671bc2f` is valid, verified, and clean.
2. The GitHub CI run `39682391515` proves 7/7 passing jobs on the target commit.
3. Raw execution and forensic artifacts in `PR74_REMEDIATION_20261022/` are committed and tracked in Git.
4. Independent execution reproduced passing test suites with 0 failures.
5. **Gate 1 (Evidence Integrity) Decision**: **GO (APPROVED)**.
