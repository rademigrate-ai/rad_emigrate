# Final Production content execution — four-phase result

2 November 2026. This continues PR #89 from `d2c6cb81428a9f48fbe8202edc608a7d1d42a5b3`. The final commit and matching CI run are recorded after commit in the private `final-execution-delivery-20261102.json` receipt. PR #89 remains Draft, open and unmerged. No frontend release was deployed.

**Global acceptance: HOLD.** The safe reconciliation and source-publication implementation is complete locally. Production execution remains blocked by the existing real recovery/endpoint/actor/callback prerequisites. The owner's backup/restore deferral was respected. No recovery evidence, human reviewer or authenticated Production actor was fabricated.

## Phase 1 — reconciliation decisions prepared and tested

The original package and generator were preserved byte-for-byte. `scripts/production_mechanical_decisions.py` validates the sealed package, reopens the original full-body captures, checks their hashes against the current 745-head readback, and independently recomputes exact block occurrence/order and non-section metadata differences.

| Disposition | Cases |
| --- | ---: |
| Exact ordered additions | 207 |
| Reorder/resection additions preserving all current occurrences | 42 |
| Deterministic `create_detached_draft` proposals | 249 |
| Substantive alternatives held | 2 |
| Total existing-key dispositions | 251 |

Every disposition binds operation ID, article/locale, current head/body hashes, desired payload, case hash and preserved conflict hash. Reviewer IDs remain NULL. Mechanical proposals do not claim human factual review, adoption of a head or publication.

`RAD-BODY-0151` (France study/fa) has two current block occurrences not preserved exactly by the proposed body, plus a recorded numeric disagreement. `RAD-BODY-0232` (UAE study/fa) has 65 unmatched current occurrences. Source precedence cannot justify silently dropping these blocks. Both current bodies remain intact in Production; both candidate alternatives and source proofs remain in the frozen private package. Their explicit disposition is `hold_preserve_both_alternatives`.

The adapter calls the existing SQL engine and recovery/actor/endpoint/callback guards. It binds mechanical decisions separately from the empty human-decision set and records the actual import actor only when an authorized execution occurs. A native PostgreSQL test executes a detached mechanical draft and exact retry while preserving the original head and publication pointer.

## Phase 2 — prepared and locally tested, NOT APPLIED

| Operation | Prepared | Actually applied in Production |
| --- | ---: | ---: |
| Initial unverified drafts | 406 | 0 |
| Detached draft candidates | 443 | 0 |
| Mechanically reconciled detached drafts | 249 | 0 |
| Total import operations | 1,098 | 0 |
| Substantive cases held from import | 2 | 2 deferred |
| New schema migrations | Reviewed packages below | 0 |
| New imported sections / blocks | Bound in the private package/register | 0 / 0 |

The complete 1,098-operation SQL review stream is private `FINAL_MECHANICAL_IMPORT_REVIEW_ONLY.sql.gz`. Its first statement raises an unconditional refusal before DDL/DML and it ends in ROLLBACK. It is concrete review material, not an applied migration or a successful import receipt.

Production re-observed at **20:07:01 UTC**: 72 migrations, 738 articles, 747 revisions, 745 heads, zero currently approved revisions and zero published heads. The latest migration remains `20261029172624` (`cms_reading_state_and_research_rls`). The current head/body/actor/title/publication fingerprint `d12ae3c102aad5a4f4ef4ee967456f82` matches the fresh full-head capture. All 745 original heads remain preserved. No Production write was attempted.

Staging was inspected read-only: 58 migration entries, 745 heads and one published head; its editorial catalog exists. The new source-publication RPC is absent there as well as in Production. Native test success is not called Staging or Production application.

Apply ordering, after all existing prerequisites pass:

