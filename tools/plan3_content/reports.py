"""Human-readable audit and integration handoff generated from actual dispositions."""

import json
from pathlib import Path


def write_reports(out: Path, m, relationships, drafts):
    def write(name, content):
        (out / name).write_text(content.strip() + "\n", encoding="utf8", newline="\n")

    write(
        "00_EXECUTIVE_SUMMARY.md",
        f"""# Plan 3 — source-backed Visa article library

Task date: 2026-10-24. Baseline main was independently refreshed to `16810a583ad4544d87f289bd16984c0e758a1515` before creating `feat/plan3-visa-content-library-20261024` in an owned D: clone. Grok PR #78 and Antigravity Plan 4 were not assumed merged or edited.

| Stage | Verified count |
| --- | ---: |
| Discovered in-scope URLs with dispositions | {m["discovered_urls"]} |
| Successfully retrieved HTML pages | {m["successfully_retrieved_pages"]} |
| Complete recognized source article bodies | {m["complete_article_bodies"]} |
| Canonical article drafts | {m["canonical_drafts"]} |
| Structurally valid initial CMS draft payloads | {m["structurally_valid_draft_payloads"]} |
| Existing production source IDs retained | {m["existing_source_ids_preserved"]} |
| Independently verified legal claims | 0 |
| Human-approved / publication-ready articles | 0 / 0 |
| Hosted imports / publications by this task | 0 / 0 |

These stages are distinct. Complete source-body capture means every text block in a recognized article container was preserved; it does not establish immigration accuracy, source-rights clearance, complete regulatory coverage or editorial approval. Metadata-only, category/navigation and failed URLs are not counted as complete articles. All articles remain unverified and `publication_allowed=false`.

The reported 812 historical source records, 10 incomplete canonical articles and four named artifact folders could not be recovered or independently verified. The owner confirmed the paths/counts were historical references. The older repository also reports 742 and 1,275 inventory totals, while its referenced JSONL/gzip row files are absent from tracked Git history. None of those totals is substituted for current collected records. `02_812_SOURCE_RECONCILIATION.csv` includes an explicit report-claim row and per-current-source unknown membership, not 812 invented source rows. Six actual hosted source-document IDs are reconciled wherever discovered.

Current sitemaps listed 380 RadVisa, 565 DigiVisa and 740 Radmohajer URLs before normalization. Public navigation, pagination, links, current source records and redirects extend that frontier. Robots rules are retained in `data/discovery.json`; fetches use a per-host interval, no form submission, no login/protection bypass and a bounded scoped frontier. Failed/denied/noneditorial/attachment URLs retain a disposition. Original HTML stays in external owned cache; compressed structured source/canonical/draft data is included here.

The timestamped read-only production snapshot recorded 22 destinations, 10 programs, 8 requirement rows, 18 step rows and 22 drafts in review, with canonical CMS tables/RPC capabilities absent at that observation. This is not a fresh hosted audit during hardening; a draft package is not a deployed backend. No historical migration replay or production writes occurred.

The engineering deliverable is a reproducible capture/validation/canonicalization/import-rehearsal pipeline and human review queue. Production content completion remains gated on missing-source resolution as appropriate, official verification of time-sensitive facts, reviewer rights/attribution checks, compatible backend, recovery evidence and separate owner authorization. Test evidence is reported separately in `13_PARSER_AND_IMPORT_TEST_RESULTS.md`; final-head CI is linked from the Draft PR, never inferred from another agent's report.
""",
    )
    conflict_count = sum(
        r["relationship"] == "potential_numeric_or_date_conflict" for r in relationships
    )
    write(
        "06_DUPLICATE_AND_CONFLICT_REPORT.md",
        f"""# Duplicate and conflict review

Exact-body duplicate groups: {m["exact_duplicate_groups"]}. Near/topic/update candidates: {len(relationships)}; numeric/date-difference candidates: {conflict_count}.

Only identical full extracted bodies with the same country association, pathway and language are automatically grouped. Country equality alone is never a merge rule. Persian diacritic/search normalization is not an exact-body equivalence rule. The preferred source order is RadVisa, DigiVisa, Radmohajer, then URL; source IDs, original titles, URLs, body hashes and timestamps remain in source records. No paragraphs from different source bodies are interleaved to manufacture completeness.

Near matches use title similarity and full-body token overlap. Different numbers/dates are a **potential** conflict, not a verified contradiction: different years, professions, visa subclasses, tax bases or policy scopes may explain them. Such groups remain distinct; no silent authoritative choice is made. Full pair records and differing numeric tokens: `data/duplicate_relationships.json`. Every group has review status not_reviewed and no publication permission.

Canonical IDs are deterministic UUIDv5 identifiers and an identity registry retains assignments on subsequent builds. A newly discovered exact duplicate must not rename an existing canonical group. Two previously distinct canonical IDs are not silently merged. Language variants stay separate; no machine-generated English or missing text is supplied. Updated body versions require human CMS revision handling, not overwrite of an existing initial draft.
""",
    )
    write(
        "11_DRAFT_IMPORT_RUNBOOK.md",
        r"""# Draft import and disposable rehearsal

This package has **no production execution mode**. The importer refuses every non-loopback/ambiguous database URL, requires a matching ownership marker and explicit `--allow-disposable-write`, and verifies the named Docker container's bound port. Never point it at hosted Supabase. Never use service_role in Flutter. No approval, publishing, Feed, role-grant or hosted migration endpoint is in the import allowlist.

1. Install pinned development dependencies: `python -m pip install -r requirements-plan3.txt`.
2. Validate offline: `python -m tools.plan3_content.cli validate --package artifacts/RAD_PLAN3_VISA_CONTENT_20261024/10_CMS_DRAFT_IMPORT_PACKAGE.json`.
3. Rehearse the transactional journal in a **new owned** file: `python -m tools.plan3_content.importer sqlite --package <package> --sqlite-db <new-owned-file> --output <owned-result.json>`.
4. Create an independently owned disposable Supabase project with collision-free high ports. Apply authoritative main migrations only to that disposable project. Do not reuse another agent's active stack, disable RLS, repair hosted history or replay history against Production. The local implementation runtime uses project `rad_plan3_20261024`, DB port 62522 and an external ownership marker. CI uses its own isolated runner/stack and marker.
5. Against that verified owned project only: `python -m tools.plan3_content.importer postgres --package <package> --db-url <owned-loopback-postgres-url> --runtime-marker <owned-marker.json> --psql <psql> --allow-disposable-write --output <owned-result.json>`.

The PostgreSQL rehearsal inserts source prerequisites without overwriting existing rows, resolves existing source-document/snapshot IDs by exact provenance, rejects identity/hash ambiguity, and calls only `create_visa_article` and `save_visa_article_draft` as a synthetic local authenticated admin. It replays both operations, checks identical receipts and draft/unverified state, confirms ordinary-user denial, checks public search cannot return these drafts, and checks Feed/publication counts unchanged. The transaction is **rolled back**. Synthetic test identities are clearly local fixtures, not fabricated human approval identities. Source documents reference `content_sources`, not `research_sources`.

Expected revision is 0. Changed content for an existing canonical ID must produce a conflict requiring human review; no blind upsert/overwrite is implemented. A lost response is retried with the identical request UUID and identical payload. Different database snapshot IDs are rebound before the deterministic wire key is calculated. Package IDs remain provenance identifiers; proposed snapshot UUIDs are never falsely presented as already hosted.

Native CMS v1 has no table block or nested-list model. Complete originals remain in structured source records; tables are represented as plain-text callouts and nested lists flattened for v1 with explicit warnings. Oversized/unknown-country/language/placeholder payloads remain in the editorial queue but are not importable. No content is truncated to fabricate completeness. Catalog extensions or global/multicountry article support need Grok's reviewed contract decision.

**Future Production import is a separate task:** compatible deployed schema/RPC/evidence storage, restore/recovery proof, authenticated human owner authorization, rights/attribution review, reviewed mapping/revision plan and an approved runner are required. This rehearsal-only CLI deliberately cannot perform that action. Draft validation never approves legal claims. Human review and human-approved publication stay mandatory.
""",
    )
    error_count = sum(bool(a["validation"]["blocking_errors"]) for a in drafts)
    write(
        "12_CONTENT_QUALITY_VALIDATION.md",
        f"""# Content quality validation

Canonical draft records: {len(drafts)}. Structurally importable initial drafts: {m["structurally_valid_draft_payloads"]}. Records with blocking technical/source/catalog issues: {error_count}. Editorially/publication ready: **0**.

Deterministic checks cover scoped URL identity, raw-cache hash, body/selector availability and text coverage, placeholder text, duplicate source blocks, absent headings, source/HTML language disagreement, source dates retained without speculative calendar/timezone conversion, numeric/date mentions needing verification, safe plain-text output, country/pathway association review, compressed-record/index hashes, canonical IDs, closed canonical RPC schema, initial-revision-only import, and source snapshot/excerpt/character-locator mapping. Unsafe executable markup is removed from extraction; original article meaning/text, lists, tables and source references remain in structured records.

Blocking errors and warnings are stored separately per source and per draft; see `04_ARTICLE_BODY_COMPLETENESS.csv` and `17_EDITORIAL_REVIEW_QUEUE.csv`. Thin bodies/unsupported countries/missing language/invalid schema are blocked rather than padded. Warnings preserve table/list v1 adaptations, source repetition, old/ambiguous dates and potential conflicts for review. Source publication/modification strings and sitemap lastmod are evidence of different things; a current retrieval timestamp is never a fresh fact-check date.

Broken internal references can be compared against recorded fetch dispositions. External references are preserved but are not all fetched or certified. A government-looking hostname does not automatically verify a claim, scope of authority or freshness. All immigration requirements, fees, processing times, admissions and promises remain unverified until competent evidence and human review support them. RAD-site content and official government evidence are separate authority classes. JSON/schema validity is technical readiness only.

No automatic editorial approval, publication permission, reviewer identity or approval timestamp is fabricated. Full source bodies and canonical bodies are in `data/*.jsonl.gz`, not reduced to summaries. No English translation is invented. Original source text is preserved; Persian normalization is used for search/dedup keys only.
""",
    )
    verification = out / "evidence/local_verification.json"
    observed = (
        json.loads(verification.read_text(encoding="utf8"))
        if verification.exists()
        else {
            "status": "NOT_YET_RECORDED",
            "reason": "Generated before final command execution; no success inferred.",
        }
    )
    write(
        "13_PARSER_AND_IMPORT_TEST_RESULTS.md",
        f"""# Parser and import verification

Evidence recorded at package generation:

```json
{json.dumps(observed, indent=2, ensure_ascii=False)}
```

Required checks: URL/manifest identities, real and synthetic parser fixtures, exact/near canonical grouping, source/citation mapping, source text preservation, draft-only gates, non-destructive idempotent journal retry, closed canonical request schemas, and actual owned PostgreSQL CMS import/retry/authorization/search isolation. Synthetic fixtures contain no purported factual immigration advice. Full tests run with `python -m unittest discover -s scripts/tests -v` after installing requirements-plan3.txt. No unavailable check is labeled passed.

The Draft PR must have successful required workflows on its exact final HEAD. CI status generated later is linked from GitHub and the final delivery receipt; this file does not turn a pending/older-head run into final-head evidence. Flutter/backend code was not changed by this content-only implementation; existing required repository CI still exercises its integration.
""",
    )
    write(
        "14_CMS_SEARCH_INTEGRATION_CONTRACT.md",
        r"""# Plan 3 ↔ CMS/Search contract

Version: rad-plan3-1. The authoritative runtime contract is `supabase/contracts/rad_v1.json` from refreshed main. No shared RPC or migration is changed by Plan 3. Current hosted Production lacks the canonical article schema; unmerged Grok/Antigravity work is not assumed deployed.

| Artifact field | Meaning / consumer rule |
| --- | --- |
| canonical_id | Stable UUIDv5 article identity; retain identity registry on recapture. |
| primary_source_id, source_ids | Source provenance identities; existing hosted IDs preserved; proposed IDs explicitly marked. |
| source snapshot ID/hash | Content-addressed proposed snapshot; runner resolves actual stored IDs without overwriting provenance. |
| body_sha256 / content_version_hash | Original extracted body version and deterministic structured draft request version. Neither is a legal-verification badge. |
| country_codes / country_code | Title/URL-derived associations with evidence; no single country invented for generic/multicountry articles. Unknown catalog countries block create. |
| pathway / category / topic | Versioned inferred taxonomy; existing category slugs retained where applicable. General/residence/new codes need owner review. |
| structured_blocks | Complete original headings/paragraphs/lists/tables, preserved outside the limited v1 rendering shape. |
| wire.create_visa_article | POST /rest/v1/rpc/create_visa_article with p_request; related kind until a human assigns one main per country/pathway. |
| wire.save_visa_article_draft | POST /rest/v1/rpc/save_visa_article_draft with p_request; expected_revision=0, stable UUID request key, complete structured sections, evidence refs, no approval fields. |
| review_status / verification_status | draft_not_reviewed /unverified. publication_allowed=false and approval fields null. |
| conflicts | Potential near/update/numeric disagreements; separate source records, never silently merged or declared verified contradictions. |
| change_diff_inputs | Block hashes and source/version hashes; compare immutable revisions, not body rewrites. |

Authenticated admin authority is required; RLS and RPC guards remain authoritative. Errors are explicit: unavailable backend, invalid schema, source/snapshot identity collision, idempotency conflict and revision conflict. Retry reuses identical request/body/key. Human review must resolve changed existing revisions; the tooling cannot overwrite or publish them. Pagination of the package/index is local file iteration; live CMS cursor rules are unchanged.

Visa Explorer/country/pathway views consume only approved compatible backend data. Article Library/related articles can use independent canonical records but user-facing public reads must use `get_visa_article`/`list_related_visa_articles` published boundaries. Smart Search is full-body `search_visa_articles`; its published-only projection must not index prepared drafts. Country/pathway filters and locale/section anchors remain intact. AI retrieval must not treat these unverified drafts as approved evidence. Research links by source/snapshot/version hashes. Feed receives nothing from this pipeline; publication is a separate explicit authorized human action.

CMS v1 adaptation notes: table structure remains in source sidecar, rendered as callout text; nested-list hierarchy remains in source data, flattened in v1. Topic/reuse/conflict metadata is not inserted as unknown closed-schema fields. Proposed backend extensions must be versioned and agreed with Grok; proposed UI support with Antigravity. No silent schema drift or service-role client credential is introduced.
""",
    )
    write(
        "15_ANTIGRAVITY_HANDOFF.md",
        r"""# Antigravity handoff — review in current RAD project conversation

No verified direct agent messaging channel exists. This document/current project conversation is the coordination channel; no direct acknowledgement or unmerged Plan 4 acceptance is claimed. Plan 3 does not modify Research/CMS/Revision Diff/Change Highlighting UI.

Read `14_CMS_SEARCH_INTEGRATION_CONTRACT.md`, the root package index and `data/canonical_articles.jsonl.gz`. Display source URLs, retrieval evidence, original publication/modification strings, unverified state, rights-review gate and blocking/warning lists. Never convert schema validation or a recently fetched date into an approved/current-law badge. Preserve independent related articles and source variants.

Requested UI work: (1) read-only package preview/import queue with blocked-source states; (2) canonical/source/snapshot/version IDs visible to editors; (3) conflict candidate comparison without automatic merge; (4) source body/table/nested-list preview with explicit v1 adaptation warning; (5) immutable old/new block-hash/source-hash inputs for revision/source diff and user change highlighting; (6) explicit retry/conflict handling and retained unsaved editor text; (7) human review and publication as separate actions. Approval identities/timestamps must come from real authenticated server actions, never from this package.

The original full body is available by source_id/canonical_id in gzip JSONL records, not only summary fields. Country/pathway/topic classification is inferred and reviewable. Persian/English variants exist only where fetched source text supports them. No generated translation or missing legal paragraph should be displayed as authoritative.
""",
    )
    write(
        "16_GROK_BACKEND_DEPENDENCIES.md",
        r"""# Grok backend dependencies — no migration or PR #78 edits

Plan 3 does not change backend migrations, security/privilege policy, shared RPCs, or Grok PR #78. It uses refreshed main's existing canonical contract in an independently owned disposable rehearsal. Production metadata shows only legacy content infrastructure; applying unreconciled history is prohibited.

Requested decisions/changes, for Grok review only:

1. Confirm authoritative deployed `create_visa_article`, `save_visa_article_draft`, `get_cms_article_draft`, published article/related/search RPCs, source_documents/content_sources FK and source_snapshots prerequisites. Plan 3's real rehearsal discovered and respects the content_sources FK; a research_sources ID is not interchangeable.
2. Reconcile hosted migration/catalog effects and recovery proof before any owner-authorized additive change. No production import is enabled in this tool.
3. Confirm safe server-owned import mapping/journal for existing document/snapshot IDs, immutable body hashes, initial revision conflict handling, explicit human actor and no overwrite/auto-approval. Keep source metadata and legal verification separate.
4. Review country catalog extensions/global or multicountry articles. Current create RPC rejects unknown countries; Plan 3 does not create arbitrary destination rows to bypass that check. Do not collapse article countries or invent RAD service coverage.
5. Agree a versioned sidecar or future schema for topic/category, source-rights review, duplicate/conflict relationships and change-diff inputs. Closed v1 requests must not receive unknown fields.
6. Decide native table and nested-list support with Antigravity; original structure is retained in Plan 3 data, not silently discarded.
7. Preserve admin/RLS/publication boundaries and published-only Smart Search/AI retrieval. Research and AI must never automatically publish to Feed.

Current 22-destination/10-program legacy seed presence is not complete content or factual verification. Eligibility, documents, fees, processing times and official authority evidence need substantive review. This handoff requests coordination; it does not claim Grok approval or production readiness.
""",
    )
    write(
        "18_CONTENT_GO_NO_GO.md",
        f"""# Content gates

| Gate | Decision / requirement |
| --- | --- |
| Discovery disposition | {m["discovered_urls"]} scoped URLs documented; failed/denied/attachment/navigation states preserved. Inspect access errors instead of claiming all pages fetched. |
| Historical 812 recovery | NOT VERIFIED; original inventory missing, owner permits reconstruction. No fabricated source rows or recovered count. |
| Source body completeness | {m["complete_article_bodies"]} complete recognized article bodies; other URLs explicitly assessed, not counted as complete articles. |
| Canonical library preparation | {m["canonical_drafts"]} independent/exact-deduplicated drafts; near/conflicting variants retained for review. |
| Technical initial draft schema | {m["structurally_valid_draft_payloads"]} valid payloads; invalid/catalog-unknown/partial records blocked. |
| Engineering verification | See actual local journal/PostgreSQL/unit evidence and exact-head Draft PR CI; pending/unavailable checks are not passes. |
| CMS human review | Prepared data is eligible for human review. Actual CMS import requires compatible backend and separately authorized runner. |
| Factual/editorial approval | NO-GO: verified claims 0, human approvals 0, publication-ready 0. RAD content is not current official legal authority. |
| Production import | NO-GO: explicitly disabled; schema alignment/recovery proof/owner authorization absent. |
| Publication / Feed | NO-GO: publication_allowed=false; no approve/publish tool or Feed mutation path. |

Engineering completion is distinct from production content completion. Remaining source access, parser/structure limitations, uncertain country/pathway associations, potentially stale/conflicting requirements, rights review and official-evidence gaps remain explicit in the queue. No eligibility/fee/processing/admission/scholarship/approval/service claim was invented to fill them.
""",
    )
    write(
        "19_EVIDENCE_INDEX.md",
        r"""# Evidence index and reproducibility

* `01` inventory: every current discovered source identity and disposition.
* `02` historical reconciliation: missing 812/10 report evidence, current membership unknown; preserves actual existing source IDs.
* `03` fetch results: HTTP, redirect, error, retrieval and raw HTML hashes.
* `04` body completeness: actual parser assessment; full source text is in data/sources.jsonl.gz.
* `05`/`06`: canonical groups, exact duplicates and unresolved near/conflict relationships.
* `07`/`08`: Country × Pathway and actual hosted structured-data gaps, not inferred legal completion.
* `09`: citation/snapshot/body-reference/date manifest; all legal verification pending.
* `10`: initial draft-only payload index and compressed request records.
* `11`/`12`/`13`: isolated rehearsal/runbook, deterministic quality checks, actual test evidence.
* `14`/`15`/`16`: unchanged runtime contracts and Antigravity/Grok handoffs.
* `17`/`18`: editorial queue and independent content gates.
* `data/discovery.json`: actual robots/sitemap evidence, declared dates and URLs.
* `data/production_*`: timestamped read-only public content metadata from initial delivery, not a current hosted readiness assertion; no private user records or secrets.
* `data/sources.jsonl.gz`: original complete/partial bodies, lists/tables, source IDs, provenance, hashes and dates. Large raw HTML remains in external owned cache, never in Git.
* `data/canonical_articles.jsonl.gz`: complete preferred source bodies with all source identities and version/block hashes. No composite legal text is invented.
* `data/cms_drafts.jsonl.gz`: exact closed-v1 create/save requests; invalid entries retained with blockers, not imported.
* `data/canonical_identity_registry.json`: retained source→canonical identities for subsequent captures.
* `data/taxonomy.json`: versioned inference rules, not administrative approval.

`data/capture.jsonl.gz` retains the compact parsed collection input, without raw HTML or repeated site navigation. Rebuild offline using the exact command in `tools/plan3_content/README.md`, including `--schema-gate`; use a new owned output directory. Copy the identity registry and evidence directory when reproducing the complete sealed delivery. The library validator checks inventory rows, manifests, body/provenance identities, pipeline fingerprints and payload hashes. Discovery is explicit network work via `python -m tools.plan3_content.crawl --help`; offline validation does not refetch sites. Raw-byte hashes, pipeline fingerprints and content hashes distinguish evidence snapshots from present-day site content. Parser re-extraction from original HTML additionally requires the external owned raw cache.

`PLAN3_MANIFEST.json` supplies counts and current gates. `CHECKSUMS.sha256` seals every package file except itself. Verify using `python -m tools.plan3_content.cli checksums --directory artifacts/RAD_PLAN3_VISA_CONTENT_20261024`. Check GitHub required checks on the exact final branch HEAD; another SHA's green run is not substituted. No Production writes, imports, migration repairs, RLS disabling, deployments or automatic publications occur.
""",
    )
