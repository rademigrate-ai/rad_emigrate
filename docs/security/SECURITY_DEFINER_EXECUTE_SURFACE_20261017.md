# E1-04 — Production SECURITY DEFINER execute-surface audit

**Audited:** 2026-10-17 (RAD Supabase `inshddthftkhcdosoqcn`; read-only `pg_proc`, `pg_get_functiondef`, and privilege catalog queries). Parent [ONE MASTER TASK #57](https://github.com/rademigrate-ai/rad_emigrate/issues/57). Remediation in [PR #62](https://github.com/rademigrate-ai/rad_emigrate/pull/62) is **not deployed**.

## Findings

- **14** `public` SECURITY DEFINER functions currently have `authenticated` EXECUTE; `anon` EXECUTE is **false for all 14** in the queried catalog.
- **2 high-priority authorization gaps:** `get_ai_access_decision(uuid,text)` and `get_ai_daily_quota_status(uuid,text)` accept arbitrary `p_user_id` and expose a user's plan/entitlement metadata and quota usage. Neither checks `auth.uid()`, caller identity, or an admin authorization gate. Any signed-in role with EXECUTE could pass someone else's UUID. No exploit attempt was made against live users.
- **11** functions contain explicit `private.has_role` checks in their definitions. The admin/super-admin controls are visible at source level; this does **not** prove every negative client role test, no bypass, or zero defects.
- **1** function, `retrieve_knowledge(text,text,text,text,integer)`, is designed to return approved knowledge and restricts `knowledge_items.review_status='approved'`. It has no per-user authorization predicate; review knowledge-item/claim publication and citation privacy separately.
- Supabase security advisor also flags `pg_net` in public schema and leaked-password protection disabled. These are distinct tasks: relocation of a used extension is **not** attempted without dependency checks.

## Exact privilege categories (live catalog)

| Function | `authenticated` EXECUTE | Source-visible authorization |
|---|---|---|
| `configure_ai_provider` | yes | super-admin gate |
| `get_ai_access_decision` | yes | **NO caller-identity check** |
| `get_ai_daily_quota_status` | yes | **NO caller-identity check; trusts requested p_role** |
| `promote_knowledge_from_evidence` | yes | admin/service guard |
| `publish_content_draft` | yes | admin guard; human-only publication retained |
| `register_knowledge_conflict` | yes | admin/service guard |
| `retrieve_knowledge` | yes | approved-only knowledge retrieval, read-only |
| `set_ai_model_configuration` | yes | admin gate |
| `set_content_draft_status` | yes | admin gate |
| `set_research_finding_status` | yes | admin gate |
| `set_research_source_configuration` | yes | admin gate |
| `set_user_role` | yes | super-admin gate |
| `update_content_draft` | yes | admin gate |
| `upsert_research_source` | yes | admin/super-admin guard |

## Proposed minimal privacy fix (PR #62)

- Replaces both SECURITY DEFINER bodies with **owner-scoped lookups**: non-service JWT callers must provide `p_user_id = auth.uid()`, otherwise they receive SQLSTATE `42501`. The genuine service_role retains cross-user server-side access.
- Ignores caller-supplied `p_role` for signed-in users and derives the effective quota role from `public.profiles`; prevents request-parameter privilege inflation.
- Preserves authenticated **own-user** RPC access and service_role EXECUTE; anon/PUBLIC remain denied. Existing expected self-service behavior is retained rather than breaking it.
- Isolated clean-schema CI runs actual positive self and service-role tests plus negative cross-user, forged-role and anon tests. PR #48's Stage 1 role/isolation tests remain required on the composite HEAD.
- No current `lib/` or `supabase/functions/` direct RPC call sites for either method found in `main`; access-decision calls quota-status **internally**.

## Gates not yet passed

1. Verify the full 14-function set with adversarial role/JWT tests, not merely string-matched function body guards.
2. Verify no confidential unapproved claims leak from `retrieve_knowledge` or nested citations.
3. Confirm same SQL on isolated production-equivalent ledger/schema (47 live historical entries vs 46 main repo files, with 16 timestamp aliases), preserve 5 pending Stage 1 migrations.
4. Owner/DBA-approved staged release with backup, PITR and operational rollback. No blind migration replay.
5. Repeat security advisor and least-privilege checks after release.

**Current result:** Forensic inventory and remediation PR prepared. **E1-04 Production acceptance remains OPEN**. No live SQL mutation.
