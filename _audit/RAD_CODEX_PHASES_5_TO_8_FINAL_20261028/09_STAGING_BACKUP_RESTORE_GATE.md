# RAD EMIGRATE — STAGING BACKUP & RESTORE GATE AUDIT (PHASE 6)
**Date:** 2026-10-28  
**Gate Status:** **BLOCKED (Hard Security Gate Enforced)**  
**Target Hosted Project:** `epolbumcfbohtmgvomki` (Staging)  
**Read-Only Production Target:** `inshddthftkhcdosoqcn` (Production — Strictly READ-ONLY)  

---

## 1. GATE EVALUATION & DEPENDENCY ANALYSIS

The project guidelines establish an inviolable safety constraint:
> "No hosted Staging writes may take place until a real encrypted backup, successful isolated restore, and separate exact import authorization are established."

### Current Verification Findings:
1. **Connection Manifest Check**:
   - Path checked: `%LOCALAPPDATA%\RAD\staging-backup\connection.json`
   - Result: **ABSENT / NOT PROVIDED**.
2. **Strict Adherence**:
   - Zero credentials or service keys were invented or substituted.
   - Zero writes, schema repairs, or migration touches were executed on Hosted Staging (`epolbumcfbohtmgvomki`).
   - Production (`inshddthftkhcdosoqcn`) remains untouched and strictly read-only.

---

## 2. PREPARED BACKUP & RESTORE RUNBOOK

When the Owner provisions the verified connection manifest, the execution runbook is as follows:
1. **Pre-Backup Validation**:
   - Confirm read-only connection string matches project `epolbumcfbohtmgvomki`.
   - Verify network latency and SSL termination.
2. **Encrypted Snapshot Creation**:
   - Stream `pg_dump` with `--format=custom` through AES-256 encryption.
   - Store encrypted snapshot in secured offline storage.
3. **Isolated Test Restore**:
   - Spin up a clean scratch PostgreSQL instance.
   - Restore custom dump; verify row counts and table fingerprints against `PROPOSED_ROLLBACK_REVIEW_ONLY.sql`.
4. **Sign-Off Checkpoint**:
   - Only upon successful verification of the isolated restore may the Owner grant import authorization.
