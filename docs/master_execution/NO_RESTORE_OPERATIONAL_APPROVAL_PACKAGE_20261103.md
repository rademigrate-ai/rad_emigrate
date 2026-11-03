# RAD Production no-Restore operational approval package

**Status: `PENDING_INDEPENDENT_REVIEW` — not an execution authorization**

**Prepared:** 2026-11-03

**PR:** [#89](https://github.com/rademigrate-ai/rad_emigrate/pull/89)

**Sealed content baseline commit:** `22f2e51ddd078f3e9ff0beecbd17637d822b1221` (the exact final implementation HEAD must be rebound separately before independent authorization)

**Owner constraint:** Restore, recovery-project creation, safety-control bypass, browser automation, credential/session-token access, and frontend deployment are not authorized.

This package is the exact review boundary for a proposed no-Restore Production release. It does not assert that the procedure is accepted, does not create a backup or recovery project, does not change a guard, and does not authorize a hosted write. The blank attestation fields are intentional.

## 1. Decision requested from independent reviewers

Reviewers must make a recorded decision for the **complete** scope below, not a general approval of a draft:

> Is the conditional no-Restore procedure in section 7 at least as protective as the existing release policy for this exact Production project, exact commit, exact forward SQL, exact corrected package, exact callbacks, import failure cases, and publication reversal when the prior `published_id` is `NULL`?

A `GO` decision is valid only when all required attestations in section 8 are signed by independent authorized people and every evidence item is bound by SHA-256. `NO-GO`, `CONDITIONAL`, or an incomplete attestation set leaves Production writes blocked. Owner agreement alone is not technical equivalence evidence.

## 2. Exact release binding

| Binding | Required value |
|---|---|
| Production Supabase project | `inshddthftkhcdosoqcn` |
| Sealed content baseline commit (not the final release HEAD) | `22f2e51ddd078f3e9ff0beecbd17637d822b1221` |
| Core forward SQL SHA-256 | `ec77fd4bba84b703a0d2994c3ce8da8112ca969a8f2a478de8061b500f675f69` |
| Core forward manifest | `_audit/.../db_forward_review/manifest.json` (`source_sha`: `81f11ce176d9645ae0503e360e22ef6a414c355b`) |
| Allocator supplement SHA-256 | `5f224ce6025ff43d02e078f51d147f0f9c7b63ce4cf7b42e0c383e6b3f6be4ca` |
| Source-faithful migration | `20261102192642_rad_source_faithful_editorial_release.sql` |
| Source-faithful migration SHA-256 | `0176bbb617c5075232e02197630ff0f6df0de492d4926a06b238475f054ef06e` |
| Corrected admission/hold migration | `20261103114340_rad_corrected_source_editorial_admission.sql` |
| Corrected admission migration SHA-256 | `577edecce2b0fe90bf2308c91add8a301976232b5a95d822374c7dae39c150b0` |
| No-Restore safety candidate (NOT APPLIED) | `20261103120000_rad_no_restore_safety_ops.sql` |
| Safety migration SHA-256 | `cce3d9dac0e821cf5ef3605d19fc84fb6c6b0ee6203067b2cfb46cfb013c083d` |
| Safety regression tests SHA-256 | `86d8267d595517c25b9782bfc8d1fcf4a085897f16e290eecd6c9c7d604c42ea` |
| Corrected package SHA-256 | `4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282` |
| Corrected package scope | 1,100 operations; 44 batches; 1,077 publication candidates; 23 holds; 0 approvals; 0 publications |
| Current observed Production state | 72 migration entries; 745 heads; 747 revisions; 0 publications |
| Current observed Production time | `2026-11-03T11:50:53.591214Z` |
| Current database engine | PostgreSQL `17.11` |

The operator must freshly re-confirm every binding immediately before execution. A stale receipt, alias, project name, service role, management connection, or client-side environment variable is not endpoint proof.

## 3. What Codex has technically verified

The following are evidence-backed checks that Codex can reproduce without a browser session or secret access:

- The candidate SQL and package hashes above.
- A fresh read-only catalog comparison: 100 functions, 86 table metadata records, and the preserved 745-head/747-revision/zero-publication state.
- The seven changed function identities, current deployed definition hashes, and proposed source location in the forward SQL.
- `pg_trgm` is absent from Production and the forward SQL requests its creation in schema `extensions`.
- The six enabled DDL event callbacks and their observed metadata/source hashes.
- Native transaction failure containment and the exact-state package-owned-row compensation tests.
- Import compensation's actual limits: it refuses catalog drift, table fingerprint drift, later writes/references, external FK boundaries, changed owned rows, and changed guard definitions; it deletes only package-owned rows and is not a reverse for committed DDL or publication.
- The corrected package's manifests, batch membership, source bindings, and hashes.
- That no supported Production batch-unpublish RPC exists for a publication whose previous pointer was `NULL`.
- That ordinary `rollback_visa_article` delegates to save behavior and therefore advances a head rather than restoring a `NULL` publication pointer.
- That no Production migration, import, approval, publication, Restore, recovery project, or guard bypass was performed.

These checks do **not** authorize execution or prove that a committed no-Restore release can be reversed.

## 4. Seven changed PostgreSQL function bodies

The proposed forward catalog changes the body or deployed definition of these exact functions. The reviewer must compare the pre-state and post-state using `pg_get_functiondef`, ACL, owner, language, volatility, security mode, `search_path`, and dependent trigger/RPC bindings. The post-state must be bound to the core forward SHA above.

| Function identity | Current deployed definition SHA-256 | Proposed source | Safety decision required |
|---|---|---|---|
| `private.is_safe_public_https_url(p_url text)` | `a5aa08d5d750691c351335c2e2313c0e91a16ad7c3f90abbde507f9110b515ec` | `db_forward_review/forward_body.sql` | Prove SSRF/IPv4-mapped-IPv6 behavior and an exact restoration path for the prior body/ACL/settings. |
| `private.prevent_profile_role_escalation()` | `954cc67ddd74f23b0840d07618a8af66b19f32073e3098bc4cf9890718e4b529` | `db_forward_review/forward_body.sql` | Prove role-change denial/audit semantics, trigger binding, and exact restoration without opening escalation. |
| `private.rad_article_verification(revision uuid)` | `4c0dc1acff287d90a3af18a2c2b03ed30f961180d36596675ba580000438ab8a` | `db_forward_review/forward_body.sql` | Prove factual-state precedence/freshness behavior and exact inverse of the deployed definition. |
| `private.rad_claim_eligible(claim uuid)` | `0e44eca646f7c634018206aea2b1505741dc58ebee5e16d754635950aabb23e0` | `db_forward_review/forward_body.sql` | Prove authority/proof/freshness joins and that reversal cannot leave altered verification semantics. |
| `private.rad_evidence(ref jsonb, section uuid)` | `e7405584ffbc2d06b89c468f7ee1c57e754c84f9b0570051cc0e74f5eeb424b5` | `db_forward_review/forward_body.sql` | Prove source/evidence projection and exact restoration of body, ACL, and dependent reader behavior. |
| `private.rad_page_position(body jsonb, version text)` | `f983903947d87c12e03f52c7183e0c07c53da10436104fe59937f3730268cc55` | `db_forward_review/forward_body.sql` | Prove cursor actor/filter/version binding and exact restoration without invalidating or exposing cursors. |
| `public.get_visa_article(p_request jsonb)` | `85de52ee2fb230a1d194eb23dbfce4eff1444a45c597a9898453b6f1d5e7a196` | `db_forward_review/forward_body.sql` | Prove published-only routing and neutral-country behavior, ACL, and exact public-reader restoration. |

**No-Restore requirement:** a transaction rollback before commit is not a post-commit inverse. A `GO` reviewer must identify how each prior definition, owner, ACL, setting, trigger binding, dependency, and externally visible behavior is restored after a committed release failure. “Re-run the old migration” is not an inverse.

## 5. `pg_trgm` and six enabled DDL callbacks

`pg_trgm` is not present in the observed Production extension catalog. The forward SQL contains `create extension if not exists pg_trgm with schema extensions;`. The following callbacks were enabled at the review checkpoint:

| Callback | Event | Owner | Function | Definition SHA-256 | Required attestation |
|---|---|---|---|---|---|
| `issue_graphql_placeholder` | `sql_drop` | `supabase_admin` | `extensions.set_graphql_placeholder` | `b0cadab880dc68f569b3e01057dc6f5acee9d05e122de6f4256130ae330bbcec` | Effect on extension/drop paths and rollback behavior |
| `issue_pg_cron_access` | `ddl_command_end` | `supabase_admin` | `extensions.grant_pg_cron_access` | `eb3fa2e82a0135bc04a6236f93331911861c91b45d72cba5d9c03c1be2c34b4c | Effect on CREATE EXTENSION and committed-state recovery |
| `issue_pg_graphql_access` | `ddl_command_end` | `supabase_admin` | `extensions.grant_pg_graphql_access` | `9ec845adab4ba00bb7740458b6c4461094697023f0f7adc693b373e2ea54f68` | Effect on CREATE EXTENSION and committed-state recovery |
| `issue_pg_net_access` | `ddl_command_end` | `supabase_admin` | `extensions.grant_pg_net_access` | `e38c4060751c9695123350596f1cb0d0c943015f3267a2a455d8efe02c711184` | Effect on CREATE EXTENSION and committed-state recovery |
| `pgrst_ddl_watch` | `ddl_command_end` | `supabase_admin` | `extensions.pgrst_ddl_watch` | `2b4b5d702ddf70fbd1a05c9825f9f9016d5c0ef97dd3df5f5b012ea23d9b94b1` | PostgREST schema-cache effects and recovery |
| `pgrst_drop_watch` | `sql_drop` | `supabase_admin` | `extensions.pgrst_drop_watch` | `3a2696133853e17a0456cbfbb233a03815f50895492143e84df983b558d76593` | Drop-path effects and recovery |

The callback source is provider-managed. A metadata hash is evidence of identity, not an attestation that the callback has no external or provider-side side effects. The independent callback reviewer must obtain supported provider evidence or an authorized operator attestation for each callback. Synthetic callback policy, an empty checklist, or an application-level test is insufficient.

## 6. Required failure and reversal coverage

### 6.1 Forward DDL failure before commit

The procedure must define the exact transaction boundary, migration runner behavior, and proof that `ROLLBACK` leaves the full preflight catalog, extension list, function definitions/ACLs, callback-visible state, migration history, and public API behavior unchanged. A failed statement, callback error, lock timeout, connection loss, or client-side timeout must be treated as indeterminate until the database state is independently read back.

### 6.2 Forward DDL failure after commit

The procedure must provide an accepted inverse for the seven function bodies, every new table/index/policy/trigger/grant, the `pg_trgm` extension, callback-induced changes, migration ledger, and any PostgREST/schema-cache effect. A separate candidate migration now preserves and transactionally restores the captured seven function definitions with immutable receipts. It explicitly refuses changes to owner, `pg_proc.proacl`, and catalog-visible dependents rather than attempting a potentially unsafe privilege reconstruction. The mechanism does **not** reverse all committed schema, extension, callback, or provider-side state. The exact release remains `NO-GO` unless the independent reviewer accepts a concrete, tested, provider-supported procedure covering those remaining changes.

### 6.3 Import failure before commit

Each import unit must be a bounded transaction with exact package/operation/payload/source hash binding. On any error, timeout, or uncertain connection result, stop and read back the journal, owned rows, heads, revisions, source records, events, catalog, and all table fingerprints. Do not retry until idempotency and absence/presence are proven.

### 6.4 Import failure after commit

The existing compensation is only conditionally supported. It can delete package-owned rows after exact-state checks, with explicit authorization, while temporarily disabling five append-only immutability triggers inside the locked compensation transaction and re-enabling them before commit. It refuses later writes/references, catalog drift, unowned FK references, changed owned rows, altered guards, and changed table sets. It does not reverse schema, extensions, callbacks, or publication pointers. Independent acceptance must explicitly approve this limited scope and the five-trigger handling; it must not be described as a full release rollback.

### 6.5 Publication failure and `published_id IS NULL`

Before any approval/publication, capture each article/locale head and `published_id` exactly. For the corrected package, the safe pre-publication value is often `NULL`. The installed `rollback_visa_article` path calls save behavior and advances the head; it does not restore a prior `NULL` publication pointer. No supported source-batch unpublish RPC is installed.

Therefore the current package has **no accepted publication reversal procedure** for a committed source-faithful publication whose prior pointer was `NULL`. A reviewer may accept the release only after identifying a provider-supported, source-specific, atomic unpublish operation that:

1. authenticates the same authorized Admin/operator;
2. locks the article head and verifies the exact batch, revision, content hash, current published pointer, and prior `NULL` value;
3. writes an immutable reversal event and restores `published_id = NULL` without advancing or substituting an unrelated head;
4. invalidates public/search projections transactionally;
5. is idempotent and refuses any later head/publication/source mutation;
6. has a tested anonymous API readback proving the article is no longer public; and
7. is separately reviewed and authorized before the first publication.

No new RPC, trigger bypass, direct table update, or compensating SQL implementing this behavior is included in this package. A separate unapproved candidate now exists in `supabase/migrations/20261103120000_rad_no_restore_safety_ops.sql`, with local PostgreSQL tests of batch unpublication, immutable event creation, search invalidation, prior-NULL pointer restoration, and stale-event replay denial. It is not installed in Production. Independent code, provider and operational review are still required before use.

## 7. Conditional no-Restore procedure for review

This is a proposal for independent acceptance, not an instruction to execute now.

1. **Bind exact inputs.** Confirm project `inshddthftkhcdosoqcn`, provider endpoint, database identity, current user/role, PostgreSQL version, candidate commit, forward/allocator/migration/package hashes, and the current baseline. Refuse aliases, stale snapshots, pooler ambiguity, or `auth.uid() IS NULL` as an editorial actor.
2. **Freeze and isolate.** Obtain a documented maintenance window. Stop application/worker/egress activity through supported controls, or provide an independently complete change-capture method. Record the control state and verify it independently. Do not create a recovery project and do not disable safety guards.
3. **Fresh preflight.** Capture full catalog, ACL/default ACL, function definitions, extension list, event-trigger metadata, migration history, affected rowsets, all 745 heads, source/editorial fingerprints, and public API denial/readback. Seal the preflight before the forward transaction.
4. **Pre-commit DDL gate.** Run the exact core closure, allocator, source-faithful migration, and corrected admission migration only within the reviewed transaction boundary. Capture callback observations. On any error or uncertain result, stop, roll back where the transaction is known open, and independently prove the baseline. Do not claim post-commit reversibility from this step.
5. **Commit decision.** Commit only if the independent DDL and callback reviewers have signed the exact hashes and the approved inverse for committed state. If no accepted inverse exists, stop before commit. The current evidence does not satisfy this gate.
6. **Import.** Run the guarded corrected import only after the schema acceptance readback. Use bounded batches/transactions, exact journal and package binding, and real authorized operator identity. On failure, use ordinary transaction rollback if uncommitted; use the limited exact-state compensation only if its independent authorization and all refusal checks pass. Never call compensation after drift.
7. **Import readback.** Verify every revision/body/section/source binding, all original heads/actors/publication pointers, package-owned journal rows, row counts, hashes, ACLs, migration history, and public draft denial. Any discrepancy is `NO-GO`; do not advance to publication.
8. **Editorial approval.** A real authenticated editorial Admin reviews and submits each bounded manifest with a real source-review note. The actor UUID, auth receipt, manifest hash, package hash, and response receipt are retained privately. No service-role or management connection substitutes for the Admin actor.
9. **Publication preflight.** Reconfirm the exact `published_id` and head for every candidate, especially the `NULL` prior pointer cases. Confirm the independent publication-reversal attestation exists before the first publication.
10. **Publication.** Submit only authorized corrected batches through the installed source-faithful RPCs. Persist actual approval/publication receipts. Stop on the first error or uncertain response; never infer success from prepared request files.
11. **Production acceptance.** Verify private Admin readback, anonymous published-only API readback, full body/content hashes, country and Other Titles routing, source-faithful status, search/index invalidation, no drafts exposed, no Feed writes, and preserved pre-existing heads. Any failure blocks merge and frontend deployment.
12. **Closeout.** Seal all receipts and hashes, obtain the independent release decision, and only then consider undrafting/merging PR #89. Frontend deployment remains a separate owner action and is not performed by this task.

## 8. Human attestations required before `GO`

The following are decisions or evidence Codex cannot supply:

- **Production identity attestation:** authorized operator confirms the endpoint/project/database/role/system identity is the real Production target and is not Staging, Security, a pooler alias, or a recovery destination.
- **Seven-function review attestation:** independent PostgreSQL/security reviewer accepts the exact pre/post definitions, dependencies, ACL/settings, behavior, and committed-state inverse for all seven functions.
- **Callback attestation:** independent provider/database operator reviews all six callback descriptors and attests the actual CREATE/DROP extension effects and recovery behavior.
- **No-Restore equivalence decision:** independent release authority accepts the complete procedure as equivalent to the existing recovery gate for this exact release, including committed DDL/callback recovery.
- **Import compensation authorization:** release authority explicitly accepts the narrow package-owned-row compensation, five-trigger transactional handling, and every refusal condition; this is not permission to bypass guards.
- **Publication reversal attestation:** independent CMS/database reviewer accepts a tested source-specific unpublish path for prior `published_id = NULL`. Without it, publication is blocked.
- **Editorial Admin attestation:** real editorial Admin confirms identity, reviews the actual manifests/source notes, and provides operation receipts from the supported CMS session. No browser token, password, or cookie is requested or retained here.
- **Release-owner authorization:** owner authorizes the exact project, commit, hashes, maintenance window, actor, operator, and stop conditions after the independent technical decisions above.

### Attestation record

Complete privately; do not fill with synthetic values in the repository.

| Attestation | Reviewer/role | Evidence file SHA-256 | Decision | Date/time | Signature/reference |
|---|---|---|---|---|---|
| Production identity |  |  | `PENDING` |  |  |
| Seven function bodies |  |  | `PENDING` |  |  |
| Six DDL callbacks / `pg_trgm` |  |  | `PENDING` |  |  |
| No-Restore equivalence |  |  | `PENDING` |  |  |
| Import failure/compensation |  |  | `PENDING` |  |  |
| NULL publication reversal |  |  | `PENDING` |  |  |
| Editorial Admin actor |  |  | `PENDING` |  |  |
| Release owner |  |  | `PENDING` |  |  |

## 9. Current decision

`NO-GO — pending independent review.`

The current evidence establishes the package and the limits of the existing compensation, but it does not establish a fully authorized no-Restore path. A candidate seven-function restoration and batch-unpublish implementation exists locally, but neither has been installed or independently accepted. The package still lacks a complete accepted inverse for committed DDL, provider-managed callback effects and all other affected objects, plus operator/Admin receipts. Do not apply migrations, import, approve, publish, undraft, merge, or deploy until those blockers are resolved by independent authorized review.

## Evidence references

- `NO_RESTORE_TECHNICAL_REVIEW_V2.json`
- `FINAL_READINESS_REGISTER.json`
- `PRODUCTION_RECOVERY_PROCEDURE_20261102.md`
- `FINAL_PRODUCTION_CONTENT_EXECUTION_20261102.md`
- `_audit/.../db_forward_review/forward_body.sql`
- `_audit/.../db_forward_review/manifest.json`
- `_audit/.../final-publication-readiness-20261103/current-catalog-metadata.json`
- `_audit/.../final-publication-readiness-20261103/no-restore-preflight-fingerprint.json`
- `_audit/.../final-publication-readiness-20261103/initial-callbacks.json`
- `_audit/.../final-publication-readiness-20261103/package-independent-verification.json`
