"""Finish a source checkpoint using immutable raw URL and heading evidence.

No network or broad HTML body re-extraction. Discovery-only surrogate escapes
allow auditing intact hrefs around an invalid byte; damaged body text is never
invented or promoted by this adapter.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import html
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from tools.content_completion.full_recovery_v4 import (
    decode_html,
    known_nonarticle_route,
)
from tools.content_completion.phase_bundle import save_json
from tools.content_completion.recovery_cache_repair_v4 import (
    anchor_evidence,
    correct_export_languages,
    reconcile_exact_source_aliases,
)
from tools.plan3_content.crawl import stable_id
from tools.plan3_content.dataset import read_jsonl, write_jsonl
from tools.plan3_content.parser import digest, text

HEADING = re.compile(
    r"<!--.*?-->|<script\b.*?</script\s*>|<style\b.*?</style\s*>|<h(?P<level>[1-6])\b[^>]*>(?P<inner>.*?)</h(?P=level)\s*>",
    re.IGNORECASE | re.DOTALL,
)


def headings(raw, content_type=""):
    try:
        decoded, encoding = decode_html(raw, content_type)
        document = decoded.decode("utf-8")
    except (UnicodeError, LookupError):
        document, encoding = (
            raw.decode("utf-8", errors="surrogateescape"),
            "utf-8-surrogateescape-evidence-only",
        )
    found = defaultdict(list)
    for match in HEADING.finditer(document):
        if not match["level"]:
            continue
        label = text(html.unescape(re.sub(r"<[^>]*>", " ", match["inner"])))
        if any(0xD800 <= ord(c) <= 0xDFFF for c in label):
            continue
        raw_tag = match.group()
        if any(0xD800 <= ord(c) <= 0xDFFF for c in raw_tag):
            continue
        found[label].append(
            {
                "level": int(match["level"]),
                "raw_heading_tag": raw_tag,
                "raw_heading_sha256": digest(raw_tag),
                "decoded_character_start": match.start(),
                "decoded_character_end": match.end(),
            }
        )
    return found, encoding


def bind_heading_levels(source, matches, encoding):
    rows = []
    for index, block in enumerate(source["blocks"]):
        if block["type"] != "heading":
            continue
        candidates = matches.get(block["text"], [])
        levels = {r["level"] for r in candidates}
        confirmed = len(levels) == 1
        rows.append(
            {
                "block_index": index,
                "level": next(iter(levels)) if confirmed else None,
                "confirmed": confirmed,
                "status": "exact_raw_heading_unique_level"
                if confirmed
                else "ambiguous_raw_heading_levels"
                if levels
                else "no_matching_raw_heading",
                "raw_html_sha256": source["raw_html_sha256"],
                "text_sha256": digest(block["text"]),
                "raw_matches": candidates,
                "decoded_encoding": encoding,
            }
        )
    return rows


def safe_evidence(value):
    if isinstance(value, str):
        return value.encode("utf-8", errors="backslashreplace").decode("utf-8")
    if isinstance(value, list):
        return [safe_evidence(v) for v in value]
    if isinstance(value, dict):
        return {k: safe_evidence(v) for k, v in value.items()}
    return value


def finalize(directory, historical_bundle, original_recovery):
    inventory = read_jsonl(directory / "inventory.jsonl.gz")
    by_url = {r["url"]: r for r in inventory}
    original_urls = {
        r["url"] for r in read_jsonl(historical_bundle / "source-master.jsonl.gz")
    }
    captures = read_jsonl(directory / "capture-versions.jsonl.gz")
    sources = read_jsonl(directory / "sources.jsonl.gz")
    supplements = read_jsonl(directory / "version-supplements.jsonl.gz")
    raw_sources, render_sources = defaultdict(list), defaultdict(list)
    for capture in captures:
        if capture.get("raw_html_asset"):
            raw_sources[capture["raw_html_asset"]].append(capture)
    for source in sources + supplements:
        render_sources[source["raw_html_asset"]].append(source)
    for path in sorted((original_recovery / "network").glob("*.html.json")):
        metadata = json.loads(path.read_text(encoding="utf-8"))
        raw_sources[path.with_suffix(".gz").as_posix()].append(
            {
                "url": metadata["url"],
                "raw_html_sha256": metadata["raw_sha256"],
                "content_type": metadata.get("content_type", ""),
            }
        )
    corrections, integrity, encoding_issues, heading_rows = {}, [], [], []
    discovery_new = {}
    journal = directory / "binding-corrections.progress.jsonl"
    verified = directory / "binding-verified-assets.progress.jsonl"
    completed = set()
    if journal.exists():
        for line in journal.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            corrections.setdefault(row["incorrect_target_url"], row)
    if verified.exists():
        for line in verified.read_text(encoding="utf-8").splitlines():
            completed.add(json.loads(line)["asset"])
    for index, (asset, refs) in enumerate(sorted(raw_sources.items())):
        raw = gzip.decompress(Path(asset).read_bytes())
        checksum = hashlib.sha256(raw).hexdigest()
        if any(r["raw_html_sha256"] != checksum for r in refs):
            raise ValueError("final_binding_raw_hash_mismatch")
        integrity.append({"asset": asset, "sha256": checksum, "bytes": len(raw)})
        hint = next((r.get("content_type") for r in refs if r.get("content_type")), "")
        if not hint:
            encoding = next(
                (r.get("decoded_encoding") for r in refs if r.get("decoded_encoding")),
                None,
            )
            hint = "text/html; charset=" + encoding if encoding else ""
        if asset in render_sources:
            matched, encoding = headings(raw, hint)
            for source in render_sources[asset]:
                evidence = bind_heading_levels(source, matched, encoding)
                source["heading_structure_evidence"] = evidence
                heading_rows.extend(
                    {
                        "source_id": source["source_id"],
                        "url": source["url"],
                        "capture_id": source["capture_id"],
                        **row,
                    }
                    for row in evidence
                )
        if asset not in completed:
            for source_url in sorted({r["url"] for r in refs}):
                try:
                    edges = list(anchor_evidence(raw, source_url, hint))
                except (UnicodeError, LookupError) as exc:
                    encoding_issues.append(
                        {
                            "asset": asset,
                            "raw_html_sha256": checksum,
                            "source_url": source_url,
                            "error": type(exc).__name__ + ":" + str(exc),
                            "body_not_redecoded_or_invented": True,
                        }
                    )
                    edges = list(
                        anchor_evidence(
                            raw, source_url, hint, discovery_surrogateescape=True
                        )
                    )
                for edge in edges:
                    target, old = (
                        edge["correct_target_url"],
                        edge["incorrect_target_url"],
                    )
                    if target not in by_url:
                        discovery_new.setdefault(
                            target,
                            {**edge, "raw_asset": asset, "raw_html_sha256": checksum},
                        )
                    if old != target and old in by_url and old not in corrections:
                        proof = safe_evidence(
                            {**edge, "raw_asset": asset, "raw_html_sha256": checksum}
                        )
                        corrections[old] = proof
                        with journal.open("a", encoding="utf-8") as stream:
                            stream.write(
                                json.dumps(proof, ensure_ascii=False, sort_keys=True)
                                + "\n"
                            )
            with verified.open("a", encoding="utf-8") as stream:
                stream.write(
                    json.dumps(
                        {"asset": asset, "raw_html_sha256": checksum}, sort_keys=True
                    )
                    + "\n"
                )
        if index % 100 == 0:
            print(
                "BINDINGS_FINAL",
                index,
                "of",
                len(raw_sources),
                "corrections",
                len(corrections),
                flush=True,
            )
    for row in inventory:
        proof = corrections.get(row["url"])
        if proof:
            row["discovery_binding_correction"] = proof
            row["corrected_source_url"] = proof["correct_target_url"]
            if (
                row["url"] not in original_urls
                and row["disposition"] != "CONTENT_CAPTURED"
            ):
                row["disposition"] = "DISCOVERY_ARTIFACT_ALIAS"
                row["basis"] = (
                    "original_raw_href_HTML_base_and_archive_wrapper_prove_discovery_construction_error"
                )
    for url, evidence in sorted(discovery_new.items()):
        reason = known_nonarticle_route(url)
        inventory.append(
            {
                "url": url,
                "source_id": stable_id(url),
                "disposition": reason[0] if reason else "SOURCE_UNRESOLVED",
                "basis": reason[1]
                if reason
                else "actual_corrected_raw_href_not_yet_captured",
                "discovery_evidence": safe_evidence(evidence),
                "capture_ids": [],
                "complete_capture_ids": [],
                "publication_allowed": False,
            }
        )
    write_jsonl(directory / "sources.jsonl.gz", sources)
    write_jsonl(directory / "version-supplements.jsonl.gz", supplements)
    write_jsonl(directory / "inventory.jsonl.gz", inventory)
    write_jsonl(
        directory / "discovery-corrections.jsonl.gz",
        sorted(corrections.values(), key=lambda r: r["incorrect_target_url"]),
    )
    write_jsonl(directory / "raw-integrity-index.jsonl.gz", integrity)
    write_jsonl(directory / "encoding-discovery-exceptions.jsonl.gz", encoding_issues)
    write_jsonl(directory / "heading-structure-evidence.jsonl.gz", heading_rows)
    write_jsonl(
        directory / "heading-structure-unresolved.jsonl.gz",
        [r for r in heading_rows if not r["confirmed"]],
    )
    correct_export_languages(directory)
    reconcile_exact_source_aliases(directory, original_urls)
    final_inventory = read_jsonl(directory / "inventory.jsonl.gz")
    unresolved = [r for r in final_inventory if r["disposition"] == "SOURCE_UNRESOLVED"]
    write_jsonl(directory / "unresolved-sources.jsonl.gz", unresolved)
    write_jsonl(
        directory / "real-frontier-inventory.jsonl.gz",
        [r for r in final_inventory if r["disposition"] != "DISCOVERY_ARTIFACT_ALIAS"],
    )
    summary_path = directory / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary.update(
        source_checkpoint_only=False,
        discovery_bindings_not_yet_reconciled=False,
        recovery_bindings_version="v4.1",
        inventory_urls=len(final_inventory),
        corrected_discovery_bindings=len(corrections),
        corrected_href_new_real_urls=len(discovery_new),
        real_frontier_urls=sum(
            r["disposition"] != "DISCOVERY_ARTIFACT_ALIAS" for r in final_inventory
        ),
        dispositions=dict(
            sorted(Counter(r["disposition"] for r in final_inventory).items())
        ),
        raw_assets_verified=len(integrity),
        encoding_discovery_exceptions=len(encoding_issues),
        heading_levels_confirmed=sum(r["confirmed"] for r in heading_rows),
        heading_levels_unresolved=sum(not r["confirmed"] for r in heading_rows),
        new_network_requests=0,
    )
    save_json(summary_path, summary)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--directory",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-ready-sources"),
    )
    parser.add_argument(
        "--historical-bundle",
        type=Path,
        default=Path("_audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028"),
    )
    parser.add_argument(
        "--original-recovery",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery"),
    )
    args = parser.parse_args()
    print(
        json.dumps(
            finalize(args.directory, args.historical_bundle, args.original_recovery),
            sort_keys=True,
        )
    )
