"""Build a source-faithful, immutable Visa *display* snapshot from reviewed candidate batches.

This is not a CMS migration, an editorial approval, or a publication receipt.
It generates a read-only, integrity-bound frontend delivery candidate. The
owner's manual deployment is the separate release decision; 23 holds are
excluded. Source captures remain private and outside the shipped asset tree.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path
from urllib.parse import urlsplit

PACKAGE_SHA = "4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282"
PRIMARY_HOSTS = {"digivisa.ir", "radvisa.com", "radmohajer.ir"}
EXPECTED = {
    "operations": 1100,
    "candidates": 1077,
    "held": 23,
    "batches": 44,
    "countries": 56,
    "countryless": 251,
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def safe_url(value: object) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlsplit(value)
    return (
        parsed.scheme in ("https", "http")
        and bool(parsed.hostname)
        and not (parsed.username or parsed.password)
    )


def compact_block(block: dict) -> dict:
    """Do not rewrite authored words, list cells, original formatting or URLs."""
    original = block.get("original_structure")
    result = {"id": block["id"], "type": block.get("type", "paragraph")}
    if isinstance(original, dict):
        result["original_structure"] = original
    else:
        result["text"] = block.get("text", "")
        if "heading_level" in block:
            result["heading_level"] = block["heading_level"]
    selected = block.get("selected_origin")
    if isinstance(selected, dict):
        result["selected_origin"] = {
            k: selected[k]
            for k in (
                "source_id",
                "source_variant_id",
                "publisher",
                "sha256",
                "block_index",
                "start",
                "end",
            )
            if k in selected
        }
    return result


def build_article(entry: dict, eligible_ids: set[str]) -> tuple[dict, dict]:
    payload_text = entry["payload_text"]
    if sha(payload_text.encode("utf-8")) != entry["payload_sha256"]:
        raise ValueError("payload_sha256_mismatch")
    payload = json.loads(payload_text)
    item = payload["item"]
    article_id, locale = item["article_id"], item["locale"]
    if locale not in ("fa", "en") or not item["sections"]:
        raise ValueError("bad_article_locale_or_missing_body")
    if item["composition_policy"] != "RAD_CONTENT_PRECEDENCE_V4.1":
        raise ValueError("source_precedence_missing")
    if item.get("verification_state") != "unverified":
        raise ValueError("unexpected_factual_verification_status")
    if (
        item.get("publication_allowed") is not False
        or item.get("published") is not False
    ):
        raise ValueError("cannot_relabel_candidate_as_approved")
    if item.get("conflicts"):
        raise ValueError("unresolved_article_conflict")
    sources = []
    for source in payload["sources"]:
        body = source.get("body_text")
        if (
            not isinstance(body, str)
            or sha(body.encode("utf-8")) != source["body_sha256"]
        ):
            raise ValueError("original_source_body_hash_mismatch")
        url = source.get("url")
        if (
            not safe_url(url)
            or urlsplit(url).hostname.removeprefix("www.") not in PRIMARY_HOSTS
        ):
            raise ValueError("invalid_primary_source_url")
        sources.append(
            {
                "url": url,
                "publisher": urlsplit(url).hostname.removeprefix("www."),
                "retrieved_at": source.get("retrieved_at"),
                "source_variant_id": source.get(
                    "source_variant_id", source.get("source_id")
                ),
                "body_sha256": source["body_sha256"],
            }
        )
    if not sources:
        raise ValueError("missing_primary_source")
    sections = []
    for section in item["sections"]:
        blocks = [compact_block(b) for b in section["blocks"]]
        if not blocks:
            raise ValueError("missing_source_blocks")
        sections.append(
            {
                "id": section["id"],
                "heading": section.get("heading", ""),
                "heading_path": section.get("heading_path", []),
                "program": section.get("program"),
                "blocks": blocks,
            }
        )
    links = []
    for link in item.get("source_links", []):
        url = link.get("original_url") or link.get("url")
        if not safe_url(url):
            continue
        record = {
            k: link[k]
            for k in (
                "url",
                "original_url",
                "label",
                "target_block_id",
                "app_locale",
                "app_fragment",
            )
            if k in link
        }
        record["url"] = url
        evidence = link.get("href_evidence")
        if isinstance(evidence, dict):
            record["href_evidence"] = {"confirmed": evidence.get("confirmed", False)}
        target = link.get("app_article_id")
        if target in eligible_ids:
            record["app_article_id"] = target
            record["frozen_target_verified"] = True
        links.append(record)
    doc = {
        "id": article_id,
        "article_id": article_id,
        "revision_id": entry["revision_id"],
        "locale": locale,
        "title": item["title"],
        "country_codes": item["country_codes"],
        "content_class": item["content_class"],
        "visa_category": item.get("visa_category"),
        "category": item.get("category"),
        "rich_sections": sections,
        "projection_map": item.get("projection_map", []),
        "sources": sources,
        "source_links": links,
        "source_publishers": item.get("source_publishers", []),
        "source_assets": [],  # Do not ship unapproved media.
        "publication_basis": "source_faithful",
        "delivery_mode": "frozen_source_readonly",
        "verification_state": "unverified",
        "editorial_approved": False,
        "references_capture_status": "not_captured",
        "source_payload_sha256": entry["payload_sha256"],
        "source_policy": "RAD_CONTENT_PRECEDENCE_V4.1",
    }
    row = {
        "id": article_id,
        "locale": locale,
        "title": item["title"],
        "country_codes": item["country_codes"],
        "content_class": item["content_class"],
        "visa_category": item.get("visa_category"),
        "source_publishers": item.get("source_publishers", []),
        "revision_id": entry["revision_id"],
    }
    return doc, row


def build(package: Path, output: Path) -> dict:
    release = json.loads(
        (package / "publication" / "release-plan.json").read_text("utf-8")
    )
    if release["package_sha256"] != PACKAGE_SHA or any(
        release[k] != v
        for k, v in [
            ("operations", EXPECTED["operations"]),
            ("eligible_proposals", EXPECTED["candidates"]),
            ("held", EXPECTED["held"]),
            ("approved", 0),
            ("published", 0),
        ]
    ):
        raise ValueError("incorrect_or_unapproved_corrected_release_plan")
    dispositions = release["dispositions"]
    if len(dispositions) != EXPECTED["operations"]:
        raise ValueError("missing_dispositions")
    eligible = {d["revision_id"] for d in dispositions if not d["holds"]}
    held = {d["revision_id"] for d in dispositions if d["holds"]}
    if len(eligible) != EXPECTED["candidates"] or len(held) != EXPECTED["held"]:
        raise ValueError("candidate_or_hold_count_mismatch")
    batches = sorted((package / "publication").glob("batch-*.approval-request.json"))
    if len(batches) != EXPECTED["batches"]:
        raise ValueError("incorrect_batch_inventory")

    # Fail closed before modifying any committed output.
    entries = {}
    article_ids = set()
    batch_members = 0
    for path in batches:
        raw = path.read_bytes()
        req = json.loads(raw)
        if sha(req["p_manifest_text"].encode("utf-8")) != req["p_manifest_sha256"]:
            raise ValueError("manifest_sha256_mismatch")
        for entry in json.loads(req["p_manifest_text"]):
            rev = entry["revision_id"]
            if rev in entries or rev not in eligible or rev in held:
                raise ValueError("duplicate_or_held_revision_in_batch")
            data = json.loads(entry["payload_text"])["item"]
            if data["article_id"] not in article_ids:
                article_ids.add(data["article_id"])
            entries[rev] = entry
            batch_members += 1
    if set(entries) != eligible or batch_members != EXPECTED["candidates"]:
        raise ValueError("release_batch_membership_does_not_match_dispositions")

    # One asset per article/locale, never loaded until opened by the reader.
    articles_dir = output / "articles"
    if output.exists():
        raise FileExistsError(
            f"Refusing to overwrite immutable content snapshot: {output}"
        )
    articles_dir.mkdir(parents=True)
    rows = []
    countries = set()
    countryless = 0
    shipped_block_count = 0
    total_plain = total_gzip = 0
    for _rev, entry in sorted(entries.items()):
        doc, row = build_article(entry, article_ids)
        name = f"{doc['id']}_{doc['locale']}.json.gz"
        serialized = canonical(doc)
        packed = gzip.compress(serialized, compresslevel=9, mtime=0)
        (articles_dir / name).write_bytes(packed)
        row.update(
            {
                "asset": f"assets/visa_frozen_content/articles/{name}",
                "sha256": sha(serialized),
                "compressed_sha256": sha(packed),
                "block_count": sum(len(s["blocks"]) for s in doc["rich_sections"]),
            }
        )
        shipped_block_count += row["block_count"]
        rows.append(row)
        countries.update(row["country_codes"])
        if not row["country_codes"]:
            countryless += 1
        total_plain += len(serialized)
        total_gzip += len(packed)
    if (
        len(rows) != EXPECTED["candidates"]
        or len(countries) != EXPECTED["countries"]
        or countryless != EXPECTED["countryless"]
    ):
        raise ValueError("source_distribution_mismatch")
    index = {
        "format": "RAD_FROZEN_VISA_DELIVERY_V1",
        "source_package_sha256": PACKAGE_SHA,
        "publication_basis": "source_faithful_candidate",
        "editorial_approved": False,
        "update_mode": "read_only",
        "production_database_written": False,
        "verification_state": "unverified",
        "total_candidates": len(rows),
        "held_excluded": EXPECTED["held"],
        "countries_count": len(countries),
        "independent_other_titles": countryless,
        "source_blocks_renderable": shipped_block_count,
        "articles": sorted(rows, key=lambda r: (r["id"], r["locale"])),
    }
    (output / "index.json").write_bytes(canonical(index))
    report = {
        "index_sha256": sha((output / "index.json").read_bytes()),
        "article_files": len(rows),
        "countries": len(countries),
        "countryless": countryless,
        "total_rendered_blocks": shipped_block_count,
        "uncompressed_bytes": total_plain,
        "compressed_bytes": total_gzip,
        "private_capture_files_shipped": 0,
        "held_articles_shipped": 0,
        "human_approvals": 0,
    }
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.package, args.output), sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
