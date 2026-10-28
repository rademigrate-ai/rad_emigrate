# Plan 3 integration handoff — hardening continuation of Draft PR #80

Audit date: 2026-10-24. This is the existing Plan 3 delivery, not a replacement PR.
Baseline reviewed: `18900fecda36ff0ca23e7b204a4ecae20340879a`.
Only the Plan 3 branch is changed. The two peer branches were fetched and inspected as Git objects, without checking out or modifying their worktrees.

## 1. Pinned contracts and scope

| Component | Read-only review target | Result |
| --- | --- | --- |
| Plan 3 | `feat/plan3-visa-content-library-20261024`, PR #80 | Existing library, crawler, parser, taxonomy, quality checks, canonicalizer, builder, reports, validator, importer, tests and CI reviewed. Fixes described below. |
| Plan 4 | `ee1d9b8ccab6a6df2a17d9eac5d4f43bf35f5c93` | CMS repository, entities, editor, source monitor/diff, lifecycle calls, generator, tests and architecture artifacts inspected. |
| Plan 5 | `a2fd158fb4b8bc6386fc3b9242333580c75d30dc` | Complete branch diff, inherited grounding implementation and SQL publication boundary inspected. |
| Shared registry | `supabase/contracts/rad_v1.json` | Identical Git blob `f179298a2a960ee9670418ddf599a5560085762a` on all three reviewed branches. No RPC rename or wire schema change required. |
| Backend lineage | Main `16810a583ad4544d87f289bd16984c0e758a1515` | 83 migration files, unchanged by Plan 3; rehearsed in a new owned local database. This does not prove hosted migration alignment. |

Plan 4 advanced during verification from `605b1978` to `ee1d9b8`; the intervening changes and its new integration handoff were reviewed read-only, and the placeholder-hash blocker remains. `peer_contract_refresh.json` records that second pin. The peer SHAs above are review pins, not promises about later branch updates. Recheck contract drift when integrating. No peer approval or completed cross-plan UI acceptance is asserted. This document is the contract-review handoff to Antigravity, Grok and the project owner through the project conversation.

## 2. Dataset reconciliation and meaning of “importable”

Delivery root: `artifacts/RAD_PLAN3_VISA_CONTENT_20261024/`.

| Stage | Baseline `18900fec` | Final local library | Meaning |
| --- | ---: | ---: | --- |
| Scoped URLs with dispositions | 1,922 | 1,922 | Includes exclusions and failures; not 1,922 articles. |
| Retrieved HTML responses | 1,206 | 1,214 | Includes navigation/category/nonarticle pages. |
| Complete substantive source article bodies | 1,083 | 1,090 | Full normalized text of recognized article containers, not legal verification. |
| Canonical drafts | 830 | 837 | 253 duplicate memberships collapsed across 85 multiple-source groups; near matches remain separate. |
| Technical initial drafts | 575 | 581 | Current: 574 Persian / 7 English; closed create/save schema and captured 22-country catalog, initial draft only. |
| Associated documents for technical drafts | 722 | 728 | Includes supporting exact duplicates and explicit rebinding receipts. |
| Blocked drafts | 255 | 256 | Current: 160 need country resolution, 96 name a country outside the captured catalog. |
| Fetch failures | 310 | 302 | Current Radmohajer: 294 transport resets, 6 HTTP 403, 2 HTTP 404. |
| Verified legal claims / human approvals / publication-ready articles | 0 / 0 / 0 | **0 / 0 / 0** | Technical validity never clears these gates. |
| Hosted imports / publications | 0 / 0 | **0 / 0** | The importer has no hosted mode. |

The current 581 are technically valid initial drafts in the rehearsed schema/catalog snapshot. They are **not** 581 approved, legally current, translated, rights-cleared, hosted-imported or publication-ready articles. Their country/pathway/topic classification remains inference requiring editorial review. Summaries are source excerpts, not verified editorial abstracts.

`data/sources.jsonl.gz`, `data/canonical_articles.jsonl.gz`, `data/cms_drafts.jsonl.gz` contain full bodies and structured provenance. `01`, `03`, `04`, `05`, `09`, `17` provide source inventory, fetch dispositions, completeness, grouping, evidence and review queue. The historical 812-row inventory remains missing evidence; it was not recovered or replaced with invented memberships.

