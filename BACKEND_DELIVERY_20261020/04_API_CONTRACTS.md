# Shared API and data contracts — backend integration candidate

Authoritative closed request/response schemas: `../supabase/contracts/rad_v1.json`, with 62 real SQL-generated synthetic request/response fixtures in `../supabase/contracts/fixtures/rad_v1_synthetic.json`. Exact runtime SQL signatures and grants: `evidence/sql_api_signatures.json`. Fixtures contain no real immigration facts or user data. Contract review by Antigravity and final project-owner approval are pending; this chat and the committed branch are the coordination channel.

Every client SQL RPC is POST `/rest/v1/rpc/<name>` with body `{"p_request": <request schema>}`. SQL success is `{data, meta}`, plus `page` for lists. All list payloads use `data.items`; notifications also include unread_count, search includes index_version/query_normalized/evidence_state, and FX history includes provider/missing_dates. Required nullable fields must be sent explicitly. UUID identities and stable section UUIDs are distinct from human-readable anchors. Dates are ISO strings, timestamps UTC, and rates/amounts/scores are decimal strings. Identity conversion has `observation: null` and `conversion_kind: identity`, not a fake fetched quote. IRT is rejected; toman is an IRR display/unit conversion with scale 10.

Mutation request_key is an actor/operation-bound UUID. Identical retries reuse the stored result; changed bodies return PT409. expected_revision/content_hash enforce CAS and exact-review identity. Tokens are opaque, actor/filter/version bound, expire after fifteen minutes, and must be restarted after PT409 cursor_expired. Limits are 1–50 and ordering is deterministic. Publication and alias changes invalidate search cursors.

SQL errors retain PostgREST's code/message/details/hint shape: PT401 authentication, PT403 authorization, PT404 hidden/missing resource, PT409 revision/idempotency/cursor conflict, PT422 invalid input, PT429 abuse control, PT503 unavailable. Existing legacy SQLSTATEs (42501, 22023, 40001, P0001/P0002) remain in the older consultation APIs; adapt by code rather than assuming one HTTP status for every legacy error. Edge errors are flat error/code/request_id where present; do not assume the old proposed nested error envelope.

