# STAGE 8: REPOSITORY OWNER PRE-ROLLOUT SIGN-OFF CHECKLIST

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 8 — Final Release Evidence Consolidation, Staging Preflight & PR #74 Hardening  
**Lead Engineer:** Codex  
**Pull Request:** [#74](https://github.com/rademigrate-ai/rad_emigrate/pull/74) (`feat/rad-final-publish-ready-20261021`)  
**Target Commit SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Date:** 2026-10-22

---

## 1. Executive Instructions for Project Owner

Before any Staging rollout can be initiated, the repository owner must complete, verify, and formally sign this operational checklist. 

**Zero migrations or Edge Function deployments may occur until all Phase 0 prerequisite gates are satisfied.**

---

## 2. Operational Rollout Checklist

```markdown
### PHASE 0: PREFLIGHT GATES (BLOCKING PREREQUISITES)
- [ ] 0.1 Worktree Commit SHA Verified: Exactly 671bc2fed782b33c0d198edac4933db4d14a9eb4
- [ ] 0.2 Git Status Clean: 0 modified, 0 untracked files
- [ ] 0.3 Staging Project Configured: RAD_STAGING_PROJECT_REF populated with 20-character reference
- [ ] 0.4 Production Exclusion Confirmed: Target is NOT "inshddthftkhcdosoqcn"
- [ ] 0.5 Supabase Auth Leaked Password Protection: Enabled in Dashboard (Authentication -> Security)
- [ ] 0.6 Manual Pre-Rollout Backup Snapshot Completed:
      - Target Project: __________________________________________________
      - Snapshot Label: pre-stage8-rollout-20261022
      - Snapshot ID: _____________________________________________________
      - Completion Timestamp: ____________________________________________
      - Verified in Console: [ ] YES
- [ ] 0.7 Automated Preflight Executed:
      Command: python scripts/staging_preflight.py --env-file staging.env
      Exit Code: 0 (Status: PASS) [ ] YES

### PHASE 1: SEQUENTIAL FORWARD MIGRATION EXECUTION (21 FILES)
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

### PHASE 2: POST-MIGRATION DATABASE SMOKE ASSERTIONS
- [ ] 2.1 Migration count equals exactly 75 (54 baseline + 21 forward)
- [ ] 2.2 Prohibited non-row table capabilities query returns 0
- [ ] 2.3 Profile role column grants query returns 0 for authenticated role
- [ ] 2.4 Admin CMS draft read routine (admin_get_content_draft) registered

### PHASE 3: EDGE FUNCTIONS DEPLOYMENT (STRICT SEQUENCING)
- [ ] 3.1 Deploy research-sync (--no-verify-jwt)
- [ ] 3.2 Deploy document-intelligence
- [ ] 3.3 Deploy ai-orchestrator
- [ ] 3.4 Execute CORS OPTIONS check:
      curl -i -X OPTIONS https://[STAGING_REF].supabase.co/functions/v1/ai-orchestrator \
        -H "Access-Control-Request-Headers: authorization, x-client-info, apikey, content-type, x-rad-request-key, x-rad-modality"
      Result: HTTP 200/204 with valid Allow-Headers [ ] YES

### PHASE 4: STAGING ACCEPTANCE TESTING & SOAK PERIOD
- [ ] 4.1 Execute Flutter Admin CMS test suite against Staging
- [ ] 4.2 Execute Copilot AI chat and token reservation roundtrip
- [ ] 4.3 Verify Visa Smart Search and deep link navigation
- [ ] 4.4 24-Hour Staging Soak Period Initiated
```

---

## 3. Formal Authorization Sign-Off

```markdown
### Staging Execution Authorization
- **Designated Execution Operator**: ________________________________________
- **Staging Project Reference**: ____________________________________________
- **Confirmed Non-Production**: [ ] YES
- **Backup Verification Confirmed**: [ ] YES
- **Repository Owner Signature**: ___________________________________________
- **Sign-Off Date**: _______________________________________________________
```
