# RAD EMIGRATE — STAGE 1 SAFE DEPLOYMENT & RECOVERY RUNBOOK

**Target Project:** `inshddthftkhcdosoqcn` (Production Supabase)  
**Execution Authority:** Production DBA / Project Owner Only  
**Antigravity Agent Role:** Read-Only Verification & Artifact Preparation  
**Required Window:** Low-traffic maintenance window (estimated execution time: < 3 minutes)  
**Revision Date:** October 17, 2026  

---

## 1. PRE-DEPLOYMENT PREREQUISITES & SAFETY CHECKLIST

Before executing ANY database migration in Production, the DBA and Project Owner must verify each prerequisite item:

- [ ] **1. Live Database Ledger Verification (Read-Only Pre-flight):**
  - Run the following check against `inshddthftkhcdosoqcn` to confirm baseline parity:
    ```sql
    SELECT version, name FROM supabase_migrations.schema_migrations 
    ORDER BY version DESC LIMIT 5;
    -- Expected: Top version is 20261007212140. None of the five 20261010* or 20261012* migrations are present.
    ```
- [ ] **2. Client & Edge Code Deployed:** Companion PR from `security/stage1-reconciliation-20261017` is built and deployed to production web and edge runtimes.
- [ ] **3. Live Backup & PITR Confirmed:** 
  - Access Supabase Dashboard -> Database -> Backups.
  - Verify a fresh backup snapshot exists.
  - Confirm Point-In-Time-Recovery (PITR) is active and the recovery window includes the current timestamp.
- [ ] **4. Write Traffic Quiescence:** 
  - Coordinate scheduled maintenance banner or execute during minimum user activity.
- [ ] **5. Checksums Verified on Execution Machine:**
  - Verify SHA-256 hashes of the 5 migration files matching `docs/releases/PHASE_A_SECURITY_MANIFEST.json`.
- [ ] **6. Strict Transaction Isolation:**
  - Execute each migration within an explicit transaction block (`BEGIN ... COMMIT`).
  - Set statement timeout (`SET statement_timeout = '15s';`) to prevent indefinite lock waits.

---

## 2. STEP-BY-STEP DBA EXECUTION SEQUENCE

Execute the 5 migrations in strict sequential order. Do NOT skip any step.

### Step 1: P0 Security Completion & Consultation Confidentiality
**File:** `supabase/migrations/20261010010000_stage1_p0_security_completion.sql`  
**Expected Duration:** < 500ms  
**Pre-condition:** Production ledger at `20261007212140`.  
**Execution:**
```bash
psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261010010000_stage1_p0_security_completion.sql
```
*Note: This script contains an internal `begin; ... commit;` block.*  
**Post-Flight Check 1:**
```sql
SELECT count(*) FROM pg_proc WHERE proname IN ('list_admin_consultations', 'update_admin_consultation', 'publish_content_draft');
-- Expected: 3
SELECT has_table_privilege('authenticated', 'public.consultation_requests', 'UPDATE');
-- Expected: false
```

---

### Step 2: Atomic AI Quota Reservation
**File:** `supabase/migrations/20261010055013_stage1_atomic_ai_quota_reservation.sql`  
**Expected Duration:** < 300ms  
**Execution:**
```bash
psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 << 'EOF'
BEGIN;
\i supabase/migrations/20261010055013_stage1_atomic_ai_quota_reservation.sql
COMMIT;
EOF
```
*Note: Migration 2 does not contain an internal transaction block; wrap in `BEGIN; ... COMMIT;`.*  
**Post-Flight Check 2:**
```sql
SELECT prosrc LIKE '%atomic_quota_reservation%' 
FROM pg_proc 
WHERE proname = 'consume_ai_daily_quota';
-- Expected: true
```

---

### Step 3: Dual-Stack SSRF Hardening (IPv4-Mapped IPv6)
**File:** `supabase/migrations/20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql`  
**Expected Duration:** < 300ms  
**Execution:**
```bash
psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql
```
**Post-Flight Check 3:**
```sql
SELECT private.is_safe_public_https_url('https://[::ffff:127.0.0.1]/api');
-- Expected: false (Loopback blocked)
SELECT private.is_safe_public_https_url('https://[::ffff:169.254.169.254]/api');
-- Expected: false (Link-local blocked)
SELECT private.is_safe_public_https_url('https://api.openai.com/v1');
-- Expected: true (Public safe URL allowed)
```

---

### Step 4: Abuse Control & Storage Upsert Alignment
**File:** `supabase/migrations/20261012110945_stage1_security_abuse_storage_alignment.sql`  
**Expected Duration:** < 500ms  
**Execution:**
```bash
psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261012110945_stage1_security_abuse_storage_alignment.sql
```
**Post-Flight Check 4:**
```sql
SELECT count(*) FROM pg_proc WHERE proname = 'submit_consultation_request';
-- Expected: 1
SELECT has_table_privilege('authenticated', 'public.consultation_requests', 'INSERT');
-- Expected: false (Direct table insert fully revoked)
SELECT count(*) FROM pg_policies WHERE tablename = 'objects' AND policyname = 'users update own documents';
-- Expected: 1
```

---

### Step 5: AI Model Numeric CHECK Constraint Validation
**File:** `supabase/migrations/20261012230000_ai_models_check_constraints_alignment.sql`  
**Expected Duration:** < 1000ms (validates 682 rows)  
**Execution:**
```bash
psql "$PROD_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261012230000_ai_models_check_constraints_alignment.sql
```
**Post-Flight Check 5:**
```sql
SELECT conname, convalidated 
FROM pg_constraint 
WHERE conname IN (
  'ai_models_consecutive_failures_nonnegative',
  'ai_models_last_latency_ms_nonnegative',
  'ai_models_rolling_success_rate_range'
);
-- Expected: 3 rows, all convalidated = true
```

---

## 3. ROLLBACK & DISASTER RECOVERY PROCEDURES

> [!CAUTION]
> Reverting the Git Pull Request DOES NOT revert database changes applied to PostgreSQL. Automatic down-migrations are not supported by Supabase.

### 3.1 Failure During Apply
If any migration fails midway through execution:
1. The failing script will automatically roll back its active transaction due to `ON_ERROR_STOP=1` and `BEGIN ... COMMIT`.
2. Do NOT attempt to run `supabase db push` or `migration repair`.
3. Assess the exact error code from PostgreSQL.
4. If remediation requires rolling back to the pre-change state:
   - Restore from the verified Point-In-Time-Recovery (PITR) point created immediately prior to the change window.

### 3.2 Post-Migration Health Probes & Alarms
Run following end-to-end user checks immediately post-deployment:
1. **Public Route Access:** Verify `/`, `/destinations`, `/visa` load anonymously.
2. **Consultation Submission:** Submit a synthetic test consultation via authenticated user; confirm ticket is created with status `'submitted'`.
3. **AI Chat Interaction:** Execute an AI question; confirm daily quota decreases by exactly 1, request status transitions to `'succeeded'`, and no double rows are created.
4. **Admin Console:** Log in with admin credentials; confirm `/admin/consultations` lists tickets and allows updating status with internal notes.
