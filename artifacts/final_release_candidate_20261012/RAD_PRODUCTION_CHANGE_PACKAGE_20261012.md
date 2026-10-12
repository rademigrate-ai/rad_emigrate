# RAD Emigrate — Production Supabase Change Package

**Date:** 2026-10-12 (updated 2026-10-13 engineering continuation)  
**Branch baseline:** `handoff/codex-stage1-stage2-20261010` @ `aed0809d2324dff1fd5fcc37653552ccb85ef9ba`  
**Production project:** `inshddthftkhcdosoqcn`  
**Status:** Engineering complete for all work that does not require production authorization. **PRODUCTION REMAINS NO-GO.**

---

## 1. Current-state inventory (verified read-only 2026-10-12/13)

| Item | Production (live) | Repository / isolated local |
|------|-------------------|-----------------------------|
| Migration records | **47** ending `20261007212140_stage9_security_grant_hardening` | **50** files ending `20261012110945_stage1_security_abuse_storage_alignment` |
| Timestamp aliases (same name, different version) | 16 | See mapping table below |
| Live-only migration names | 4 | — |
| Repo-only migration filenames (pending) | — | 7 (see ordered delta) |
| `public`/`private` tables | 57 | 57 (column/RLS flags match; not full schema identity) |
| Functions | 47 | 51 |
| Policies | 117 | 118 |
| User triggers | 24 | 26 |
| Missing app CHECK constraints | 4 (3 AI + 1 document endpoint) | Present in repo |
| Missing index | `consultation_requests_user_created_idx` | Present in last migration |
| AI owner guards | **FAIL** (no `auth.uid() = p_user_id`) | Fixed in `20261010010000` |
| Feed publication | **FAIL** (allows draft/review) | Fixed in `20261010010000` (requires `approved`) |
| Consultation direct INSERT | **true** | Revoked; RPC-only in `20261012110945` |
| `admin_note` SELECT by authenticated | **true** | Revoked column grant |
| Feed/content_drafts direct writes | **true** | Revoked + human-only triggers |
| `submit_consultation_request` | **absent** | Present |
| Leaked-password protection | **disabled** | Auth setting (owner) |
| Hosted staging branch | **none** | Local disposable stack only |

### Historical alias mapping (name match ≠ statement equivalence)

| Live version | Name | Repository version |
|---|---|---|
| 20261005123027 | client_delivery_ai_scopes | 20261004203000 |
| 20261005123202 | stage1_ai_research_completion | 20261005102000 |
| 20261005123255 | stage2_review_feed_publish | 20261005120000 |
| 20261005180215 | stage3_fk_covering_indexes | 20261005190000 |
| 20261006144235 | stage2_visa_structured_steps | 20261005130000 |
| 20261006144246 | stage5_research_review_candidate_backfill | 20261006132931 |
| 20261006161823 | fix_profile_update_with_check_role_escalation | 20261006180000 |
| 20261006221616 | ai_dynamic_routing_architecture | 20261007080000 |
| 20261007075108 | ai_credential_failure_routing | 20261007080001 |
| 20261007075110 | research_atomic_review_candidate | 20261007080002 |
| 20261007171212 | stage2_knowledge_completion | 20261007180000 |
| 20261007183840 | stage4_user_ai_quota_grounding | 20261007210000 |
| 20261007192522 | stage4_limit_ai_runtime_chain | 20261007212000 |
| 20261007202907 | stage6_entitlement_access_decision | 20261007230000 |
| 20261007205734 | stage7_ops_consultation_app_status | 20261008010000 |
| 20261007212140 | stage9_security_grant_hardening | 20261008020000 |

**Live-only names:**  
`20261007142614_ai_discovery_auto_enable_chat`,  
`20261007171310_stage2_promote_knowledge_fn`,  
`20261007171341_stage2_retrieve_and_conflict_fn`,  
`20261007185216_stage4_guest_quota_advisory_lock`.

