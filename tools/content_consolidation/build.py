"""Offline correction and full-fidelity country/category consolidation of the sealed library.

No network, hosted write, legal verification or publication is performed here.
Every old URL has a disposition; snapshots change when corrected text changes.
"""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import digest, search_normalize
from tools.plan3_content.taxonomy import classify

from .parser import extract_primary

PRIMARY = {"radvisa.com", "digivisa.ir"}
STOP = {"کشور"}  # Direction, conditions, audience and year are scope-bearing.
CATEGORIES = {
    "university": ("دانشگاه", "کالج", "university", "college"),
    "living-costs": ("هزینه زندگی", "هزینه های زندگی", "cost of living"),
    "qualifications": ("معادل سازی", "آزمون", "ارزشیابی", "qualification", "exam"),
    "education": ("تحصیل", "بورسیه", "مدرسه", "study", "education"),
    "culture-living": ("فرهنگ", "زندگی", "living", "culture"),
    "migration": ("ویزا", "مهاجرت", "اقامت", "visa", "immigration"),
}


def title_key(title):
    value = search_normalize(title).replace("\u200c", " ")
    return " ".join(t for t in re.findall(r"[\w]+", value) if t not in STOP)


def category(title):
    value = search_normalize(title)
    return next(
        (key for key, words in CATEGORIES.items() if any(w in value for w in words)),
        "general-guide",
    )


def topic_key(source):
    # Country alone, a broad pathway or a same-site page date never proves scope.
    return (
        source["language"],
        tuple(source["taxonomy"]["country_codes"]),
        source["taxonomy"]["pathway"],
        title_key(source["title"]),
    )


def consolidate(members):
    from .composition import compose

    if (
        "radmohajer.ir" in {s["domain"] for s in members}
        and len({s["domain"] for s in members}) > 1
    ):
        raise ValueError("supplementary_source_must_remain_standalone")
    first = members[0]
    return compose(
        members,
        uid("independent:" + digest(topic_key(first))),
        first["title"],
        first["taxonomy"]["country_codes"],
    )


