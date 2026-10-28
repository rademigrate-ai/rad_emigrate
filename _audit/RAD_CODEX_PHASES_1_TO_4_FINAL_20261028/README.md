# RAD EMIGRATE — CODEX PHASES 1–4 FINAL IMPLEMENTATION HANDOFF

This is the committed implementation and data handoff. The post-commit execution report is `verification/FINAL_IMPLEMENTATION_HANDOFF.md`; its machine-readable receipts identify the exact final Git SHA, commands, exit codes, log hashes and CI run. A report from an earlier SHA does not establish acceptance of this implementation. The final transport ZIP includes those receipts. Do not mark complete three-site content coverage or hosted acceptance PASS.

## Baseline and collaboration

- Repository: `rademigrate-ai/rad_emigrate`.
- Starting integration HEAD: `2484537ce05c11bf7463d62b043851dc04a35057`, independently verified against PR #85. Baseline Actions run `40650871013` succeeded in eight jobs. PR #85 remained open, Draft and unmerged when rechecked during this task.
- Dedicated branch: `support/codex-phases1-4-20261028`. This branch descends from the integration HEAD and preserves `8321370035cc8a8ff7cff349e5cd55a56fa78da3`, original recovery `04056872a064ad215a87ac164efb0c0244488ba1`, and all prior integration work.
- Only the Codex-owned `rad_content_worktree` was edited. Desktop Antigravity/content worktrees, their `_scratch` captures, original cache directories and synced `sources/` were read-only inputs. No contributor branch was reset or force-pushed.
- Seven required roadmap, feature matrix, SQL QA and transfer/hash documents are copied byte-for-byte under `reference-evidence/`; `reference-input-manifest.json` records their SHA-256 values. PR #85's descriptive body still cites older validation: the actual head, exact receipts and source evidence take precedence.

## Implemented source recovery

`source-master.jsonl.gz` accounts for **2,055** unique URL/source identities across all three sites. This includes all 1,922 frozen records, the eight earlier discovery leads and 125 additional listing-linked identities. It distinguishes **1,385** sources with a complete owned body and verified raw HTML, **214** raw captures without a complete article, **50** unavailable/unfetched leads, and **406** deliberately excluded noneditorial, stateful, query or legacy-template routes. These are source records, not 2,055 distinct substantive articles.

`source-captures.jsonl.gz` retains **2,833** capture versions, their complete body strings and structured blocks, raw/body/structure hashes, original acquisition metadata where known, body links, media references and uncertainty. All 2,833 raw capture references are hash verified; identical raw bytes share an asset. There are **1,323 unique complete-body language/hash pairs**; this count does not imply 1,323 approved articles. The block ledger preserves **98,705** captured blocks and **17,575,357** body characters including repeated versions. Raw files are stored losslessly in `assets/raw/`; short physical filenames avoid Windows path limits, while full SHA-256 values and byte collision checks remain authoritative.

The 259 Antigravity raw files all match their recorded SHA-256. Re-parsing actual HTML identifies 192 complete owned articles, 20 thin/placeholder bodies, 46 listings and one unrecognized/error page. The former 206-substantive/53-empty split was insufficient to establish article completeness. All original raw evidence is retained. **152 listing excerpts** remain explicitly partial.

The targeted recovery requested only 126 missing article URLs linked from those retained excerpts, respecting the site's actual robots policy and a minimum three-second interval. All returned HTTP 200; **125** contain complete owned bodies and **one** remains thin. The robots response, timestamps, redirects, response metadata and exact raw hashes are retained in `targeted-recovery-policy.json` and `targeted-network-observations.jsonl.gz`. No root/sitemap restart, authentication, access bypass or recursive crawl occurred.

All **100 frontier URLs already have full historical bodies plus exact matching original raw HTML in preserved local caches**. All 33 local refetch pairs pass raw TXT, normalized-LF TXT and HTML checks; their parsed article bodies match the frozen bodies. The missing 67 refetches therefore do not represent 67 absent historical bodies. `frontier100-original-cache-proof.json` records each exact identity and capture. **The original Grok package has now been transferred and independently verified:** ZIP SHA-256 `8d4ae958a231596e7a844cf669a5ab23acd6fc3d51fe4606001a4082ae0ca1f2`, 355/355 original files, 21,264,441 bytes. All 146 primary TXT exports match existing intake exactly, and all 100 original Mohajer owned bodies match preserved versions. No additional import operation was created. `grok-original-file-index.json` maps all 355 original paths to exact assets (354 physical assets because identical bytes share storage), with the original transfer manifest and per-source reconciliation. All 33 refetch/original TXT pairs differ bytewise; independent comparison found exactly 765 numeric/visitor-counter line differences and zero other textual line differences. Originals and refetches remain separate evidence; whole-page TXT dynamic counters are never conflated with owned article bodies. All **146 primary-source intake records** have matching body and raw hashes, itemized in `primary146-integrity-proof.json`.