1. Rehearse the reviewed Production CMS closure on the proven restored checkpoint, then apply it through the migration mechanism. The preserved core is `ec77fd4bba84b703a0d2994c3ce8da8112ca969a8f2a478de8061b500f675f69`; the allocator supplement is `5f224ce6025ff43d02e078f51d147f0f9c7b63ce4cf7b42e0c383e6b3f6be4ca`.
2. Render and execute the authorized mechanical import using the sealed package, bound decisions, real actor/session and exact target. Verify every operation/revision/body plus all preserved heads and source records.
3. Apply `20261102192642_rad_source_faithful_editorial_release.sql` **after** the draft import. It adds event columns, so applying it before the old package's full-row preservation checks would change their baseline shape. Do not weaken those checks or rewrite old migration history.

The old compensating SQL is not an instruction to disable triggers under this task. No compensation, reset, history repair or trigger disabling was performed in Production.

## Phase 3 — source-faithful contract implemented; hosted publication blocked

The existing standard editorial path requires verified facts, documented clearance and complete original-reference capture for imported content. It did not support faithful republication without factual certification. The new migration adds an explicit `publication_basis='source_faithful'` inside the **same** CMS events, immutable revisions, heads, catalog, search index and public readers. It creates no parallel article store or preview application.

The source contract admits only payloads recorded by the guarded importer under package `c9b4d7e84711a3fb478b639d724289a3f2694a298448d662d4637894d0318353` and source-integrity receipt `2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77`. Client roles cannot insert admissions, journals or batch records. A real authenticated Admin separately calls approval and publication; import never calls them.

Approval and publication recheck exact payload bytes/hash, immutable stored body and rich composition, current head/publication pointers, catalog country associations, original language, snapshot text/hash/URL/capture identity, source-publisher independence, numeric conflicts and media flags. Both operations lock heads and shared catalog rows in deterministic order. Approval, publication and their exact retries preserve actors/timestamps and reject changed payloads or later head changes. A source-specific pointer guard refuses direct publication before the legitimate published event exists.

Factual verification remains unchanged and is returned as `unverified`. The standard factual-verification, human-clearance, reference and claim guards remain in force for standard publication. Anonymous readers receive only genuinely published pointers. The Flutter reader displays the source-faithful factual-status label in Persian/English, flags unconfirmed link capture without calling links broken, and keeps uncleared media unrendered. Canonical source deep links delegate to the existing full rich reader rather than flattening tables/lists through the older presentation.

Testing found and fixed a real search failure: missing legacy program metadata produced NULL search content for detached/neutral articles. The existing search trigger now uses an empty metadata string while retaining the complete published article text.

| Source-publication result | Count |
| --- | ---: |
| Prepared proposals | 1,084 distinct article/revision identities |
| Persian / English proposals | 1,073 / 11 |
| Immutable approval-request batches, up to 25 members | 44 |
| Source-supported countries with proposals | 56 |
| Multi-country proposals | 17 |
| Global Other Titles proposals | 261 |
| Held from publication | 16 |
| Actually approved / published / publicly accessible corpus articles in Production | **0 / 0 / 0** |

The 16 holds are the union of two substantive version cases and 15 operations containing 17 numeric disagreements; France study/fa belongs to both groups. No numerical value was invented or selected to conceal a disagreement. Fourteen conflicting operations remain importable as unverified drafts. All 3,134 media references and 1,335 explicitly unconfirmed link-evidence records remain preserved in the original corpus. Media suppression and link status are independent of factual certification.

`scripts/source_editorial_batches.py` emits the fixed manifests, approval-request templates, separate publish requests, all 1,100 dispositions and country coverage. It groups locales of an article together because catalog activity is shared. Request notes and authenticated actor are deliberately unfilled. The requests are proposals, not approval receipts. Their full-size hosted transport/runtime behavior must be rehearsed on the restored acceptance environment before Production; only the bounded synthetic SQL workflow has executed here.

## Phase 4 — code validation and target acceptance

