# Duplicate and conflict review

Exact-body duplicate groups: 85. Near/topic/update candidates: 216; numeric/date-difference candidates: 211.

Only identical full extracted bodies with the same country association, pathway and language are automatically grouped. Country equality alone is never a merge rule. Persian diacritic/search normalization is not an exact-body equivalence rule. The preferred source order is RadVisa, DigiVisa, Radmohajer, then URL; source IDs, original titles, URLs, body hashes and timestamps remain in source records. No paragraphs from different source bodies are interleaved to manufacture completeness.

Near matches use title similarity and full-body token overlap. Different numbers/dates are a **potential** conflict, not a verified contradiction: different years, professions, visa subclasses, tax bases or policy scopes may explain them. Such groups remain distinct; no silent authoritative choice is made. Full pair records and differing numeric tokens: `data/duplicate_relationships.json`. Every group has review status not_reviewed and no publication permission.

Canonical IDs are deterministic UUIDv5 identifiers and an identity registry retains assignments on subsequent builds. A newly discovered exact duplicate must not rename an existing canonical group. Two previously distinct canonical IDs are not silently merged. Language variants stay separate; no machine-generated English or missing text is supplied. Updated body versions require human CMS revision handling, not overwrite of an existing initial draft.