Original HTTP acquisition times remain unknown for 392 retained captures. File modification times and article publication dates are preserved as evidence but never substituted for HTTP capture time. New draft storage uses the real local evidence-intake timestamp with explicit semantics where the original timestamp is absent. Unknown original HTTP statuses stay NULL in the generated snapshot pre-registration transaction.

## Draft delivery and architecture

The combined `prepared/` package preserves the earlier 80 new drafts, 91 revisions and 20 duplicate-reader hides and adds **289** complete independent Mohajer drafts. Company About/Contact pages are preserved as excluded organization evidence; they are not imported as new country articles.

- **369 new locales:** 23 canonical Visa pages and 346 independent articles (57 previously prepared plus 289 additional).
- **91 existing-locale revisions:** 30 canonical enrichments and 61 catalog/country reclassifications. Previously corrected Global Talent, medical-return-to-Iran, country-specific birth, medical study/work and comparative/global scopes remain intact.
- **20 guarded duplicate-reader hides:** original revisions, snapshots and provenance remain immutable. Every source block must already have its canonical placement; edited or human-reviewed content causes a conflict.
- **148 canonical locales / 141 identities:** one continuous page for each supported Country × Category × Locale. The 51 foreign-country canonical scope remains source-based. `prepared/canonical-page-inventory.json` is authoritative.
- **944 active independent locales in the plan**, including preserved existing readers. Mohajer pathways remain full standalone articles in the single Other Titles experience, never automatically appended to canonical Visa bodies.
- **446 source snapshots** in combined intake and **460** new/revised reference maps. `prepared/source-section-ledger.jsonl.gz` preserves the original 31,055-block placement ledger; `capture-block-ledger.jsonl.gz` accounts for every retained capture version.

`destination-proposals.json` provides source IDs, canonical categories, independent article IDs, Persian/English names and draft-only decisions for 56 country codes considered by the combined operation. It explicitly identifies all 29 earlier missing codes using the dated catalog observation; current hosted presence must be rechecked. Source-only independent coverage does not invent an incoming Visa program or public destination tile.

`duplicate-conflict-ledger.jsonl.gz` contains 46 exact-body alias groups, three normalized-body overlap groups and 95 substantial shared-block candidates. Exact source identity, full body, block structure, language and version evidence are compared. Shared country/title or partial similarity never authorizes a merge. Distinct original bytes and unique sections remain retained; alias attachment and uncertain mappings require human review.

All **2,617 earlier excluded blocks** retain their exact original structures and reasons in `reviewed-exclusions.jsonl.gz`. Of these, **2,487 listing blocks on 30 primary-site pages** are explicitly retained as potentially substantive partial evidence, not discarded as meaningless navigation or misrepresented as complete articles. No claim is made that every teaser's unique substance has an approved article destination. The remaining 130 retain explicit soft-404, company/contact, placeholder, empty product and FAQ-control reasons. These original blocks remain independently inspectable.

`complete-human-review-queue.jsonl.gz` contains 434 review items covering recovered articles, uncertain country scope, normalized/near overlaps and the previous listing exclusions. `unresolved-source-register.jsonl.gz` accounts for 264 non-excluded incomplete/unavailable records; many are listings/placeholders rather than established missing articles. It retains exact URL, source ID, status/error, capture references, blocker and next legitimate action. Complete coverage and editorial acceptance remain BLOCKED by these dependencies.

## Technical changes

1. `source_evidence.py`: versioned owned-body extraction, Wayback link unwrapping, preserved encoded URL delimiters, heading levels, nested lists, table spans/cells, Unicode and original link provenance. Long listing excerpts never become full articles merely because no Read More link appears.
2. Country matching uses word boundaries and explicit title/path evidence. It avoids UK/Ukraine, India/engineering and Rome/form substring errors; body-only mentions are review candidates. Disagreement never picks the first country.
3. `reconcile_all_sources.py` is now an import-safe compatibility CLI. Importing it no longer reads/writes contributor-relative `_scratch` files or executes reconciliation.
4. `phase_bundle.py`, `phase_delivery.py`, `phase_verify.py` compile and independently verify additive payloads, complete provenance, exclusions, overlaps, source coverage and deterministic delivery. Portable replay uses the committed capture evidence and repository baselines without external cache paths or network.
5. `prepare_delivery.py` preserves unknown capture metadata during snapshot pre-registration. It verifies every full Admin reader and public draft rejection inside the transaction, with one statement per reader so aggregate verification cannot exhaust the per-statement timeout. Deterministic gzip has no platform-dependent header or timestamp.
6. `rehearse_delivery.py` verifies exact retry, changed-input rejection, human-review guards, metadata honesty, rollback of original heads/catalog and retained immutable history. Runtime receipts can be stored outside committed data.
7. Research worker silent 100,000-character prefix truncation is removed. Over-contract normalized evidence fails visibly with `source_text_too_large`; exactly 100,000 characters retain the last character. No partial snapshot, finding or Feed write occurs.
8. The existing atomic Research ingest already creates one review candidate per new finding. The corrective SQL acceptance verifies the positive path, idempotency and unchanged Feed count. The protected transport default remains unavailable until an authorized protected adapter exists. No migration or publication bypass was added.
9. CI accepts handoff PRs targeting the integration branch, checks the new package and Research transition, and explicitly checks out the exact PR HEAD in all eight jobs.

