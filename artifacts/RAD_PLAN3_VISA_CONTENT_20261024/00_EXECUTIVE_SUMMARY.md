# Plan 3 — source-backed Visa article library

Task date: 2026-10-24. Baseline main was independently refreshed to `16810a583ad4544d87f289bd16984c0e758a1515` before creating `feat/plan3-visa-content-library-20261024` in an owned D: clone. Grok PR #78 and Antigravity Plan 4 were not assumed merged or edited.

| Stage | Verified count |
| --- | ---: |
| Discovered in-scope URLs with dispositions | 1922 |
| Successfully retrieved HTML pages | 1214 |
| Complete recognized source article bodies | 1090 |
| Canonical article drafts | 837 |
| Structurally valid initial CMS draft payloads | 581 |
| Existing production source IDs retained | 6 |
| Independently verified legal claims | 0 |
| Human-approved / publication-ready articles | 0 / 0 |
| Hosted imports / publications by this task | 0 / 0 |

These stages are distinct. Complete source-body capture means every text block in a recognized article container was preserved; it does not establish immigration accuracy, source-rights clearance, complete regulatory coverage or editorial approval. Metadata-only, category/navigation and failed URLs are not counted as complete articles. All articles remain unverified and `publication_allowed=false`.

The reported 812 historical source records, 10 incomplete canonical articles and four named artifact folders could not be recovered or independently verified. The owner confirmed the paths/counts were historical references. The older repository also reports 742 and 1,275 inventory totals, while its referenced JSONL/gzip row files are absent from tracked Git history. None of those totals is substituted for current collected records. `02_812_SOURCE_RECONCILIATION.csv` includes an explicit report-claim row and per-current-source unknown membership, not 812 invented source rows. Six actual hosted source-document IDs are reconciled wherever discovered.

Current sitemaps listed 380 RadVisa, 565 DigiVisa and 740 Radmohajer URLs before normalization. Public navigation, pagination, links, current source records and redirects extend that frontier. Robots rules are retained in `data/discovery.json`; fetches use a per-host interval, no form submission, no login/protection bypass and a bounded scoped frontier. Failed/denied/noneditorial/attachment URLs retain a disposition. Original HTML stays in external owned cache; compressed structured source/canonical/draft data is included here.

The timestamped read-only production snapshot recorded 22 destinations, 10 programs, 8 requirement rows, 18 step rows and 22 drafts in review, with canonical CMS tables/RPC capabilities absent at that observation. This is not a fresh hosted audit during hardening; a draft package is not a deployed backend. No historical migration replay or production writes occurred.

The engineering deliverable is a reproducible capture/validation/canonicalization/import-rehearsal pipeline and human review queue. Production content completion remains gated on missing-source resolution as appropriate, official verification of time-sensitive facts, reviewer rights/attribution checks, compatible backend, recovery evidence and separate owner authorization. Test evidence is reported separately in `13_PARSER_AND_IMPORT_TEST_RESULTS.md`; final-head CI is linked from the Draft PR, never inferred from another agent's report.
