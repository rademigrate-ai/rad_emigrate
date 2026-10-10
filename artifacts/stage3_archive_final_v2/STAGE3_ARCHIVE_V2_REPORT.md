# STAGE 3 — Final Archive Dataset Cleanup (v2)

- Branch: `handoff/codex-stage1-stage2-20261010` · HEAD: `d33cafb505cc92f9e22fb63c7176284819462d2a`
- Source package (preserved unchanged): `artifacts/stage3_manus_reconciliation_20261010/`
- Output: `artifacts/stage3_archive_final_v2/`
- Official Stage 3 production readiness: **NO-GO** (unchanged).

## 1. Source integrity (Task 1)

| File | SHA-256 (computed) | Manifest value | Match |
|---|---|---|---|
| `radvisa_archive_discovery.jsonl` | `aa70f2d9eb87190676136969b6eb01ac96c872ead998d1f3617db9b606185966` | same | ✅ |
| `digivisa_archive_discovery.jsonl` | `6195c15e659d69f1f8fccd650b4691c6414de5274e43511a22a9e781990de9cf` | same | ✅ |

Both source files were re-hashed after output generation: unchanged. Row counts 242 / 423 with schema `u,l,c,t,f,p,i,s`, all `UNREACHABLE:live_host_timeout` / `review_required_regulatory` / `metadata_only_regen` / `wayback_cdx`. One pre-existing normalization finding: `radvisa_archive_discovery.jsonl` L242 `https://radvisa.com/SmartPicture.aspx?f=%7E` is not idempotent under `normalize_url()` (`%7E` → `~`); that row is quarantined in v2 (NC5), so the v2 outputs contain **zero** normalization non-conformances.

## 2. Classification rules (Tasks 3–4)

Explicit, reproducible, deterministic rules applied to each URL (lowercased path):

| Code | Rule | Rationale |
|---|---|---|
| NC1 | basename ∈ {`robots.txt`, `ads.txt`, `app-ads.txt`} | Reserved crawler/advertising declaration files — machine endpoints |
| NC2 | path starts `/.well-known/` | RFC 8615 well-known URIs (security.txt, dnt-policy.txt, trust.txt, nodeinfo, openid-configuration) — machine endpoints |
| NC3 | path starts `/administrator/` or basename ∈ {`Captcha.aspx`, `login.aspx`} | Non-public backend/auth surface |
| NC4 | path starts `/cgi-sys/` and basename `suspendedpage.cgi` | Hosting suspension placeholder |
| NC5 | basename `smartpicture.aspx` | Image/asset generator handler — consistent with v1's static-asset quarantine rationale |
| NC6 | basename ∈ {`feed`, `rss`} | Machine-readable feed endpoint |
| NC7 | basename `404.htm` | Soft-404 error template, not real content |

The 11 accepted `.txt` URLs were each classified individually: all 11 fall under NC1 (5: robots/ads/app-ads on both domains minus digivisa robots? — no robots.txt only radvisa) and NC2 (6: `.well-known/{dnt-policy,security,trust}.txt` on both domains). Precisely: NC1 = `ads.txt`, `app-ads.txt` (both domains, 4) + `radvisa.com/robots.txt` (1) = 5; NC2 `.well-known/*.txt` = 6. **All 11 are non-content machine endpoints** — none is article or guidance content.

**Reviewed under the same rules and explicitly RETAINED as content** (Task 4, not rejected):
- `radvisa.com/Index.aspx`, `radvisa.com/index.aspx?Type=CategoryArticle&ID_Root=-1` — site index / article category listing
- `radvisa.com/catarticle/all/page/2..4`, `digivisa.ir/catarticle/**/page/2..8` and `digivisa.ir/catarticle/all/page/2..8` — article pagination (content listings)

No other non-content endpoints were found under these rules (no `/sitemap.xml`, no asset extensions, no duplicate-scheme paths).

## 3. Outputs (Task 7)

| File | Rows | Bytes |
|---|---:|---:|
| `radvisa_archive_discovery_v2.jsonl` | **229** (from 242, −13) | 70,520 |
| `digivisa_archive_discovery_v2.jsonl` | **413** (from 423, −10) | 131,591 |
| **Total v2** | **642** | |
| `STAGE3_ARCHIVE_V2_QUARANTINE.json` | 23 records | 17,694 |
| `STAGE3_ARCHIVE_V2_MANIFEST.json` | — | 4,707 |

Kept rows are byte-exact copies of source lines (v2 line sets are verified exact subsets of the v1 lines; only removals, zero edits).

## 4. Newly quarantined URLs (Task 8) — 23 records, each with exact reason + original source

