# Plan 3 integration handoff — continuous country/category content

This supersedes the earlier source-article archive layout. The source branch is `feat/content-consolidation-staging-20261026`, based on `d93355e9960ed3c229615f2d38ca4044f2809138`. Exact tested commit and CI evidence are delivered separately to avoid a self-referential commit hash. No peer branch is changed. Frontend review by Antigravity and final owner release approval remain pending.

## Identity and storage

`visa_articles.id` is the canonical UUID identity, shared across locales and country associations. `visa_article_revisions.id` is an immutable locale revision UUID; its integer `revision` is the optimistic concurrency value. `visa_article_heads.head_id` selects the editable head and `published_id` independently selects the public version. A source UUID identifies an original document; a snapshot UUID identifies an immutable capture and must not be substituted for an article or revision ID. Rich block UUIDs and projected v1 section UUIDs are different: use `projection_map` to navigate search anchors to original rich blocks.

The core manifest is `df46e65e9b8452b6043b24db7b7528d3c29cf4242a84d367032f705a8dbb9464`; batch `9bf5902a-dabc-5cd7-832d-430ecd1be159` imported 743 locales / 736 identities. All are draft/unverified. Existing v1 request/response schemas are retained. Additive reader metadata belongs in `editorial-3`; do not inject its fields into closed `rad_v1.json` envelopes.

Private additive tables hold catalog associations, rich revision structure, review receipts, human clearances, proposed Other Titles and original reference maps. They extend the existing CMS; they are not a parallel public article database. Country associations may be empty for genuinely global/ambiguous material. Only one main identity is proposed per supported country/category; legally meaningful programs remain internal scopes. No country or English translation is invented.

## RPC requests and responses

All calls use POST `/rest/v1/rpc/<name>`. `rpc_surface.json` records exact deployed-source argument names/types/defaults and SQL EXECUTE grants, independently extracted from the clean database. Public responses use `{data: object, meta: object}` from `private.rad_envelope`; trace IDs change per call. Compare `data`, not whole envelopes, for retry checks.

| RPC | Request | Data returned | Authorization |
|---|---|---|---|
| `resolve_editorial_article_slug` | `p_country_code,p_slug,p_locale` | article_id UUID | Published-only, no preview; fail on ambiguous slug |
| `get_editorial_article` | `p_article_id:UUID,p_locale:fa|en,p_preview:bool=false` | card, revision, sections, rich_sections, projection_map, sources, available_locales, preview, translation_fallback_used=false, other_titles | Public published pointer; preview server Admin only |
| `get_editorial_reference_links` | same | revision_id, links[], capture_status complete|not_captured, verification_state not_inferred_from_links | Same published/preview boundary |
| `list_visa_content_countries` | `p_locale,p_preview=false` | items[{country_code,category_count}],preview | Published categories only; preview Admin |
| `list_country_visa_content` | `p_country_code,p_locale,p_preview=false` | country_code, categories[], other_titles[],preview | Public published cards and approved links; preview Admin |
| `list_editorial_relations` | `p_article_id,p_locale,p_preview=false` | items[] with rank and relation revision | Public parent and related cards must be published; approved links only |
| `list_editorial_articles` | exact filters/cursor in rpc_surface.json | items and cursor | Published-only; no private fallback |
| `list_editorial_review_queue` | `p_locale,p_offset=0,p_limit=20` | items, offset, limit; composition/conflicts/source map | Server Admin only |
| `get_editorial_source_snapshot` | `p_article_id,p_snapshot_id,p_revision_id=null` | bound original body/hash/capture metadata | Server Admin only; snapshot must contribute to requested revision |
| `get_editorial_link_review` | `p_article_id,p_locale` | category_links,country_links; per-link revision | Server Admin only |
| `review_editorial_relation` | parent/related UUIDs, expected_revision, decision approved|rejected, rank, request_key UUID | persisted link decision | Server Admin; exact retry receipt; changed payload or stale revision409 |
| `review_country_other_title` | country_code, article_id, expected_revision, decision, rank, request_key UUID | persisted country link decision | Same Admin/concurrency rule |
| `clear_editorial_revision` | revision UUID, documented note | cleared=true,approved=false,published=false | Admin; actual official verification + complete references + revision/hash binding required |
| `import_editorial_draft` | batch UUID, manifest SHA256, Admin actor UUID, full item, immutable sources[] | import receipt | Service only AND enabled exact staging target marker |
| `propose_editorial_relations` | p_relations array<=1000, state=proposed | integer processed count | Service + staging marker; cannot approve |
| `attach_editorial_reference_map` | article UUID, locale, expected_revision, manifest hash, map | revision_id,input_hash | Service + marker; draft only; immutable map history; no source-body mutation |
| `rollback_editorial_import` | batch UUID | detached count, preserved edited/reviewed/published count | Service + marker; no evidence/history deletion |

