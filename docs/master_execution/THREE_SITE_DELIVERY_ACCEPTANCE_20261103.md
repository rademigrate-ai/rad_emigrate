# Three-site content delivery acceptance — NOT READY FOR DEPLOYMENT

3 November 2026. Continues PR #89. The owner has stopped new backup, recovery,
restore and project creation. This investigation performed no hosted writes,
publication, Feed writes, project creation or frontend deployment.

## Acceptance register

| Gate | Independently observed or prepared | Actual delivery |
| --- | --- | --- |
| URL inventory | 38,231 frozen discovery-frontier URLs; 38,269 unique URLs after union with source and gap ledgers | Historical website completeness unproved; old crawler labels are not editorial exclusions |
| Frozen captured source records | 2,454 identities: DigiVisa 1,160, RADVisa 847, RadMohajer 447 | Raw text preserved; this is not 2,454 proved complete authored articles: 8 indexes and 1 article with an update notice require separate treatment |
| Original 421 gaps | All identities retained: 2 previous full recoveries, 64 capture classifications, 355 without complete-body proof | 419 remain outside the complete-body corpus; classifications do not imply missing historical articles |
| Raw passage integrity | 60,576 unique source blocks match owned original DOM; tables/lists checked structurally; zero unaccounted blocks | Offline evidence only |
| Source-to-revision mapping | 61,991 destination occurrences, 1,100 sealed proposed article/locale revisions, 1,093 articles | No proposed revision imported here |
| Consolidation | 42,226 retained destination blocks; 19,761 exact and 4 semantic duplicate representations; V4.1 preserved | Both alternative numeric values retained |
| Placement | Frozen corpus: 56 country codes, 262 country-neutral article/locales; 427 independent RadMohajer article/locales | Four Dubai country corrections prepared; placement acceptance remains HOLD |
| Import | 406 initial + 443 detached + 249 mechanically reconciled = 1,098 prepared; 2 substantive cases held | 0 imported articles/revisions here |
| Publication | Original 1,084 proposals, 44 rehashed batches, 16 held; proposed 56 countries and 261 Other Titles | 0 approved / 0 published; 27 total held after 7 source-kind and 4 routing exceptions; 1,073 remain unaffected by these specific holds, not approved |
| Production preservation | 745/745 head, body, section, title, actor, hash, revision, time and publication bindings unchanged from previous readback | 745 heads / 747 revisions / 0 published at 10:17 UTC |
| Production migrations | 72 historical entries; required closure, detached allocator and source-faithful publication contract absent | 0 migration versions applied here |
| CMS actor/receipts | Two existing super_admin accounts; management access confirmed | No authenticated editorial session or operation-specific callback attestation established; no approval receipt fabricated |
| Anonymous Production APIs | Draft RPC 404/PT404; direct revisions 401/42501 | Country, Other Titles and source approval RPCs 404/PGRST202; public content acceptance blocked |
| Verification | 395 Python regressions cover native SQL/migration/RLS/retry/publication and raw capture classification; new tool lint/format gates included | Final commit test outcomes and CI SHA/run are recorded in the private final receipt and PR checks |
| Merge / deployment | Conditional acceptance unsatisfied | PR #89 remains Draft and unmerged; no deployment commit |

The larger URL inventory is a discovery frontier, not a count of authored
articles. Its 27,492 legacy `SOURCE_UNRESOLVED` labels cannot certify either
content loss or absence. Every frontier entry remains in the new register with
its original label and explicit proof state. No prior unresolved URL is dropped.

## Original evidence and lawful retrieval

The independent tool recalculates all 14 source-input seals, original raw HTML
hashes, original block/structure hashes, composition inputs, sealed operation
payloads and source/snapshot aliases. It verifies every original block against
owned DOM text in order, preserving multiplicity and numeric qualifications, and
checks list nesting, table cells/spans/headers and captions. Different destinations
may legitimately reference the same source block; duplicate coverage within one
article/locale is rejected. DOM offsets are normalized-text positions, not raw byte
positions. Undated captures remain undated. Invalid UTF-8 outside the owned body
is preserved with evidence-only surrogate decoding; damaged body text cannot pass.