All original 255 blocked entries remain blocked. One newly recovered generic article adds a country-resolution blocker, bringing the current queue to 256. All remain in the review queue. The 96 catalog-dependent drafts span IE 8; HU 7; RO/PL/QA/RU/IS 6 each; PT/LU 5 each; ZA/IR/SK/CN 4 each; UA/CY/HR/PH/GR 3 each; TH/IN/CZ/GE/AM 2 each. Adding these countries would assert catalog coverage; Plan 3 does not do that. The original 159 country-resolution entries (160 after recovery) include generic, ambiguous and multicountry subjects; choosing one country without an approved model would distort their scope.

The original 310 failures remain timestamped evidence. Original-cache review re-extracted all 1,206 HTML pages and 1,083 complete bodies without mismatch. An explicit retry then retrieved eight former transport failures: seven substantive bodies and one 13-character FAQ stub. The ninth attempted URL returned HTTP 403, so the run stopped and the other 294 transport failures were not retried. The five original 403s and two 404s were not retried. All nine attempted records retain prior failures in `fetch_history`. No denial was bypassed. See `independent_review.json`, `transport_recovery.json` and `recovery_comparison.json` under `docs/plan3_integration_evidence/`.

Comparison against Git objects at `18900fec` proves all original 1,083 source bodies, 830 canonical identities and 830 create/save wire payloads are unchanged, and all original 575 technical drafts remain valid. The seven new canonical drafts are six technically valid Netherlands articles and one blocked generic article. Both original HTML and recovered HTML hashes/bodies were independently checked; no legal claim or missing paragraph was generated.

## 3. Identity and revision contract

| Identifier | Exact meaning | Integration rule |
| --- | --- | --- |
| Plan 3 `source_id` | Proposed `source_documents.id`, or an actual retained hosted document ID for the six known documents | It is **not** `content_sources.id`, `research_sources.id`, an authority ID or a citation ID. Resolve by exact normalized URL/ID, reject ambiguity. |
| Collector ID | UUIDv5 of normalized source URL, namespace `67ef6686-5f55-4ce9-9efa-d03045f46589` | Independent of an existing document ID; do not replace retained IDs with it. |
| Proposed snapshot ID | UUIDv5 of `snapshot:<document_id>:<body_sha256>` | Rebind to an existing matching `(document_id, content_hash)` snapshot when present. Confirm stored body hashes before reuse. |
| Canonical ID | `visa_articles.id`; retained source→article registry identity | Not a source ID or revision ID. Existing identities cannot silently merge; a previously deduplicated group splitting into distinct bodies now stops for human reconciliation. Unavailable sources retain their registry identities. |
| Revision ID | Database-issued `visa_article_revisions.id` | Never substitute a canonical ID, snapshot UUID or payload hash. |
| Revision integer | Optimistic concurrency value per article/locale | Package saves use `expected_revision=0`; the first save returns revision 1. Subsequent editorial saves must use the current server revision. Do not replay an initial package to overwrite edits. |
| Source body hash | SHA-256 of captured normalized source text | Identifies source bytes at the text layer, not CMS state or current law. |
| Package payload hash | SHA-256 of canonicalized Plan 3 create/save JSON | Integrity/version input for the package journal. Not the database content hash. |
| Database content hash | Server hash of stored revision content | Exact lifecycle precondition. Obtain it from the server's revision result/history. Do not recompute it using the Plan 3 hash algorithm or use a placeholder. |
| Request key | Deterministic UUID per exact create/save input | Snapshot rebinding changes save input and therefore its request key. A changed input with a reused key must conflict. |

Source URLs are normalized without collapsing meaningful query IDs, reserved escaped separators or language paths. Original display text remains distinct from Persian search normalization. Hashes detect content drift within a trusted checkout; they are not signatures of source authenticity or factual correctness.

## 4. Compatible RPC and model surface

All requests are sent as `rpc(name, {'p_request': request})`; no extra sidecar fields may enter the closed v1 JSON schemas.

