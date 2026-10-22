# Visa Smart Search — Backend Contract Notes

**Status:** Contract for Phase 6 implementation  
**Sources indexed (published only):**

- Canonical main articles (`article_role = main`, editorial approved)
- Independent related articles (`article_role = related`, editorial approved)
- Section headings and bodies
- Country / pathway metadata (`canonical_key`, destinations, programs)

## Requirements

- Persian/English normalization
- Synonyms and aliases layer
- Typo-tolerant fallback
- Relevant snippets with stable section deep links
- Pagination and filters (country, pathway, language)
- **Never** expose drafts, unapproved, or research_proposals content through public search

## Privacy / security

- Public search RPCs: anon/authenticated read of approved content only
- Admin search may include draft state under role checks
- No leakage of factual_status `unverified` regulatory claims as confirmed facts in snippets