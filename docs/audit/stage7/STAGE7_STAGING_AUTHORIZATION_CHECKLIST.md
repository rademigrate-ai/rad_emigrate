# STAGE 7: STAGING ROLLOUT SAFETY REVIEW & AUTHORIZATION CHECKLIST

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 7 — Independent Release Gate Verification & Staging Authorization Readiness  
**Auditor:** Antigravity (Independent Principal Release Auditor & Technical Release Manager)  
**Pull Request:** [#74](https://github.com/rademigrate-ai/rad_emigrate/pull/74) (`feat/rad-final-publish-ready-20261021`)  
**Target Commit SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Audit Date:** 2026-10-22

---

## 1. Executive Summary & Review Scope

Before an operator or automated deployment pipeline executes database alterations in a staging environment, the rollout runbook must undergo an adversarial safety audit. 

Antigravity audited [`STAGING_ROLLOUT_RUNBOOK.md`](file:///C:/Users/Mehrshad/.gemini/antigravity/brain/e3426aa8-8f58-49a4-9d18-138c342d4053/STAGING_ROLLOUT_RUNBOOK.md) to ensure:
1. Complete separation of Staging and Production environments.
2. Immutability and checksum verification of SQL migration scripts.
3. Strict sequential execution with well-defined transactional boundaries.
4. Definitive stop-on-error behavior and clear rollback triggers.
5. Verifiable post-rollout validation queries.

### Independent Review Determination
Antigravity approves the **Staging Rollout Runbook** as technically robust, safe, and actionable. Below is the operational checklist that must be completed and countersigned before execution.

---

## 2. Safety Audit of `STAGING_ROLLOUT_RUNBOOK.md`

### 2.1 Environmental Separation Safeguards
- **Finding**: The runbook strictly uses parameterized environment variables (`$STAGING_DB_URL` and `$STAGING_PROJECT_REF`).
- **Safety Enforcement**: It explicitly cautions the operator:
  > *Confirm that environment variables point strictly to the Staging project, NEVER to hosted production `inshddthftkhcdosoqcn`.*
- **Preflight Identity Assertion**: The runbook executes:
  ```sql
  SELECT current_database(), current_user, inet_server_addr(), version();
  ```
  The operator must confirm that the database name matches the staging instance before piping SQL files.

### 2.2 Rejection of Ambiguous Automation
- Earlier deployment scripts in legacy repos used `supabase db push` or automated migration repair commands (`supabase migration repair`).
- **Antigravity Audit Finding**: Automated `supabase db push` could attempt to reconcile all 81 repository migrations, replaying the 27 historical files and triggering fatal table collision errors.
- **Runbook Design**: The runbook uses an **explicit, deterministic, file-by-file pipeline** applying only the 21 validated forward additions. This is the safest possible operational method.

### 2.3 Post-Rollout Smoke Test Integrity
The runbook defines four automated verification checks:
1. `leaked_privileges` query against `information_schema.table_privileges` (must return `0`).
2. `column_privileges` query on `profiles.role` (must return `0` rows for `authenticated`).
3. Verification of `admin_get_content_draft` routine in `information_schema.routines` (must return `1`).
4. `curl` OPTIONS preflight check on `ai-orchestrator` verifying `x-rad-request-key` and `x-rad-modality`.

---

## 3. Pre-Execution Operational Checklist

The operator and project owner must complete and verify each item in this checklist:

```markdown
### PHASE 0: PREFLIGHT GATES (BLOCKING)
- [ ] 0.1 Worktree Commit Verified: SHA is exactly 671bc2fed782b33c0d198edac4933db4d14a9eb4
- [ ] 0.2 Git Status Clean: 0 modified, 0 untracked files
- [ ] 0.3 Environment Isolation Verified: STAGING_DB_URL does NOT contain "inshddthftkhcdosoqcn"
- [ ] 0.4 Project Owner Written Sign-off Received
- [ ] 0.5 Supabase Auth Leaked Password Protection Toggled ON in Dashboard
- [ ] 0.6 Manual Pre-Rollout Backup Snapshot Completed:
      - Snapshot Label: pre-stage6-migration-reconciliation-20261022
      - Snapshot ID: __________________________________________________
      - Timestamp: ____________________________________________________
- [ ] 0.7 Staging Baseline Version Check: SELECT count(*) FROM schema_migrations returns 54

### PHASE 1: DATABASE MIGRATION EXECUTION (21 FILES)
- [ ] 1.01 Apply 20261019204906_rad_security_contract_foundation.sql
- [ ] 1.02 Apply 20261019205040_rad_visa_cms_official_evidence.sql
- [ ] 1.03 Apply 20261019205454_rad_currency_cache_alerts.sql
- [ ] 1.04 Apply 20261019205459_rad_feed_notifications_search.sql
- [ ] 1.05 Apply 20261019205502_rad_copilot_scoped_reservations.sql
- [ ] 1.06 Apply 20261019210000_g002_content_architecture_scaffolding.sql
- [ ] 1.07 Apply 20261019210423_rad_content_workflows.sql
- [ ] 1.08 Apply 20261019211000_security_quota_owner_and_publish_approved.sql
- [ ] 1.09 Apply 20261019211908_rad_feed_delivery_contracts.sql
- [ ] 1.10 Apply 20261019212615_rad_source_jobs_merge_enforcement.sql
- [ ] 1.11 Apply 20261019213129_rad_contract_finalization.sql
- [ ] 1.12 Apply 20261019214411_rad_legacy_quota_budget_compatibility.sql
- [ ] 1.13 Apply 20261020103648_rad_backend_integrity_completion.sql
- [ ] 1.14 Apply 20261020105854_rad_search_aliases_currency_history.sql
- [ ] 1.15 Apply 20261020111217_rad_restore_legacy_publish_privileges.sql
- [ ] 1.16 Apply 20261020112300_rad_crm_search_integration_hardening.sql
- [ ] 1.17 Apply 20261020114612_rad_transport_contract_registry_alignment.sql
- [ ] 1.18 Apply 20261020115539_rad_leased_research_base_contract.sql
- [ ] 1.19 Apply 20261020123523_rad_explicit_service_profile_bootstrap.sql
- [ ] 1.20 Apply 20261020192732_rad_revoke_client_nonrow_table_privileges.sql
- [ ] 1.21 Apply 20261021210337_rad_cms_admin_draft_reads.sql

### PHASE 2: POST-MIGRATION DATABASE SMOKE CHECKS
- [ ] 2.1 Verify 0 Prohibited Table Privileges (TRUNCATE, TRIGGER, REFERENCES)
- [ ] 2.2 Verify 0 Profile Role Column Grants for authenticated role
- [ ] 2.3 Verify admin_get_content_draft routine registered
- [ ] 2.4 Verify migration table reports exactly 75 records (54 baseline + 21 forward)

### PHASE 3: EDGE FUNCTIONS DEPLOYMENT
- [ ] 3.1 Deploy research-sync (--no-verify-jwt)
- [ ] 3.2 Deploy document-intelligence
- [ ] 3.3 Deploy ai-orchestrator
- [ ] 3.4 Execute CORS OPTIONS preflight test on ai-orchestrator

### PHASE 4: STAGING ACCEPTANCE & CLIENT SMOKE TEST
- [ ] 4.1 Execute Flutter Admin CMS Test Suite against Staging
- [ ] 4.2 Execute AI Copilot Conversation and Quota Reservation Test
- [ ] 4.3 Verify Visa Smart Search and Deep Link Routing
- [ ] 4.4 Verify Booking Appointment Invalidation
```

---

## 4. Formal Sign-Off Section

Execution of the Staging Rollout is authorized once the signatures below are recorded:

```markdown
### Staging Authorization Sign-Off
- **Lead Release Auditor**: Antigravity
  - *Recommendation*: **RECOMMEND AUTHORIZATION UPON OWNER ACTIONS**
  - *Date*: 2026-10-22
- **Lead Supabase Architect**: Codex
  - *Package Status*: **ACCEPTED & READY**
  - *Date*: 2026-10-22
- **Project Owner (Approval to Execute)**: ____________________________________
  - *Signature*: ____________________________________________________________
  - *Date*: _________________________________________________________________
```
