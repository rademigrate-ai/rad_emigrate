# Provider request: protected catalog locking for RAD Production

**OWNER-CONFIRMED SUBMITTED; ticket reference and technical provider response PENDING. NOT APPROVED.** Project `inshddthftkhcdosoqcn`, PostgreSQL 17.11, existing database only. No Restore, extra project, paid service, catalog DML, superuser grant or ownership bypass is requested.

The proposed safety bootstrap `supabase/migrations/20261103120000_rad_no_restore_safety_ops.sql` requires a short transaction-scoped `LOCK TABLE pg_catalog.pg_proc IN SHARE MODE` during a fixed seven-function pre-core capture and, separately, an independently authorized definition inverse. Both use `lock_timeout='2s'` and the existing advisory lock. Current management executor `postgres` is not superuser; the catalog belongs to `supabase_admin`, and postgres has no MAINTAIN/UPDATE/DELETE/TRUNCATE privileges. Caller login alone does not confer a SECURITY DEFINER owner's catalog authority. The guarded release cannot advance without its pre-core safety capture; the inverse is blocked too. Ordinary CMS read/save RPCs are not all catalog-lock operations.

Please state whether Supabase supports a narrowly protected executor for these exact operations. PostgreSQL 17 documents MAINTAIN as a sufficient lock privilege; this is a capability observation, not a request for arbitrary catalog grants. If provider policy disallows the operation, give the supported equivalent isolation and failure guarantees, or explicitly deny it. Do not grant broadly privileged roles or change system catalog/function ownership to make the check pass.

## Exact requested scope

Public entry points: `public.get_release_function_state(text)`, `public.capture_release_function_state(text,text,text)`, `public.reverse_release_function_state(bigint,text,text)`. Private implementation: `private.rad_capture_function_state(text,text,text[],text,text)`, `private.rad_restore_function_state(bigint,text,text)`, `private.rad_release_function_frame(text[])`, `private.rad_catalog_lock_executor_available()`. The candidate source is authoritative for argument names and enforcement. The helper is not client-executable. All independent authorization records, real editorial Admin identity checks, exact seven-member allowlist, package/hash/current state bindings, OID/owner/ACL/dependent checks, immutability and retry rules must remain enforced.

The inverse covers definitions only. It does not reverse the complete core closure (20 new tables, 76 new functions, columns, constraints, indexes, triggers, grants/policy), migration history, extension or callback effects. Review the attached dependency map and complete no-Restore approval package before accepting any first hosted write, including installation of the bootstrap itself.

## Seven pre-core definitions

| Identity | Observed deployed definition SHA-256 |
|---|---|
| `private.is_safe_public_https_url(p_url text)` | `a5aa08d5d750691c351335c2e2313c0e91a16ad7c3f90abbde507f9110b515ec` |
| `private.prevent_profile_role_escalation()` | `954cc67ddd74f23b0840d07618a8af66b19f32073e3098bc4cf9890718e4b529` |
| `private.rad_article_verification(revision uuid)` | `4c0dc1acff287d90a3af18a2c2b03ed30f961180d36596675ba580000438ab8a` |
| `private.rad_claim_eligible(claim uuid)` | `0e44eca646f7c634018206aea2b1505741dc58ebee5e16d754635950aabb23e0` |
| `private.rad_evidence(ref jsonb, section uuid)` | `e7405584ffbc2d06b89c468f7ee1c57e754c84f9b0570051cc0e74f5eeb424b5` |
| `private.rad_page_position(body jsonb, version text)` | `f983903947d87c12e03f52c7183e0c07c53da10436104fe59937f3730268cc55` |
| `public.get_visa_article(p_request jsonb)` | `85de52ee2fb230a1d194eb23dbfce4eff1444a45c597a9898453b6f1d5e7a196` |

## Enabled managed callbacks (fresh metadata, 2026-11-04)

