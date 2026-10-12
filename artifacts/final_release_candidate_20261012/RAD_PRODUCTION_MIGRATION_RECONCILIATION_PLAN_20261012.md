# Production migration reconciliation and controlled release plan

Read-only inspection on 2026-10-12: live project
`inshddthftkhcdosoqcn` has **47** migration records ending at
`20261007212140_stage9_security_grant_hardening`. The verified isolated
repository chain has **50** files ending at
`20261012110945_stage1_security_abuse_storage_alignment`. These are **not**
the same ledger: 16 same-name migrations carry different timestamps, four
live-only migration names exist, and seven local-only filenames exist. A
blind `supabase db push`, migration-history repair, or rename is unsafe.

## Actual-schema comparison

Read-only catalog comparisons against the isolated local stack found:

| Object class | Live | Local | Material delta |
|---|---:|---:|---|
| `public`/`private` tables | 57 | 57 | Column names/types/nullability and RLS flags match; **not full schema equivalence** |
| `public`/`private` functions | 47 | 51 | Local-only: human Feed trigger helper, Admin consultation list/update RPCs, consultation submit RPC |
| `public`/`private`/`storage` policies | 117 | 118 | Local-only document Storage UPDATE policy |
| User triggers | 24 | 26 | Local-only human-only Feed item/localization mutation guards |

After normalizing CRLF, ten common function bodies differ, including the
two AI access/quota RPCs, Feed publication, profile role guard, URL validator,
quota consumers, notification helper, model-catalog ingest and knowledge
promotion. For the 14 advisor-flagged functions, only the two AI RPCs and
Feed publication differ semantically after whitespace normalization. Live
table grants also differ for consultation requests, content drafts, and Feed
items; the local security migration narrows applicant/Admin write access.
Storage base-table ACL differences may reflect Supabase service version and
must not be treated as app migration instructions without DBA review.

An expanded 2026-10-13 read-only comparison covered constraints, indexes,
column defaults, extension versions and Storage bucket configuration across
`public`, `private` and `storage`: **760 live versus 781 local catalog
entries**, with 23 keyed differences. All 238 live column defaults and all
seven extension versions match local definitions. The material app-owned
local-only objects are four CHECK constraints and one index:

| Local-only object | Expected source / deployment dependency |
|---|---|
| `ai_models_consecutive_failures_check` | Historical `ai_dynamic_routing_architecture` alias; reconcile its live statements before treating alias as equivalent |
| `ai_models_measured_latency_ms_check` | Same historical AI routing alias |
| `ai_models_recent_success_rate_check` | Same historical AI routing alias |
| `document_processor_config_public_endpoint_check` | `20261010010000` P0 security migration; validate existing endpoint rows before application |
| `consultation_requests_user_created_idx` | `20261012110945` abuse-control migration |

The other 18 keyed differences are one live-only `storage.LOGO` public bucket
and local-only Storage-service `iceberg_namespaces`/`iceberg_tables`
constraints, defaults and indexes. They are **not** application migration
instructions. Preserve the live `LOGO` bucket; compare Storage service
versions and policies separately. Constraint and index names were compared
alongside definitions, so the three absent AI checks are not hidden by the
matching AI column types. Also reconcile column-level grants, sequences,
functions, policies, triggers, bucket objects and affected data in the DBA
rehearsal; this catalog audit is not a byte-identical database diff.

## Historical mapping gate — before any deployment

The following live-version → repository-version mappings share names but not
version IDs. DBA must compare `schema_migrations.statements`, final catalog
effects, and data effects; a matching name alone does **not** authorize
marking a migration applied. No production ledger row should be rewritten.

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

Live-only names: `20261007142614_ai_discovery_auto_enable_chat`,
`20261007171310_stage2_promote_knowledge_fn`,
`20261007171341_stage2_retrieve_and_conflict_fn`, and
`20261007185216_stage4_guest_quota_advisory_lock`. The two Stage 2 functions
have production-parity counterparts in the repository and the guest quota
lock is present in the local final function. The live AI discovery migration
**auto-enables** newly discovered chat models; the repository's final
`ingest_ai_model_catalogue` leaves new models disabled. This is a real
functional divergence requiring AI/product-owner decision and a targeted
rehearsal, not an excuse to overwrite production or silently change local
behavior.

## Ordered candidate delta — do not execute yet

Only after the historical mapping gate, an owner-approved production-like
rehearsal, backup and release authorization, review these local-only files in
timestamp order:

1. `20261007180001_stage2_knowledge_promote.sql` and
   `20261007180002_stage2_knowledge_retrieve_conflict.sql`: **historical
   aliases**, not new DDL candidates. Verify parity with the two live Stage 2
   functions; do not replay or fabricate ledger entries.
2. `20261007220000_stage5_visa_editorial_summaries.sql`: **data UPDATE** to
   empty destination/program descriptions. Requires separate Visa editorial
   and legal approval; capture affected-row preview. Do not bundle it
   automatically with security closure.
3. `20261010010000_stage1_p0_security_completion.sql`: closes applicant
   `admin_note`, AI owner guards and approved/human-only Feed publication;
   verify consultation Admin workflow before/after.
4. `20261010055013_stage1_atomic_ai_quota_reservation.sql`: atomic
   authenticated quota reservation; verify Edge Function RPC contract and
   concurrency scenario before application.
