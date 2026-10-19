# G-002 / C-002 Content Architecture Scaffolding

**Migration:** `supabase/migrations/20261019210000_g002_content_architecture_scaffolding.sql`  
**Branch:** `feature/g002-c002-implementation-20261019`  
**Baseline HEAD at branch creation:** `95e1fda`

## What this adds

| Object | Change |
|--------|--------|
| `knowledge_items.article_role` | `main` \| `related` (default related) |
| `knowledge_items.canonical_key` | `country_iso:pathway` for main articles |
| Unique index | one main article per canonical_key |
| `knowledge_claims.factual_status` | six G-002 statuses (default unverified) |
| `knowledge_claims.human_review_required` | boolean (default true) |
| `source_documents.validation_status` | candidate/validated/rejected/inaccessible |
| `source_documents.authority_category` | finer categories incl. credential_evaluator |
| `source_snapshots` dates | publication_date, effective_date, confidence_notes |
| `research_proposals` | admin-only queue; never auto-publishes |

## What this does NOT do

- Does not populate any visa content or official evidence.
- Does not change Feed publication (`publish_content_draft` remains exclusive).
- Does not alter existing `review_status` editorial workflow.
- Does not apply itself to production.
- Does not invent immigration facts.

## Enforcement still required at RPC layer

Promotion to factual `verified` must check that linked snapshot authority has `validation_status = validated`. That gate is documented for follow-on RPC work and is not fully encoded as a DB trigger in this migration to avoid blocking existing admin flows during rollout.

## Test plan (isolated)

1. Apply on disposable local/staging DB only.
2. Confirm additive columns exist with defaults.
3. Confirm unique index rejects second main row for same canonical_key.
4. Confirm research_proposals RLS: non-admin cannot select/insert.
5. Confirm existing promote/retrieve paths still function with defaults.