def build(library, caches, output, capture=None, capture_sha256=None):
    output.mkdir(parents=True, exist_ok=True)
    old = read_jsonl(library / "data/sources.jsonl.gz")
    corrected, corrections = [], []
    captured = {}
    if capture is not None:
        if (
            not capture_sha256
            or hashlib.sha256(capture.read_bytes()).hexdigest() != capture_sha256
        ):
            raise ValueError("extraction_capture_checksum_required")
        rows = read_jsonl(capture)
        captured = {row["source_id"]: row for row in rows}
        if len(captured) != len(rows) or set(captured) != {
            row["source_id"] for row in old
        }:
            raise ValueError("extraction_capture_source_inventory_mismatch")
    for source in old:
        if captured:
            row = copy.deepcopy(captured[source["source_id"]])
            if (
                row["url"] != source["url"]
                or row["raw_html_sha256"] != source["raw_html_sha256"]
            ):
                raise ValueError("extraction_capture_origin_mismatch")
            if source["fetch_status"] == "fetched":
                if row["previous_extraction"]["body_sha256"] != source["body_sha256"]:
                    raise ValueError("extraction_capture_lineage_mismatch")
                corrections.append(
                    {
                        "source_id": source["source_id"],
                        "url": source["url"],
                        "old_body_sha256": source["body_sha256"],
                        "new_body_sha256": row["body_sha256"],
                        "changed": source["body_sha256"] != row["body_sha256"],
                        "old_complete": source["complete_article_body"],
                        "new_complete": row["complete_article_body"],
                        "omitted_regions": row["omitted_regions"],
                    }
                )
            corrected.append(row)
            continue
        row = copy.deepcopy(source)
        if source["fetch_status"] != "fetched":
            row["consolidation_disposition"] = "retained_" + source["fetch_status"]
            corrected.append(row)
            continue
        raw = None
        for cache in caches:
            p = cache / (source["collector_id"] + ".html.gz")
            if p.is_file():
                candidate = gzip.decompress(p.read_bytes())
                if hashlib.sha256(candidate).hexdigest() == source["raw_html_sha256"]:
                    raw = candidate
                    break
        if raw is None:
            row["consolidation_disposition"] = "blocked_missing_hash_verified_raw_html"
            corrected.append(row)
            continue
        parsed = extract_primary(raw, source["resolved_url"] or source["url"])
        body = parsed["body_text"]
        row["previous_extraction"] = {
            "body_sha256": source["body_sha256"],
            "snapshot_id": source["snapshot_id"],
            "complete_article_body": source["complete_article_body"],
        }
        row.update(
            body_text=body,
            blocks=parsed["blocks"],
            body_sha256=digest(body) if body else None,
            body_status=parsed["body_status"],
            language=parsed["language"],
            parser_selector=parsed["selector"],
            body_links=parsed.get("body_links", []),
            source_assets=parsed.get("source_assets", []),
            omitted_regions=parsed.get("omitted_regions", []),
        )
        row["taxonomy"] = classify(parsed["title"], source["url"])
        row["title"] = parsed["title"]
        # English proper names in a Persian university table are not a reviewed
        # English translation. The narrative/title language remains Persian.
        if (
            re.search(r"[\u0600-\u06ff]", row["title"])
            and len(re.findall(r"[\u0600-\u06ff]", body)) >= 50
        ):
            row["language"] = "fa"
        row["snapshot_id"] = (
            uid("snapshot:" + source["source_id"] + ":" + digest(body))
            if body
            else None
        )
        row["complete_article_body"] = bool(
            parsed["body_status"] == "complete_source_container"
            and len(body) >= 300
            and row["taxonomy"]["page_type"] in ("article", "news")
            and row["language"] in ("fa", "en")
        )
        if re.search(
            r"^/(?:catarticle|catnews|faq|formid|search)(?:/|$)",
            __import__("urllib.parse", fromlist=["urlsplit"])
            .urlsplit(source["url"])
            .path,
        ):
            row["complete_article_body"] = False
            row["taxonomy"]["page_type"] = "navigation_or_interactive_page"
        row["consolidation_disposition"] = (
            "body_ready_for_unreviewed_composition"
            if row["complete_article_body"]
            else "nonarticle_or_incomplete_requires_review"
        )
        corrections.append(
            {
                "source_id": source["source_id"],
                "url": source["url"],
                "old_body_sha256": source["body_sha256"],
                "new_body_sha256": row["body_sha256"],
                "changed": source["body_sha256"] != row["body_sha256"],
                "old_complete": source["complete_article_body"],
                "new_complete": row["complete_article_body"],
                "omitted_regions": row["omitted_regions"],
            }
        )
        corrected.append(row)
    write_jsonl(
        output / "extraction_capture.jsonl.gz",
        [
            {
                k: v
                for k, v in row.items()
                if k not in ("destinations", "inclusion_status")
            }
            for row in corrected
        ],
    )
    from .composition import compose_library

    articles, mappings, relations, country_relations = compose_library(
        corrected, title_key, topic_key
    )
    supplementary = [a for a in articles if a["source_publishers"] == ["radmohajer.ir"]]
    write_jsonl(output / "source_destination_mapping.jsonl.gz", mappings)
    write_jsonl(output / "country_other_titles.jsonl.gz", country_relations)
    ledger = [r for a in articles for r in a["segment_ledger"]]
    write_jsonl(output / "segment_preservation.jsonl.gz", ledger)
    # Every substantive block is either preserved or exactly represented by a
    # structurally identical block. Unavailable pages retain explicit states.
    represented = {(r["source_id"], r["block_index"]) for r in ledger}
    missing = [
        {"source_id": s["source_id"], "block_index": i, "sha256": digest(b["text"])}
        for s in corrected
        if s.get("consolidation_disposition") == "body_ready_for_unreviewed_composition"
        for i, b in enumerate(s["blocks"])
        if (s["source_id"], i) not in represented
    ]
    write_jsonl(output / "unaccounted_segments.jsonl.gz", missing)
    if missing:
        raise ValueError("unique_source_segments_unaccounted_for")
    destinations = defaultdict(list)
    for a in articles:
        for source_id in a["source_ids"]:
            destinations[source_id].append(
                {
                    "article_id": a["article_id"],
                    "locale": a["locale"],
                    "content_class": a["content_class"],
                    "visa_category": a["visa_category"],
                }
            )
    for source in corrected:
        source["destinations"] = destinations[source["source_id"]]
        classes = {x["content_class"] for x in source["destinations"]}
        source["inclusion_status"] = (
            "partially_in_main_and_complete_other_titles"
            if classes == {"canonical", "editorial"}
            else "included_in_main_visa_content_pending_verification"
            if classes == {"canonical"}
            else "independent_other_titles_pending_review"
            if classes == {"editorial"}
            else source["consolidation_disposition"]
        )
    write_jsonl(output / "sources.jsonl.gz", corrected)
    write_jsonl(output / "articles.jsonl.gz", articles)
    write_jsonl(output / "extraction_corrections.jsonl.gz", corrections)
    write_jsonl(output / "relations.jsonl.gz", relations)
    write_jsonl(
        output / "claims_review_queue.jsonl.gz",
        [{"article_id": a["article_id"], **c} for a in articles for c in a["claims"]],
    )
    summary = {
        "schema_version": "rad-country-category-consolidation-v3",
        "original_manifest_sha256": hashlib.sha256(
            (library / "PLAN3_MANIFEST.json").read_bytes()
        ).hexdigest(),
        "url_dispositions": len(corrected),
        "dispositions": dict(
            Counter(s["consolidation_disposition"] for s in corrected)
        ),
        "corrected_complete_bodies": sum(
            s["complete_article_body"]
            and s["consolidation_disposition"]
            == "body_ready_for_unreviewed_composition"
            for s in corrected
        ),
        "extraction_changed": sum(c["changed"] for c in corrections),
        "article_candidates": len(articles),
        "country_category_proposals": sum(
            a["content_class"] == "canonical" for a in articles
        ),
        "two_primary_source_canonical_proposals": sum(
            a["content_class"] == "canonical" and set(a["source_publishers"]) == PRIMARY
            for a in articles
        ),
        "source_segments_accounted": len(represented),
        "unaccounted_segments": len(missing),
        "country_other_titles_proposals": len(country_relations),
        "standalone_supplementary": len(supplementary),
        "related_proposals": len(relations),
        "categories": dict(Counter(a["category"] for a in articles)),
        "languages": dict(Counter(a["locale"] for a in articles)),
        "verified_legal_claims": 0,
        "human_approved_articles": 0,
        "publication_ready": 0,
        "pipeline_sha256": {
            str(p).replace("\\", "/"): hashlib.sha256(
                p.read_bytes().replace(b"\r\n", b"\n")
            ).hexdigest()
            for p in sorted(Path("tools/content_consolidation").glob("*.py"))
        },
        "files": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(output.glob("*.gz"))
        },
    }
    (output / "manifest.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
    )
    return summary


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--library", type=Path, required=True)
    p.add_argument("--cache", type=Path, action="append", default=[])
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--capture", type=Path)
    p.add_argument("--capture-sha256")
    args = p.parse_args()
    print(
        json.dumps(
            build(
                args.library, args.cache, args.output, args.capture, args.capture_sha256
            ),
            ensure_ascii=False,
        )
    )