**Functional divergence:** Live AI discovery auto-enables newly discovered chat models. Repository `ingest_ai_model_catalogue` leaves new models disabled. Requires product/AI owner decision; do not silently overwrite production behavior.

---

## 2. Historical migration reconciliation manifest

- **Canonical baseline for production:** the live 47-row ledger. Never rewrite `schema_migrations` rows.
- **Aliases:** treat as historical equivalents only after DBA compares `statements` / final catalog effects. Do not mark repo files as applied solely because names match.
- **Missing CHECKs on `ai_models`:** columns exist; named constraints `ai_models_consecutive_failures_check`, `ai_models_measured_latency_ms_check`, `ai_models_recent_success_rate_check` are absent. Forward-only migration supplied: `20261012230000_ai_models_check_constraints_alignment.sql`.
- **`document_processor_config_public_endpoint_check`:** supplied by `20261010010000`.
- **`consultation_requests_user_created_idx`:** supplied by `20261012110945`.

---

## 3. Exact SQL migration files and hashes (security path)

Ordered for the **security-only** production path (editorial Stage 5 excluded):

| Order | File | Purpose |
|------:|------|---------|
| 0 | `20261012230000_ai_models_check_constraints_alignment.sql` | Add 3 missing AI model CHECKs |
| 1 | `20261010010000_stage1_p0_security_completion.sql` | AI owner guards, Feed approved-only + human triggers, admin_note column revoke, document endpoint CHECK, admin consultation RPCs |
| 2 | `20261010055013_stage1_atomic_ai_quota_reservation.sql` | Atomic quota reservation |
| 3 | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` | URL validator hardening |
| 4 | `20261012110945_stage1_security_abuse_storage_alignment.sql` | Consultation RPC + rate limits, direct INSERT revoke, Storage UPDATE own policy, index |

**Excluded from this path until separate approval:**  
`20261007220000_stage5_visa_editorial_summaries.sql` (data UPDATE).

**Historical aliases (do not re-execute):**  
`20261007180001_stage2_knowledge_promote.sql`,  
`20261007180002_stage2_knowledge_retrieve_conflict.sql`.

---

## 4. Dependency order

1. DBA attests restorable off-machine backup or PITR recovery point.  
2. Rehearse entire chain on isolated clone that has been seeded with the live 47-statement history (or a production-like snapshot).  
3. Preflight SQL.  
4. Apply `20261012230000` (AI CHECKs).  
5. Apply `20261010010000` (P0 security).  
6. Apply `20261010055013` (atomic quota).  
7. Apply `20261010070000` (SSRF).  
8. Apply `20261012110945` (consultation + Storage).  
9. Post-deployment verification SQL + disposable-identity security probes.  
10. Re-run security advisor.

Never use `supabase db push` against divergent ledgers. Apply one approved version at a time with recorded hashes and transaction outcome.

---

## 5. Preflight checks (abort on unexpected)

```sql
select version, name from supabase_migrations.schema_migrations order by version;
select current_setting('server_version') as postgres_version;

select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) args,
       p.prosecdef, p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') auth_exec
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in
  ('get_ai_access_decision','get_ai_daily_quota_status',
   'publish_content_draft','submit_consultation_request')
order by p.proname;

select has_table_privilege('authenticated','public.consultation_requests','INSERT') as direct_insert_allowed,
       has_column_privilege('authenticated','public.consultation_requests','admin_note','SELECT') as admin_note_readable,
       has_table_privilege('authenticated','public.feed_items','INSERT') as feed_insert_allowed;

select count(*) filter (where status='published') as published_feed_count from public.feed_items;

select conname from pg_constraint
where conname in (
  'ai_models_consecutive_failures_check',
  'ai_models_measured_latency_ms_check',
  'ai_models_recent_success_rate_check',
  'document_processor_config_public_endpoint_check'
) order by conname;

select count(*) as bad_ai_rows from public.ai_models
where consecutive_failures < 0
   or (measured_latency_ms is not null and measured_latency_ms < 0)
   or (recent_success_rate is not null and (recent_success_rate < 0 or recent_success_rate > 1));