| Operation | Transport / authorization | Required request properties | Response schema ($defs) | Pagination |
|---|---|---|---|---|
| `get_backend_contract_status` | RPC / public | none | `get_backend_contract_status_response` | none |
| `get_rad_job_status` | RPC / creator_or_admin | `job_id` | `get_rad_job_status_response` | none |
| `get_visa_article` | RPC / public | `selector`, `locale` | `get_visa_article_response` | none |
| `list_related_visa_articles` | RPC / public | `article_id`, `locale`, `cursor`, `limit` | `list_related_visa_articles_response` | cursor |
| `save_visa_article_draft` | RPC / admin | `article_id`, `locale`, `expected_revision`, `title`, `summary`, `sections`, `related_article_ids`, `merge_manifest_id`, `request_key` | `save_visa_article_draft_response` | none |
| `submit_visa_article_review` | RPC / human_admin | `article_id`, `revision_id`, `expected_revision`, `content_hash`, `note`, `request_key` | `submit_visa_article_review_response` | none |
| `approve_visa_article_revision` | RPC / human_admin | `article_id`, `revision_id`, `expected_revision`, `content_hash`, `note`, `request_key` | `approve_visa_article_revision_response` | none |
| `reject_visa_article_revision` | RPC / human_admin | `article_id`, `revision_id`, `expected_revision`, `content_hash`, `note`, `request_key` | `reject_visa_article_revision_response` | none |
| `publish_visa_article_revision` | RPC / human_admin | `article_id`, `revision_id`, `content_hash`, `request_key` | `publish_visa_article_revision_response` | none |
| `rollback_visa_article` | RPC / admin | `article_id`, `locale`, `from_revision_id`, `expected_revision`, `reason`, `request_key` | `rollback_visa_article_response` | none |
| `list_visa_article_revisions` | RPC / admin | `article_id`, `locale`, `cursor`, `limit` | `list_visa_article_revisions_response` | cursor |
| `discover_official_authorities` | RPC / admin | `country_code`, `topic`, `profession`, `request_key` | `discover_official_authorities_response` | none |
| `list_official_authorities` | RPC / admin | `country_code`, `topic`, `state`, `cursor`, `limit` | `list_official_authorities_response` | cursor |
| `enqueue_research_refresh` | RPC / admin | `authority_ids`, `request_key` | `enqueue_research_refresh_response` | none |
| `list_research_proposals` | RPC / admin | `editorial_state`, `verification_state`, `article_id`, `cursor`, `limit` | `list_research_proposals_response` | cursor |
| `get_research_proposal` | RPC / admin | `proposal_id` | `get_research_proposal_response` | none |
| `review_research_proposal` | RPC / human_admin | `proposal_id`, `expected_revision`, `decision`, `note`, `request_key` | `review_research_proposal_response` | none |
| `official-source-worker` | Edge / worker | `job_id`, `lease_token` | `official_source_worker_response` | none |
| `get_fx_quote` | RPC / public | `base`, `quote`, `rate_basis`, `allow_stale` | `get_fx_quote_response` | none |
| `convert_currency` | RPC / public | `base`, `quote`, `amount`, `input_unit`, `output_unit`, `decimal_places`, `allow_stale` | `convert_currency_response` | none |
| `get_fx_history` | RPC / public | `base`, `quote`, `date_from`, `date_to`, `cursor`, `limit` | `get_fx_history_response` | cursor |
| `create_currency_alert` | RPC / owner | `base`, `quote`, `direction`, `threshold`, `cooldown_seconds`, `request_key` | `create_currency_alert_response` | none |
| `update_currency_alert` | RPC / owner | `alert_id`, `expected_revision`, `enabled`, `threshold`, `cooldown_seconds`, `request_key` | `update_currency_alert_response` | none |
| `delete_currency_alert` | RPC / owner | `alert_id`, `expected_revision`, `request_key` | `delete_currency_alert_response` | none |
| `list_currency_alerts` | RPC / owner | `cursor`, `limit` | `list_currency_alerts_response` | cursor |
| `currency-refresh` | Edge / worker | `pairs` | `currency_refresh_response` | none |
| `list_feed` | RPC / public_or_owner | `locale`, `category`, `saved_only`, `cursor`, `limit` | `list_feed_response` | cursor |
| `get_feed_item` | RPC / public_or_owner | `item_id`, `locale` | `get_feed_item_response` | none |
| `save_feed_draft` | RPC / admin | `item_id`, `expected_revision`, `locale`, `title`, `summary`, `body`, `category`, `article_id`, `expires_at`, `request_key` | `save_feed_draft_response` | none |
| `review_feed_draft` | RPC / human_admin | `revision_id`, `expected_revision`, `decision`, `content_hash`, `note`, `request_key` | `review_feed_draft_response` | none |
| `publish_feed_revision` | RPC / human_admin | `revision_id`, `content_hash`, `request_key` | `publish_feed_revision_response` | none |
| `set_feed_saved` | RPC / owner | `item_id`, `saved`, `request_key` | `set_feed_saved_response` | none |
| `mark_feed_read` | RPC / owner | `item_id`, `request_key` | `mark_feed_read_response` | none |
| `list_notifications` | RPC / owner | `unread_only`, `type`, `cursor`, `limit` | `list_notifications_response` | cursor |
| `mark_notification_read` | RPC / owner | `notification_id`, `request_key` | `mark_notification_read_response` | none |
| `mark_all_notifications_read` | RPC / owner | `before`, `request_key` | `mark_all_notifications_read_response` | none |
| `get_notification_preferences` | RPC / owner | none | `get_notification_preferences_response` | none |
| `save_notification_preferences` | RPC / owner | `expected_revision`, `preferences`, `request_key` | `save_notification_preferences_response` | none |
| `notification-dispatch` | Edge / worker | none | `notification_dispatch_response` | none |
| `search_visa_articles` | RPC / public | `query`, `locale`, `country_codes`, `pathway_slugs`, `article_kind`, `allow_locale_fallback`, `cursor`, `limit` | `search_visa_articles_response` | cursor |
| `ai-orchestrator` | Edge / public_or_owner | `action`, `request_key`, `session_id`, `guest_key`, `locale`, `messages`, `context`, `authorized_data_scopes`, `scope` | `ai_orchestrator_response` | none |
| `create_visa_article` | RPC / admin | `article_id`, `kind`, `country_code`, `pathway_slug`, `slug`, `request_key` | `create_visa_article_response` | none |
| `get_visa_merge_manifest` | RPC / admin | `manifest_id` | `get_visa_merge_manifest_response` | none |
| `visa-content-ingest` | Edge / worker | `article_id`, `source_snapshot_ids`, `expected_revision`, `request_key` | `visa_content_ingest_response` | none |
| `create_feed_comment` | RPC / authenticated | `feed_id`, `parent_id`, `body`, `request_key` | `create_feed_comment_response` | none |
| `delete_feed_comment` | RPC / authenticated | `comment_id`, `expected_revision`, `request_key` | `delete_feed_comment_response` | none |
| `moderate_feed_comment` | RPC / human_admin | `comment_id`, `expected_revision`, `state`, `note`, `request_key` | `moderate_feed_comment_response` | none |
| `list_feed_comments` | RPC / public | `feed_id`, `cursor`, `limit` | `list_feed_comments_response` | cursor |
| `get_visa_reading_state` | RPC / authenticated | `article_id`, `locale` | `get_visa_reading_state_response` | none |
| `save_visa_reading_state` | RPC / authenticated | `article_id`, `locale`, `section_id`, `saved`, `expected_revision`, `request_key` | `save_visa_reading_state_response` | none |
| `approve_visa_source_inventory` | RPC / human_admin | `article_id`, `source_snapshot_ids`, `expected_inventory_revision`, `request_key` | `approve_visa_source_inventory_response` | none |
| `save_visa_search_alias` | RPC / human_admin | `locale`, `alias`, `canonical`, `enabled`, `expected_revision`, `request_key` | `save_visa_search_alias_response` | none |

