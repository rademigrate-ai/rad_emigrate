# RAD EMIGRATE — STAGE 1 PRODUCTION SECURITY AUDIT & FORENSICS REPORT

**Date:** October 17, 2026
**Auditor / Agent:** Antigravity Advanced Agentic Coding Assistant
**Repository:** `rademigrate-ai/rad_emigrate`
**Target Pull Request:** PR #48 (`rademigrate-ai:phase-a/security-migrations-20261015`)
**Production Supabase Reference:** `inshddthftkhcdosoqcn`
**Baseline Git Commit:** `678e7a4c898995bb4a0519afd467df4126dd4a2e` (PR #51 merged cleanly on `main`)
**Integration Branch:** `security/stage1-reconciliation-20261017` (HEAD: `19127c6`)
**Status:** COMPLETE — AUDIT VERIFIED — NO LIVE WRITES PERFORMED

---

## 1. EXECUTIVE SUMMARY & MISSION OBJECTIVE

The Stage 1 Security Hardening mission is to evaluate, reconcile, and prove production readiness for the five verified Stage 1 database security migrations in PR #48, without making any modifications to live Production Supabase data, schema, migration ledger, Auth, Storage, Vault, or Edge Functions.

The five security migrations address critical P0/P1 security vulnerabilities:
1. **Consultation Confidentiality & Privilege Tightening:** Revokes unrestricted table-level access, establishes column-level grants, introduces secure SECURITY DEFINER RPCs for consultation intake and admin review with audit logging, enforces human-only Feed publishing via triggers, and validates OCR endpoint HTTPS destinations.
2. **Atomic AI Quota Reservation:** Eliminates concurrency race conditions in daily AI request counting via advisory transaction locks (`pg_advisory_xact_lock`), reserving request slots atomically before model inference.
3. **SSRF Hardening (IPv4-Mapped IPv6):** Closes loopback and private network bypasses by hardening regex and network parsing against dual-stack IPv4-mapped IPv6 address formats (`::ffff:127.0.0.1`, `::ffff:10.0.0.0/8`, etc.).
4. **Abuse Control & Storage Alignment:** Enforces strict user-scoped rate limiting (3/hour, 10/day) on consultation intake via `submit_consultation_request`, revokes direct table `INSERT` from `authenticated`, and aligns storage RLS policies with user-scoped upsert operations.
5. **AI Model Constraint Validation:** Enforces non-negative bounds and [0.0, 1.0] domain invariants on latency, failure counts, and success rates using `NOT VALID` followed by `VALIDATE CONSTRAINT` to prevent table-level exclusive lock starvation.

---

## 2. PRODUCTION FORENSICS & BASELINE RECONCILIATION

### 2.1 The Three Sources of Truth

Our audit identified three distinct layers of state that must be reconciled:
1. **Repository Migration Chain:** 46 sequential migrations on `main` + 5 pending Stage 1 migrations in PR #48 = 51 migrations.
2. **Production Migration Ledger (`supabase_migrations.schema_migrations`):** Historical ledger records 47 entries ending at version `20261007212140`.
3. **Live PostgreSQL Schema:** Actual tables, functions, RLS policies, column grants, triggers, and constraints present in project `inshddthftkhcdosoqcn`.

```
+-----------------------------------------------------------------------------------+
| THREE SOURCES OF TRUTH                                                            |
|                                                                                   |
|  [Repository PR #48]                 [Production Ledger]     [Live Schema]        |
|  51 migration files                  47 ledger entries       57 tables            |
|  - 46 base migrations                - 16 timestamp aliases  47 functions         |
|  - 5 Stage 1 security migrations     - 4 live-only names     117 RLS policies     |
|                                      - Ends at 20261007212140                     |
+-----------------------------------------------------------------------------------+
```

### 2.2 Forensic Analysis of the Live Production Ledger (Historical Baseline vs Current Session)

> [!IMPORTANT]
> **Live Production State Status: UNVERIFIED in this Session**
> No live database credentials or interactive database connections were provided for this session. Therefore, live production schema and ledger status are explicitly classified as **UNVERIFIED**. The findings below reflect documented forensic baselines established during the October 12–13, 2026 audits, not newly verified live telemetry. Live database execution remains strictly **NO-GO**.

1. **Missing Migrations:** The five Stage 1 migrations (`20261010010000`, `20261010055013`, `20261010070000`, `20261012110945`, `20261012230000`) were confirmed absent in the historical production ledger.
2. **Historical Timestamp Aliases (16 Entries):** Historical development resulted in 16 migration ledger entries where filenames in Production differ by seconds/minutes from early branch commits. These aliases MUST NOT be replayed or touched, as doing so would cause duplicate DDL conflicts or corrupt the migration history.
3. **Live-Only Names (4 Entries):** Certain early migrations exist under alternate names in the historical ledger.
4. **Clean Baseline Parity:** In the baseline audit, 57 application tables, 47 functions, and 117 RLS policies were active in Production, satisfying semantic baseline parity. Existing AI models (682 rows) and document processor configurations satisfied all pending CHECK constraints.

---

## 3. IDENTIFIED INCOMPATIBILITIES & ROOT CAUSES

Through comprehensive static analysis of the Flutter application and Supabase Edge Functions against the 5 security migrations, we identified three critical blockers that would cause immediate production incidents if PR #48 were deployed without client reconciliation:

### 3.1 Defect 1: Client Consultation Submission Denial & Unsafe Fallback Elimination
- **Vulnerability / Security Action:** Migration 4 (`20261012110945_stage1_security_abuse_storage_alignment.sql`) revokes all direct `INSERT` privileges on `public.consultation_requests` from `authenticated` users, requiring all submissions to pass through `submit_consultation_request(p_topic, p_message, p_related_application_id)` to enforce 3/hour and 10/day abuse limits.
- **Client Incompatibility:** `lib/features/consultation/presentation/pages/consultation_page.dart` originally performed direct table insert, and initial fallback attempts used a broad `catch (_)` which would dangerously bypass security on permission errors or timeouts.
- **Consequence:** Immediate breakage of applicant consultation requests upon migration execution, or unsafe fallback bypassing security boundaries.
- **Resolution Applied:** Updated `consultation_page.dart` and created `lib/core/supabase/rpc_compat.dart` with `isRpcMissingException`. Only missing-RPC errors (`PGRST202` / `42883`) fall back to direct insert during rolling deployments. All authorization failures (`42501`), rate limits (`P0001`), validation errors (`22023`), timeouts, and network failures fail closed and rethrow.

### 3.2 Defect 2: Admin Consultation Console Failure & Narrow Admin Fallback
- **Vulnerability / Security Action:** Migration 1 (`20261010010000_stage1_p0_security_completion.sql`) revokes table-wide `SELECT` on `public.consultation_requests` from `authenticated`, specifically withholding `admin_note` from applicant column grants. It also revokes direct `UPDATE` privileges, replacing them with audited SECURITY DEFINER functions `list_admin_consultations()` and `update_admin_consultation(uuid, text, text)`.
- **Admin Incompatibility:** `lib/features/admin/presentation/pages/admin_consultations_page.dart` directly selected `admin_note` and executed direct table updates with broad `catch (_)` fallback.
- **Consequence:** Admin users would be unable to view or update consultation tickets once Migration 1 was executed, or non-admin users could trigger fallbacks.
- **Resolution Applied:** Updated `admin_consultations_page.dart` to query `list_admin_consultations` RPC and update via `update_admin_consultation` RPC, with narrow `isRpcMissingException` fallback. Permission errors (`42501`) and validation rejections fail closed immediately.

### 3.3 Defect 3: AI Quota Fail-Open, Double-Counting & Orphaned Reservations
- **Vulnerability / Security Action:** Migration 2 (`20261010055013_stage1_atomic_ai_quota_reservation.sql`) modified `consume_ai_daily_quota` to atomically insert an `ai_requests` row with `status: 'running'` and `routing_reason: 'atomic_quota_reservation'` inside an advisory transaction lock, returning `request_id`.
- **Edge Function Defect:** `supabase/functions/ai-orchestrator/handler.ts` swallowed quota check errors (failing open), ignored `quota.request_id`, and proceeded to insert a *second* `ai_requests` row.
- **Consequence:**
  1. Failed quota checks allowed unmetered AI usage (fail-open).
  2. Every valid query consumed TWO quota units instead of one, cutting user quota in half.
  3. The initial reservation row was never updated on success/failure, remaining orphaned in `status: 'running'`.
- **Resolution Applied:** Updated `handler.ts` to strictly fail closed: returns 503 on quota check errors, 500 on malformed quota responses, and 429 on daily limit reached. Captured `quota.request_id`, attached `session_id` and routing metadata via `PATCH`, and completely eliminated the duplicate direct `INSERT` fallback into `ai_requests`.

---

## 4. VERIFIED SHA-256 MIGRATION HASHES

All five migration files in PR #48 were verified byte-for-byte against `docs/releases/PHASE_A_SECURITY_MANIFEST.json`:

| Order | Migration Filename | Manifest SHA-256 Hash | Repository Checkout Hash | Verification |
|---|---|---|---|---|
| 1 | `20261010010000_stage1_p0_security_completion.sql` | `76a28ae3fc16f1f50689b0ea84be5e1d5eb8da9142f36f68593a12ffc7a33f38` | `76a28ae3fc16f1f50689b0ea84be5e1d5eb8da9142f36f68593a12ffc7a33f38` | MATCH |
| 2 | `20261010055013_stage1_atomic_ai_quota_reservation.sql` | `51ab2bf16a503a4296238b72e505876352934dfc4aee4606132479e3e3b74dbf` | `51ab2bf16a503a4296238b72e505876352934dfc4aee4606132479e3e3b74dbf` | MATCH |
| 3 | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` | `b94878a87677bf9fe1ebefafae22c8ae6e431f9d50a2e55729fb136367f08ca7` | `b94878a87677bf9fe1ebefafae22c8ae6e431f9d50a2e55729fb136367f08ca7` | MATCH |
| 4 | `20261012110945_stage1_security_abuse_storage_alignment.sql` | `9de2fd2515ec9a79e496a77dffad3d7e50406859e86a0b16a2d1033230b04a11` | `9de2fd2515ec9a79e496a77dffad3d7e50406859e86a0b16a2d1033230b04a11` | MATCH |
| 5 | `20261012230000_ai_models_check_constraints_alignment.sql` | `d456396f9bf7b4a2bfec431526fc18d9f5da62134da99b21f9fb551a31b7d5eb` | `d456396f9bf7b4a2bfec431526fc18d9f5da62134da99b21f9fb551a31b7d5eb` | MATCH |

---

## 5. RECONCILIATION SUMMARY & DEPLOYMENT GATE STATUS

| Investigation Area | Result | Notes |
|---|---|---|
| Migration Integrity | PASS | SHA-256 hashes match byte-for-byte; no manual ledger alterations |
| Application Compatibility | RESOLVED | Client & Edge Function PR companion implemented with narrow capability detection & fail-closed quota |
| Flutter Test Suite | PASS | 446 tests passing (100% green); static analysis 0 issues; 249 files formatted |
| Web Production Build | PASS | Release compilation succeeded in 103.3s |
| Android Toolchain Build | PASS | Debug APK compiled in 78.5s; Release signing gate enforced |
| Live Production Status | UNVERIFIED / NO-GO | No credentials present in session; zero write operations permitted; strictly NO-GO |
| Overall Deployment Gate | HOLD | Awaiting owner approval of PR #48, companion PR merge, and DBA change window |
