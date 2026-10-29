"""Recover misclassified geographic article bodies as unverified local drafts.

The sealed source corpus is read-only. No hosted import or publication occurs.
Only complete source containers whose fresh raw bytes, blocks and links match
the frozen extraction are candidates. Ambiguous country or duplicate identity
stays blocked for review; the original source wording is never summarized.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import unquote, urlsplit
from uuid import UUID

from tools.content_consolidation.import_payload import payload
from tools.editorial_reference_capture import extract_references
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import digest, search_normalize


def is_geographic_candidate(source):
    path = unquote(urlsplit(source["url"]).path).lower()
    title = search_normalize(source.get("title") or "")
    taxonomy = source.get("taxonomy", {})
    if not (
        source.get("consolidation_disposition")
        == "nonarticle_or_incomplete_requires_review"
        and taxonomy.get("page_type") == "organization"
        and source.get("body_status") == "complete_source_container"
        and len(source.get("body_text", "")) >= 300
        and source.get("language") in ("fa", "en")
        and path.startswith("/article/")
        and re.search(r"درباره|about", title)
    ):
        return False
    if re.search(
        r"درباره\s*(?:ی\s*)?(?:ما|موسسه|مؤسسه|شرکت|گروه|راد)(?:\s|$)|about\s+(?:us|rad)(?:\s|$)",
        title,
    ):
        return False
    # Explicit country evidence or an explicit city topic, never inferred
    # from an unrelated immigration route or an arbitrary general article.
    return bool(taxonomy.get("country_codes") or re.search(r"شهر|city", title))


def make_draft(source, country_evidence=None):
    body = source["body_text"]
    if (
        digest(body) != source["body_sha256"]
        or "\n\n".join(x["text"] for x in source["blocks"]) != body
    ):
        raise ValueError("source_body_hash_or_block_sequence_mismatch")
    identity = uid("rad-geographic-recovery-v1:" + source["source_id"])
    country_codes = (
        []
        if source["taxonomy"].get("country_disagreement")
        else source["taxonomy"].get("country_codes", [])
    )
    if country_evidence is not None:
        if (
            country_codes
            or country_evidence["source_id"] != source["source_id"]
            or not re.fullmatch(r"[A-Z]{2}", country_evidence["country_code"])
            or not country_evidence["excerpt"]
            or country_evidence["excerpt"] not in body
        ):
            raise ValueError("invalid_country_source_evidence")
        country_codes = [country_evidence["country_code"]]
    sections, ledger, claims = [], [], []
    offset = 0
    for index, block in enumerate(source["blocks"]):
        value = block["text"]
        start = body.find(value, offset)
        if start < 0:
            raise ValueError("source_block_unbound")
        end = start + len(value)
        offset = end
        if not sections or block["type"] == "heading":
            sections.append(
                {
                    "id": uid(identity + ":section:" + str(len(sections))),
                    "heading": value if block["type"] == "heading" else source["title"],
                    "program": "independent",
                    "blocks": [],
                }
            )
        ref = {
            "source_id": source["source_id"],
            "snapshot_id": source["snapshot_id"],
            "url": source["url"],
            "block_index": index,
            "start": start,
            "end": end,
            "sha256": digest(value),
            "structure_sha256": digest(block),
        }
        block_id = uid(identity + ":block:" + str(index))
        sections[-1]["blocks"].append(
            {
                "id": block_id,
                "type": block["type"],
                "text": value,
                "original_structure": block,
                "provenance": [ref],
            }
        )
        ledger.append(
            {
                **ref,
                "destination_article_id": identity,
                "status": "preserved",
                "represented_block_id": block_id,
            }
        )
        if block["type"] != "heading":
            claims.append(
                {
                    "block_id": block_id,
                    "verification_status": "not_verified",
                    "official_references": [],
                    "verified_at": None,
                    "review_reason": "source_claim_requires_official_and_human_review",
                    "provenance": ref,
                }
            )
    return {
        "article_id": identity,
        "title": source["title"],
        "locale": source["language"],
        "country_codes": country_codes,
        "pathway": "general",
        "visa_category": None,
        "category": "general-guide",
        "content_class": "editorial",
        "source_ids": [source["source_id"]],
        "source_urls": [source["url"]],
        "source_publishers": [source["domain"]],
        "sections": sections,
        "omissions": [],
        "claims": claims,
        "conflicts": [],
        "segment_ledger": ledger,
        "editorial_state": "draft",
        "verification_state": "unverified",
        "reviewer_id": None,
        "published": False,
        "publication_allowed": False,
        "composition_review": "independent_geography_country_and_visa_scope_require_human_review",
        "english_translation": "original_english_source_only"
        if source["language"] == "en"
        else "not_available",
        "country_source_evidence": country_evidence,
    }


def reference_capture(source, caches):
    UUID(source["collector_id"])
    for cache in caches:
        path = cache / (source["collector_id"] + ".html.gz")
        if not path.is_file():
            continue
        raw = gzip.decompress(path.read_bytes())
        if (
            len(raw) <= 16 * 1024 * 1024
            and hashlib.sha256(raw).hexdigest() == source["raw_html_sha256"]
        ):
            return extract_references(raw, source)
    return None


def build(sources, old_articles, observations, registry, caches, country_evidence=None):
    observations = {
        row["source_id"]: row for row in observations if row.get("source_id")
    }
    existing_ids = {
        source for article in old_articles for source in article["source_ids"]
    }
    old_source_ids = {s for a in old_articles for s in a["source_ids"]}
    original_hashes = defaultdict(list)
    for source in sources:
        if source["source_id"] in old_source_ids and source.get("body_sha256"):
            original_hashes[(source["language"], source["body_sha256"])].append(
                source["source_id"]
            )
    results, drafts, ready, reference_maps = [], [], [], []
    candidates = [s for s in sources if is_geographic_candidate(s)]
    candidate_hashes = Counter((s["language"], s["body_sha256"]) for s in candidates)
    for source in candidates:
        sid = source["source_id"]
        observation = observations.get(sid, {})
        reasons = []
        if sid in existing_ids:
            reasons.append("source_already_in_existing_article")
        expected_structure = digest(source["blocks"])
        expected_links = digest(source.get("body_links", []))
        if (
            observation.get("change_disposition") != "body_blocks_and_links_unchanged"
            or observation.get("fresh_raw_status") != "hash_verified_raw"
            or observation.get("old_body_sha256") != source["body_sha256"]
            or observation.get("fresh_body_sha256") != source["body_sha256"]
            or observation.get("old_structure_sha256") != expected_structure
            or observation.get("fresh_structure_sha256") != expected_structure
            or observation.get("old_links_sha256") != expected_links
            or observation.get("fresh_links_sha256") != expected_links
        ):
            reasons.append("current_source_not_fully_matched")
        if (
            original_hashes[(source["language"], source["body_sha256"])]
            or candidate_hashes[(source["language"], source["body_sha256"])] > 1
        ):
            reasons.append("duplicate_identity_review_required")
        draft = make_draft(source, (country_evidence or {}).get(sid))
        capture = reference_capture(source, caches)
        if capture is None:
            reasons.append("original_reference_capture_unavailable")
        else:
            positions = {
                r["block_index"]: b["id"]
                for section in draft["sections"]
                for b in section["blocks"]
                for r in b["provenance"]
            }
            for link in capture["links"]:
                if link["url"].split("#", 1)[0].rstrip("/") == source["url"].rstrip(
                    "/"
                ):
                    index = capture["anchors"].get(
                        unquote(urlsplit(link["url"]).fragment)
                    )
                    if index is not None:
                        link["target_block_id"] = positions.get(index)
            reference_maps.append(
                {
                    "article_id": draft["article_id"],
                    "locale": draft["locale"],
                    "expected_revision": 1,
                    "map": {
                        "capture_status": "complete",
                        "sources": [
                            {
                                key: capture[key]
                                for key in (
                                    "snapshot_id",
                                    "body_sha256",
                                    "raw_html_sha256",
                                )
                            }
                        ],
                        "links": capture["links"],
                        "media_reuse": "not_authorized",
                        "legal_verification": "not_inferred_from_links",
                    },
                }
            )
        if len(draft["country_codes"]) != 1:
            reasons.append("country_mapping_requires_review")
        if re.search(
            r"ویزا|تحصیل|مهاجرت|visa|study|immigration",
            search_normalize(
                source["title"] + " " + unquote(urlsplit(source["url"]).path)
            ),
        ):
            reasons.append("possible_main_visa_contribution_requires_review")
        result = payload(draft, {sid: source}, registry)
        if result["status"] != "technical_draft_only":
            reasons.append("closed_cms_contract:" + result["status"])
        drafts.append(draft)
        if not reasons:
            ready.append(result)
        results.append(
            {
                "source_id": sid,
                "url": source["url"],
                "title": source["title"],
                "article_id": draft["article_id"],
                "country_codes_proposed": draft["country_codes"],
                "source_blocks": len(source["blocks"]),
                "fresh_disposition": observation.get(
                    "change_disposition", "not_observed"
                ),
                "technical_status": "local_draft_candidate"
                if not reasons
                else "blocked_review",
                "reasons": reasons,
            }
        )
    return results, drafts, ready, reference_maps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--observations", type=Path, required=True)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--raw-cache", type=Path, action="append", required=True)
    parser.add_argument("--country-evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("output must be a new directory")
    sources = read_jsonl(args.corpus / "sources.jsonl.gz")
    articles = read_jsonl(args.corpus / "articles.jsonl.gz")
    observations = [
        json.loads(line)
        for line in args.observations.read_text(encoding="utf-8").splitlines()
    ]
    registry = json.loads(args.registry.read_text(encoding="utf-8"))
    evidence_rows = json.loads(args.country_evidence.read_text(encoding="utf-8"))
    evidence = {row["source_id"]: row for row in evidence_rows}
    if len(evidence) != len(evidence_rows):
        raise ValueError("duplicate_country_source_evidence")
    rows, drafts, ready, reference_maps = build(
        sources, articles, observations, registry, args.raw_cache, evidence
    )
    args.output.mkdir(parents=True)
    write_jsonl(args.output / "geographic-drafts.jsonl.gz", drafts)
    write_jsonl(args.output / "technically-ready-payloads.jsonl.gz", ready)
    write_jsonl(args.output / "article-reference-maps.jsonl.gz", reference_maps)
    (args.output / "dispositions.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    result = {
        "identified_sources": len(rows),
        "local_complete_drafts": len(drafts),
        "technical_candidates": len(ready),
        "reference_maps": len(reference_maps),
        "blocked_for_review": len(rows) - len(ready),
        "source_blocks_retained": sum(r["source_blocks"] for r in rows),
        "hosted_imports": 0,
        "official_verified_claims": 0,
        "human_approvals": 0,
        "publication_ready": 0,
    }
    (args.output / "summary.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result))


if __name__ == "__main__":
    main()