Full field types, enums, bounds, nullable alternatives, nested data models and request examples are in the machine registry/fixtures. Key shared models: VisaArticle, ArticleSection/Input, ContentBlock, EvidenceRef, MergeManifest, ResearchProposal/SectionChange, Authority, FxObservation, ConversionResult, CurrencyAlert, FeedItem, FeedComment, NotificationPreferences, Notification, NavigationTarget, SearchHit, VisaReadingState and CopilotResult.

Internal service RPCs use their explicit named arguments below, not p_request unless the signature says so. reserve_rad_ai_request binds user/session ownership and reserves 1–8192 output tokens; same key returns a running/terminal replay, and denied responses have allowed=false. settle_rad_ai_request returns true exactly once, then false; consumption must be within the reservation. expire_rad_ai_reservations releases running state with a conservative token charge and purges cached replies after 24 hours. Maintenance scheduling is not activated here. retrieve_verified_official_claims returns results/evidence_state, requires service role, and checks current published usage and live proof eligibility. get_research_article_base requires a live research-refresh lease and an authority country scope matching the target article; it returns current sections and server-generated before_hash values. Workers reuse these hashes in SectionChange and must not reproduce PostgreSQL JSON canonicalization in JavaScript or a model. No service RPC is a human publication endpoint.

Protected workers are synchronous in the existing code: currency-refresh accepts pairs and returns per-pair cached/unavailable results; visa-content-ingest returns a draft/manifest envelope; official-source-worker reports candidates/verified=0/status; notification-dispatch returns sandbox counters. These supersede the earlier proposed JobResult shapes. Jobs created by admin research RPCs still use get_rad_job_status. Purpose-token and deployment JWT boundaries stay server-only; workers remain disabled.

## Exact verified SQL signatures

