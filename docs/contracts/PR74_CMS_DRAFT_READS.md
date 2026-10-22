# PR #74 CMS and locale contract handoff

Frontend owner: Antigravity. Backend/integration owner: Codex. Review channel: the current RAD ChatGPT project conversation. No direct agent messaging channel is verified. This document is ready for Antigravity and project-owner review; their approval is **not claimed**.

The normative schemas are in `supabase/contracts/rad_v1.json`. This change introduces two necessary **read-only admin RPCs**, because the existing CMS called a nonexistent list RPC and the canonical revision tables intentionally deny client reads. It does not grant direct table access. The migration `20261021210337_rad_cms_admin_draft_reads.sql` is proposed and disposable-tested only; it has not been applied to hosted Supabase.

## Transport, access, and errors

Both operations use `POST /rest/v1/rpc/<name>` with `{ "p_request": <request> }`. Require a valid authenticated human JWT and the current database profile role `admin` or `super_admin`. `anon`, `PUBLIC`, and `service_role` have no EXECUTE grant. `authenticated` EXECUTE still runs `private.rad_require_admin()` before reading anything. Fixed empty search paths and existing RLS/table ACLs remain intact.

Responses use `{data, meta}` and paged responses also have `page`. `meta` requires `request_id` (UUID), `contract_version: "1"`, `server_time` (UTC timestamp), `requested_locale`, `resolved_locale`, and `fallback_used` (boolean). Locales are `fa` or `en`; these admin reads perform no implicit fallback.

Handle authentication/authorization denial, not found (`PT404`), cursor/revision conflict (`PT409`), invalid request (`PT422`), missing RPC, timeout, transport failure, and malformed response separately from successful empty data. SQL state authorization errors are mapped by PostgREST; do not assume a successful HTTP response is a valid acknowledgment. CMS retains unsaved title/summary on failed saves. It clears private state when SDK identity changes and drops late responses from the prior account.

## `list_cms_articles`

Request:

```json
{"locale":"fa","cursor":null,"limit":50}
```

`limit` is 1–50. `cursor` is null or the opaque `page.next_cursor`; it is bound to the request and current locale's head version. A changed head invalidates an old cursor. `page` is `{next_cursor: string|null, has_more: boolean}`. The client checks pagination consistency and rejects a repeated immediate cursor.

`data.items` contains at most 50 objects with all of:

| Field | Type / meaning |
|---|---|
| `id`, `slug`, `country_code` | Article UUID, slug, two-letter country code |
| `kind`, `locale` | `main` or `related`; exact `fa` or `en` |
| `title`, `revision` | Real head title and positive revision |
| `editorial_state`, `verification_state` | Existing independent lifecycle and evidence enums |
| `updated_at` | Head revision's stored creation timestamp; never a synthesized fact-check date |

The current Flutter repository loads both locales, following each cursor. List entries preserve locale in `/admin/cms/canonical/:id?locale=en`. Empty responses remain empty; there are no runtime article or proposal fixtures.

## `get_cms_article_draft`

Request:

```json
{"article_id":"<article UUID>","locale":"en"}
```

`data` requires `revision_id`, `revision`, `editorial_state`, `verification_state`, `updated_at`, and `content`. `content` contains exactly the existing draft-save input fields **except `request_key`**:

```text
article_id: UUID
locale: fa | en
expected_revision: current head revision
title: string (1..300)
summary: string (0..1500)
sections: ArticleSectionInput[]
related_article_ids: UUID[]
merge_manifest_id: UUID | null
```

`ArticleSectionInput` retains `id`, `anchor`, `heading`, `order`, `blocks`, and **`evidence_refs`**. Evidence inputs retain snapshot UUID, nullable claim UUID, excerpt, and locator. The server returns the exact stored head body with its current revision; it does not rebuild drafts from a lossy public display DTO. Flutter validates returned article identity, locale, revision, metadata, and the complete nested contract before editing.

## Existing write operations remain separate

`save_visa_article_draft` keeps its approved request/response contract. Flutter changes title/summary only, preserves sections/evidence/related IDs/merge manifest, sends the loaded revision and locale, and uses a UUID v4 request key. An unchanged uncertain retry reuses the same key; a user edit creates a new key. Success requires the expected article UUID, next revision, `draft` state, locale, and a complete `ArticleRevisionResult` acknowledgment. Saving does not submit, approve, fact-verify, or publish.

`list_research_proposals` now sends the required filter/cursor/limit request and consumes `data.items`. `get_research_proposal` loads the selected proposal. Review sends the **displayed proposal revision**, decision `accept|reject`, note, and a UUID key. Its response must acknowledge the same proposal, next proposal revision, resulting decision, and (for acceptance) a draft for the proposal's target article. Acceptance creates a draft; it does not publish or assert official factual verification. The unsupported client factual-status dropdown has been removed.

Human review, factual evidence validation, and `publish_visa_article_revision` remain separate backend-authorized operations. This editor exposes draft saving only. No AI/research worker receives a publishing capability.

## Search/article locale handoff

Search takes an explicit UI locale. Every canonical hit retains `requestedLocale` and backend `match_locale` as `resolvedLocale`. UUID routes carry `locale`, `requested_locale`, the existing section UUID, and section anchor. The article provider key contains article UUID and **both locales**; `get_visa_article` receives the resolved locale. Thus a Persian search result with English-only published content opens its English revision. Legacy country/pathway and independent-article provider keys also include locale.

AI remains text-only contract v1. All required response fields, nested citations/actions/tool results/quota, and metadata are validated against a generated subset of the registry. Missing flags or evidence state are a transport error, never evidence of certainty. Browser preflight now permits all three actual RAD client headers. The hosted legacy Edge version remains an operational rollout dependency.
