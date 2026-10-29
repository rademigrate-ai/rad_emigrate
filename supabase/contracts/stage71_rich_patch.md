# Stage 7.1 lossless patches

Rich source blocks remain immutable source evidence. An edited block retains its original_structure, source text and provenance, and adds current_structure/current_text plus editorial_evidence. Readers prefer current_structure; unchanged blocks and sections are structurally identical. Removed blocks remain recoverable through the immutable parent revision. Source references remain accessible, including references whose former in-page target was explicitly removed.

Each proposal binds an article locale, exact base revision/content hash and rich hash. Patches target stable section/block UUIDs and a server-issued block hash. Operations: replace_text at an existing text/caption leaf, add_after with a new paragraph UUID, or remove an explicitly reviewed block. Tables, nested lists, headings, links, block identity, source coverage and unrelated content are never round-tripped through Markdown/HTML/plain text. Closed-v1 text is only a derived search projection.

Admin-only APIs: get_structured_article_context, propose_structured_research, get_research_review_context_v2, save_structured_research_review. Review uses the Stage7 request envelope and patch IDs as decision section_id values. save_review persists incomplete review; create_draft requires all explicit decisions; reject_proposal requires a note. Changed bodies create a new unverified draft, never approval/publication. Exact actor-scoped UUID retries are stable; stale head, baseline hashes, proposal version or review version conflict. A legacy review call cannot accept a structured proposal.

The Stage7 and Stage7.1 migrations remain held for separate explicit review and authorization. No hosted deployment is authorized by this document.
