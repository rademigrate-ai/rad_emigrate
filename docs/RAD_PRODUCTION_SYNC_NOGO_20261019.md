# RAD Production Supabase Synchronization — Evidence Report

**Date:** 2026-10-19  
**GitHub main HEAD (verified):** `526ae7307de683b1f082a288a9d2c4356cfbc232`  
**Production project:** `inshddthftkhcdosoqcn` (eu-west-1)  
**Production writes performed:** **NONE**  
**Official 47-gate ledger:** remains **3/47 VERIFIED_PASS** (not changed)

---

## A. Repository State

| Item | Value |
|------|--------|
| Branch | `main` (tracks `origin/main`) |
| HEAD | `526ae73` |
| Migration files | **59** under `supabase/migrations/` |
| Edge Functions in repo | `ai-orchestrator`, `document-intelligence`, `research-sync`, `notification-dispatch`, `payment-sandbox` |
| Working tree | Clean except generated platform registrant noise |
| Commits/PRs created this session | **None** (docs-only report; no production change) |

---

## B. Supabase Production State

### Live re-query status: **BLOCKED**

- Supabase connector auth: **unavailable** (`request_connector_auth` → unavailable).
- No service-role or database credentials available in this agent session (correct — secrets must not be injected).
- Therefore **no live** table counts, migration history, Edge Function versions, or advisor results were re-fetched in this session.

### Last committed read-only observation (2026-10-18 artifacts in repo)

Source: `supabase/reconciliation/rad_live_migrations_observed_20261018.json`, `production_statement_fingerprints_20261018.json`, `docs/releases/LIVE_SQL_FINGERPRINT_AUDIT_20261018.md`.

| Observation | Value |
|-------------|--------|
| Project | `inshddthftkhcdosoqcn` |
| Recorded migrations | **47** |
| Last recorded version | `20261007212140` (`stage9_security_grant_hardening`) |
| Public tables (prior) | 57 with RLS enabled (historical) |
| Edge Functions (prior) | research-sync v4 (`verify_jwt=false`), ai-orchestrator v11, document-intelligence v3 |
| Advisor (prior) | DEFINER findings, pg_net in public, leaked-password protection disabled |

**These are historical. They are not a substitute for a live 2026-10-19 query.**

---

## C. Migration Reconciliation Matrix

### Summary

| Class | Count |
|-------|------:|
| Live history versions (2026-10-18) | 47 |
| Repository migration files (main @ 526ae73) | 59 |
| Repo version IDs not present in live history | 33 |
| Live-only names (no exact repo version match) | 4 |
| Same-name SQL text mismatches (fingerprint audit) | 12 |
| Multi-chunk live SQL not comparable | 2 |
| Local clean replay of all 59 (disposable DB, 2026-10-19) | **59/59 OK** (with storage stubs + explicit COMMIT) |

### Live-only (production history, not as exact repo filenames)

| Version | Name | Action |
|---------|------|--------|
| 20261007142614 | ai_discovery_auto_enable_chat | Manual semantic verify; do not history-repair blindly |
| 20261007171310 | stage2_promote_knowledge_fn | Live function parity previously observed; full effect unproven |
| 20261007171341 | stage2_retrieve_and_conflict_fn | Same |
| 20261007185216 | stage4_guest_quota_advisory_lock | Same |

### Repository-only security/completion migrations (not in live history as these versions)

| Version | Repository file | Preliminary action class |
|---------|-----------------|--------------------------|
| 20261010010000 | stage1_p0_security_completion | **Not applied** — security path; needs clone rehearsal |
| 20261010055013 | stage1_atomic_ai_quota_reservation | **Not applied** |
| 20261010070000 | stage1_ssrf_ipv4_mapped_ipv6 | **Not applied** |
| 20261012110945 | stage1_security_abuse_storage_alignment | **Not applied** |
| 20261012230000 | ai_models_check_constraints_alignment | **Not applied** |
| 20261017190000 | security_ai_entitlement_rpc_privacy | **Not applied** |
| 20261018125432 | local47_crm_notification_outbox | **Not applied** |
| 20261018142313 | local47_payment_sandbox_integrity | **Not applied** |
| 20261018143455 | local47_notification_privilege_alignment | **Not applied** |
| 20261018152513 | local47_document_atomic_processing | **Not applied** |
| 20261018154834 | local47_observability_privacy_and_triage | **Not applied** |
| 20261018210000 | stage10_covering_fk_indexes_completion | **Not applied** |
| 20261018211645 | phase24_mock_checkout_and_crm_search | **Not applied** |