`ArticleCard` contains id, locale, title, summary, visa_category, category, content_class canonical|editorial, country_codes[], revision_id, revision, editorial_state, verification_state, source_publishers[]. `RichSection` contains id, heading, program and blocks[]. Blocks retain type/text/original_structure/provenance; tables retain rows/cells/header/colspan/rowspan and lists retain nesting. Provenance includes source_id,snapshot_id,url,block_index,start,end,sha256,structure_sha256. The segment ledger distinguishes preserved from exact-duplicate representations. `ReferenceLink` includes original_href,url (fragment preserved), label,source_snapshot_id,source_url,verification_state=unverified,target_block_id nullable. Zero current original anchors can safely map to destination blocks; external originals retain all 90 captured fragments.

## Errors, pagination and client state

403 denies unauthorized preview/admin/service operations. 404 means no published article or requested translation. 409 means stale expected revision or changed retry payload: refresh, show a conflict, never silently overwrite. 422 means invalid shape, unsafe/unbound reference or unmet verification/clearance. Transport/timeout failures show retry. Only PGRST202/42883 for a genuinely missing additive reader RPC permits the legacy published-only UUID reader; 403/404 never do. Missing reference RPC visibly reports capture unavailable. Revision IDs must match between body and link responses; reject races instead of mixing revisions.

Queue pagination uses offset/limit; use the exact bounded defaults and clamps recorded by SQL. Editorial listing uses its opaque cursor; do not reinterpret it as an offset. Keep `request_key` UUID stable for a retry, generate a fresh UUID only for a new decision. Public readers never switch into preview because the caller is Admin. All preview/queue/source/link state must invalidate on account/session changes. No persistent private content cache is introduced.

## Lifecycle and Plan 4 / Plan 5 boundaries

Import → mapping/dedup/source/conflict review → official fact verification → documented human clearance → explicit CMS submission/approval → separate explicit publication. Source capture, link approval and clearance each do NOT approve an article. Evidence-only/summary revisions carry rich structure and reference maps; body edits invalidate stale rich/reference projections while history remains intact. Clearance is revision/hash-bound. Research, AI and importer cannot auto-publish Visa or Feed. Public search and `retrieve_knowledge` use published-only projections; imported drafts are absent even when an Admin calls the public search. Neither embeddings nor a source capture can substitute for publication.

The source-batch importer refuses existing/human-edited/published heads. Exact full retry was rehearsed twice. Do not rerun historical migrations on Production. Reconcile the live ledger and actual schema first, then review minimal forward changes, backups and restore proof. All six content forwards are staged only; Management API ledger timestamps differ from local filenames and must be mapped, not repaired speculatively.

## Frontend handoff, fixtures and unresolved decisions

Routes: `/visa/content-countries`, `/visa/content-countries/:countryCode`, `/visa/content/:articleId?locale=fa|en`, `/visa/articles/:articleId?locale=...&requested_locale=...#section`, `/admin/cms/reconciliation`. Preview requires `preview=true` plus real server Admin authorization. Reader presents one continuous body and one Other Titles collection when approved related items exist. Empty collections are hidden. UUID search anchors use projection_map. Existing catalog/program navigation stays available.

Real staging preview: Canada Study FA `d570925f-44e1-52ec-ab91-e801dd4be6b6`, revision `0a9c0be2-7045-4723-b7ea-7389f8dede4d`, snapshot `8959a9d0-d706-5c06-a643-f0a66d8ac79c`. Public request404, ordinary A/B preview403, Admin full original body allowed. Clearly synthetic old published fixture `d54dace4-4f43-47ac-a235-3312814ec5e9`, revision `205b93a1-afec-4cf3-b15e-696dd61e243e`, is unchanged and proves no legal claim. Local regression IDs are deterministic synthetic-only fixtures inside rollback transactions. Actual credentials are external and never included in delivery.

Antigravity must review the additive reader, overlapping verification banner wording, rich table/list presentation and new Admin route. Grok must review category/program mapping, source scope and corpus reconciliation. The legacy independent-slug route now resolves through `resolve_editorial_article_slug(p_country_code,p_slug,p_locale)` into the same published-only UUID rich reader. ISO country codes or published catalog destination slugs/UUIDs are accepted; missing/draft/unpublished/missing-translation selectors return404, and ambiguous slugs return409. The retained repository adapter also uses the resolved UUID instead of an invalid v1 related tuple. This compatibility fix has rollback-only publication/unpublish/country/locale tests and a real route widget regression. Full live-site coverage, 302 historical fetch/HTTP failures, 153 incomplete/nonarticle dispositions, translation review, image reuse rights and every substantive legal claim remain human/operational gates. No real imported article is publication-ready.
