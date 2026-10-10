# STAGE 3 — Three-Site Live Content Snapshot Pilot (2026-10-11)

- Repository: `C:\Users\Mehrshad\Desktop\Projects\rad_emigrate` · Branch `handoff/codex-stage1-stage2-20261010` @ `f48e39f` (unchanged; **no Git writes**)
- Environment: owner Windows workstation, strictly non-production
- Evidence window (UTC): 2026-10-10T22:07Z → 22:14Z
- Artifacts: `artifacts/stage3_three_site_snapshot_pilot_20261011/` (new folder; nothing overwritten)
- Official Stage 3 production readiness: **NO-GO** (unchanged)

## 1. Compliance

- robots.txt: radmohajer freshly fetched (HTTP 200; Disallow only system paths — `/administrator/`, `/bin/`, `/cache/`, etc.; **zero selected URLs affected**); radvisa/digivisa reused same-session allow-all evidence.
- Selection: exactly 10 URLs/site, deterministic, each traceable to committed evidence — radmohajer from `docs/inventory/radmohajer_ir.jsonl` (committed `b98699a`), radvisa/digivisa from the committed v1 discovery shortlist (`f48e39f` manifest). Previously captured URLs and known soft-404 slugs excluded.
- Sequential fetches, ≥2.1s spacing, 15s timeouts, 2 MB body cap, identifying UA. No auth, forms, personal data, or site modification. No DB/hosted writes, no code changes, no Git writes, no publishing/promotion. All records marked REVIEW_REQUIRED. Historical metrics and decision B untouched.

## 2. Results

| Metric | radmohajer.ir | radvisa.com | digivisa.ir |
|---|---:|---:|---:|
| Selected / captured / failed | 10 / **9** / **1** | 10 / **10** / 0 | 10 / **10** / 0 |
| Real-content snapshots (HTTP 200, unique) | 9 | 10 | 10 |
| Soft-404 responses | 0 | 0 | 0 |
| Redirects followed | 2 | 0 | 0 |
| Duplicate content | 0 | 0 | 0 |
| Total bytes captured | 1,176,447 | 1,738,291 | 1,354,838 |

**The one failure (recorded accurately, not substituted):** `radmohajer.ir-05` — `https://radmohajer.ir/en/لینک-های-مهم/faq` returned a genuine **HTTP 404** from the server (after an RFC 3986-encoded retry). This is real evidence: that archived inventory URL no longer exists live, consistent with the radmohajer site's own URL evolution.

**Client-side issue handled transparently:** 8 initial radmohajer attempts failed *before any request was sent* (urllib refuses non-ASCII paths and raw spaces — the documented W6 limitation of the inventory's stored URLs). They were retried with RFC 3986 percent-encoding; each retry record notes this. No server ever saw the failed attempts, so no rate-limit impact.

**Note on titles:** the five radmohajer article captures (`200-روسیه` … `204-ویزای-کاری-نروژ`) return HTTP 200 with unique content hashes and no not-found markers, but their `<title>` is the site shell name ("موسسه بین المللی راد") — Joomla articles without unique page titles. They are counted as real-content captures with this caveat noted, not as soft-404s.

## 3. Three-site comparison

- **radvisa.com / digivisa.ir (ASP.NET/Plesk, shared host 185.192.112.58):** every shortlist URL resolved to live, unique article content (122–251 KB pages; homepage shells ~101–132 KB). The current `/article/`, `/content/`, `/news/` scheme is fully live. digivisa's `catarticle`/`catnews` listing pages also returned real content.
- **radmohajer.ir (Joomla, host 88.99.68.25):** service pages (free consultation ×2) and privacy policy live; numbered `component/content/article/NNN` pages live but without unique titles; the archived Persian-slug `/en/…/faq` path is dead (404). radmohajer shows the same "old URLs decay, new content lives" pattern as the other two, milder.
- **Cross-site:** all three sites are live and serving substantial current immigration/education content; every captured page is regulatory-adjacent and stays REVIEW_REQUIRED pending official verification. No cross-site duplicate content detected (29/29 unique hashes).

## 4. Validation

- All **29** saved HTML files re-hashed against the manifest: **exact matches** (0 errors); sizes match; all statuses 200; all records carry provenance (`source_evidence`) and REVIEW_REQUIRED status.
- Counts: 29 captured + 1 failed = 30 selected (10/site cap respected). Unique hashes 29/29. Truncations 0.
- Manifest sha256: `d6844c8248ab86903406290f77d47850e64489e13118123df750ecfc4068f453`

## 5. Artifacts

```
artifacts/stage3_three_site_snapshot_pilot_20261011/
  STAGE3_THREE_SITE_PILOT_MANIFEST.json   (provenance-rich; validation block included)
  STAGE3_THREE_SITE_PILOT_REPORT.md       (this file)
  radmohajer.ir/radmohajer.ir-01..10.html (9 files; -05 was a 404, no body)
  radvisa.com/radvisa.com-01..10.html     (10 files)
  digivisa.ir/digivisa.ir-01..10.html     (10 files)
```

## 6. ONE recommended next action

**Owner-gated preservation commit of this pilot folder** (same pattern as the four prior evidence deliveries) so the 29 snapshots and manifest survive locally — then, if desired, an owner-authorized expansion of the shortlist capture toward the full 1,007-URL live-discovery set in bounded batches, feeding a future `source_documents` merge (hosted writes remain out of scope until separately authorized).

Regulatory content remains REVIEW_REQUIRED; metrics and decision B untouched; **Stage 3 remains NO-GO**.