| Operation | Request fields | Response / authorization |
| --- | --- | --- |
| `create_visa_article` | `article_id`, `kind=related`, `country_code`, `pathway_slug`, `slug`, UUID `request_key` | Envelope `data.article_id`, `data.created`, `meta`; authenticated server-confirmed admin only. |
| `save_visa_article_draft` | `article_id`, `locale`, `expected_revision=0`, `title`, `summary`, `sections`, `related_article_ids=[]`, `merge_manifest_id=null`, UUID `request_key` | `ArticleRevisionResult`: article/revision IDs, revision, server content hash, editorial/verification state, timestamp. Admin only; result must be draft/unverified. |
| `get_cms_article_draft` | `article_id`, `locale` | Lossless `content` plus revision metadata. Plan 4's `CmsArticleDraft` preserves raw sections and evidence on save. Admin only. |
| `list_visa_article_revisions` | Exact registry request, including article/locale and pagination | Supplies `RevisionSummary.content_hash`; use the entry matching the current revision ID. Admin only. |
| `search_visa_articles` | Query, locale, country/pathway arrays, optional article kind, locale fallback, opaque cursor, limit | Published revision hits with article/revision/section IDs, anchor and navigation target. Public; drafts must return no hits. |
| `retrieve_verified_official_claims` | `p_query`, `p_locale`, nullable `p_country_code`, nullable `p_topic` | Service-role-only official grounding. No direct Flutter call; no content-draft fallback. |

The exact JSON Schemas, required keys, enum values and length bounds remain in `supabase/contracts/rad_v1.json`. `docs/plan3_integration_evidence/contract_fixture.json` supplies an actual small unverified Plan 3 create/save fixture with original source text and IDs. The complete gzip payload supplies all 581 positive cases and 256 blocked cases, including the unchanged original 575 technical drafts.

Section input remains `{id, anchor, heading, order, blocks, evidence_refs}`. Blocks remain `{id, type, text, items}`. Evidence input remains `{snapshot_id, claim_id:null, excerpt, locator}`. `locator` uses Python Unicode code-point positions in the captured source: `<selector>;chars=<start>:<end>`. Excerpts are exact source substrings, capped at 4,000 characters; they are not verified claims. They are not Dart UTF-16 offsets or search snippet match ranges.

Plan 4 `ArticleSectionInput`, `ContentBlock` and `EvidenceInput` match these fields. Its expanded `EvidenceRef` is a **server response projection**, adding source-document ID, publisher/class, URL, authority, verification/freshness and timestamps. Do not place that response object into `evidence_refs` input. Resolve proposed snapshot IDs before the CMS reads them. First-party RAD classification is not government authority verification.

Pagination uses the registry's opaque cursor and returned page metadata. Preserve locale and filters between pages; a stale cursor/index version requires a restart. Do not synthesize cursor offsets. Error handling must preserve unsaved editor data: forbidden/unauthorized → no retry as another actor; `PT409` revision/inventory/idempotency conflicts → reload and reconcile; `PT422` validation/evidence/catalog failure → retain blockers; unavailable/malformed responses → no success receipt or publication assumption.

## 5. Confirmed defects and remediation