Many intermediate repo versions are **timestamp aliases** of live-applied logical names (different version IDs, overlapping purpose). Fingerprint audit: **12 same-name SQL mismatches** — do not treat as identical.

### Critical rule

**Do not `db push` or repair `schema_migrations` until:**
1. Live history is re-queried today.
2. Object-level schema diff is complete.
3. Production-equivalent clone upgrade succeeds.
4. Backup/PITR gate is GO.

---

## D. Backup & Recovery — **NO-GO GATE**

| Check | Result |
|-------|--------|
| Org plan / PITR capability verified this session | **NOT VERIFIED** |
| Latest recoverable backup timestamp | **UNKNOWN** |
| Logical dump of production | **NOT PERFORMED** |
| Restore test on isolated environment | **NOT PERFORMED** |
| Auth/Storage/Vault coverage | **UNKNOWN** |

**STOP BEFORE PRODUCTION WRITE:** Backup and recovery path cannot be verified without owner dashboard access and privileged credentials.

---

## E. Changes Actually Applied to Production

**None.**

No migrations applied. No Edge Functions deployed. No Auth/Vault/Storage changes. No data modifications.

---

## F. Security

| Topic | Status |
|-------|--------|
| Fingerprint NO-GO safeguard unit tests | **4/4 PASS** (`python -m unittest ... test_live_migration_sql_fingerprints.py`) |
| `verify_live_migration_sql_fingerprints.py` | **Exit 2 / NO_GO** (expected) |
| SECURITY DEFINER live body re-audit | **BLOCKED** (no live SQL access) |
| Case-tracker session isolation (client) | Fixed on main (`a9969c1`) — authenticated session only |
| Research/AI auto-publish to Feed | Domain + acceptance tests on main; live policy re-verify blocked |
| Leaked password protection | Prior: disabled; enable requires owner dashboard action |
| pg_net in public | Prior advisor; do not move without dependency map |

---

## G. Edge Functions

| Function | In repo | Live (2026-10-18) | Deployed this session |
|----------|---------|-------------------|-----------------------|
| research-sync | Yes | v4, verify_jwt=false | **No** |
| ai-orchestrator | Yes | v11, verify_jwt=true | **No** |
| document-intelligence | Yes | v3, verify_jwt=true | **No** |
| notification-dispatch | Yes | Not previously listed | **No** |
| payment-sandbox | Yes | Not previously listed | **No** |

`verify_jwt=false` on research-sync must be treated as intentional only after verifying alternate auth (cron secret / service role). **Not changed.**

---

## H. Test Results (this session + recent verified)

| Check | Result |
|-------|--------|
| Migration fingerprint unit tests | **4/4 PASS** |
| Fingerprint verifier vs production snapshot | **NO_GO exit 2** |
| Disposable clean migration replay (59) | **59/59 OK** (prior local work, not production) |
| Flutter identity + no-auto-publish on main | **+8 PASS** (post-merge) |
| Full flutter test / analyze | Prior Claude evidence on RC; **not re-run full suite this session** |
| Live production smoke | **NOT RUN** |

---

## I. Outstanding Work (exact blockers)

1. **Owner:** Re-enable or authorize Supabase Management API / dashboard read for project `inshddthftkhcdosoqcn`.
2. **Owner:** Confirm plan tier, latest backup timestamp, PITR window; optionally export logical backup.
3. **Engineer + owner:** Re-query `supabase_migrations.schema_migrations` live; rebuild matrix with current HEAD.
4. **Engineer:** Object-level catalog diff (tables, RLS, functions, grants) vs isolated reconstruction from main.
5. **Engineer:** Production-equivalent **clone** upgrade path for the additive security + local47 migrations.
6. **Owner approval:** Explicit written authorization before any production migration or Edge deploy.
7. **Owner:** Leaked-password protection enablement in Auth settings.
8. **Editorial:** Visa content remains review-gated; no invented immigration data.

---

## J. Final Release Decision

| Decision | Verdict |
|----------|---------|
| GitHub readiness | **GO** (`main` @ `526ae73` integrated) |
| Database readiness (production schema sync) | **NO-GO** |
| Edge Function readiness (production deploy) | **NO-GO** |
| Production backend readiness | **NO-GO** |
| Full product release readiness | **NO-GO** |

**Reason:** Production write safety gate failed — live state and backup/recovery could not be verified in this session; migration ledger still has version/SQL mismatches; applying missing migrations without clone rehearsal and owner authorization would risk production data and history integrity.
