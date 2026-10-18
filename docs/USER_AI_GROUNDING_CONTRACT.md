# User AI Grounding Contract

## Trusted path

`approved Knowledge` → `retrieve_knowledge` → `loadGrounding` → model context as **UNTRUSTED_RETRIEVED_CONTENT**

## Never trusted as factual Knowledge

- Stage 3 inventory rows
- REVIEW_REQUIRED / pending claims
- raw research findings
- content drafts
- unreviewed snapshots

## Labels in context

- `[APPROVED]` / `[APPROVED CLAIM]`
- `[CONFLICT — do not resolve unilaterally]`
- `[OPEN CONFLICT]`

## No-knowledge

If no approved evidence: instruct model not to invent immigration specifics; `uncertain: true` on response.

## Retrieval failure and approval boundaries

- Empty, malformed or unavailable `retrieve_knowledge` results stay insufficient. Never substitute an unfiltered list of recent Knowledge items for a query match.
- Parent items require explicit `review_status = approved`. Claims require explicit approval and `is_current = true`; missing flags are not approvals.
- Current conflicting claims and open conflicts remain labelled as disagreements and force `uncertain: true`, even when other approved citations exist. Conflicting claims do not count as approved claims or supply approved citations.
- Retrieved text has XML delimiters escaped before inclusion inside `UNTRUSTED_RETRIEVED_CONTENT`. This preserves the structural boundary; it does not prove resistance to semantic prompt injection.
- A true `has_approved_evidence` flag reports repository review metadata, not independently verified factual correctness or source freshness. Human editorial review and real-provider evaluation remain required.
