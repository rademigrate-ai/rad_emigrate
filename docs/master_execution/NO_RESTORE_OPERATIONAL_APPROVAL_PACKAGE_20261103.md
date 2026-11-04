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
| Pre-core bootstrap SHA-256 | `2aea67c25903623ce98a76bf2f86dbf1d637adc91c701b86474cb7b94536de44` |
| Safety regression tests SHA-256 | `9eff3c16e348c019d096007b0bf6282c683beba7e363aeeee0353a137186ba88` |
| Post-publication-contract withdrawal candidate (NOT APPLIED) | `20261103180754_rad_source_unpublish_safety.sql` |
| Withdrawal migration SHA-256 | `0cde295bbcbda93cad57230b2f637112fdcba2301305aa65af7b1378bcd0013a` |
| Portable clean-schema SQL regression SHA-256 | `7276184ba6085a2e43ff2f7ef10a32aa5328a7237c9b293b143e2520bde8dec5` |
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
| `issue_pg_cron_access` | `ddl_command_end` | `supabase_admin` | `extensions.grant_pg_cron_access` | `eb3fa2e82a0135bc04a6236f93331911861c91b45d72cba5d9c03c1be2c34b4c` | Effect on CREATE EXTENSION and committed-state recovery |
| `issue_pg_graphql_access` | `ddl_command_end` | `supabase_admin` | `extensions.grant_pg_graphql_access` | `9ec845adab4ba00bbf7740458b6c4461094697023f0f7adc693b373e2ea54f68` | Effect on CREATE EXTENSION and committed-state recovery |
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

The candidate authenticated `unpublish_source_editorial_batch` RPC now exists in `20261103180754_rad_source_unpublish_safety.sql`. It is prepared and tested locally, not installed or independently accepted in Production. It restores prior-NULL public pointers without advancing the head, preserving bodies, authors and factual status. Exact request/member receipts and a trigger-assigned full transaction ID prevent stale event reuse while allowing legitimate calls inside savepoints. A hold added after publication can block further approval/publication without blocking safe withdrawal. Catalog activation and immutable history intentionally remain; this is not a universal publication-state inverse.

## 7. Conditional no-Restore procedure for review

This is a proposal for independent acceptance, not an instruction to execute now. Migration filenames order clean-schema reconstruction; the Production dependency sequence below is a separate explicitly reviewed plan. The original combined safety candidate has been split because capture after the core forward cannot establish its preimage.

1. **Accept the complete policy before any hosted write.** Independent PostgreSQL/security and Supabase/operator reviewers must accept the exact scope and a concrete committed-DDL/callback failure procedure. Bind final candidate commit and every artifact hash; the owner then authorizes the exact release window. The existing guarded mechanism remains fail-closed without its required evidence; an unaccepted policy is not an alternate execution mode.
2. **Verify identity and maintenance controls.** Bind project `inshddthftkhcdosoqcn`, database/system identity, provider endpoint, executor role, all old rowsets/catalog/ACLs, migration ledger and actual callback descriptors. Freeze writers/workers/egress through supported controls. Do not infer editorial identity from management postgres access.
3. **Install the pre-core bootstrap only when independently accepted.** `20261103120000_rad_no_restore_safety_ops.sql` depends only on the existing CMS Admin/immutability foundation. Its own DDL, grants, schema-cache/callback effects and bounded catalog lock must already be reviewed. Capture baseline evidence before this first change as well.
4. **Capture before the core forward.** A real authenticated editorial Admin calls `get_release_function_state` and `capture_release_function_state` using the exact corrected package and reviewed state SHA. Capture fixes all seven original definition hashes, ordered settings, language, volatility, security mode, OIDs, owner, raw ACL and incoming catalog-visible dependents. Preserve the immutable receipt. Late capture on an upgraded catalog is refused.
5. **Apply only the reviewed core closure and allocator.** Respect exact transaction/commit and callback gates. A pre-commit rollback does not establish a committed-state inverse. The proposed seven-function inverse alone is insufficient for the entire schema closure.
6. **Import guarded drafts.** Only after schema acceptance, run the corrected package in bounded transactions. Use exact source/payload/package/journal binding and authorized operator identity. Before advancing, prove every old head/body/author/public pointer, new revision/source binding and anonymous draft denial. Limited package-owned-row compensation requires its own exact-state checks and separate authorization.
7. **Install publication contracts AFTER import.** Apply the sealed source-faithful publication migration, corrected admission/hold migration, then `20261103180754_rad_source_unpublish_safety.sql`. Verify every schema object, ACL, hold, public projection and callback. None of these migrations publishes content.
8. **Prepare any inverse independently.** Reversal requires an immutable private operator authorization bound to source receipt, real Admin actor, full expected-current-state hash, exact request hash, evidence SHA and expiry. No client/Admin API can create that authorization. Catalog/advisory locking and prevalidation refuse OID, owner, ACL, dependency or unexpected state drift. Exact retry reuses its original receipt; partial failure rolls back the whole inverse call.
9. **Real editorial review and publication.** The actual Admin reviews eligible manifests/source notes and submits supported bounded batch operations. Persist actual actor/time/manifest/package/approval/publication receipts. Keep all 23 holds. Source withdrawal covers only the explicitly recorded prior-NULL pointer case; no substitute head or Feed write is permitted.
10. **Verify real Production acceptance.** Read back full source bodies/hashes, country/Other Titles routing, search, locales, attribution, truthful source-faithful status, preserved old heads/authors, zero draft exposure and zero unauthorized Feed publication. Uncertain outcomes are NO-GO.
11. **Close out only after every gate.** Seal final evidence, obtain independent release decision and exact-HEAD CI/repository clearance, then conditionally merge PR #89. Frontend deployment remains the owner's separate action.