| Callback | Event | Definition SHA-256 |
|---|---|---|
| `issue_graphql_placeholder` | `sql_drop` | `b0cadab880dc68f569b3e01057dc6f5acee9d05e122de6f4256130ae330bbcec` |
| `issue_pg_cron_access` | `ddl_command_end` | `eb3fa2e82a0135bc04a6236f93331911861c91b45d72cba5d9c03c1be2c34b4c` |
| `issue_pg_graphql_access` | `ddl_command_end` | `9ec845adab4ba00bbf7740458b6c4461094697023f0f7adc693b373e2ea54f68` |
| `issue_pg_net_access` | `ddl_command_end` | `e38c4060751c9695123350596f1cb0d0c943015f3267a2a455d8efe02c711184` |
| `pgrst_ddl_watch` | `ddl_command_end` | `2b4b5d702ddf70fbd1a05c9825f9f9016d5c0ef97dd3df5f5b012ea23d9b94b1` |
| `pgrst_drop_watch` | `sql_drop` | `3a2696133853e17a0456cbfbb233a03815f50895492143e84df983b558d76593` |

## Evidence and acceptance requested

1. Bind provider/operator identity, exact project/system identifier, final release commit, migration/file hashes and maintenance window. Confirm executor scope through supported provider evidence, without exposing secrets.
2. Review the six callbacks, `pg_trgm` creation, PostgREST/schema-cache effects, bootstrap DDL, transaction boundaries, committed partial failures and retry procedure. Provide an operation-specific failure-stop/compensation matrix; deleting the extension is not a universal inverse of callback grants.
3. Establish an independently reviewed protected execution route. With a legitimate editorial Admin session, execute real capture and verify an immutable receipt against independently collected seven-member state. An availability boolean is not acceptance. Exercise timeout/concurrent DDL, ordinary-user/anonymous denial, stale-state/OID/owner/ACL/dependent refusal, exact retry and independently authorized inverse in an approved existing isolated environment. Never run destructive acceptance against Production.
4. Supply signed, hash-bound reviewer/provider evidence for the complete no-Restore procedure. The repository's guarded renderer currently requires verified recovery evidence; a no-Restore alternative must be independently accepted, implemented under that policy, and tested before it can replace that requirement. Do not fabricate recovery evidence or restart deferred recovery work.
5. Reconfirm Production binding and retained 745 heads/747 revisions/zero publications before any authorized first write. Refuse drift and retain a private operation receipt. Codex has neither provider approval nor a successful managed capture/inverse receipt.

An advisory lock coordinates cooperative callers only. A post-write hash cannot prevent overwriting concurrent DDL; application-table locks do not isolate pg_proc; SERIALIZABLE alone is not complete DDL failure handling. Any alternative must prove equivalent guarantees independently before implementation or use.

References: [PostgreSQL 17 LOCK](https://www.postgresql.org/docs/17/sql-lock.html), [Supabase role restrictions](https://supabase.com/docs/guides/database/postgres/roles-superuser). The published docs do not establish an approved RAD executor.

## Submission status in the resumed execution

**OWNER-CONFIRMED SUBMITTED.** The owner reports Supabase confirmed “Your ticket has been logged for RAD.” No ticket reference or actual technical provider response is available yet. This is submission evidence, not approval. The agent did not submit: connected tools have no Supabase ticket API, supported Firefox control ended at URL-policy enforcement, and a launch request was rejected as “blocked by policy.” The owner submitted through the legitimate manual channel. No alternate browser/session/token access, plan upgrade or charge occurred through this task.

Fresh read-only inspection confirms PostgreSQL 17.11, the same role/catalog restriction and retained 72 migrations/745 heads/747 revisions/zero publications. The release remains blocked. Follow the response-incorporation checklist in [FINAL_EMPLOYER_DEPLOY_READINESS.md](FINAL_EMPLOYER_DEPLOY_READINESS.md): authenticate the actual ticket/response reference, classify its decision, bind the exact supported role/lock/function scope, obtain separate complete no-Restore acceptance, rehearse managed restrictions/failures, then refresh exact release authorization and fingerprints. Neither submission nor provider lock guidance supplies the independent full no-Restore decision.

Final candidate commit/hashes must be rebound from the new private `backend-activation-resolution-20261104/FINAL_EMPLOYER_DEPLOY_READINESS.json` receipt before actual acceptance. Official support process: https://supabase.com/support-policy. Do not incur charges or upgrade a plan without explicit authorization.