Original captures for all 64 classification candidates were inspected. The
classification register separates error responses, publisher placeholders,
mixed authored text/update notices, listings with partial excerpts, media pages
without authored transcripts, empty containers, service forms, sitemap/navigation
and authored-text candidates. The two previous full recoveries remain separately
identified; thin or mismatched text does not become a reconstructed article.
Error responses never prove historical absence.

The raw link investigation exposed eight paginated article/news indexes inside
the supposedly complete frozen corpus. Their owned `.BoxCenter` containers have
pagination and repeated teaser cards: an owned container alone does not prove an
authored article. A ninth source retains an actual authored introduction plus a
publisher update notice; it is not an empty placeholder. All 489 affected blocks
remain preserved, while the seven destination article/locales are held. The other
2,445 captures are authored-text candidates; raw matching alone does not certify
that each is a historically complete article. Final capture-kind evidence is
separate from the original frozen completeness flags and seals.

All 6,135 recorded body links have literal capture evidence. The recheck matched
10,320 previously recorded anchor occurrences without a fragment/hash mismatch,
then recovered supplementary anchor evidence for 118 records. Seven required
byte-offset proofs because unrelated attributes contain invalid UTF-8; their
literal hrefs/labels and source bytes were preserved. The 1,332 records with
multiple original targets retain that ambiguity. Neither liveness, broken-link
status nor public media rights were certified.

The bounded exact-421 recheck recorded 40 fetch outcomes, 379 host-circuit skips
and 2 independently reproved local recoveries. It recovered zero new bodies.
Publisher 403 stopped further host requests; skipped URLs were not individually
proved unavailable. DigiVisa/RADVisa error redirects and soft errors were retained
as observations. No proxy, authentication workaround or protection bypass was
used. No authorized publisher CMS export or body archive was found in the bounded
local scan. Three public archive-availability samples returned no snapshot; this
does not exhaust the archive history of the 355 missing bodies.

## Editorial exceptions and concrete placement corrections

`RAD-BODY-0151`: both unmatched France pharmacy paragraphs remain preserved.
Neither has an exact counterpart anywhere in the 1,100 proposed bodies. Source
priority cannot authorize discarding current content of undetermined provenance.