-- Expect 0

select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id;
```

---

## 6. Backup and restoration verification

**Required before any production change:**

- [ ] DBA attests tested, restorable off-machine backup **or** verified PITR recovery point with known restore window.
- [ ] Snapshot of `schema_migrations`, function definitions for the four critical RPCs, grant matrix for consultation/feed/drafts, Storage policies, and row counts for key tables.
- [ ] Maintenance window defined; traffic and Edge workers controlled.
- [ ] Rollback strategy: prefer stop / roll-forward for failed steps. If integrity is lost, restore the verified recovery point in a separate environment, compare, then authorize production recovery. Do **not** attempt blind reverse of security grants.

---

## 7. Staging rehearsal results (local only)

- Isolated local stack applied all 50 repository migrations.
- SECURITY DEFINER denial regression: 13 protected RPCs returned `forbidden` for ordinary authenticated principal (PASS).
- Consultation E2E (real Chrome, local): PASS.
- Storage owner + cross-owner denial + MIME: PASS. Fixtures cleaned.
- Hosted staging: **BLOCKED** (no non-production project).
- Android device: **BLOCKED**.

These are local evidence only. They do **not** authorize production.

---

## 8. Expected object / data changes after security path

| Change | Type |
|--------|------|
| 3 named CHECKs on `ai_models` | Additive constraint |
| `get_ai_access_decision` / `get_ai_daily_quota_status` bodies | Owner-bound; empty search_path; role from profiles |
| `publish_content_draft` | Requires `approved`; sets human actor marker |
| `private.guard_human_feed_mutation` + 2 triggers | Blocks non-human Feed writes |
| Column SELECT grant on `consultation_requests.admin_note` | Revoked from authenticated |
| Table INSERT on `consultation_requests` | Revoked; `submit_consultation_request` RPC |
| Rate-limit index | Added |
| Storage policy `documents storage update own` | Added / aligned |
| `document_processor_config_public_endpoint_check` | Added + validated |
| Admin list/update consultation RPCs | Added |

No Auth users, applications, documents, research evidence, or existing approved configurations are deleted. Feed content is not auto-published.

---

## 9–12. Maintenance window, stop conditions, post-deploy verification, approval checklist

See full detail in repository file. Summary:

- Apply one migration at a time; record hashes and outcomes.
- Stop on preflight failure, transaction failure, or failed disposable-identity probe.
- Prefer roll-forward; restore from verified recovery point only if integrity is lost.
- Owner must check every box on the approval checklist before GO.

---

## Acceptance matrix (engineering status)

| Area | Status |
|------|--------|
| Historical migration differences resolved (engineering) | PASS |
| Unexplained application-owned schema drift | PASS (cataloged) |
| Confirmed security defects fixed in code | PASS |
| Confirmed security defects fixed in production | FAIL / BLOCKED |
| RLS and RPC access controls regression-tested | PASS (local) |
| Storage and Consultation protected (code + local) | PASS |
| Feed publication strictly human-approved (code) | PASS |
| Feed publication live | FAIL |
| Existing production data preserved | PASS |
| Exact production deployment package ready | PASS |
| Hosted staging | BLOCKED |
| Android device | BLOCKED |
| Screen reader | NOT RUN |
| **Production GO** | **NO-GO** |

## Required owner approvals (blocking)

1. Production migration application authorization for the ordered security path.
2. Backup / PITR attestation.
3. AI discovery behavior decision (auto-enable vs keep disabled).
4. Auth: enable leaked-password protection (or explicit accept risk).
5. Hosted staging project (or explicit cost approval) if further hosted verification is required.
6. Separate: Stage 5 Visa editorial and Stage 3 baseline reconciliation.

## Final recommendation

**PRODUCTION: NO-GO.**

All independently executable engineering work is complete. No production database, Auth, Storage, Edge Function, secret, or migration history was modified.

Apply the package only after explicit release-owner approval and a verified recovery point.