**radvisa.com (13):**
- NC2: `/.well-known/dnt-policy.txt` (L3), `/.well-known/nodeinfo` (L4), `/.well-known/openid-configuration` (L5), `/.well-known/security.txt` (L6), `/.well-known/trust.txt` (L7)
- NC7: `/404.htm` (L20) · NC1: `/ads.txt` (L21), `/app-ads.txt` (L22), `/robots.txt` (L240)
- NC3: `/Captcha.aspx` (L66) · NC6: `/feed` (L229)
- NC5: `/SmartPicture.aspx` (L241), `/SmartPicture.aspx?f=%7E` (L242)

**digivisa.ir (10):**
- NC2: `/.well-known/dnt-policy.txt` (L3), `/.well-known/nodeinfo` (L4), `/.well-known/openid-configuration` (L5), `/.well-known/security.txt` (L6), `/.well-known/trust.txt` (L7)
- NC7: `/404.htm` (L21) · NC3: `/Administrator/Login.aspx` (L22)
- NC1: `/ads.txt` (L23), `/app-ads.txt` (L24) · NC4: `/cgi-sys/suspendedpage.cgi` (L386)

Each quarantine record carries: URL, domain, reason code, full reason text, source filename, source line number, source file SHA-256, and the complete original row. Nothing was silently deleted.

Reason-code totals: NC2=10, NC1=5, NC7=2, NC3=2, NC5=2, NC6=1, NC4=1.

## 5. Validation (Task 9) — all pass

- Counts: 229 + 413 = 642 = source 665 − 23 quarantined ✓
- Schema: exact keys `u,l,c,t,f,p,i,s` on all 642 rows ✓
- HTTPS + exact domain per file: 642/642 ✓
- `normalize_url()` idempotence: 642/642 (0 errors) ✓
- Uniqueness: 229/229 and 413/413 unique raw **and** after normalization ✓
- Provenance: `i=metadata_only_regen`, `s=wayback_cdx`, `f=unknown`, `c=other`, `l` ∈ {fa,en} on all rows ✓
- Terminal states: `UNREACHABLE:live_host_timeout` 642/642; no `FETCHED_AND_CAPTURED` anywhere ✓
- Quarantine file: 23 unique URLs, all sourced to the two v1 files ✓

## 6. Preservation (Task 5, 10)

- `docs/inventory/radmohajer_ir.jsonl` SHA-256 = `7a031c9c3f729be2d177787275b6ed4f7b0d6d61e4e7bd1377b6162ce15b31a9` — matches expected ✓
- METRICS (`1a396f55…`) and SUMMARY (`c239575d…`) hashes unchanged vs v1 manifest ✓
- All five original Manus package files re-hashed after this run: unchanged ✓
- No Git writes; canonical paths untouched; no crawling, no CDX retry, no hosted operations.

## 7. Documented limitations

- The v1 package's prior quarantine (46 radvisa + 12 digivisa) exists only as counts in its manifest; per-URL lists were never persisted and were **not** re-derived here (audit-repetition restriction). Full per-URL quarantine traceability therefore begins with this v2 package.
- Counts 229/413 do not claim identity with the historical METRICS row sets (296/239); the original row-level lists were never preserved. radvisa remains −67 vs METRICS; digivisa remains +174.
- All rows remain metadata-only Wayback CDX discovery; no live reachability or content verification is implied.

## 8. SHA-256 ledger (v2 outputs)

```
cc3662d87acfdfb7c434bbb2818fc08122bf5bf1992e33ad97c938a6c4125313  radvisa_archive_discovery_v2.jsonl
223fa58e6dce9043f8ed5d8f4146ee2dd7145d245cc49d6261157eb43257c7d7  digivisa_archive_discovery_v2.jsonl
08ae24f8a30fc0a7292753c3d4b057afbc56a8b3e5b5a8adecd7d2f6c2fa283e  STAGE3_ARCHIVE_V2_QUARANTINE.json
5feda60d647cecf6bb5fb35d4f41b7a0454a9c5a9dd5f353a9512fd50d97fe7f  STAGE3_ARCHIVE_V2_MANIFEST.json
(this report: see STAGE3_ARCHIVE_V2_MANIFEST.json sibling listing after commit of this file)
```

## 9. Decision

**READY FOR OWNER-REVIEWED GIT DELIVERY** of the isolated `artifacts/stage3_archive_final_v2/` folder — subject to explicit owner approval and a delivery commit scoped to that folder only (plus this report). All validation checks pass; all exclusions are traceable; all originals are preserved.

Official Stage 3 production readiness remains **NO-GO**: live-host reachability, regulatory verification, canonical row-set reconciliation, and hosted operations remain blocked.