Fresh local checks: **1,189 Flutter tests passed; 376 Python tests passed; Flutter analysis passed; Dart formatting checked 496 files with zero changes; Python formatting/lint and diff checks passed.** Native SQL tests cover real CMS approval/publication/readers on owned synthetic data, anonymous preview denial, non-Admin/service ACLs, immutable old heads, source/factual distinction, shared-locale catalog activation, source conflict/media rejection, direct-pointer denial, retry receipts and zero automatic Feed writes. The mechanical adapter's detached import/retry also passed on native PostgreSQL. These are local synthetic receipts, not client content imported to Production.

CI runs the source-publication SQL test on a fresh canonical Supabase schema in addition to existing Auth/RLS, reconstruction, content, Flutter, Web and Android gates. The final commit and exact eight-job result belong in the external delivery receipt; older green runs do not certify this change.

Real Production anonymous HTTP readback at **20:07:40 UTC** returned draft `get_visa_article`: **404/PT404**; direct revisions: **401/42501**; full country reader: **404/PGRST202**. The complete editorial reader and new source-release RPC remain uninstalled. Therefore published-corpus desktop/mobile/Android acceptance and source-to-Production content readback are **blocked**, not passed. No source-faithful Production publication receipt exists. The prior hosted-browser observation is historical; no new frontend deployment or Android device acceptance is claimed.

The frozen source-integrity result remains **60,576 accounted segments, zero missing, 42,226 retained blocks and 19,765 equivalent references**. Its artifact hashes were reverified. This does not prove every live page was captured. The separate historical URL inventory still has 419 unresolved entries: 355 unavailable and 64 awaiting classification.

## Exact remaining prerequisites and owner handoff

The blocking Production transaction requires the already designed real coordinated checkpoint/isolated restore evidence, exact target/endpoint identity, actual Admin actor/session, six bound owner/recovery/forward receipt files, final-delivery binding and operation-specific callback review. Those prerequisites are absent. Backup/restore remains owner-deferred; none was fabricated or restarted here. The Supabase management connector is not an authenticated editorial Admin session.

After those prerequisites exist, from this checkout:

```powershell
python -m scripts.production_mechanical_decisions render --package "D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\db_forward_review\production_reconciliation_package_v3_final_release" --decisions "D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\final-execution-mechanical-decisions-v2-20261102.json" --authorization "<completed private authorization.json>" --scope approved_production --output "<new reviewed executable SQL.sql>"
```

The existing authorization must additionally bind `mechanical_decisions_sha256` and `mechanical_adapter_sha256`; `human_decisions_sha256` binds the empty human-decision list. Existing real recovery/actor/endpoint/callback/final-delivery checks still apply. Rendering is offline and does not execute SQL. Omitting authorization only produces a refusing review stub.

Once exact import readback and the new publication migration are accepted, use the actual Admin's authenticated Supabase client to submit copied `batch-*.approval-request.json` files with that actor's real source-review note to `approve_source_editorial_batch`. Then explicitly submit each stored `publish_request` to `publish_source_editorial_batch`. Persist the real returned approval/publication receipts privately and verify full bodies, hashes, country/Other Titles lists and draft denial through public APIs. No individual 1,100-row human review is introduced. Do not infer these operations succeeded from prepared files.

Only after those data/publication checks and the final HEAD's CI pass should the owner integrate the reviewed PR and manually deploy the chosen commit on the existing Render service: build `bash scripts/build_web_render.sh`, output `build/web`, preserve SPA deep-link fallback, configure `APP_ENV=production`, the Production Supabase URL and a public publishable key. No service-role/provider/database secret belongs in the Web build. The owner then verifies `/version.json` against the chosen commit and exercises country cards, complete articles, Other Titles, RTL/LTR, search/filter, desktop/mobile and supported Android. This task did not merge PR #89 or perform that deployment.

The private evidence root remains `D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031`; new receipts/packages use `final-execution-*`. [The metadata register](final_production_content_execution_20261102.json) supplies exact code/artifact hashes, operation totals and country-by-country proposed versus actual published counts. This report supersedes the prior report's blanket publication-contract blocker; the recovery and real target-acceptance blockers remain.