### Locally executable coverage and explicit limits

The native suite exercises original pre-core capture, retries across separate transactions, exact seven-member scope, expected-state binding, separate/expired/wrong-actor authorization, owner/ACL/OID/dependency drift, quoted multi-schema settings and language/security/volatility preservation, member-injection refusal, partial-inverse atomicity and concurrent DDL lock refusal. Source tests cover multiple articles/locales, original authors/bodies/heads, late-member failure atomicity, same/cross-transaction replay, ordinary-user/other-Admin denial, held-content withdrawal, real two-connection retry and transactional search removal. Portable clean-schema SQL and normal local Auth JWT checks exercise supported RPC boundaries in CI.

**Managed executor requirement confirmed:** read-only Production inspection on 2026-11-03 confirms `postgres` is not superuser and has none of UPDATE/DELETE/TRUNCATE on `pg_catalog.pg_proc`, whose owner is `supabase_admin`. The isolated managed Supabase stack reproduces the denial. Capture and inverse now explicitly refuse with `provider_approved_catalog_lock_executor_required` before writing a receipt. The read-only Admin metadata RPC reports this capability separately. A provider-approved, narrowly protected executor is required; this package does not grant catalog privileges, change function owners or remove the catalog lock. Native positive inverse tests use the owned native superuser fixture. Managed Supabase tests establish refusal and normal Auth boundaries, not successful managed inversion.

Owned local extension tests demonstrate pre-commit rollback, dependent-object DROP refusal, committed DROP and synthetic `ddl_command_end`/`sql_drop` callbacks. A callback-created schema grant deliberately persists after extension DROP. This is evidence that a bare DROP is insufficient; it is not evidence about actual Supabase callback side effects or PostgREST cache behavior. No database Restore is performed.

The seven-function inverse does not reverse the rest of the core DDL, new tables/functions/indexes/policies/columns/grants, extensions, provider callback effects or migration history. `pg_depend` cannot establish all dynamic SQL/application dependencies. Withdrawal leaves catalog activation and immutable review/history intact and excludes prior non-NULL publication pointers. A complete independently accepted procedure for those remaining states is still mandatory.

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

## 2026-11-04 capability correction and owner boundary

PostgreSQL 17 also permits MAINTAIN for a SHARE table lock. The candidate now observes that existing privilege in a private invoker helper, alongside UPDATE/DELETE/TRUNCATE. It retains the actual `LOCK TABLE pg_catalog.pg_proc IN SHARE MODE`, timeout, Admin checks, independently accepted request binding, current-state checks and immutable receipts. It grants no catalog privilege. Twenty native tests pass, including an owned local role with MAINTAIN only taking the actual lock. Production postgres has none of the four privileges; provider acceptance remains pending.

The current implementation inventory and provider request are in [FINAL_EMPLOYER_DEPLOY_READINESS.md](FINAL_EMPLOYER_DEPLOY_READINESS.md) and [PROVIDER_CATALOG_LOCK_REQUEST_20261104.md](PROVIDER_CATALOG_LOCK_REQUEST_20261104.md). Historical evidence above retains its original date; current evidence is separately labeled there. A passing local test does not fill any independent approval field. The owner will perform both final merge and frontend deployment. Employer acceptance testing occurs after deployment.

## Latest owner instruction: conditional agent merge

The new backend-activation execution brief supersedes the earlier owner-only merge instruction: Codex may merge PR #89 only after all actual Production, independent provider/no-Restore, CI and repository requirements pass. Frontend deployment stays owner-only. This change authorizes conditional merge work; it does not complete any independent attestation, waive recovery evidence, approve a protected executor, or permit a hosted write while safety remains unresolved. All attestation fields remain PENDING. The original renderers and corrected package are unchanged; the new offline format adapter validates their inputs without adding a release-authorization mode.
