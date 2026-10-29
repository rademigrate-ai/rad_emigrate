# Plan 3 ↔ CMS/Search contract

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
