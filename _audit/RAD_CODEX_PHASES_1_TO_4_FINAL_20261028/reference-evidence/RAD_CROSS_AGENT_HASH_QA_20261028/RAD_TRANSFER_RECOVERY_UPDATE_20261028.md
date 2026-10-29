# RAD — Grok partial transfer / local recovery verification
Date: 2026-10-28

## Current verified position
- The original Grok agent reports 355 source-artifact files (~21 MB). Those original artifact bytes are **NOT fully transferred to this PC**.
- Actual Grok intake directory:
  `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_audit\GROK_RECOVERY_INTAKE_20261028\RAD_CONTENT_GAP_RECOVERY_20261027`
- The 100 intended `body_ready_for_unreviewed_composition` URLs and source IDs are precisely recoverable from Codex's existing 422-row source register. Their exact local URL map was created: `mohajer_100_compact.json` (100 rows; SHA-256 `C3D51B42BEB6C1276E09CA3C992EF657EE58C728A937B31641A62D6BC7168BD3`).
- The 100 URLs have **zero URL overlap** with the latest 259-record Antigravity recovery corpus after canonical normalization. This is based on registered URLs, not article-body semantic dedup.
- A permitted fresh public HTTP request returned 200 for the first URL. Grok's `windows_refetch_mohajer.py` was run locally; after 33 successful filename pairs and an extended period without more file creation, the *specific Python process started for this test* was stopped to avoid unnecessarily repeating stalled requests.

## Content actually on the PC
- **33 .html + 33 .txt files**, saved in `recovered_bodies_radmohajer`.
- All **33 pairs passed independent local structural, UTF-8 and SHA-256 checks** (see `LOCAL_REFETCH_PARTIAL_VERIFICATION.json`).
- The re-fetch script calculated TXT hash on LF-normalized text, but Windows `Path.write_text` persisted CRLF line endings. Therefore on-disk TXT raw SHA differs from the filename hash. The normalized LF UTF-8 SHA matches all 33 filename suffixes; both on-disk and normalized digests are captured in the verification report. **Do not compare the LF-normalized hash to the raw file bytes without normalization.**
- The remaining **67 of the 100 source IDs are not locally verified**. Exact remaining URLs: `REFETCH_REMAINING_URLS.json`.
- The other **146 primary-source TXT files**, Grok's original full manifests, 52/48 editorial rationale CSV, and the original HTML/TXT bytes for the full 100 have **not** been independently copied or hash-compared against the agent artifacts.

## Separate existing Antigravity corpus
- The Antigravity `_scratch/recovered_radmohajer_articles.jsonl.gz` contained 259 unique URLs and 206 with nonempty substantive parsed bodies at earlier inspection, with 259 cached HTML raw SHA checks passing.
- Some recovered pages are category listings/Wayback archives and need source-faithful article segmentation. Local triage findings: `UNPARSED_HTML_CANDIDATE_TRIAGE.csv`.
- Do not simply count all 100 + 259 as 359 complete articles. URL-level uniqueness is only a dedup stage; complete body and section-level uniqueness are not verified.

## GitHub / PR status (independent)
- PR #85 remains **Draft, unmerged**.
- Latest PR head `2484537ce05c11bf7463d62b043851dc04a35057`.
- CI Run `40650871013`: **8/8 jobs success**, including plan3-content, flutter, Android, web, clean-schema, migration-reconstruction, routing and keyword scan.
- Prior failing isolated Ruff formatting and lint issues in `tools/content_completion/reconcile_all_sources.py` were corrected without knowingly changing business logic.

## Safe next steps for Antigravity/Grok
1. Preserve the 33 local source pairs and verification report; consider their content **UNVERIFIED for editorial completeness and NOT approved for publication**.
2. Obtain the missing original Grok artifact bytes via an authorized shared-folder/Drive/OneDrive mechanism, or consider conservative low-rate re-fetch of the 67 missing URLs only. Do not bypass 403/rate limits. Preserve provenance of **fresh live** material distinctly from Grok's original captured snapshot.
3. Obtain the two mapping CSVs and original full SHA manifests from Grok; the locally reconstructed 100-source URL map does NOT reproduce the 52/48 editorial judgments.
4. Compare original Grok SHA manifests with locally fetched HTML; do not claim byte-for-byte transfer unless hashes match.
5. Keep Mohajer articles independent in Other Titles pending human approval. Main Visa canonical pages consolidate RAD Visa and DigiVisa only.
6. No hosted Staging or Production writes, no publication, no PR merge without owner authorization.

## Evidence paths
- `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_audit\RAD_CROSS_AGENT_HASH_QA_20261028\LOCAL_REFETCH_PARTIAL_VERIFICATION.json`
- `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_audit\RAD_CROSS_AGENT_HASH_QA_20261028\REFETCH_REMAINING_URLS.json`
- `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_audit\RAD_CROSS_AGENT_HASH_QA_20261028\GROK100_LOCAL_RECONCILIATION.json`
- `C:\Users\Mehrshad\Desktop\RAD - Emigrate\_audit\RAD_CROSS_AGENT_HASH_QA_20261028\mohajer_100_compact.json`

All results are local-only or GitHub source commits. No hosted database writes and no Windows shutdown were performed in this task.
