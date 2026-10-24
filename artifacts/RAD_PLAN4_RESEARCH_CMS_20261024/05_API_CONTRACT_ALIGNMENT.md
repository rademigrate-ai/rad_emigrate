# 05 — API CONTRACT ALIGNMENT

## 1. Canonical Schema Registry

All client-server communications in RAD Emigrate adhere strictly to the immutable JSON Schema specification defined in `supabase/contracts/rad_v1.json`.

During Plan 4 execution, the client-side contract compiler (`scripts/generate_dart_contracts.py`) was extended to incorporate all 20 Plan 4 request and response definitions:

```
rad_v1.json ($defs) ──► scripts/generate_dart_contracts.py ──► lib/core/supabase/rad_contract_schemas.dart ──► requireRadContract()
```

---

## 2. Plan 4 Endpoint Registry Table

| RPC Method Name | Request Contract Schema | Response Contract Schema | Primary Response Data Type |
|:---|:---|:---|:---|
| `submit_visa_article_review` | `submit_visa_article_review_request` | `submit_visa_article_review_response` | `ArticleRevisionResult` |
| `approve_visa_article_revision` | `approve_visa_article_revision_request` | `approve_visa_article_revision_response` | `ArticleRevisionResult` |
| `reject_visa_article_revision` | `reject_visa_article_revision_request` | `reject_visa_article_revision_response` | `ArticleRevisionResult` |
| `publish_visa_article_revision` | `publish_visa_article_revision_request` | `publish_visa_article_revision_response` | `PublicationResult` |
| `rollback_visa_article` | `rollback_visa_article_request` | `rollback_visa_article_response` | `ArticleRevisionResult` |
| `list_visa_article_revisions` | `list_visa_article_revisions_request` | `list_visa_article_revisions_response` | `{ items: RevisionSummary[] }` |
| `list_official_authorities` | `list_official_authorities_request` | `list_official_authorities_response` | `{ items: Authority[] }` |
| `discover_official_authorities` | `discover_official_authorities_request` | `discover_official_authorities_response` | `JobResult` |
| `enqueue_research_refresh` | `enqueue_research_refresh_request` | `enqueue_research_refresh_response` | `JobResult` |
| `approve_visa_source_inventory`| `approve_visa_source_inventory_request`| `approve_visa_source_inventory_response`| `{ inventory_revision, inventory_hash, source_snapshot_ids }` |
| `list_research_proposals` | `list_research_proposals_request` | `list_research_proposals_response` | `{ items: ResearchProposal[] }` |
| `get_research_proposal` | `get_research_proposal_request` | `get_research_proposal_response` | `ResearchProposal` |
| `review_research_proposal` | `review_research_proposal_request` | `review_research_proposal_response` | `{ proposal, draft_revision }` |
| `save_visa_article_draft` | `save_visa_article_draft_request` | `save_visa_article_draft_response` | `ArticleRevisionResult` |
| `get_cms_article_draft` | `get_cms_article_draft_request` | `get_cms_article_draft_response` | `{ content, revision, revision_id }` |

---

## 3. Strict Fail-Closed Validation

In `SupabaseAdminCmsRepository._rpc`:
1. Before transmitting any RPC to Supabase, `requireRadContract('${name}_request', request)` validates field types, required keys, min/max lengths, UUID formats, and regex patterns.
2. Upon receiving the payload, `requireRadContract(responseSchema, response)` validates the response structure.
3. If any field violates the contract (e.g., unexpected enum value, null in non-nullable field, malformed timestamp), a `FormatException` is thrown immediately.
4. The repository translates `FormatException` to `CmsException('malformed')`, rejecting the payload and preventing corrupted state from entering the client application.