- `public.approve_visa_article_revision(p_request jsonb) → jsonb`
- `public.approve_visa_source_inventory(p_request jsonb) → jsonb`
- `public.assign_admin_consultation(p_consultation_id uuid, p_assignee_id uuid, p_expected_revision integer) → jsonb`
- `public.claim_official_research_job() → jsonb`
- `public.consume_ai_daily_quota(p_user_id uuid, p_role text) → jsonb`
- `public.convert_currency(p_request jsonb) → jsonb`
- `public.create_currency_alert(p_request jsonb) → jsonb`
- `public.create_feed_comment(p_request jsonb) → jsonb`
- `public.create_visa_article(p_request jsonb) → jsonb`
- `public.delete_currency_alert(p_request jsonb) → jsonb`
- `public.delete_feed_comment(p_request jsonb) → jsonb`
- `public.discover_official_authorities(p_request jsonb) → jsonb`
- `public.enqueue_research_refresh(p_request jsonb) → jsonb`
- `public.expire_rad_ai_reservations() → integer`
- `public.finish_official_research_job(p_job_id uuid, p_lease_token uuid, p_candidates jsonb, p_safe_code text DEFAULT NULL::text) → boolean`
- `public.get_backend_contract_status(p_request jsonb) → jsonb`
- `public.get_feed_item(p_request jsonb) → jsonb`
- `public.get_fx_history(p_request jsonb) → jsonb`
- `public.get_fx_quote(p_request jsonb) → jsonb`
- `public.get_notification_preferences(p_request jsonb) → jsonb`
- `public.get_official_research_job(p_job_id uuid, p_lease_token uuid) → jsonb`
- `public.get_rad_job_status(p_request jsonb) → jsonb`
- `public.get_research_article_base(p_job_id uuid, p_lease_token uuid, p_article_id uuid, p_locale text) → jsonb`
- `public.get_research_proposal(p_request jsonb) → jsonb`
- `public.get_visa_article(p_request jsonb) → jsonb`
- `public.get_visa_merge_manifest(p_request jsonb) → jsonb`
- `public.get_visa_reading_state(p_request jsonb) → jsonb`
- `public.ingest_visa_snapshots(p_request jsonb) → jsonb`
- `public.list_admin_consultations() → SETOF consultation_requests`
- `public.list_currency_alerts(p_request jsonb) → jsonb`
- `public.list_feed(p_request jsonb) → jsonb`
- `public.list_feed_comments(p_request jsonb) → jsonb`
- `public.list_notifications(p_request jsonb) → jsonb`
- `public.list_official_authorities(p_request jsonb) → jsonb`
- `public.list_related_visa_articles(p_request jsonb) → jsonb`
- `public.list_research_proposals(p_request jsonb) → jsonb`
- `public.list_visa_article_revisions(p_request jsonb) → jsonb`
- `public.mark_all_notifications_read(p_request jsonb) → jsonb`
- `public.mark_feed_read(p_request jsonb) → jsonb`
- `public.mark_notification_read(p_request jsonb) → jsonb`
- `public.moderate_feed_comment(p_request jsonb) → jsonb`
- `public.publish_feed_revision(p_request jsonb) → jsonb`
- `public.publish_visa_article_revision(p_request jsonb) → jsonb`
- `public.record_fx_observation(p_observation jsonb) → uuid`
- `public.record_official_source_change(p_job_id uuid, p_lease_token uuid, p_article_id uuid, p_locale text, p_old_snapshot_id uuid, p_new_snapshot_id uuid, p_new_sections jsonb, p_changes jsonb) → jsonb`
- `public.reject_visa_article_revision(p_request jsonb) → jsonb`
- `public.reserve_rad_ai_request(p_user_id uuid, p_request_key uuid, p_body_hash text, p_reserved_output_tokens integer, p_session_id uuid DEFAULT NULL::uuid) → jsonb`
- `public.retrieve_verified_official_claims(p_query text, p_locale text, p_country_code text DEFAULT NULL::text, p_topic text DEFAULT NULL::text) → jsonb`
- `public.review_feed_draft(p_request jsonb) → jsonb`
- `public.review_research_proposal(p_request jsonb) → jsonb`
- `public.rollback_visa_article(p_request jsonb) → jsonb`
- `public.save_feed_draft(p_request jsonb) → jsonb`
- `public.save_notification_preferences(p_request jsonb) → jsonb`
- `public.save_visa_article_draft(p_request jsonb) → jsonb`
- `public.save_visa_reading_state(p_request jsonb) → jsonb`
- `public.save_visa_search_alias(p_request jsonb) → jsonb`
- `public.search_visa_articles(p_request jsonb) → jsonb`
- `public.set_feed_saved(p_request jsonb) → jsonb`
- `public.settle_rad_ai_request(p_request_id uuid, p_http_status integer, p_response jsonb, p_output_tokens integer) → boolean`
- `public.submit_consultation_request(p_topic text, p_message text, p_related_application_id uuid DEFAULT NULL::uuid) → uuid`
- `public.submit_visa_article_review(p_request jsonb) → jsonb`
- `public.transition_admin_consultation(p_consultation_id uuid, p_status text, p_expected_revision integer, p_admin_note text DEFAULT NULL::text) → jsonb`
- `public.update_admin_consultation(p_consultation_id uuid, p_status text, p_admin_note text DEFAULT NULL::text) → void`
- `public.update_currency_alert(p_request jsonb) → jsonb`
- `public.verify_official_claim(p_claim_id uuid) → jsonb`

## Proposed new-feature contracts — NOT IMPLEMENTED, approval required

- Existing confirmed booking foundation is submit_consultation_request(topic,message,related_application_id?) → UUID. It is an owned intake request, with three/hour and ten/day limits; it does not promise a booked appointment. Owner reads exclude admin_note/assignment internals; admins use the explicit RPCs.
- Proposed create_appointment_request: owned request_key, service_reference, preferred UTC windows and IANA timezone; response request_id/state=requested/revision. Availability, confirmation, rescheduling, cancellation and interview/provider ownership must be approved before implementation.
- Proposed estimate_immigration_costs: approved scenario/input schema, decimal line items with currency, provenance, as_of/validity, declared assumptions and missing_inputs; no invented totals when required evidence is absent. Tax/fee scope and FX policy require approval.
- Proposed compare_visa_pathways: bounded published article IDs and approved comparison fields; values retain source/revision/missing state. Existing get_visa_article is reusable now. Eligibility/ranking/recommendation semantics require approval.
- Proposed compare_universities: approved university IDs/dataset version/fields, with citations, effective dates and missing states. Dataset provenance/licensing, partnerships and ranking rules are unapproved; no endpoint or fabricated dataset was added.
