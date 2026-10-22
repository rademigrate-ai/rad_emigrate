# STAGE 8: IMMUTABLE FORWARD MIGRATION MANIFEST

**Project:** RAD Emigrate (`rademigrate-ai/rad_emigrate`)  
**Stage:** Stage 8 — Final Release Evidence Consolidation, Staging Preflight & PR #74 Hardening  
**Lead Engineer:** Codex  
**Pull Request:** [#74](https://github.com/rademigrate-ai/rad_emigrate/pull/74) (`feat/rad-final-publish-ready-20261021`)  
**Target Commit SHA:** `671bc2fed782b33c0d198edac4933db4d14a9eb4`  
**Date:** 2026-10-22

---

## 1. Executive Summary & Manifest Authority

This document defines the **immutable forward migration manifest** required to transition the hosted production baseline of 54 migrations to the full release candidate schema of 75 migrations.

Every migration in this 21-file sequence has been cryptographically fingerprinted, dependency-ordered, and verified through dual-stack isolated rehearsals.

### Core Governance Directives:
- **Strict Sequential Order**: Migrations must be executed in the exact numerical order listed below.
- **Individual Transaction Isolation**: Each file runs within its own transaction boundary (`BEGIN ... COMMIT`).
- **Stop on First Error**: If any migration fails, execution halts immediately; no subsequent scripts are executed.
- **Zero Historical Replays**: Replaying any of the 27 historical repository files is strictly forbidden.

---

## 2. Master 21 Forward Additions Manifest Table

| # | Version | Filename | SHA-256 (LF Normalized) | Purpose & Catalog Effect | Preconditions & Idempotency |
| :-: | :---: | :--- | :--- | :--- | :--- |
| **01** | `20261019204906` | `rad_security_contract_foundation.sql` | `3f6fb779b2b39202f1ad9a254a1cdb952903f3a1cfb9670d642434459f4667dd` | Revokes `INSERT/UPDATE (role)` on `profiles`; enforces `chk_profile_roles`; defines `set_user_role()`. | Table `public.profiles` exists; idempotent column revoke. |
| **02** | `20261019205040` | `rad_visa_cms_official_evidence.sql` | `86f063682a53ae7de40ff9547cfb50790f8c4051ed3e20e68eb38f5d9ca2557d` | Creates `official_sources`, `research_snapshots`, and knowledge promotion tables. | `CREATE TABLE IF NOT EXISTS`; dependencies: `01`. |
| **03** | `20261019205454` | `rad_currency_cache_alerts.sql` | `f5dd28555fd2a391b3b45b1c87a96531753f6d9c0375b4b6329c82df48450884` | Creates `currency_cache` and `currency_alert_preferences` tables. | `CREATE TABLE IF NOT EXISTS`; dependencies: `01`. |
| **04** | `20261019205459` | `rad_feed_notifications_search.sql` | `4eecd6634e3501ac10eebf8d17d50116999353ec848b1af025061377e1e0c42e` | Creates `feed_notifications`; creates trigram search indexes. | Extension `pg_trgm` active; `CREATE INDEX IF NOT EXISTS`. |
| **05** | `20261019205502` | `rad_copilot_scoped_reservations.sql` | `9dc47563d265e7783702ec7330fef2290a4482862cf9b03e83d60f7d240d748b` | Creates `ai_requests` reservation ledger for two-phase quota control. | `CREATE TABLE IF NOT EXISTS`; dependencies: `01`. |
| **06** | `20261019210000` | `g002_content_architecture_scaffolding.sql` | `f5fc08f64fd22efa914cc46c58ceb692ca347cae5a9a09702929e0d0095f8994` | Scaffolds content categories, taxonomies, and editorial workflow metadata. | Schema definition; dependencies: `02`. |
| **07** | `20261019210423` | `rad_content_workflows.sql` | `807875ea31b7098d1f520a70fdc4d914fb132aaad6b514ab9ae194324e305e3d` | Defines editorial state machines (`draft`, `in_review`, `published`). | Table constraints and status validations; dependencies: `06`. |
| **08** | `20261019211000` | `security_quota_owner_and_publish_approved.sql` | `672148a8a51ad33eff61ea1f4b68f09317c69166ab4c7f88490958f6211b16fa` | Implements `consume_ai_daily_quota` and publishing approval RPCs. | `CREATE OR REPLACE FUNCTION`; dependencies: `05, 07`. |
| **09** | `20261019211908` | `rad_feed_delivery_contracts.sql` | `55f2560b4e46c342c306782c1246c6fb310814d1e384c070c40e72cc478babcc` | Exposes closed contract views for feed item delivery and subscriptions. | View definitions; dependencies: `04`. |
| **10** | `20261019212615` | `rad_source_jobs_merge_enforcement.sql` | `d417e2b35b4a05190fd22d8da22c2179be44370fb9a0a246e864394fad88b160` | Enforces hash deduplication and source job concurrency locks. | Trigger definitions; dependencies: `02`. |
| **11** | `20261019213129` | `rad_contract_finalization.sql` | `e21c565f2f377f2f3b2201b33031b2fa7a7f140b65f8b449e4e2eb85a83cc5fb` | Finalizes constraints and foreign keys across core tables. | Schema qualification; dependencies: `01-10`. |
| **12** | `20261019214411` | `rad_legacy_quota_budget_compatibility.sql` | `7d65098001f2dbecc52ad74ff46f262d69efb9638e217346e16c20225a0834ad` | Backwards compatibility view for legacy token budget queries. | `CREATE OR REPLACE VIEW`; dependencies: `08`. |
| **13** | `20261020103648` | `rad_backend_integrity_completion.sql` | `ac86171d4aa63e27c113efa811035be00c383be855b80a3e539bfdfd5767fd47` | Adds foreign key cascades and integrity triggers across CRM entities. | `ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS`. |
| **14** | `20261020105854` | `rad_search_aliases_currency_history.sql` | `1f6440f176a1333da2bebc3b5ae1ecdc84af4e378040552467edfa0c0046b985` | Creates search alias dictionary table and historical exchange rate ledger. | `CREATE TABLE IF NOT EXISTS`; dependencies: `03, 04`. |
| **15** | `20261020111217` | `rad_restore_legacy_publish_privileges.sql` | `8cd83db51feb86bbe40b2ea5e325a93ddaf642b534f056eda0fa39139870d981` | Restores vetted publishing privileges to authorized editorial roles. | Granular `GRANT EXECUTE`; dependencies: `08`. |
| **16** | `20261020112300` | `rad_crm_search_integration_hardening.sql` | `de82f8350f330cdb3bb5dc5a2978353824ed8bab7637b2c6f89ce36455b7f0b6` | Hardens CRM consultation intake and search index queries. | Index optimizations; dependencies: `13, 14`. |
| **17** | `20261020114612` | `rad_transport_contract_registry_alignment.sql` | `8ae61793f441ade43a7bfc9fb37f22ff1817a2fd6014c9c8d0a1e152cd1b81f4` | Maps transport serialization contract to REST JSON envelopes. | Schema definitions; dependencies: `11`. |
| **18** | `20261020115539` | `rad_leased_research_base_contract.sql` | `8c13fa85d06a6f57d28c90bc676a5cab57ad6da3e7f19fcad50c054973238129` | Leased research background worker base contract. | `CREATE TABLE IF NOT EXISTS`; dependencies: `02, 10`. |
| **19** | `20261020123523` | `rad_explicit_service_profile_bootstrap.sql` | `569ac10dc29dc1cec17b45b3ab885f4d728fc202c99b165f394aaa228d4344d4` | Bootstraps explicit service role profile records. | Idempotent `ON CONFLICT DO NOTHING`; dependencies: `01`. |
| **20** | `20261020192732` | `rad_revoke_client_nonrow_table_privileges.sql` | `5d7dfc6f38181431ed4203c1529fbb9b8764d0f89234891c5ab41e5c05e510f3` | **CRITICAL SECURITY**: Revokes `TRUNCATE, TRIGGER, REFERENCES` from client roles. | Idempotent DO block; alters default privileges; dependencies: `01-19`. |
| **21** | `20261021210337` | `rad_cms_admin_draft_reads.sql` | `63bb109c7b7d1ae57a4fdcf2c8394828601644004d94fe032705a33d3cc2b021` | **PR #74 TERMINAL CONTRACT**: Exposes `admin_get_content_draft` with admin ACL. | `CREATE OR REPLACE FUNCTION`; dependencies: `01-20`. |

---

## 3. Detailed Specification of the 4 Excluded Legacy Foundations

| Excluded Foundation | Originating Historical Branch | Reason for Exclusion from Forward Sequence | Production Substitute / Modern Architecture |
| :--- | :--- | :--- | :--- |
| **`apply_sandbox_payment_event`** | Phase 1 Payment Mocking | Synthetic mock payment event queue created for offline developer testing. | Replaced by production Stripe webhook handler and signed secret validation. |
| **`payment_sandbox_config`** | Phase 1 Payment Mocking | Configuration toggle for synthetic payment engine. | Replaced by Stripe environment configuration. |
| **`document_processing_leases`** | Phase 2 Multi-Process Worker | Database-level worker lock table for local OCR processes. | Replaced by `document-intelligence` Edge Function and asynchronous storage triggers. |
| **`operational_events` / `incidents`** | Phase 3 Local Telemetry | Database-backed event logging table. | Replaced by Supabase Cloud Logging and Logflare metrics. |

---

## 4. Postcondition Verification Queries

Following execution of all 21 forward migrations, the operator must execute the following automated validation assertions:

```sql
-- 1. Verify exact migration version count equals 75 (54 baseline + 21 forward)
SELECT count(*) AS total_migrations FROM supabase_migrations.schema_migrations;
-- EXPECTED: 75

-- 2. Verify 0 client non-row privileges
SELECT count(*) AS leaked_privileges
FROM information_schema.table_privileges
WHERE grantee IN ('anon', 'authenticated')
  AND table_schema = 'public'
  AND privilege_type IN ('TRUNCATE', 'TRIGGER', 'REFERENCES');
-- EXPECTED: 0

-- 3. Verify profile role column grants are revoked
SELECT count(*) AS leaked_role_grants
FROM information_schema.column_privileges
WHERE grantee = 'authenticated'
  AND table_schema = 'public'
  AND table_name = 'profiles'
  AND column_name = 'role';
-- EXPECTED: 0

-- 4. Verify admin draft read routine is registered
SELECT count(*) AS draft_routine_count
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'admin_get_content_draft';
-- EXPECTED: 1
```

---

## 5. Manifest Certification

Codex certifies that the 21 forward additions specified above constitute the complete, immutable, and reproducible database migration delta required for PR #74.
