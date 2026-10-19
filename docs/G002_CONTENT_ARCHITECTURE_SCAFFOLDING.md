# G-002 Content Architecture Scaffolding

**Migration:** `20261019210000_g002_content_architecture_scaffolding.sql`  
**Branch:** `feature/g002-c002-implementation-20261019`  
**Status:** Authored on branch; **not applied** to production or staging by default.

## What it adds

| Object | Change |
|--------|--------|
| `knowledge_items.article_role` | `main` \| `related` |
| `knowledge_items.canonical_key` | `country_iso:pathway` for mains; unique partial index |
| `knowledge_claims.factual_status` | six values; default `unverified` |
| `knowledge_claims.human_review_required` | default true |
| `source_documents.validation_status` | candidate \| validated \| rejected \| inaccessible |
| `source_documents.authority_category` | expanded taxonomy |
| `source_documents.verified_domain` | after domain validation |
| `source_snapshots` date/confidence fields | publication_date, effective_date, confidence_notes |
| `research_proposals` | admin-only RLS; never auto-publishes |

## CMS import package

Use offline package:
`/home/workdir/artifacts/RAD_CONTENT_CMS_INTEGRATION_20261019/`

All records in that package are **draft / unverified / candidate**. Import must not set `review_status=approved` or `factual_status=verified`.

## Apply order (authorized environments only)

1. Disposable DB rehearsal  
2. Staging after security sign-off  
3. Production only after explicit owner authorization + backup/PITR readiness  

Never apply as part of an unattended merge to main without owner approval.
