# Knowledge Production Evidence (Stage 2)

Production project: `inshddthftkhcdosoqcn`

## Pre-Stage 2

- knowledge_items / claims / citations = 0
- source_documents = 3 (radvisa.com, digivisa.ir, radmohajer.ir/fa)
- source_snapshots ≥ 8
- research_findings = 8
- feed_items = 0

## Post-Stage 2 representative corpus

Created via `promote_knowledge_from_evidence` against existing snapshots (not fabricated immigration law):

1. `rad-contact-tehran-fa` — FA contact from radmohajer.ir
2. `rad-services-overview-fa` — FA service-topic overview as published (not legal guarantees)
3. `digivisa-brand-fa` — DigiVisa brand identity from digivisa.ir
4. `rad-contact-tehran-en` — EN contact claim with RAD snapshot citation

## Repository ↔ production

Canonical schema/RPC definitions live in `supabase/migrations/20261007180000_stage2_knowledge_completion.sql`. Production objects were created via three apply_migration steps with the same SQL content. Clean replay of the repository migration on a pre-Stage-2 database yields the same Stage 2 Knowledge capability (empty tables until seed/promote).

## Invariants

- Promote does not insert feed_items
- Approved claims require citations
- Repeated promote is idempotent on claim_key
- Migration does not rewrite historical ledger entries
