#!/usr/bin/env python3
"""Build the Stage 3 canonical content dataset from extracted records.

Outputs (under --out):
  CANONICAL_CONTENT_DATASET.jsonl   - normalized, evidence-backed records
  DUPLICATE_CANONICAL_MAP.json      - content-hash duplicate/equivalence groups
  INGESTION_DRYRUN_RESULT.json      - simulated upsert against the real DB
                                        contract (source_documents /
                                        source_snapshots) with NO writes
  DATASET_MANIFEST.json             - counts, sha256s, schema mapping

Deterministic and stdlib-only. Every regulatory record remains
REVIEW_REQUIRED; nothing here is promotion-ready or Feed-eligible.
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from extract import shingles  # noqa: E402  (shared near-duplicate definition)

EXTRACTOR_VERSION = "stdlib_htmlparser_v1"
DATASET_SCHEMA = "rad-canonical-content-v1"

CONTENT_TYPE_RULES = [
    (re.compile(r"/article/|component/content/article", re.I), "article"),
    (re.compile(r"contact|تماس|ارتباط", re.I), "contact"),
    (re.compile(r"service|خدمات", re.I), "service"),
    (re.compile(r"/(fa|en)?/?(index)?$|/$|(radmohajer\.ir|radvisa\.com|digivisa\.ir)$", re.I), "home"),
    (re.compile(r"category|blog|اخبار|مقالات", re.I), "category"),
]


def content_type_for(url: str, title: str) -> str:
    probe = url + " " + (title or "")
    for pat, ctype in CONTENT_TYPE_RULES:
        if pat.search(probe):
            return ctype
    return "other"


def normalize_language(raw, url: str, site: str):
    """Map BCP-47 tags to the DB contract enum ('fa' | 'en'); None if unknown.

    The DB check constraint allows exactly 'fa'/'en' and source_documents.
    language_code is nullable, so unknown stays None rather than guessing.
    """
    if isinstance(raw, str) and raw.strip():
        primary = raw.strip().lower().split("-")[0]
        if primary in ("fa", "en"):
            return primary
    if "/fa" in url or site == "digivisa.ir":
        return "fa"
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    root = pathlib.Path(args.root)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    records = []
    for jf in sorted((root / "extracted").glob("*.jsonl")):
        if jf.name == "quality_ledger.jsonl":
            continue
        for line in jf.read_text(encoding="utf-8").splitlines():
            if line.strip():
                records.append(json.loads(line))

    # Duplicate / canonical-equivalence groups:
    #  1) exact normalized-body sha256 equality, plus
    #  2) near-duplicate equivalence via shingle Jaccard > 0.9 (same threshold
    #     extract.py uses to REVIEW-flag near duplicates), restricted to
    #     same-site pairs with similar body length.
    for rec in records:
        body = rec.get("main_text") or ""
        rec["_body_hash"] = hashlib.sha256(body.encode("utf-8")).hexdigest()
        rec["_shingles"] = shingles(body)

    parent = list(range(len(records)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i, j):
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[max(ri, rj)] = min(ri, rj)

    by_hash = defaultdict(list)
    for idx, rec in enumerate(records):
        by_hash[rec["_body_hash"]].append(idx)
    for idxs in by_hash.values():
        for other in idxs[1:]:
            union(idxs[0], other)
    by_site = defaultdict(list)
    for idx, rec in enumerate(records):
        by_site[rec["domain"]].append(idx)
    for idxs in by_site.values():
        idxs.sort(key=lambda i: len(records[i]["_shingles"]))
        for a_pos, i in enumerate(idxs):
            si = records[i]["_shingles"]
            li = len(records[i].get("main_text") or "")
            for j in idxs[a_pos + 1:]:
                lj = len(records[j].get("main_text") or "")
                if not si or not records[j]["_shingles"]:
                    continue
                if min(li, lj) / max(li, lj, 1) < 0.8:
                    continue  # different-length pages cannot be near duplicates
                sj = records[j]["_shingles"]
                jac = len(si & sj) / len(si | sj)
                if jac > 0.9:
                    union(i, j)

    groups = defaultdict(list)
    for idx, rec in enumerate(records):
        groups[find(idx)].append(rec)

    quality_rank = {"PASS": 0, "REVIEW": 1, "FAIL": 2}
    dup_map = {
        "schema_version": "rad-duplicate-canonical-map-v2",
        "method": "exact normalized-body sha256 equivalence UNION near-duplicate "
                  "shingle Jaccard > 0.9 (same threshold as extract.py) within "
                  "same site and similar length; primary chosen by quality rank "
                  "(PASS>REVIEW>FAIL), then shortest URL, then capture order",
        "groups": [],
        "singletons": 0,
    }
    canonical_records = []
    for _root_key, members in sorted(groups.items(), key=lambda kv: kv[1][0]["u"]):
        members.sort(key=lambda r: (quality_rank.get(r["quality"], 3), len(r["u"]),
                                    r.get("extracted_at") or ""))
        primary = members[0]
        group_id = "dg-" + primary["_body_hash"][:16]
        if len(members) > 1:
            dup_map["groups"].append({
                "group_id": group_id,
                "primary_url": primary["u"],
                "members": [{
                    "url": r["u"],
                    "quality": r["quality"],
                    "snapshot_sha256": r.get("snapshot_sha256"),
                    "match_type": "exact_body"
                        if r["_body_hash"] == primary["_body_hash"]
                        else "near_duplicate_jaccard>0.9",
                } for r in members],
            })
        else:
            dup_map["singletons"] += 1
        for r in members:
            canonical_url = r.get("canonical_url") or r["u"]
            rec_id = "rad-" + hashlib.sha256(
                ("canonical:v1|" + canonical_url).encode("utf-8")).hexdigest()[:24]
            canonical_records.append({
                "id": rec_id,
                "site": r["domain"],
                "original_url": r["u"],
                "canonical_url": canonical_url,
                "raw_snapshot_ref": r.get("snapshot_path"),
                "raw_snapshot_sha256": r.get("snapshot_sha256"),
                "body_sha256": r["_body_hash"],
                "extracted_title": r.get("title"),
                "title_source": r.get("title_source"),
                "title_is_fallback": bool(r.get("shell_title")),
                "body": r.get("main_text") or "",
                "language": normalize_language(r.get("lang"), r["u"], r["domain"]),
                "content_type": content_type_for(r["u"], r.get("title")),
                "provenance": {
                    "capture_timestamp": r.get("extracted_at"),
                    "extraction_method": r.get("extraction_method"),
                    "http_status": r.get("http_status"),
                    "final_url": r.get("final_url"),
                },
                "extraction_version": EXTRACTOR_VERSION,
                "quality_classification": r["quality"],
                "quality_reasons": r.get("quality_reasons") or [],
                "regulatory_verification_status": "REVIEW_REQUIRED",
                "review_status": "unreviewed",
                "official_evidence_refs": [],
                "duplicate_group": group_id,
                "is_group_primary": r is primary,
                "source_published_date": r.get("published") or None,
                "source_modified_date": r.get("modified") or None,
            })

    ds_path = out / "CANONICAL_CONTENT_DATASET.jsonl"
    with open(ds_path, "w", encoding="utf-8", newline="\n") as f:
        for rec in sorted(canonical_records, key=lambda r: (r["site"], r["canonical_url"])):
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    (out / "DUPLICATE_CANONICAL_MAP.json").write_text(
        json.dumps(dup_map, ensure_ascii=False, indent=2), encoding="utf-8")

    # ---- Ingestion dry-run against the real DB contract (NO WRITES) ----
    # source_documents: canonical_url UNIQUE; source_snapshots:
    # UNIQUE (document_id, content_hash) where content_hash := sha256(body).
    seen_doc_urls = set()
    snapshot_keys = set()
    dry = {
        "schema_version": "rad-ingestion-dryrun-v1",
        "target_contract": {
            "documents_table": "public.source_documents",
            "document_key": "canonical_url (unique)",
            "snapshots_table": "public.source_snapshots",
            "snapshot_key": "(document_id, content_hash) unique",
            "content_hash_definition": "sha256(extracted normalized body text)",
            "mapping": {
                "source_documents.canonical_url": "canonical_url",
                "source_documents.title": "extracted_title (fallback titles flagged)",
                "source_documents.language_code": "language (fa|en)",
                "source_documents.source_authority": "'rad_official' (constant)",
                "source_documents.jurisdiction": "destination guess or NULL",
                "source_snapshots.normalized_text": "body",
                "source_snapshots.content_hash": "body_sha256",
                "source_snapshots.http_status": "provenance.http_status",
                "source_snapshots.fetched_at": "provenance.capture_timestamp",
                "source_snapshots.metadata": "{original_url, raw_snapshot_sha256, "
                                             "quality_classification, extraction_version, "
                                             "regulatory_status}",
            },
            "explicitly_not_touched": [
                "public.knowledge_items / knowledge_claims (promotion is a separate "
                "admin step under promote_knowledge_from_evidence)",
                "public.research_findings / content_drafts (research-sync pipeline only)",
                "public.feed_items (auto-publication prohibited)",
                "public.destinations / visa_* (Phase H package, separate authorization)",
            ],
        },
        "rows_total": len(canonical_records),
        "would_insert_documents": 0,
        "would_skip_existing_documents": 0,
        "would_insert_snapshots": 0,
        "would_skip_existing_snapshots": 0,
        "would_fail_language_check": 0,
        "would_fail_missing_title": 0,
        "notes": [
            "Dry-run simulates canonical_url and (document_id, content_hash) "
            "uniqueness only; it performs no network or database operations.",
            "A production ingest must run in a transaction and remains an "
            "operator action requiring explicit owner authorization.",
            "All rows carry regulatory_verification_status=REVIEW_REQUIRED; "
            "ingestion into source evidence tables does NOT promote knowledge.",
        ],
    }
    for rec in sorted(canonical_records, key=lambda r: (r["site"], r["canonical_url"])):
        # language_code is nullable in source_documents; only invalid
        # (non-null, non-fa/en) values would violate the check constraint
        if rec["language"] is not None and rec["language"] not in ("fa", "en"):
            dry["would_fail_language_check"] += 1
        if not rec["extracted_title"]:
            dry["would_fail_missing_title"] += 1
        if rec["canonical_url"] in seen_doc_urls:
            dry["would_skip_existing_documents"] += 1
        else:
            seen_doc_urls.add(rec["canonical_url"])
            dry["would_insert_documents"] += 1
        key = (rec["canonical_url"], rec["body_sha256"])
        if key in snapshot_keys:
            dry["would_skip_existing_snapshots"] += 1
        else:
            snapshot_keys.add(key)
            dry["would_insert_snapshots"] += 1
    (out / "INGESTION_DRYRUN_RESULT.json").write_text(
        json.dumps(dry, ensure_ascii=False, indent=2), encoding="utf-8")

    per_site = Counter(r["site"] for r in canonical_records)
    per_quality = Counter((r["site"], r["quality_classification"]) for r in canonical_records)
    manifest = {
        "schema_version": DATASET_SCHEMA,
        "dataset_sha256": hashlib.sha256(ds_path.read_bytes()).hexdigest(),
        "duplicate_map_sha256": hashlib.sha256(
            (out / "DUPLICATE_CANONICAL_MAP.json").read_bytes()).hexdigest(),
        "dryrun_sha256": hashlib.sha256(
            (out / "INGESTION_DRYRUN_RESULT.json").read_bytes()).hexdigest(),
        "rows": len(canonical_records),
        "per_site": dict(per_site),
        "per_site_quality": {f"{s}:{q}": n for (s, q), n in sorted(per_quality.items())},
        "duplicate_groups": len(dup_map["groups"]),
        "duplicate_group_members": sum(len(g["members"]) for g in dup_map["groups"]),
        "all_review_required": True,
        "feed_eligible": 0,
    }
    (out / "DATASET_MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
