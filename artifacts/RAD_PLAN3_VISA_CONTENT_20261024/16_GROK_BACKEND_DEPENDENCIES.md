# Grok backend dependencies — no migration or PR #78 edits

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
