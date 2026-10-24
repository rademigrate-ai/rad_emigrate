"""Offline inspection/validation; no network or hosted mutation commands."""

import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path

from .dataset import read_jsonl, validate_package
from .importer import load_import


def verify_checksums(directory):
    root = directory.resolve()
    seen = set()
    for line in (root / "CHECKSUMS.sha256").read_text(encoding="utf8").splitlines():
        expected, name = line.split("  ", 1)
        target = (root / name).resolve()
        if not target.is_relative_to(root) or name in seen or len(expected) != 64:
            raise ValueError("unsafe_checksum_entry")
        if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            raise ValueError("checksum_mismatch:" + name)
        seen.add(name)
    actual = {
        p.relative_to(root).as_posix()
        for p in root.rglob("*")
        if p.is_file() and p.name != "CHECKSUMS.sha256"
    }
    if seen != actual:
        raise ValueError("checksum_inventory_mismatch")
    return {"files_verified": len(seen), "status": "PASS"}


def verify_library(directory, registry):
    verify_checksums(directory)
    load_import(directory / "10_CMS_DRAFT_IMPORT_PACKAGE.json", registry)
    m = json.loads((directory / "PLAN3_MANIFEST.json").read_text(encoding="utf8"))
    sources = read_jsonl(directory / "data/sources.jsonl.gz")
    canonical = read_jsonl(directory / "data/canonical_articles.jsonl.gz")
    drafts = read_jsonl(directory / "data/cms_drafts.jsonl.gz")
    by_source = {s["source_id"]: s for s in sources}
    with (directory / "01_SOURCE_DISCOVERY_INVENTORY.csv").open(
        encoding="utf8", newline=""
    ) as f:
        inventory = list(csv.DictReader(f))
    if len(inventory) != len(sources) or {r["source_id"] for r in inventory} != set(
        by_source
    ):
        raise ValueError("inventory_source_mismatch")
    if len({s["url"] for s in sources}) != len(sources):
        raise ValueError("duplicate_inventory_url")
    counts = {
        "discovered_urls": len(sources),
        "canonical_drafts": len(canonical),
        "successfully_retrieved_pages": sum(
            s["fetch_status"] == "fetched" for s in sources
        ),
        "complete_article_bodies": sum(s["complete_article_body"] for s in sources),
        "structurally_valid_draft_payloads": sum(
            a["validation"]["draft_payload_valid"] for a in drafts
        ),
    }
    if any(m[k] != v for k, v in counts.items()) or m["fetch_states"] != dict(
        Counter(s["fetch_status"] for s in sources)
    ):
        raise ValueError("manifest_counts_mismatch")
    from .dataset import digest, digest_bytes

    for c in canonical:
        primary = by_source[c["primary_source_id"]]
        if (
            c["body_text"] != primary["body_text"]
            or digest(c["body_text"]) != c["body_sha256"]
        ):
            raise ValueError("canonical_body_mismatch")
        if not set(c["source_ids"]) <= set(by_source):
            raise ValueError("canonical_provenance_missing")
    if {c["canonical_id"] for c in canonical} != {a["canonical_id"] for a in drafts}:
        raise ValueError("canonical_draft_mismatch")
    root = Path(__file__).resolve().parents[2]
    for name, expected in m["pipeline_file_sha256"].items():
        target = (root / name).resolve()
        if (
            not target.is_relative_to(root)
            or digest_bytes(target.read_bytes()) != expected
        ):
            raise ValueError("pipeline_version_mismatch")
    return {
        "status": "PASS",
        "counts": counts,
        "publication_ready": 0,
        "hosted_mutations": False,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="mode", required=True)
    v = sub.add_parser("validate")
    v.add_argument("--package", type=Path, required=True)
    v.add_argument(
        "--registry", type=Path, default=Path("supabase/contracts/rad_v1.json")
    )
    c = sub.add_parser("checksums")
    c.add_argument("--directory", type=Path, required=True)
    library_parser = sub.add_parser("library")
    library_parser.add_argument("--directory", type=Path, required=True)
    library_parser.add_argument(
        "--registry", type=Path, default=Path("supabase/contracts/rad_v1.json")
    )
    i = sub.add_parser("inspect")
    i.add_argument("--directory", type=Path, required=True)
    i.add_argument("--canonical-id", required=True)
    i.add_argument("--output", type=Path)
    a = p.parse_args()
    if a.mode == "validate":
        load_import(a.package, a.registry)
        result = validate_package(a.package, a.registry)
    elif a.mode == "checksums":
        result = verify_checksums(a.directory)
    elif a.mode == "library":
        result = verify_library(a.directory, a.registry)
    else:
        records = read_jsonl(a.directory / "data/canonical_articles.jsonl.gz")
        result = next((r for r in records if r["canonical_id"] == a.canonical_id), None)
        if result is None:
            raise ValueError("canonical_article_not_found")
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if a.mode == "inspect" and a.output:
        a.output.write_text(rendered, encoding="utf8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