| ID | Severity | Evidence / regression | Disposition |
| --- | --- | --- | --- |
| P3-H01 | P1 | `tools/plan3_content/importer.py:301`, `local_psql_environment`; libpq `PGHOSTADDR` can override an explicit URI hostname. | Fixed: strip inherited `PG*` options/service routing and pin loopback host address. Regression injects remote host/service/session options; hosted/ambiguous URIs are still rejected before a DB call. |
| P3-H02 | P1 | `tools/plan3_content/crawl.py:71,116`, `SafeRedirect.redirect_request` and `Collector.throttle` | Fixed: exclude stateful/noneditorial redirect destinations and throttle every redirect using the target host's policy. Synthetic regressions cover logout/admin/form targets and target-host throttling. No live stateful request was used as a test. |
| P3-H03 | P2 | `tools/plan3_content/dataset.py:178,311`, `canonicalize` / `updated_identities`; two previously joined sources diverging reproduced duplicate canonical IDs. | Fixed: stop on identity splits and retain identities for temporarily unavailable sources. No current canonical ID changed. |
| P3-H04 | P1 | `tools/plan3_content/importer.py:26`, `dataset.py:559`, `traceability.py:6` | Fixed: independently reconstruct source→draft semantics; reject rehashed text changes, removed references, promoted catalog flags, mismatched index metadata, graph identity/partition/body/provenance errors. Hash-only validation was insufficient. |
| P3-H05 | P2 | Rehearsals previously staged only primary documents; source sidecars contained additional exact duplicates. | Fixed: stage all 728 documents/snapshots for the 581 current drafts, classify first-party origins without approval, retain article→all-source rebinding receipts. Closed CMS evidence continues to reference the primary source; the full mapping is an explicit sidecar. |
| P3-H06 | P2 | PostgreSQL receipt comparisons previously allowed SQL NULL to evade inequality checks. | Fixed: NULL-safe checks for identity, revision, content-hash shape, draft/unverified state and exact retry. Added AI grounding baseline comparison and a negative placeholder-hash lifecycle probe. |
| XPLAN-H01 | P1 integration blocker | **Plan 4** `lib/features/admin/presentation/pages/admin_cms_canonical_editor_page.dart:139` at `ee1d9b8`: `contentHash: '0' * 64`. Backend `20261019205040_rad_visa_cms_official_evidence.sql:245` requires the actual revision hash. | Peer branch unchanged. Antigravity must carry the current server hash into `_submitReview` (e.g. matching revision history entry), preserve generation/concurrency checks and add a successful real-hash / rejected-placeholder regression. The Plan 3 disposable negative probe proves rejection. |
| XPLAN-H02 | P2 contract-document conflict | Plan 4 `artifacts/RAD_PLAN4_RESEARCH_CMS_20261024/PLAN4_INTEGRATION_HANDOFF.md:26,62,129` at `ee1d9b8` describes sidecar fields as direct CMS input, uses `in_review`, and prescribes an Auth app-metadata admin role. | Use the actual registry and SQL: closed `wire` requests only; wire state `review`; admin authorization through server-controlled `profiles.role` (`20261003210302_project09_visa_catalog.sql:19`). Antigravity should correct its handoff. No peer code or authorization rule is changed here. |

The runtime package remains an initial-draft package, not a production import service. Source registration is fixture work by the owner-controlled local runner. Plan 4/5 clients must not receive direct privileges on the canonical workflow tables or private origin/inventory/authority tables.

## 6. Publication, search and AI boundaries

Verified at the pinned peer SHAs, whose relevant backend definitions are inherited unchanged from main:

* Search joins `visa_article_search_documents` to `visa_article_heads.published_id`, with article and locale agreement (`20261020112300_rad_crm_search_integration_hardening.sql:123`). A draft head is not a published head.
* Public article/related RPCs likewise resolve published heads; CMS draft access is separately admin-gated. Canonical tables have RLS enabled and direct client privileges revoked.
* `retrieve_verified_official_claims` requires service role, current eligible official evidence and a claim reference in sections of a **published** article (`20261019210423_rad_content_workflows.sql:104–127`). A raw snapshot, draft, research proposal or editor approval alone cannot satisfy that path.
* `ai-orchestrator/knowledge_grounding.ts:42,65–69` calls only that RPC and rejects unverified, malformed, future-dated or stale evidence. It has no fallback to `content_drafts`, raw Plan 3 bodies or the legacy broad knowledge retriever.
* Plan 3 writes no knowledge claims, official proof, review approvals, inventory approvals, published heads, Feed items or AI ingestion jobs. All package `claim_id` values remain null. Consequently this library contributes **zero public AI grounding claims** until a separate verified, published process is completed.

These are code and disposable-runtime conclusions. They do not establish that hosted functions match these definitions. Plan 5's added source-string assertions are supplementary; they are not substituted for the Plan 3 real-database draft-isolation rehearsal or existing security suites.

## 7. Schema prerequisites and unresolved decisions

