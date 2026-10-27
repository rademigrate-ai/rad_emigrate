"""Create a source-to-destination inventory without changing the sealed corpus.

Fresh crawler journals are observations, not evidence of exhaustive discovery or
editorial approval. The crawler can still be running while a snapshot is made.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

from tools.content_consolidation.parser import extract_primary
from tools.plan3_content.parser import digest, normalize_url


def jsonl(path):
    with gzip.open(path, "rt", encoding="utf-8") as stream:
        return [json.loads(line) for line in stream]


def progress(cache):
    result = {}
    for path in sorted(cache.glob("*.progress.jsonl")):
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    # The active writer may have an incomplete final line.
                    continue
                url = normalize_url(row["url"])
                prior = result.get(url)
                if (
                    row.get("fetch_status") == "robots_denied_or_unavailable"
                    and prior
                    and prior.get("fetch_status") == "fetched"
                ):
                    # An intentionally skipped host is not a new HTTP result.
                    # Retain the previous actual observation and expose the hold.
                    prior["latest_access_status"] = row["fetch_status"]
                else:
                    result[url] = row
    return result


def fresh_body(row, cache):
    if row.get("fetch_status") != "fetched":
        return None, "not_fetched"
    raw_path = cache / (row["id"] + ".html.gz")
    if not raw_path.is_file():
        return None, "missing_raw_capture"
    raw = gzip.decompress(raw_path.read_bytes())
    if hashlib.sha256(raw).hexdigest() != row.get("raw_sha256"):
        return None, "raw_hash_mismatch"
    parsed = extract_primary(raw, row.get("final_url") or row["url"])
    return parsed, "hash_verified_raw"


def make_records(sources, articles, mappings, ledger, fresh, cache):
    by_url = {normalize_url(s["url"]): s for s in sources}
    by_id = {s["source_id"]: s for s in sources}
    if len(by_url) != len(sources) or len(by_id) != len(sources):
        raise ValueError("duplicate_source_identity")
    by_source = defaultdict(list)
    for row in ledger:
        by_source[row["source_id"]].append(row)
    mapping_by_source = {row["source_id"]: row for row in mappings}
    article_by_identity = {(a["article_id"], a["locale"]): a for a in articles}
    article_ids = {a["article_id"] for a in articles}
    if len(article_by_identity) != len(articles):
        raise ValueError("duplicate_article_locale")
    for row in ledger:
        if row["source_id"] not in by_id:
            raise ValueError("orphan_source_segment")
        if row["destination_article_id"] not in article_ids:
            raise ValueError("orphan_destination_segment")

    records = []
    for url in sorted(set(by_url) | set(fresh)):
        old, observed = by_url.get(url), fresh.get(url)
        parsed, raw_status = (
            fresh_body(observed, cache) if observed else (None, "not_yet_observed")
        )
        old_hash = old.get("body_sha256") if old else None
        new_hash = (
            digest(parsed["body_text"]) if parsed and parsed.get("body_text") else None
        )
        old_structure = digest(old["blocks"]) if old and "blocks" in old else None
        new_structure = (
            digest(parsed["blocks"]) if parsed and "blocks" in parsed else None
        )
        old_links = digest(old["body_links"]) if old and "body_links" in old else None
        new_links = (
            digest(parsed["body_links"]) if parsed and "body_links" in parsed else None
        )
        if not observed:
            change = "not_recrawled"
        elif observed.get("fetch_status") != "fetched":
            change = "fresh_fetch_unresolved"
        elif raw_status != "hash_verified_raw":
            change = raw_status
        elif new_hash is None:
            change = "fresh_body_missing_or_nonarticle"
        elif not old or not old_hash:
            change = "fresh_body_requires_placement_review"
        elif old_hash == new_hash:
            if (
                old_structure is None
                or new_structure is None
                or old_links is None
                or new_links is None
            ):
                change = "body_text_unchanged_structure_or_links_unavailable"
            elif old_structure == new_structure and old_links == new_links:
                change = "body_blocks_and_links_unchanged"
            else:
                change = "structure_or_links_changed_requires_reconciliation"
        else:
            change = "body_changed_requires_reconciliation"
        entries = by_source.get(old["source_id"], []) if old else []
        mapping = mapping_by_source.get(old["source_id"], {}) if old else {}
        destinations = sorted({e["destination_article_id"] for e in entries})
        records.append(
            {
                "url": url,
                "source_id": old.get("source_id") if old else None,
                "domain": old.get("domain") if old else observed.get("domain"),
                "title": old.get("title") if old else (parsed or {}).get("title"),
                "old_disposition": old.get("consolidation_disposition")
                if old
                else "new_discovery",
                "old_fetch_status": old.get("fetch_status") if old else None,
                "old_fetch_error": old.get("fetch_error") if old else None,
                "old_body_sha256": old_hash,
                "old_structure_sha256": old_structure,
                "old_links_sha256": old_links,
                "old_complete_body": old.get("complete_article_body") if old else None,
                "fresh_fetch_status": observed.get("fetch_status")
                if observed
                else "not_observed",
                "latest_access_status": observed.get("latest_access_status")
                if observed
                else None,
                "fresh_http_status": observed.get("status") if observed else None,
                "fresh_error": observed.get("error") if observed else None,
                "fresh_retrieved_at": observed.get("retrieved_at")
                if observed
                else None,
                "fresh_raw_status": raw_status,
                "fresh_body_sha256": new_hash,
                "fresh_structure_sha256": new_structure,
                "fresh_links_sha256": new_links,
                "fresh_block_count": len(parsed.get("blocks", [])) if parsed else None,
                "change_disposition": change,
                "country_codes_proposed": mapping.get("country_codes", []),
                "visa_category_proposed": mapping.get("visa_category"),
                "mapping_status": mapping.get("mapping_status", "not_mapped"),
                "destination_article_ids": destinations,
                "segment_destination_entries": len(entries),
                "original_coverage_verified_in_staging": False,
            }
        )
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    sources = jsonl(args.corpus / "sources.jsonl.gz")
    articles = jsonl(args.corpus / "articles.jsonl.gz")
    mappings = jsonl(args.corpus / "source_destination_mapping.jsonl.gz")
    ledger = jsonl(args.corpus / "segment_preservation.jsonl.gz")
    relations = jsonl(args.corpus / "country_other_titles.jsonl.gz")
    rows = make_records(
        sources, articles, mappings, ledger, progress(args.cache), args.cache
    )
    with (args.output / "source-reconciliation.jsonl").open(
        "w", encoding="utf-8"
    ) as out:
        for row in rows:
            out.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    with (args.output / "source-reconciliation.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as out:
        writer = csv.DictWriter(out, fieldnames=list(rows[0]))
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    k: json.dumps(v, ensure_ascii=False) if isinstance(v, list) else v
                    for k, v in row.items()
                }
            )
    with (args.output / "source-section-ledger.jsonl").open(
        "w", encoding="utf-8"
    ) as out:
        for row in ledger:
            out.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    article_fields = [
        "article_id",
        "locale",
        "title",
        "content_class",
        "country_codes",
        "visa_category",
        "source_ids",
        "sections",
        "blocks",
        "proposed_other_titles_countries",
        "publication_allowed",
    ]
    countries = defaultdict(set)
    for relation in relations:
        countries[(relation["article_id"], relation["locale"])].add(
            relation["country_code"]
        )
    with (args.output / "article-inventory.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as out:
        writer = csv.DictWriter(out, fieldnames=article_fields)
        writer.writeheader()
        for article in articles:
            writer.writerow(
                {
                    "article_id": article["article_id"],
                    "locale": article["locale"],
                    "title": article["title"],
                    "content_class": article["content_class"],
                    "country_codes": json.dumps(article.get("country_codes", [])),
                    "visa_category": article.get("visa_category"),
                    "source_ids": json.dumps(article["source_ids"]),
                    "sections": len(article["sections"]),
                    "blocks": sum(
                        len(section["blocks"]) for section in article["sections"]
                    ),
                    "proposed_other_titles_countries": json.dumps(
                        sorted(countries[(article["article_id"], article["locale"])])
                    ),
                    "publication_allowed": article["publication_allowed"],
                }
            )
    summary = {
        "historical_sources": len(sources),
        "article_locales": len(articles),
        "segment_destination_entries": len(ledger),
        "observed_urls": len(progress(args.cache)),
        "all_known_urls": len(rows),
        "dispositions": dict(Counter(r["change_disposition"] for r in rows)),
        "domains": dict(Counter(r["domain"] for r in rows)),
        "historical_dispositions": dict(Counter(r["old_disposition"] for r in rows)),
        "captured_segment_statuses": dict(Counter(r["status"] for r in ledger)),
        "limitations": [
            "Crawler may be incomplete",
            "Mapping and legal content require human review",
            "No proof of live CMS equivalence or rendered coverage",
        ],
    }
    (args.output / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
