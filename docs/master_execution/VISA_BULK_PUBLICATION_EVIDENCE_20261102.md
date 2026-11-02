# RAD Visa — evidence gate for owner-requested batch publication (2026-11-02)

**Status: NOT RELEASE-APPROVED.** The content owner expressed *conditional* willingness to approve a bulk publication once the site capture/import was verified as correct. That condition is **not met by current evidence**. Do not convert the owner's preference to per-claim legal verification or an exact revision clearance receipt.

This is aggregate, reproducible, read-only inspection of the **sealed local** V4 Production-reconciliation input. No article bodies, private identifiers or client data are included in this public-repository report.

## What was checked

Source packet: `db_forward_review/production_reconciliation_package_v3_final_release/operations.jsonl.gz` in the local private audit store (not committed).

- 1,100 proposed operations: **406** new unverified drafts, **443** detached unverified revisions, **251** unresolved existing-key comparisons.
- **1,085** Persian + **15** English operations. Source evidence covers 56 country codes; 821 single-country, 17 multiple-country, 262 country-neutral.
- Structural scanner traversed **14,184** sections, **42,226** blocks, 6,241 source link references and 3,134 media assets.
- No duplicate article+locale keys, duplicate operation IDs, empty titles, empty section records, invalid country code syntax or missing source snapshot/capture/segment ledger flags were detected by the scanner.
- Source URL hostnames belonged to the three expected project domains (radvisa.com, digivisa.ir, radmohajer.ir). This is host provenance checking, **not** current legal/immigration fact checking or source licensing verification.

## Publication blockers found, regardless of bulk owner preference

| Check | Actual evidence | Implication |
|---|---|---|
| Overall revision state | 1,100 `draft`, all 1,100 `unverified` | No revision has passed the existing publication clearance contract |
| Visa/immigration claims | 28,931 `not_verified`; **0** official references/verified timestamps in the claim ledger | The prior site copy is not proof that requirements, prices or timelines are legally current |
| Numeric conflicts | 17 explicit unresolved numeric disagreements across 15 operations | Official evidence and adjudication required; do not pick one value arbitrarily |
| Link evidence | 6,130 link records with structured evidence, of which 1,335 have `confirmed=false`; 111 with other evidence representation | Review flagged source links; `confirmed=false` does not by itself prove a URL is broken |
| Media | 3,134 source media references, all `public_render_allowed=false`, spanning 714 operations | Do not show embedded media without technical/rights clearance |
| Source comparison | 19,765 documented omissions in 616 operations: 19,761 exact structure/text repetitions and four ordered-concept phrase equivalences | These are primarily deliberate deduplications, **not evidence of 19,765 missing paragraphs**; phrase-equivalence decisions still need review |
| Production runtime | 745 existing heads, **zero published**; 72 migrations and no full editorial country reader RPCs | Current hosted app cannot serve full published editorial country content |

Just **two** proposed operations have no claims in the parsed ledger. Only **one** meets the scanner's narrow criterion: zero claims, no conflicts, no media and exactly one country. That does **not** by itself establish publishability or rights; no candidate receives publication approval from this scanner.

The above source fields are **metadata assertions of the saved corpus**, not newly authenticated official facts. Full current authoritative source verification has not been executed.

## Safe batch-release decision

- **Import candidates (not public):** The sealed Production-specific guarded package isolates 849 draft operations. Existing 745 head pointers, authors and publication pointers must remain unchanged. Its preconditions include binding an authorized current actor and the current hosted schema/endpoint and recovery/rollback evidence; it explicitly refuses unreviewed direct execution.
- **Reconciliation:** The other 251 different keys need precise source/head decision receipts. Bulk owner approval of the *process* does not resolve conflicting versions.
- **Release batch:** Require a fixed version/locale/content hash list, source/official evidence per relevant claim, resolved numeric/link cases, cleared/omitted media, correct country/global navigation, authorized reviewer identity and publish operation receipts.
- **No bypass:** Do not set `publication_allowed`, `verified`, `approved`, `published_id`, or `Feed` via fabricated status changes or mass SQL updates. Research/AI/source ingestion must never auto-publish to Feed.
- **No unrelated operations:** The Staging reader is implemented and tested. This report does not deploy, merge, mutate Production, give legal advice, or authorize publication.

## Evidence retained locally

- Private aggregate result: `_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review/bulk_publication_structural_qa_20261102.json`
- Read-only scanners: `_audit/RAD_MASTER_CONVERGENCE_20261031/bulk_publication_structural_qa.py`, `bulk_qa_issue_classification.py`, `bulk_qa_release_cohorts.py`.
- Existing sealed package and human reconciliation templates remain separate; do not edit or re-sign them based on this aggregate review.

**Release decision:** `HOLD_PUBLICATION_PENDING_EVIDENCE`. Code CI passing or owner willingness to bulk approve does not satisfy the checks above.