1. **Backend/owner:** reconcile the hosted migration ledger against actual schema effects and backup/restore evidence before any additive deployment/import plan. Do not replay historical migrations or repair a ledger from this package. The production schema snapshot in `data/production_canonical_schema_gate.json` is timestamped evidence from the earlier delivery; it reported absent canonical tables/RPCs and is **not** a fresh hosted audit or proof they are still absent.
2. **Backend:** provide a separately authorized server-owned import journal mapping package/source/canonical IDs to actual document, snapshot, revision and request receipts. `source_documents.source_id` references **content_sources**, not research_sources. Reject URL/ID/hash ambiguity; never overwrite existing snapshots, editorial revisions or approval metadata. The local rehearsal now classifies RAD origins; an actual runner must preserve that provenance step too.
3. **Antigravity:** resolve XPLAN-H01 before claiming end-to-end CMS review readiness. Review the source/canonical/snapshot distinctions and the actual fixture. No direct agent acceptance has been received.
4. **Owner + backend + frontend:** choose global/multicountry article semantics and catalog expansion policy for the 256 current blocked entries. Do not choose an arbitrary country or create service-coverage claims from URL vocabulary.
5. **Frontend + backend:** tables currently use source-derived text callouts; 65 drafts carry that adaptation warning. Native table spans/cells and nested-list hierarchy remain in the source/canonical sidecar, not the v1 CMS block contract. Agree a versioned extension before promising exact rich rendering.
6. **Editorial + backend:** all 837 are `kind=related`; no main RadVisa/DigiVisa composite article or approved merge manifest is fabricated. `approve_visa_source_inventory` requires both publishers, explicit human approval and an inventory revision. Do not call it merely to register supporting duplicates or force these independent articles through a main-article workflow. Linking “other titles” to main articles remains an editorial mapping decision.
7. **Frontend:** initial section/block IDs are deterministic. Subsequent editor revisions must retain IDs for unchanged sections and assign new IDs to inserts; reimporting initial payloads is not a revision-diff strategy. Keep source, payload and server revision hashes distinct.
8. **Editorial/owner:** resolve inaccessible sources only through permitted public access, official factual verification and rights/attribution review. The three RAD websites are first-party content sources, not government legal evidence. No legal completeness or accuracy gate has passed.

## 8. Reproduction, fixtures and acceptance gates

Run from the existing checkout with `requirements-plan3.txt` in an owned virtual environment:

```text
python -m unittest discover -s scripts/tests -v
python -m tools.plan3_content.cli library --directory artifacts/RAD_PLAN3_VISA_CONTENT_20261024
python -m tools.plan3_content.importer sqlite --package artifacts/RAD_PLAN3_VISA_CONTENT_20261024/10_CMS_DRAFT_IMPORT_PACKAGE.json --sqlite-db <new-owned-db> --output <owned-receipt>
```

The complete offline rebuild command is in `tools/plan3_content/README.md`. Copy the existing identity registry and evidence directory to a new owned output before building; require identical `CHECKSUMS.sha256`. The parsed capture is committed. Original-HTML re-extraction additionally needs the external owned raw cache; CI does not pretend to refetch the historical web pages. Compression engine/parameters and LF text fingerprints are pinned for Windows/Linux reproducibility.

Fixtures and evidence:

* `scripts/tests/test_plan3_content.py`: synthetic URL/parser, body integrity, identity split/retention, ungrounded text, missing evidence, catalog/index forgery, duplicate-support preservation, local-runtime and libpq-environment regressions. Synthetic prose makes no immigration claim.
* `docs/plan3_integration_evidence/contract_fixture.json`: actual small captured unapproved article wire example for Antigravity decoding/revision-mapping review.
* `docs/plan3_integration_evidence/independent_review.json`: original-cache re-extraction, failure triage/retry and pinned peer-registry proof.
* `docs/plan3_integration_evidence/local_verification.json`: actual hardening verification receipts, hashes, counts and scope, including 126 Python regressions, 1,019 Flutter tests, 158 Deno tests, Web and Android debug builds. External full logs remain under the owned `D:\RAD_PLAN3_20261024` evidence directory.
* `artifacts/RAD_PLAN3_VISA_CONTENT_20261024/evidence/local_verification.json`: sealed delivery-generation verification, distinguished from exact final GitHub HEAD checks.
* PR #80 checks: require **all eight** CI jobs green on the final pushed SHA. The historical `18900fec` green run alone does not satisfy this continuation. Final SHA/run/job matrix is supplied with the delivery receipt in the project conversation.

| Gate | Verdict |
| --- | --- |
| Plan 3 engineering review and isolated integration preparation | Proceed only with the recorded hardening verification and exact final-HEAD CI evidence. |
| Shared JSON wire contracts | Compatible at the pinned Plan 4/5 SHAs. |
| Full cross-plan CMS workflow acceptance | **BLOCKED** by XPLAN-H01 and owner review of the unresolved mappings/extensions above. |
| Public search / AI use of these unapproved drafts | **NO-GO**; no publication or verified claims exist. |
| Hosted import, staging authorization, production release or publication | **NO-GO**; requires separate schema/recovery, factual, human-review and owner-authorization gates. |

No merge, hosted migration/import, deployment, force push, publication or peer-branch modification is part of this handoff.
