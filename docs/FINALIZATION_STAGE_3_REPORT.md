# Finalization Stage 3 Report — RAD Content Migration

## Result

**COMPLETE with external host reachability limitation** for digivisa.ir and radvisa.com from the Stage 3 runner network. radmohajer.ir fully discovered (740 URLs). Safe first-party contact/organization claims promoted. Regulatory immigration pages inventoried and classified as `requires_verification` — **not** blindly promoted.

## Starting baseline

- Branch base: `feature/stage2-knowledge-completion`
- SHA: `235475e2dcf4837ced16e9d1e21b56c4fa088abc`
- Stage 2 **not** merged to `main` at Stage 3 start
- Stage 3 branch: `feature/stage3-rad-content-migration`

## Site discovery

### radmohajer.ir
- Sitemap: `https://radmohajer.ir/sitemap.xml` (HTTP 200)
- Discovered URLs: **740** (normalized unique)
- Languages: FA 733, EN 7
- Sample fetched: home FA/EN, contacts FA/EN, about EN (HTTP 200)
- About FA path `/fa/درباره-ما` returned 404 for that slug

### digivisa.ir
- Status from Stage 3 runner: **connection timeout** (browser + curl)
- Existing production `source_documents` row retained for homepage
- Inventory records homepage as `unreachable_from_stage3_runner`
- Operator re-fetch required when host is reachable

### radvisa.com
- Status from Stage 3 runner: **connection timeout**
- Existing production homepage snapshot retained
- Same treatment as digivisa.ir

## Classification (radmohajer)

| Category | Count |
|----------|------:|
| study_guidance | 215 |
| work_guidance | 76 |
| investment_guidance | 46 |
| immigration_guidance | 42 |
| visa_visitor | 25 |
| legal | 13 |
| organization_about | 4 |
| contact | 2 |
| home | 2 |
| other | 315 |

Freshness: **404** pages `requires_verification` (mostly immigration/study/work with sitemap lastmod ~2020); **8** `likely_current` (contact/about/home/service).

Promotion policy: **8** safe_first_party; **732** review_required_regulatory.

## Ingestion

- New source_documents: contact FA, contact EN, about EN
- New snapshots with content hashes (idempotent on document_id+content_hash)
- Re-used existing homepage documents/snapshots for radvisa/digivisa/radmohajer home

## Knowledge promotion (approved, evidence-backed only)

Safe first-party only:
- Tehran phone numbers FA (`rad-tehran-phones-fa`)
- Tehran phone numbers EN (`rad-tehran-phones-en`)
- Institute operated in Tehran since 2006 EN (`rad-institute-founded-tehran-en`)
- Prior Stage 2 items retained (contact/services/brand)

**Not promoted:** study/work/investment/visa eligibility, fees, processing times, program availability (stale risk; sitemap dates 2020).

## Official-source verification

No regulatory claim was approved as current law. External government verification is required before promoting any inventoried immigration guidance pages.

## Stale / superseded

All radmohajer immigration/study/work/investment/visa pages flagged `requires_verification` due to sitemap `lastmod` clustering at 2020-03-09 and topics that change under government policy. Evidence is **preserved in inventory**, not deleted.

## Conflicts

No fabricated conflicts. No material RAD-vs-official conflict rows created because regulatory claims were not approved.

## Duplicates

- URL normalization: http→https, strip www, trailing slash, tracking params, fragments
- Sitemap raw 740 → unique 740 after normalization
- Cross-site: radvisa/digivisa currently unreachable; relationship mapping deferred to re-fetch

## Feed safety

`feed_items = 0` after Stage 3. Promote path does not write Feed.

## Production Knowledge state (post Stage 3)

- knowledge_items: 7
- knowledge_claims: 7
- knowledge_citations: 7
- source_documents: 6
- source_snapshots: 11
- feed_items: 0

## Repeatable process

- `tools/stage3_content_migration/url_normalize.py`
- `docs/RAD_CONTENT_INVENTORY.json` full inventory
- research-sync edge function remains the production fetch path (SSRF-safe)
- Future: enable hosts → research-sync → snapshot → promote only under trust policy

## Instagram

Deferred. No unauthorized Instagram scraping.

## Migration lineage

No ledger rewrite. No destructive schema change. Additive data only.
