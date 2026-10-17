# RAD Emigrate — Stage 1 production security cutover runbook (CORRECTED)

> **RELEASE GATE: NO-GO as of 2026-10-17. READ THIS BEFORE EXECUTING ANY SQL.**
>
> This supersedes the earlier unverified runbook, which mistakenly:
> (1) instructed ordinary `psql -f` without recording new versions in `supabase_migrations.schema_migrations`;
> (2) asserted deploying a quota-reservation-dependent Edge Function *before* the quota migration would be safe;
> (3) used incorrect `ai_models` constraint names; and (4) assumed backup/PITR availability and old model counts without proof.
>
> **Do not apply anything to Production until the reconciliation and operator gates below PASS.** A successful clean-schema CI test proves only isolated reconstruction.

**Master Task:** [#57](https://github.com/rademigrate-ai/rad_emigrate/issues/57)  
**Security migration PR:** [#48](https://github.com/rademigrate-ai/rad_emigrate/pull/48) — 5 files; not merged or deployed.  
**Client/Edge compatibility PR:** [#56](https://github.com/rademigrate-ai/rad_emigrate/pull/56) — under review.  
**Combined integration trial:** [#59](https://github.com/rademigrate-ai/rad_emigrate/pull/59) — 7/7 CI jobs PASSED, local 491 Flutter tests passed, **DO NOT MERGE** integration probe.  
**Live project:** `inshddthftkhcdosoqcn` (RAD Supabase).  
**Read-only live forensic ledger:** [LIVE_MIGRATION_RECONCILIATION_20261017.md](LIVE_MIGRATION_RECONCILIATION_20261017.md).

## 1. Exact production checks established by direct read-only queries

| Requirement | Observed on 2026-10-17 |
|---|---|
| Live migration ledger | **47** versions, latest `20261007212140_stage9_security_grant_hardening` |
| `main` migration folder | **46** SQL files |
| Historical aliases, name matches only | **16** names have different recorded versions |
| Nonmatching named lineages | 4 live-only / 3 repo-only |
| New Stage 1 versions recorded | **0 of 5** |
| `consume_ai_daily_quota(uuid,text)` | count-only, **no** atomic reservation `request_id` |
| `submit_consultation_request`, `list_admin_consultations` | both **absent** |
| `ai_models` rows | **721**; **0** negative `consecutive_failures`, negative `measured_latency_ms`, or out-of-[0,1] `recent_success_rate` |
| New numeric CHECK constraints | all **3 absent** |
| `consultation_requests` | 0 records; direct table privileges exist, subject to RLS |
| Backups / PITR / recovery test | **UNVERIFIED**, not assumed |
| Real production SMTP/recovery end-to-end | **UNVERIFIED**, not assumed |

**Consequence:** A blind `supabase db push` or `supabase migration repair` is unsafe: version-based matching may replay historical same-name migrations. **Do not mutate existing 47 records, fake equivalence, or drop data.**

## 2. Five proposed additive migrations (in source order only)

The following are **pending files in PR #48**, not commands to run today:

| Step | Exact source file | Effect | Expected postcondition |
|---|---|---|---|
| 1 | `20261010010000_stage1_p0_security_completion.sql` | Consultation confidentiality, explicit admin RPC and Feed publication protection | RLS/column grants and admin RPC checked under cross-role tests |
| 2 | `20261010055013_stage1_atomic_ai_quota_reservation.sql` | Serialized quota check + INSERT reservation row | `consume_ai_daily_quota` returns `request_id`, disallows anon/authenticated direct EXECUTE |
| 3 | `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql` | Reject loopback/link-local IPv4-mapped IPv6 URLs | Negative SSRF regression test passes |
| 4 | `20261012110945_stage1_security_abuse_storage_alignment.sql` | Consultation submission RPC/abuse control; private Storage upsert ACLs | `submit_consultation_request` present; direct INSERT revoked; Storage ownership intact |
| 5 | `20261012230000_ai_models_check_constraints_alignment.sql` | Non-negative and [0,1] numeric limits | All three **actual source-defined names** `ai_models_consecutive_failures_check`, `ai_models_measured_latency_ms_check`, `ai_models_recent_success_rate_check` exist and are validated |

**Never use the three outdated constraint names** `ai_models_consecutive_failures_nonnegative`, `ai_models_last_latency_ms_nonnegative`, `ai_models_rolling_success_rate_range`; they are not defined in Step 5. Validate against actual source and `pg_constraint`, not an old report.

## 3. Mandatory before any authorized change (STOP if any item incomplete)

- [ ] Verify the exact source SHAs and the 5 SQL SHA-256 hashes against `docs/releases/PHASE_A_SECURITY_MANIFEST.json` before change.
- [ ] Fully reconcile the **27 exact version/name matches, 16 timestamp aliases, 4 live-only and 3 repo-only names** to catalog effects. Obtain separate semantic-equality proof for aliased functions, RLS and grants; prevent any historical replay. No attempts to modify a remote ledger without separately reviewed migration-history plan.
- [ ] Prove a disposable, production-equivalent clone reproduces live roles, RLS, functions, triggers, Storage predicates, Vault references (without secrets), cron and data constraints; compare **before/after** fingerprints.
- [ ] Verify backups, PITR and recovery window via the authorized Supabase dashboard/operator. Document the actual restore procedure and practice a recovery on an isolated clone. Never assert backup availability from project tier alone.
- [ ] Freeze mutually-dependent client, Edge and migrations at independently reviewed SHAs; have a tested canary and revert path. Confirm that the Flutter Web build includes compatible consultation RPC handling.
- [ ] Prove negative tests: anon denied private RPCs; users denied admin notes/role escalation; ordinary users cannot publish Feed; AI quota concurrent requests never exceed the limit; Storage cannot leave owner's folder or accepted MIME/size; malformed provider URLs fail closed.
- [ ] Obtain explicit release owner/DBA approval, defined change window, monitoring and a **write-traffic quiescence** mechanism covering consultation submission and AI. If traffic cannot be paused, demonstrate a backward-compatible dual-version deployment on a disposable clone before rollout.

## 4. Safe **planned** release order (requires all gates; NOT EXECUTED)

1. Take a verified backup; record the restore checkpoint and schema fingerprints, health metrics, Auth/Edge deployed versions, and 47-entry ledger fingerprint.
2. Quiesce relevant writes or provide an independently proven compatibility bridge. **Never** deploy new PR #56 AI Edge handler while the production quota RPC still returns **no `request_id`**: it will correctly fail closed (500 `quota_reservation_invalid`). Conversely, new database quota reservation can double-count if an *old* Edge handler continues independently inserting requests.
3. Install a tested Flutter client version capable of invoking the new consultation RPC and strict missing-RPC fallback. Keep critical actions disabled during cutover until API/DB align.
4. Apply each forward-only migration in its intended transaction to Production **through an approved ledger-aware procedure** that records its **new** migration version exactly once. Raw `psql -f` alone executes SQL but does **not** record the migration in Supabase history. Do not repair or forge existing 47 entries to make pushes succeed. Confirm postconditions and exact new ledger entries after each operation.
5. Deploy matching reviewed Edge Functions and client build only after the corresponding RPCs are operational. Confirm Edge digest/versions, auth modes and that the public client never receives service-role credentials.
6. Run production authorized smoke canaries: ordinary/admin registration/login/recovery, consultation submit/list/update, AI successful request and exactly-once quota row, 429 quota enforcement, expired-reset denial, Feed review-only publish, document upload/download ownership, and full rollback readiness. No synthetic personal data beyond authorized test accounts.
7. Restore traffic only if all checks pass; monitor rejected credentials, 5xx, quota failures, review publication, Admin access, and per-user isolation. If any fail: stop traffic, revert release components where safe and follow the verified recovery strategy. **Reverting a Git PR is not a database rollback.**

## 5. Read-only SQL verification snippets for authorized operator

```sql
-- Existing history is authoritative:
select version, name from supabase_migrations.schema_migrations
order by version desc limit 10;

-- Guard expected new versions; must currently return ZERO rows:
select version, name from supabase_migrations.schema_migrations
where version in ('20261010010000','20261010055013','20261010070000',
                  '20261012110945','20261012230000');

-- Validate exact CHECK names from the fifth migration AFTER it runs:
select conname, convalidated, pg_get_constraintdef(oid) as definition
from pg_constraint where conrelid='public.ai_models'::regclass
and conname in ('ai_models_consecutive_failures_check',
                'ai_models_measured_latency_ms_check',
                'ai_models_recent_success_rate_check');

-- After Step 2, check return shape through isolated role-gated integration tests.
-- Never invoke quota RPC on live user data purely to probe it (it creates a row).
select p.oid::regprocedure::text as signature,
       p.prosecdef as security_definer,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='consume_ai_daily_quota';
```

## 6. Evidence and non-goals

- Separate review gate PASS: PR #59 composite CI `39057208355` 7/7, Flutter 491/491, local static Phase-A 7/7, recovery 8/8.
- Production gate **NO-GO** until ledger semantic differences, backup/PITR, release concurrency, Edge/DB ordering and real browser/user acceptance are verified.
- No action in this document authorizes unreviewed Production DDL, migration-history modifications, reset, data deletion, Auth/Vault/Edge changes, or automatic Feed publication.
- Supabase CLI authoritative reference: https://supabase.com/docs/reference/cli/supabase-db-push — its `--dry-run` lists pending migrations by **version**, not semantic alias equivalence.
