# Knowledge Production Evidence (Stage 2)

Production project: `inshddthftkhcdosoqcn`

## Pre-Stage 2

- knowledge_items / claims / citations / conflicts / versions = 0
- source_documents = 3 (radvisa.com, digivisa.ir, radmohajer.ir/fa)
- source_snapshots ≥ 8
- research_findings = 8 (review status)
- feed_items = 0

## Seed corpus (representative, evidence-backed)

Created only from existing snapshots via `promote_knowledge_from_evidence`:

1. **rad-contact-tehran-fa** — FA contact number from radmohajer.ir snapshot
2. **rad-services-overview-fa** — FA service-topic overview as published on site (not legal guarantees)
3. **digivisa-brand-fa** — DigiVisa brand identity from digivisa.ir snapshot
4. **rad-contact-tehran-en** — EN contact claim citing FA or EN snapshot

No immigration eligibility, fees, processing times, or success rates were invented.

## Invariants verified

- Promote does not insert feed_items
- Approved claims require citations
- Repeated promote is idempotent on claim_key
