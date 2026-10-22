# STAGE 8: COMPREHENSIVE TEST RESULTS & EXECUTION LOGS

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 8 — Final Release Evidence Consolidation, Staging Preflight & PR #74 Hardening  
**Lead Engineer:** Codex  
**Pull Request:** [#74](https://github.com/rademigrate-ai/rad_emigrate/pull/74) (`feat/rad-final-publish-ready-20261021`)  
**Target Commit SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Date:** 2026-10-22

---

## 1. Master Testing Summary Matrix

All test suites across Flutter, Python, SQL, and HTTP acceptance harnesses were executed in isolated environments against the candidate release codebase:

| Test Harness / Suite | Total Tests | Passed | Failed | Skipped / Excluded | Success Rate | Execution Environment |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Flutter Unit & Widget Tests** | **750** | **750** | **0** | **0** | **100%** | Flutter 3.47.6 • Dart 3.13.5 |
| **Python Script & Preflight Tests**| **52** | **52** | **0** | **0** | **100%** | Python 3.14.7 |
| **Database SQL Test Suites** | **19** | **16** | **0** | **3** (Justified) | **100%** (Applicable)| PostgreSQL 15 / Supabase CLI |
| **HTTP API Acceptance Checks** | **28** | **28** | **0** | **0** | **100%** | PostgREST 12 / Local Harness |
| **GitHub Actions CI Workflows**| **7** | **7** | **0** | **0** | **100%** | Ubuntu 22.04 Cloud Runners |

---

## 2. Flutter & Dart Test Results

### 2.1 Code Quality & Static Analysis
- **Command**: `flutter analyze`
- **Output**: `No issues found! (ran in 12.4s)`
- **Analyzer Status**: **0 errors, 0 warnings, 0 lints**.

### 2.2 Flutter Admin CMS Test Suite
- **Command**: `flutter test test/admin/admin_cms_test.dart`
- **Execution Timestamp**: 2026-10-22T02:32:34Z
- **Duration**: 4.0 seconds
- **Assertions Verified**:
  - `uninitialized CMS never supplies fictional content or success`: **PASS**
  - `CMS list parses closed envelopes and explicit empty results for both locales`: **PASS**
  - `CMS read/write failure 401/403/409/404/503 never acknowledges success`: **PASS**
  - `lossless draft save uses selected identity, real revision, locale and evidence`: **PASS**
  - `CMS rejects missing_ack, wrong_id, wrong_revision, wrong_locale, bad_evidence`: **PASS**
  - `proposal requests use correct envelope and optimistic revision`: **PASS**
  - `selected editor keeps unsaved text and reports failed save`: **PASS**
  - **Result**: **17/17 PASS**.

### 2.3 Security Remediation & Contract Suite
- **Command**: `flutter test test/security/pr74_remediation_test.dart`
- **Execution Timestamp**: 2026-10-22T02:32:59Z
- **Duration**: 3.0 seconds
- **Assertions Verified**:
  - `generated client schemas match approved registry exactly`: **PASS**
  - `single fee expression parsing (CAD $150, AUD $150, 150 EUR, US$150)`: **PASS**
  - `ambiguous/unsupported fee preserved as publishedTextOnly prose`: **PASS**
  - `login/profile completion destination sanitization`: **PASS**
  - `open redirect rejection (//evil.invalid, path traversal, control chars)`: **PASS**
  - `closed AI envelope schema validation`: **PASS**
  - `uncertain flag enforced for stale or truncated evidence`: **PASS**
  - `dormant interview adapter rejects missing/invented receipt values`: **PASS**
  - **Result**: **54/54 PASS**.

### 2.4 Total Flutter Suite Coverage
- **Total Test Files**: 141 files in `test/`.
- **Total Unit & Widget Tests**: 750 tests.
- **Pass Rate**: 750/750 (100% GREEN).

---

## 3. Python Verification & Preflight Test Results

- **Command**: `python -m unittest discover -s scripts/tests`
- **Execution Timestamp**: 2026-10-22T02:45:16Z
- **Duration**: 7.269 seconds
- **Total Tests Executed**: 52 tests.
- **Key Modules Tested**:
  - `test_staging_preflight.py` (9/9 PASS): Rejection of missing project ID, production project ID, invalid formats, missing backup records, missing owner approvals, and migration checksum mismatches.
  - `test_staging_environment.py` (13/13 PASS): Validation of staging environment flags, database targets, public key claims, and private credential isolation.
  - Supporting script test suites (30/30 PASS).
- **Result**: **52/52 PASS (100% GREEN)**.

---

## 4. Database SQL Test Suites (`supabase/tests/`)

Recorded in `PR74_REMEDIATION_20261022/upgrade_sql_results.json` from rehearsal on port 61822:

| Test Script | Status | Duration | Category |
| :--- | :---: | :---: | :--- |
| `security_regression.sql` | **PASS** | 0.101s | Privilege revokes, schema security |
| `phase_a_constraint_backfill.sql` | **PASS** | 0.160s | Constraint enforcement, foreign keys |
| `phase_a_security.sql` | **PASS** | 0.244s | Role privileges, session security |
| `stage2_knowledge_completion.sql` | **PASS** | 0.149s | Knowledge base tables and relations |
| `stage4_user_ai.sql` | **PASS** | 0.108s | User AI preferences, profile linkages |
| `local47_crm_notifications.sql` | **PASS** | 0.298s | CRM intake, consultation status lifecycle |
| `local47_payment_sandbox.sql` | **NOT RUN** | - | *Excluded: Obsolete local payment mock* |
| `local47_definer_acl.sql` | **PASS** | 0.175s | Security definer search path and ACL |
| `local47_document_processing.sql` | **NOT RUN** | - | *Excluded: Obsolete worker lease locks* |
| `local47_observability.sql` | **NOT RUN** | - | *Excluded: Obsolete local incident table* |
| `rad_client_table_privileges.sql` | **PASS** | 0.098s | Verification of 0 non-row privileges |
| `rad_content_security.sql` | **PASS** | 0.211s | Profile role escalation & CMS security |
| `rad_feed_currency_security.sql` | **PASS** | 0.248s | Currency cache, alert preferences |
| `rad_interactions.sql` | **PASS** | 0.201s | User interaction logs, idempotency |
| `rad_merge_provenance.sql` | **PASS** | 0.318s | Evidence merge and provenance chains |
| `rad_official_evidence.sql` | **PASS** | 0.408s | Official evidence intake and validation |
| `rad_privacy_security.sql` | **PASS** | 0.099s | User data redaction and isolation |
| `rad_quota_security.sql` | **PASS** | 0.103s | Daily token quotas, guest rate limits |
| `rad_search_performance.sql` | **PASS** | 8.878s | Trigram & full-text search performance |

---

## 5. End-to-End HTTP Acceptance Suite (`http_acceptance.json`)

28 HTTP acceptance checks executed against `http://127.0.0.1:61721`:
- Synthetic Auth signup HTTP 200: **PASS**
- JWT RLS profile owner isolation: **PASS**
- HTTP role UPDATE denied: **PASS**
- Orphan profile INSERT role escalation denied: **PASS**
- Safe orphan profile completion succeeds: **PASS**
- Private & Vault schemas not exposed via REST: **PASS**
- Direct draft table query denied: **PASS**
- Quota service boundary denies ordinary JWT: **PASS**
- Cross-user consultation read hidden: **PASS**
- Cross-user consultation status mutation denied: **PASS**
- Concurrency test (10 concurrent requests admit exactly 2): **PASS**
- Same key reuses exact reservation: **PASS**
- Changed-body key replay conflicts: **PASS**
- Settlement updates same reservation: **PASS**
- Terminal settlement fenced: **PASS**

---

## 6. GitHub Actions CI Evidence (Run 39682391515)

- **Workflow Run**: `https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39682391515`
- **Commit Target**: `671bc2fed782b33c0d198edac4933db4d14a9eb4`
- **Jobs Executed**:
  1. `clean-schema`: **Success**
  2. `routing`: **Success**
  3. `repository-keyword-scan`: **Success**
  4. `web-build`: **Success**
  5. `migration-reconstruction`: **Success**
  6. `flutter`: **Success**
  7. `android-build`: **Success**
- **Conclusion**: **100% GREEN (7/7 Passed)**.
