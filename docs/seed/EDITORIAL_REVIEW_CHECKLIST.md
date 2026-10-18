# Editorial review checklist — evidence & visa seed v1

**Package date:** 2026-10-18  
**Registry:** `docs/seed/evidence_registry_v1.json`  
**Visa init:** `docs/seed/visa_initialization_package_v1.json`  
**University seed:** `docs/seed/university_scholarship_seed_v1.json` (empty by design)

## Before any staging/production content write

- [ ] Every `EvidenceRecord` source URL opens and matches the stated topic
- [ ] Retrieval dates are accurate
- [ ] No invented fees, processing times, CRS points, or success rates
- [ ] `reviewStatus` promoted only by named reviewer (`approvedDescriptive` vs `approvedForEligibilityRules`)
- [ ] Eligibility rules (if any) live in a separate `CuratedRulePackage` with `editorialApproved: true`
- [ ] `CuratedRulesGate.loadApproved` verified fail-closed for unapproved packages
- [ ] Staging import via Codex-owned process; not raw production SQL from seed files
- [ ] RLS and `published` flags verified in staging
- [ ] Rollback plan: unpublish + registry version retained

## Explicit non-goals of v1 seed

- Auto-publishing to production
- Auto-generating eligibility rules from IRCC prose
- University tuition/scholarship amounts
- Non-Canada destinations (expand with official sources only)