## Reproduction and verification

Run from this branch's repository root with pinned `requirements-plan3.txt` installed:

```powershell
python -m tools.content_completion.phase_verify --directory _audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028 --reproduce
```

This verifies the complete manifest, every raw/body/structure checksum, all 460 CMS payloads and unique canonical locale slots; re-parses versioned captured HTML; then reconstructs drafts, mappings, ledgers and import/rollback SQL in a fresh temporary directory and requires byte-identical output. It does not use hosted credentials.

`phase_bundle` can reproduce initial ingestion from the seven read-only reference documents, Antigravity cache, verified 33-pair intake, original frozen caches, preserved source-resume cache and targeted network observation/cache. Its pinned evidence-intake timestamp is `2026-10-28T09:30:43Z`. That initial ingestion mode performs no network requests. `targeted_recovery` is a separate, explicit public-read tool and is not needed for offline reproduction.

`phase_acceptance` records core, Flutter/build and local SQL groups against one clean exact Git HEAD. The final execution report contains actual results; earlier preliminary attempts are diagnostic only. Build configuration matches repository CI placeholders and is not a claim of hosted Staging UI acceptance.

## Antigravity: integration order and phases 5–8

1. Review this branch's handoff PR against `integration/stage7-unified-20261026`. Integrate its code/data commit with normal conflict review. Do not reset the live integration checkout or remove `_scratch`. If integrating by cherry-pick, preserve the whole atomic commit, including the source corpus and contracts. PR #85 stays Draft and unmerged.
2. Consume this whole directory, its `final-manifest.json`, and `verification/` from the final ZIP/local execution. Runtime verification identifies the final exact SHA. Repeat offline `phase_verify --reproduce`, content/UI regressions and SQL acceptance after integration if the implementation changes.
3. The supported combined entry point is `import-review/PROPOSED_IMPORT_REVIEW_ONLY.sql.gz`, with exact input/checksum/batch details in `import-plan.json`. **Do not send the new historical payloads directly to the old import RPC without generated snapshot pre-registration:** that legacy RPC assumes HTTP 200 and would lose the explicit unknown capture metadata. The proposed SQL remains review-only.
4. Before any hosted content operation: obtain a real encrypted Staging backup through an approved read-only connection, successfully restore and validate it locally, obtain explicit exact-operation Owner authorization, and execute a fresh matching read-only preflight. No verified approved connection or actual hosted backup/restore exists in this delivery. Local synthetic fixtures and transaction rollback do not satisfy that gate.
5. Keep the gate closed until those prerequisites pass. Then apply only the reviewed content operation on the exact Staging target `epolbumcfbohtmgvomki`. Use its guarded retry/batch journal and conservative `PROPOSED_ROLLBACK_REVIEW_ONLY.sql.gz`; reviewed/edited heads or relations must conflict instead of being overwritten. Recheck canonical slot collisions and all source/snapshot identities immediately beforehand.
6. Validate actual authenticated Admin navigation, all affected canonical and independent full bodies, long Persian RTL scrolling, tables/list spans, links, country associations, full-page Research review, findings-to-review candidates, unauthorized-user denial, public draft exclusion and explicit editorial publication controls. New recovered drafts have not been imported or rendered in hosted Staging by this task.
7. Human editors must resolve historic/current legal claims against official authorities, source conflicts, ambiguous country associations, near duplicates, listing gaps and media rights. Every draft remains unverified, reviewer-null and publication-disabled. No automatic Feed publication is authorized.

## Verdict and boundaries

Phase 1 baseline: PASS. Phase 2 evidence reconciliation/recovery: implemented, with complete coverage BLOCKED by itemized source/editorial gaps; original Grok transfer dependency is now resolved. Phase 3 technical draft package: implemented; exhaustive substantive placement/approval remains BLOCKED where listed. Phase 4 acceptance: consult the exact final execution receipt, not baseline green tests. The entire mission must not be labeled unconditional COMPLETE while essential source/editorial criteria remain unresolved.

No hosted writes, hosted migrations/history repairs, Auth/RLS/grant/Vault/secret changes, hosted imports, deployments, purchases, Feed publications or PR merges were performed. Production `inshddthftkhcdosoqcn` was not accessed. The owner's computer remains running.
