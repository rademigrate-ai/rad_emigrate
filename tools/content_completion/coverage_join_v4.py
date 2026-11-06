"""Join independently collected source, database and application evidence.

Never infer rendering from an import row or from composition alone. Missing
receipts keep the gate red. Raw URL discoveries of unknown eligibility stay
explicitly unresolved rather than being counted as recovered/excluded articles.
"""

import argparse
import gzip
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path


def read_rows(path):
    if not path.exists():
        return []
    if path.suffix == ".json":
        value = json.loads(path.read_text("utf-8"))
        if not isinstance(value, list):
            raise ValueError("expected_receipt_array:" + str(path))
        return value
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def join_evidence(inventory, sources, articles, database, render, environment=None):
    by_destination = {(a["article_id"], a["locale"]): a for a in articles}
    errors = []
    if not inventory or not sources or not articles:
        errors.append("empty_inventory_sources_or_composition")
    if len(by_destination) != len(articles):
        errors.append("duplicate_article_locale")
    captured_inventory = {
        r["url"]
        for r in inventory
        if r.get("disposition") == "CONTENT_CAPTURED" and r.get("url")
    }
    extraction_gaps = sorted(captured_inventory - {s["url"] for s in sources})
    if extraction_gaps:
        errors.append("captured_inventory_missing_source_bodies")
    db = {(r["article_id"], r["locale"]): r for r in database}
    ui = {(r["article_id"], r["locale"]): r for r in render}
    if len(db) != len(database) or len(ui) != len(render):
        errors.append("duplicate_database_or_render_receipts")
    if environment and any(
        row.get("environment") != environment for row in database + render
    ):
        errors.append("receipt_environment_missing_or_mismatched")
    if len({(s["source_id"], s["snapshot_id"]) for s in sources}) != len(sources):
        errors.append("duplicate_source_snapshot")
    segment_targets = defaultdict(list)
    for article in articles:
        key = (article["article_id"], article["locale"])
        receipt = db.get(key, {})
        screen = ui.get(key, {})
        database_ok = (
            not environment or receipt.get("environment") == environment
        ) and all(
            receipt.get(k) is True
            for k in (
                "revision_exists",
                "rich_sections_match",
                "reader_sections_match",
                "source_references_valid",
                "composition_payload_match",
                "placement_matches",
            )
        )
        screen_ok = (
            (not environment or screen.get("environment") == environment)
            and screen.get("route_opened") is True
            and screen.get("body_render_verified") is True
            and screen.get("full_api_structure_verified") is True
            and not screen.get("console_errors")
        )
        revision_ok = bool(receipt.get("revision_id")) and screen.get(
            "revision_id"
        ) == receipt.get("revision_id")
        for ref in article["segment_ledger"]:
            segment_targets[
                (ref["source_id"], ref["snapshot_id"], ref["block_index"])
            ].append(
                {
                    "article_id": key[0],
                    "locale": key[1],
                    "content_class": article["content_class"],
                    "retained_block_id": ref["represented_block_id"],
                    "decision": ref["status"],
                    "article_revision": receipt.get("revision_id"),
                    "app_destination": f"/visa/content/{key[0]}?locale={key[1]}&preview=true",
                    "database_verified": database_ok,
                    "render_verification": screen_ok and revision_ok,
                    "render_probe": screen.get("render_probe"),
                }
            )
    lineage = []
    fully_transferred = 0
    verified_by_url = defaultdict(list)
    visa_sources, other_sources, merged_sources = set(), set(), set()
    missing_composition = missing_database = missing_render = 0
    for source in sources:
        complete = bool(source["blocks"])
        if not complete:
            errors.append("empty_source_body:" + source["url"])
        rows = []
        for index, block in enumerate(source["blocks"]):
            targets = segment_targets[
                (source["source_id"], source["snapshot_id"], index)
            ]
            if not targets:
                missing_composition += 1
            if not any(t["database_verified"] for t in targets):
                missing_database += 1
            if not any(
                t["database_verified"] and t["render_verification"] for t in targets
            ):
                missing_render += 1
                complete = False
            for target in targets:
                if target["database_verified"] and target["render_verification"]:
                    (
                        visa_sources
                        if target["content_class"] == "canonical"
                        else other_sources
                    ).add(source["url"])
                    article = by_destination[(target["article_id"], target["locale"])]
                    if len(set(article["source_urls"])) > 1:
                        merged_sources.add(source["url"])
            rows.append(
                {
                    "source_block_index": index,
                    "structure_sha256": hashlib.sha256(
                        json.dumps(
                            block,
                            ensure_ascii=False,
                            sort_keys=True,
                            separators=(",", ":"),
                        ).encode("utf-8")
                    ).hexdigest(),
                    "block_type": block["type"],
                    "destinations": targets,
                }
            )
        fully_transferred += complete
        verified_by_url[source["url"]].append(complete)
        lineage.append(
            {
                "source_url": source["url"],
                "source_id": source["source_id"],
                "source_snapshot": source["snapshot_id"],
                "raw_html_sha256": source["raw_html_sha256"],
                "source_body_sha256": source["body_sha256"],
                "fully_verified_transfer": complete,
                "original_blocks": rows,
            }
        )
    dispositions = Counter(r["disposition"] for r in inventory)
    verified_urls = {url for url, states in verified_by_url.items() if all(states)}
    # Page counts require every captured version and segment to be represented;
    # a single successful block may not inflate a partially transferred page.
    visa_sources &= verified_urls
    other_sources &= verified_urls
    merged_sources &= verified_urls
    missing_destinations = []
    for key in by_destination:
        r = db.get(key, {})
        s = ui.get(key, {})
        if not (
            (not environment or r.get("environment") == environment)
            and (not environment or s.get("environment") == environment)
            and r.get("revision_exists") is True
            and r.get("rich_sections_match") is True
            and r.get("reader_sections_match") is True
            and r.get("source_references_valid") is True
            and r.get("composition_payload_match") is True
            and r.get("placement_matches") is True
            and s.get("route_opened") is True
            and s.get("body_render_verified") is True
            and s.get("full_api_structure_verified") is True
            and not s.get("console_errors")
            and s.get("revision_id") == r.get("revision_id")
        ):
            missing_destinations.append({"article_id": key[0], "locale": key[1]})
    recovered_ok = not (
        errors
        or missing_composition
        or missing_database
        or missing_render
        or missing_destinations
    )
    unresolved = sum(v for k, v in dispositions.items() if "UNRESOLVED" in k)
    report = {
        "status": "PASS" if recovered_ok and not unresolved else "FAIL",
        "environment": environment or "UNSPECIFIED_TEST_INPUT",
        "recovered_corpus_status": "PASS" if recovered_ok else "FAIL",
        "discovered_url_records": len(inventory),
        "url_dispositions": dict(dispositions),
        "complete_source_snapshot_variants": len(sources),
        "complete_source_urls": len({s["url"] for s in sources}),
        "fully_verified_source_snapshot_transfers": fully_transferred,
        "fully_verified_source_url_transfers": sum(
            all(states) for states in verified_by_url.values()
        ),
        "source_urls_represented_in_merged_articles": len(merged_sources),
        "source_urls_available_in_visa_cards": len(visa_sources),
        "source_urls_available_in_other_titles": len(other_sources),
        "composed_article_locales": len(articles),
        "composed_classes": dict(Counter(a["content_class"] for a in articles)),
        "source_segments_without_composition": missing_composition,
        "source_segments_without_database_verification": missing_database,
        "source_segments_without_render_verification": missing_render,
        "destinations_without_complete_evidence": missing_destinations,
        "unresolved_discovery_records": unresolved,
        "unrecoverable_claims": dispositions.get("SOURCE_UNRECOVERABLE", 0),
        "errors": errors,
        "captured_urls_without_source_bodies": extraction_gaps,
        "public_production_release": "PENDING_SEPARATE_OWNER_AUTHORIZATION",
        "limitation": "Browser probes must identify their actual scope; source/body/hash checks do not by themselves prove every visual pixel or media URL.",
    }
    return report, lineage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028")
    )
    parser.add_argument("--inventory", type=Path)
    parser.add_argument("--composition", type=Path)
    parser.add_argument("--database", type=Path)
    parser.add_argument("--render", type=Path)
    parser.add_argument("--environment", default="staging:epolbumcfbohtmgvomki")
    args = parser.parse_args()
    root = args.root
    report, lineage = join_evidence(
        read_rows(args.inventory or root / "recovery-ready-sources/inventory.jsonl.gz"),
        read_rows((args.composition or root / "composition") / "sources.jsonl.gz")
        + read_rows(
            (args.composition or root / "composition") / "supplements.jsonl.gz"
        ),
        read_rows((args.composition or root / "composition") / "articles.jsonl.gz"),
        read_rows(args.database or root / "database-receipts.jsonl.gz"),
        read_rows(args.render or root / "render-receipts.jsonl.gz"),
        args.environment,
    )
    with gzip.open(
        root / "RAD_FULL_SOURCE_PROVENANCE.jsonl.gz", "wt", encoding="utf-8"
    ) as stream:
        for row in lineage:
            stream.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    (root / "RAD_APPLICATION_CONTENT_COVERAGE.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                k: v
                for k, v in report.items()
                if k != "destinations_without_complete_evidence"
            }
        )
    )
    raise SystemExit(0 if report["status"] == "PASS" else 1)


if __name__ == "__main__":
    main()
