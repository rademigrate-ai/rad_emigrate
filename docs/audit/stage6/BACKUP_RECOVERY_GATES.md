# BACKUP AND DISASTER RECOVERY GATES

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 6 — Supabase Migration Reconciliation & Staging Readiness  
**Target Project:** `inshddthftkhcdosoqcn`  
**Gate Status:** **BLOCKED (OWNER ACTION REQUIRED)**  
**Author:** Codex (Principal Supabase/PostgreSQL Architect & Release Engineer)

---

## 1. Gate Status and Executive Finding

| Quality Gate | Current Status | Blocker Description | Resolution Path |
| :--- | :---: | :--- | :--- |
| **Backup & Recovery Gate** | **BLOCKED** | Hosted Supabase project backup retention, PITR status, and WAL archiving are unverified from read-only client access. | Project Owner must verify PITR and trigger manual snapshot via Dashboard. |

> [!CAUTION]
> **Zero production mutations are permitted until this gate is satisfied.**
> Database migrations alter table structures, drop privileges, and update indexes. While the 21 forward migrations have passed 100% of rehearsal tests without data loss, industry-standard deployment governance mandates that an independent, restorable backup exists and has been verified prior to executing schema DDL.

---

## 2. Technical Analysis of Hosted Project `inshddthftkhcdosoqcn`

### 2.1 Capabilities and Limitations of Read-Only Client Inspection
From read-only SQL, REST, and public API interfaces, the following parameters are visible:
- PostgreSQL engine version: PostgreSQL 15.x / 16.x on Supabase managed infrastructure.
- Migration ledger: 54 recorded migrations in `supabase_migrations.schema_migrations`.
- Table count: 29 core tables, plus internal auth and storage schemas.

However, **Supabase platform management APIs and physical backup facilities are decoupled from the PostgreSQL database engine**:
- **Point-in-Time Recovery (PITR)**: Requires Supabase Pro or Enterprise tier with continuous WAL archiving to object storage.
- **Physical Snapshots**: Nightly automated pg_dump snapshots vary from 7 days (Pro) to 30 days (Enterprise). On Free tier, automated backups and PITR are **unavailable**.
- **Management Permissions**: Initiating or inspecting backups requires administrative access to the Supabase Cloud Management Console (`api.supabase.com/v1/projects/{ref}/backups`).

### 2.2 Disaster Recovery Objectives

RAD Emigrate handles user immigration profiles, legal consultation requests, payment transaction logs, and official evidence citations. A reliable backup configuration must satisfy:

| Objective Metric | Target SLA | Requirement for Compliance |
| :--- | :--- | :--- |
| **RPO (Recovery Point Objective)** | **< 1 Hour** | Continuous WAL archiving (Point-in-Time Recovery enabled). Ensures maximum acceptable data loss in catastrophic outage is under 60 minutes. |
| **RTO (Recovery Time Objective)** | **< 4 Hours** | Automated snapshot restoration via Supabase CLI or Dashboard. Complete restore of database and schema within 240 minutes. |
| **Backup Retention Window** | **>= 14 Days** | Daily automated snapshot history retained for at least two weeks. |

---

## 3. Owner Verification Runbook (Required Action)

The project owner must execute the following protocol prior to opening the Staging/Production release windows:

### Step 1: Verify Subscription Tier and PITR Status
1. Log into the **Supabase Dashboard**:  
   `https://supabase.com/dashboard/project/inshddthftkhcdosoqcn`
2. Navigate to **Project Settings** (gear icon) -> **Database**.
3. Scroll down to the **Backups** section.
4. Verify the following:
   - Is **Point in Time Recovery (PITR)** marked **Enabled**?
   - If disabled, click **Enable PITR** (requires Pro tier or higher). Confirm that WAL archiving begins.

### Step 2: Manually Trigger a Pre-Rollout Backup Snapshot
1. In the **Backups** panel, locate **Scheduled Backups** or **Manual Backups**.
2. Click **Take Backup Now** / **Create Backup**.
3. Label the snapshot: `pre-stage6-migration-reconciliation-20261022`.
4. Wait for the status indicator to transition to **Completed**.
5. Record the backup ID and completion timestamp.

### Step 3: Optional Isolated Restore Verification (Recommended)
1. In the Supabase Dashboard, create a temporary development branch or clone:
   - Navigate to **Project Settings** -> **Database** -> **Backups**.
   - Select **Restore to a New Project** or use `supabase db clone`.
2. Verify that the cloned database starts up cleanly and reports 54 rows in `supabase_migrations.schema_migrations`.
3. Terminate or pause the cloned instance after verification.

---

## 4. Formal Sign-Off Template

Once the owner completes the verification steps, the following gate checklist must be completed and countersigned in the release notes:

```markdown
### Backup and Recovery Gate Sign-Off
- **Supabase Project Ref**: inshddthftkhcdosoqcn
- **Project Tier**: [ ] Pro / [ ] Team / [ ] Enterprise
- **Point-in-Time Recovery (PITR)**: [ ] ENABLED / [ ] VERIFIED
- **Pre-Rollout Backup Snapshot ID**: ___________________________________
- **Snapshot Completion Timestamp**: ___________________________________
- **Verified By (Owner Name/Signature)**: _______________________________
- **Date**: ___________________________________________________________
- **Gate Status**: [ ] APPROVED FOR STAGING ROLLOUT
```

---

## 5. Conclusion

The isolated local rehearsal has verified 100% schema integrity and test suite success. However, enforcing the **BLOCKED** state on the Backup & Recovery Gate preserves production safety standards. Upon completion of the owner verification runbook, this gate transitions to **GO**.
