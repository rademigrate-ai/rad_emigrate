# STAGE 3 — Complete Sitemap Reconciliation v2 (2026-10-11)

- Repository: `C:\Users\Mehrshad\Desktop\Projects\rad_emigrate` · Branch `handoff/codex-stage1-stage2-20261010` @ `9b2e758` (unchanged; **no Git writes**)
- Owner authorization: complete the previously bounded sitemap discovery
- Prior v1 artifacts untouched (`STAGE3_LIVE_DISCOVERY_MANIFEST.json` sha256 `81cf5f7c…7f551b`, delta report unchanged)
- Official Stage 3 production readiness: **NO-GO** (unchanged)

## 1. Method

- Local check first: the complete raw sitemap XML had **not** been preserved in the v1 run (only 200-loc samples), so the two public `sitemap.xml` files were re-fetched — **2 HTTP requests total**, robots allow-all, 2.1s spacing, 15s timeout, 2 MB cap. Request log with timestamps is embedded in the v2 manifest.
- This time the full raw XML was **preserved locally** (`radvisa_com_sitemap_full.xml` 59,507 B; `digivisa_ir_sitemap_full.xml` 84,215 B) with SHA-256 recorded, so no future re-fetch is needed for this dimension.
- The 200-loc cap is **removed**; all `<loc>` entries parsed, normalized with `tools/stage3_content_migration/normalize_url`, deduplicated, and classified with the same exclusion rules as v1.
- Navigation and HTTP-verified evidence reused from the v1 task (nav from local homepage captures; 16 HEAD checks) — no page capture, no crawling.

## 2. Complete counts

| Metric | radvisa.com | digivisa.ir |
|---|---:|---:|
| raw `<loc>` entries (complete) | **380** | **565** |
| — excluded non-content (assets/utility) | 15 | 0 |
| — wrong-host | 0 | 0 |
| — normalized duplicates removed | **1** | 0 |
| **normalized unique content URLs (sitemap)** | **364** | **565** |
| v1 capped sample (200 locs) → v2 full | 200 → **364** (+164) | 200 → **565** (+365) |
| nav content URLs (complete, local evidence) | 36 | 44 |
| **union of live-discovered content URLs** | **399** | **608** |
| sitemap ∧ nav / sitemap-only / nav-only | 1 / 363 / 35 | 1 / 564 / 43 |
| HTTP-verified (from v1 HEAD checks; not re-tested) | 8 | 8 |
| **overlap with archive evidence** | **33 of 229 = 14.4%** | **8 of 413 = 1.9%** |
| archived-only (not in current live set) | **196** | **405** |
| live-only (present live, absent from archive evidence) | **366** | **600** |

Loc accounting closes exactly per domain: content + excluded + wrong-host + normalized-duplicates = raw total (380 and 565). The single radvisa duplicate was a normalization collision (two raw locs collapsing to one canonical URL) — documented with examples in the manifest.

## 3. Interpretation (unchanged thesis, now with complete data)

1. The v1 lower bounds were indeed lower bounds: the complete sitemap adds 164 radvisa and 365 digivisa content URLs. Total live-discovered content URL space is now **1,007 URLs** (399 + 608) versus 642 archive-evidence rows.
2. Archive overlap remains small and stable: **14.4%** radvisa, **1.9%** digivisa — the restructure conclusion from v1 is confirmed with full data, not overturned.
3. Provenance distinctions preserved: sitemap-listed ≠ live-verified; only the 16 v1 HEAD-checked URLs carry `http_verified`. The v2 manifest's `category_note` states this explicitly per domain.
4. Under owner decision B, archive evidence (229/413) stays historical; the live sets (364/565 sitemap content URLs) are recorded as **current discovery evidence**, not as canonical inventory and not force-fitted to any historical count. Nothing was invented or padded.

## 4. Artifacts (all new; nothing overwritten)

```
artifacts/stage3_live_discovery_20261011/
  STAGE3_LIVE_DISCOVERY_MANIFEST_v2.json    (sha256 a2bddee139d248f623a5440d75ae99b0ddb22a3b3b176460cc85129f52429e17)
  STAGE3_LIVE_RECONCILIATION_V2.md          (this file)
  radvisa_com_sitemap_full.xml              (59,507 B, raw preserved; sha256 in manifest)
  digivisa_ir_sitemap_full.xml              (84,215 B, raw preserved; sha256 in manifest)
  (v1 artifacts unchanged: STAGE3_LIVE_DISCOVERY_MANIFEST.json, STAGE3_LIVE_DISCOVERY_DELTA_REPORT.md)
```

## 5. Validation (all pass)

- HTTP requests this task: exactly 2 (both sitemaps, logged) ✓
- Loc accounting closes exactly per domain ✓ (one initial mismatch — the uncounted normalization duplicate — was caught by validation and fixed with an explicit `normalized_duplicates_removed` field; no data was altered)
- Union/category decomposition sums verified ✓ · archive delta sums verified against 229/413 ✓ · v1→v2 deltas verified ✓ · preserved raw XML re-hashed against manifest ✓ · no page captures, no shortlist changes, no excluded-class URLs ✓

## 6. ONE recommended next step

**Owner decision on the live-discovery record:** either (a) commit the completed live-discovery artifacts (v2 manifest + reconciliation + preserved sitemaps) as a tracked Stage 3 evidence set — a small, docs-only, owner-gated delivery like the prior four — or (b) proceed directly to an owner-authorized bounded live snapshot run over the `http_verified` + corroborated shortlist to build current `source_documents`-ready evidence. Option (a) is the natural next step because it durably preserves the 1,007-URL live record that currently exists only in the working tree.

Regulatory content remains REVIEW_REQUIRED; historical metrics and decision B are untouched; **Stage 3 remains NO-GO**.