`RAD-BODY-0232`: all 65 unmatched UAE blocks have exact counterparts elsewhere
in the proposed corpus. This identifies destination reconciliation rather than
global text loss; it does not approve replacing the current head. Four Dubai
articles were incorrectly neutral. Separate versioned proposals bind their literal
UAE source excerpts to existing country `AE`, preserving article IDs, full draft
bodies, sections and unverified status. The official geography reference is the
[UAE Ministry of Economy and Tourism](https://www.moet.gov.ae/en/web/guest/emirates-of-the-uae).
Its saved representation is explicitly extracted page text, not raw HTML.

The four article IDs are `5c194fbe-8ff4-5859-9ceb-b022150df411`,
`8fb42803-9366-5cb2-b205-9a2db8ef9892`,
`ab608dab-b278-5a2c-9142-8bbb9f78aa9f` and
`b9613c29-55a6-5885-a1d4-1001aa9733f0`. Their proposals are not an executable
replacement package or a publication approval. The original C9 seal is unchanged.
Do not approve the old four routing payloads; new reviewed package/admission and
publication hashes must bind the corrected proposals first.

The 17 numeric candidates across 15 operations now have complete original source
structures, heading contexts, raw block proofs, numeric-token locations and target
representations attached. Every declared numeric token was found. The detector
compares section-level value sets, including phone numbers, years and FAQ ordinals;
an empty/nonempty difference is not proof of contradictory claims. No fact was
invented or conflicting alternative discarded. Existing 16 publication holds and
the two substantive alternatives remain. Seven source-kind destination exceptions
and four routing exceptions increase the publication hold union to 27. These 11
are disjoint from the original 16. The original batches cannot be approved as-is;
corrected eligibility, source receipts and exact publication bindings must be
prepared before execution. Hold counts are not completed imports.

## Production route investigation

Raw `pg_proc`, ACL/RLS, schema, migration, trigger and callback evidence was compared
with the actual reviewed SQL. The core closure contains 83 function definitions,
17 triggers and 55 SECURITY DEFINER declarations; it is not a row-only insert.
The existing forward and sealed generator/allocator/publication migration bytes
remain unchanged. No historical migration chain was replayed.

| Check class | Evidence and lawful alternative evaluated | Result / unresolved dependency |
| --- | --- | --- |
| Integrity and recovery | Exact existing heads, max-revision allocator, journals/idempotency, schema compatibility, rollback, unchanged grants and callbacks | Rollback handles a failed transaction, not recovery after commit or Auth/Storage/external callback effects. Required real checkpoint/isolated-restore proof does not exist in approved evidence. New recovery is owner-deferred |
| Actor and operator authorization | Actual `private.rad_require_admin()` requires existing auth.uid, authenticated JWT role and admin/super_admin profile | CLI/Dashboard/management SQL cannot establish the editorial session. No JWT/GUC actor impersonation is allowed |
| Callback safety | Six enabled callback descriptors and hashes re-read | Metadata is not operation-specific reviewer attestation. Exact callback policy/receipt remains unestablished; disabling hooks is not equivalent |
| Renderer bindings | Six real receipt-file hashes, exact package/physical endpoint, historical source role plus final commit/generator/allocator binding | Hash-format placeholders or a new success flag cannot replace genuine receipts. Owner task authorization exists, but required receipt/evidence bindings are incomplete |
| Ordinary CMS save | Actual `private.rad_save_article` definition inspected | Always advances head; cannot replace detached import while preserving all 745 original pointers |
| Ordinary create/publish | Actual `private.rad_article_mutate` inspected | Create requires registered nonnull country. Publication requires current head/hash and merge-manifest ancestry; cannot substitute for the missing neutral library/source-faithful contract |
| Direct table inserts / existing Staging | Actual grants and environment bindings inspected | Privileged insertion bypasses the CMS/journal contract; Staging state and synthetic fixtures cannot prove Production restore or publication |

No equally protective, already authorized route was found. The exact first blocker
is the existing release mechanism's requirement for a **verified real Production
checkpoint and isolated restore**, with genuine receipt files. The owner has
deferred that work. The separate actual editorial actor, callback review and final
package/endpoint bindings must also pass before any later release. The guard was
not weakened and no new recovery activity was initiated. Publication migration
order remains: reviewed core/allocator, guarded import, exact baseline/readback,
then `20261102192642_rad_source_faithful_editorial_release.sql`, real batch approval,
real batch publication and public acceptance. None was executed here.

## Reproducible evidence

Private continuation root:
`D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\three-site-delivery-20261103`.
The original inputs and package are immutable. `source_delivery_forensics.py --help`
documents offline replay arguments; baseline and additive-two-source composition
directories must both be supplied, with `rad_full_content_v4` as the audit asset
root. No source network request or hosted write occurs in that tool.

- `forensics-v5/manifest.json`: seals the complete 38,269-URL register,
  421-URL capture classifications, 2,454 raw-source proofs and 61,991-row revision
  crosswalk. Earlier failed audit attempts remain retained, superseded by this pass.
- `capture-kind-audit-v2/manifest.json`: final capture classifications supersede
  earlier completeness assumptions and the preliminary placeholder classification;
  source and operation holds remain explicit. `supplementary-link-*-evidence` files
  supply the newly recovered link evidence without editing original seals.
- `numeric-original-context-crosswalk.jsonl.gz`,
  `substantive-global-source-crosscheck.json` and
  `dubai-country-correction-receipt.json`: unresolved alternatives and corrections.
- `production-cms-definitions.json`, `production-final-{raw,heads,callbacks}.json`,
  `production-preservation-comparison.json` and `anonymous-api-final.json`:
  timestamped real Production evidence, not recovery receipts.
- `FINAL_ACCEPTANCE_REGISTER.json`: final candidate SHA, exact CI run/jobs, source
  and artifact hashes, actual versus prepared counts and final unmerged PR status.

Hosted acceptance remains incomplete. Final-HEAD CI success cannot change that
result; merge and deployment remain blocked.