5. `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql`: URL validator hardening;
   verify existing configured provider/source URLs remain valid.
6. `20261012110945_stage1_security_abuse_storage_alignment.sql`: consultation
   RPC/rate limits, direct INSERT revocation, and owner Storage UPDATE policy;
   verify client upload/upsert/consultation journey against the rehearsed stack.

**Execution boundary:** because the first true candidate is editorial data
and its approval is separate, no migration is currently authorized. Do not
use CLI auto-push across divergent ledgers. A DBA must approve a canonical
baseline/alias manifest and an exact per-file migration runner after replaying
the live 47-statement history plus the proposed delta in an isolated clone.
Apply only distinct approved versions, one at a time, with recorded hashes,
transaction outcome, and post-step checks. Never mark a skipped SQL file as
applied merely to advance the ledger.

Dependency order for the security-only path is: verify the 16 historical
aliases and four live-only effects; preview data against the missing CHECK
constraints; rehearse P0 `20261010010000` (AI owner checks, Feed approval and
human guard, document endpoint constraint); then atomic quota
`20261010055013`; then URL validation `20261010070000`; then consultation
and Storage alignment `20261012110945`. Keep `20261007220000` editorial
UPDATE outside this path until separate approval. Existing `LOGO` bucket and
Storage internals must survive the rehearsal unchanged.
The three AI model CHECK constraints are not supplied by the four pending
security files. If the DBA confirms they were omitted from the live historical
alias, prepare a separate reviewed forward-only migration; do not replay the
entire aliased AI routing file against production.

## Read-only preflight SQL

Run immediately before an authorized change; abort on unexpected results.

```sql
select version, name from supabase_migrations.schema_migrations
order by version;
select current_setting('server_version') as postgres_version;
select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) args,
       p.prosecdef, p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') auth_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') anon_exec
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in
  ('get_ai_access_decision','get_ai_daily_quota_status',
   'publish_content_draft','submit_consultation_request')
order by p.proname;
select relname, relrowsecurity from pg_class
where oid in ('public.consultation_requests'::regclass,
              'public.feed_items'::regclass);
select has_table_privilege('authenticated',
  'public.consultation_requests','INSERT') as direct_insert_allowed,
  has_column_privilege('authenticated',
  'public.consultation_requests','admin_note','SELECT') as admin_note_readable;
select count(*) filter (where status='published') as published_feed_count
from public.feed_items;
select conrelid::regclass::text as table_name, conname,
       pg_get_constraintdef(oid, true) as definition
from pg_constraint
where conname in ('ai_models_consecutive_failures_check',
                  'ai_models_measured_latency_ms_check',
                  'ai_models_recent_success_rate_check',
                  'document_processor_config_public_endpoint_check')
order by conname;
select id, public, file_size_limit, allowed_mime_types
from storage.buckets order by id;
```

Before production authorization, DBA/release owner must attest a tested,
restorable off-machine backup or PITR recovery point, Auth/Storage/config
inventory, schema and data snapshot with checksums, maintenance window,
operator identity, and stop/rollback decision thresholds. Keep application
traffic and Edge workers controlled during migration. A rollback is **not** a
blind reverse of security grants: prefer stop/roll-forward for failed steps;
if data or schema integrity is lost, restore the verified recovery point in a
separate environment, compare, and only then authorize production recovery.
Stage 5 editorial text needs a before-image backup because its UPDATE is not
automatically reversible from the migration file.

## Post-deployment verification SQL — after authorization only

```sql
select version, name from supabase_migrations.schema_migrations
where version >= '20261007220000' order by version;
select has_function_privilege('authenticated',
  'public.get_ai_access_decision(uuid,text)','EXECUTE') as ai_rpc_callable,
  has_function_privilege('anon',
  'public.get_ai_access_decision(uuid,text)','EXECUTE') as anon_ai_rpc_callable,
  has_function_privilege('authenticated',
  'public.submit_consultation_request(text,text,uuid)','EXECUTE')
  as consultation_rpc_callable;
select has_table_privilege('authenticated',
  'public.consultation_requests','INSERT') as direct_insert_allowed,
  has_column_privilege('authenticated',
  'public.consultation_requests','admin_note','SELECT') as admin_note_readable;
select tgname from pg_trigger where not tgisinternal and tgrelid in
  ('public.feed_items'::regclass,
   'public.feed_item_localizations'::regclass)
order by tgname;
select policyname from pg_policies
where schemaname='storage' and tablename='objects'
  and policyname='documents storage update own';
select conname from pg_constraint
where conname in ('ai_models_consecutive_failures_check',
                  'ai_models_measured_latency_ms_check',
                  'ai_models_recent_success_rate_check',
                  'document_processor_config_public_endpoint_check')
order by conname;
select indexname from pg_indexes where schemaname='public'
  and tablename='consultation_requests'
  and indexname='consultation_requests_user_created_idx';
```

SQL catalog checks are necessary but insufficient: after deployment, use
disposable identities for cross-owner AI/consultation denial, Storage
upload/upsert, approved-only human Feed publication, Admin consultation
download, and Auth recovery; then rerun the security advisor and check logs.
Those production checks were **not run** in this task. Production NO-GO.
