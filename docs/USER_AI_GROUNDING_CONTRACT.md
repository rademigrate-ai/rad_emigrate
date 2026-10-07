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
