"""Repair discovery bindings and extract preserved HTTP successes without refetching.

Original recovery evidence remains immutable. Every corrected synthetic URL is
bound to its actual raw href, document base, raw hash and corrected target.
"""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import html
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlsplit

from tools.content_completion.full_recovery_v4 import (
    FULL,
    Recovery,
    capture_from_raw,
    decode_html,
    known_nonarticle_route,
    resolve_html_base,
    source_language_evidence,
    substantive_owned_body,
)
from tools.content_completion.phase_bundle import save_json
from tools.content_completion.source_evidence import original_url
from tools.plan3_content.crawl import stable_id
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import HOSTS, normalize_url, search_normalize

TAG = re.compile(
    r"<!--.*?-->|<script\b.*?</script\s*>|<style\b.*?</style\s*>|<(?P<tag>a|link|base)\b(?P<attrs>[^>]*?)>",
    re.IGNORECASE | re.DOTALL,
)
ATTR = re.compile(r"""([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))""")
_BINDING_CACHE = {}


def join_scope(href, base):
    if href.startswith(("?", "#")):
        return base
    parsed = urlsplit(base)
    if href.startswith("/") or urlsplit(href).scheme:
        return parsed.scheme + "://" + parsed.netloc + "/"
    return parsed.scheme + "://" + parsed.netloc + parsed.path.rsplit("/", 1)[0] + "/"


def document_base(raw, fallback, content_type=""):
    decoded, _ = decode_html(raw, content_type)
    match = re.search(
        r"<base\b([^>]*?)>", decoded.decode("utf-8"), re.IGNORECASE | re.DOTALL
    )
    if match:
        values = {
            k.lower(): html.unescape(a or b or c)
            for k, a, b, c in ATTR.findall(match[1])
        }
        if values.get("href"):
            try:
                base = resolve_html_base(values["href"], fallback)
                if urlsplit(base).hostname in HOSTS:
                    return base
            except (ValueError, UnicodeError):
                pass
    return fallback


def anchor_evidence(raw, source_url, content_type="", discovery_surrogateescape=False):
    try:
        decoded, encoding = decode_html(raw, content_type)
        document = decoded.decode("utf-8")
    except (UnicodeError, LookupError):
        if not discovery_surrogateescape:
            raise
        document = raw.decode("utf-8", errors="surrogateescape")
        encoding = "utf-8-surrogateescape-discovery-evidence-only"
    tags = []
    base = source_url
    for match in TAG.finditer(document):
        if not match["tag"]:
            continue
        attributes = {
            key.lower(): html.unescape(quoted or single or unquoted)
            for key, quoted, single, unquoted in ATTR.findall(match["attrs"])
        }
        if match["tag"].lower() == "base" and attributes.get("href"):
            try:
                candidate = resolve_html_base(attributes["href"], source_url)
                if urlsplit(candidate).hostname in HOSTS:
                    base = candidate
            except (ValueError, UnicodeError):
                pass
        elif attributes.get("href"):
            tags.append((attributes["href"], match.group(), match.start(), match.end()))
    for href, raw_tag, start, end in tags:
        try:
            binding_key = (href, join_scope(href, source_url), join_scope(href, base))
            if binding_key not in _BINDING_CACHE:
                _BINDING_CACHE[binding_key] = (
                    normalize_url(href, source_url),
                    original_url(href, base),
                )
            old, corrected = _BINDING_CACHE[binding_key]
        except (ValueError, UnicodeError):
            continue
        if urlsplit(corrected).hostname in HOSTS:
            yield {
                "source_url": source_url,
                "original_href": href,
                "document_base_url": base,
                "incorrect_target_url": old,
                "correct_target_url": corrected,
                "raw_anchor_tag": raw_tag,
                "decoded_character_start": start,
                "decoded_character_end": end,
                "decoded_encoding": encoding,
                "method": "literal_anchor_outside_script_style_comment_and_HTML_base_archive_unwrap",
            }


def clone_capture(template, url, metadata, asset):
    row = copy.deepcopy(template)
    sid = stable_id(url)
    row.update(
        source_id=sid,
        url=url,
        snapshot_id=uid(f"snapshot:{sid}:{row['body_sha256']}")
        if row["body_sha256"]
        else None,
        capture_id=uid(
            f"rad-full-recovery-v4:{sid}:{row['raw_html_sha256']}:{row['body_sha256']}"
        ),
        acquisition_timestamp=metadata.get("retrieved_at"),
        resolved_url=metadata.get("final_url", url),
        http_status=metadata.get("status"),
        raw_html_asset=asset,
    )
    return row


def correct_export_languages(directory):
    ledger, counts, original_counts = [], Counter(), Counter()
    for name in ("sources.jsonl.gz", "version-supplements.jsonl.gz"):
        path = directory / name
        rows = read_jsonl(path)
        for row in rows:
            original = row.get("original_capture_language", row["language"])
            language, evidence = source_language_evidence({**row, "language": original})
            row["original_capture_language"] = original
            row["language"], row["language_evidence"] = language, evidence
            original_counts[original] += 1
            counts[language] += 1
            if language != original:
                ledger.append(
                    {
                        "source_id": row["source_id"],
                        "url": row["url"],
                        "snapshot_id": row["snapshot_id"],
                        "capture_id": row["capture_id"],
                        "raw_html_sha256": row["raw_html_sha256"],
                        "body_sha256": row["body_sha256"],
                        "original_capture_language": original,
                        "corrected_source_language": language,
                        "evidence": evidence,
                        "body_changed": False,
                        "translation_created": False,
                    }
                )
        write_jsonl(path, rows)
    write_jsonl(directory / "language-corrections.jsonl.gz", ledger)
    summary_path = directory / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["original_capture_languages"] = dict(sorted(original_counts.items()))
    summary["source_languages"] = dict(sorted(counts.items()))
    summary["source_language_metadata_corrections"] = len(ledger)
    save_json(summary_path, summary)
    return {
        "corrections": len(ledger),
        "source_languages": dict(counts),
        "original_capture_languages": dict(original_counts),
    }


def reconcile_exact_source_aliases(directory, historical_urls):
    sources = read_jsonl(directory / "sources.jsonl.gz")
    inventory = read_jsonl(directory / "inventory.jsonl.gz")
    by_url = {r["url"]: r for r in inventory}
    groups, aliases = defaultdict(list), []
    for source in sources:
        by_url[source["url"]]["disposition"] = "CONTENT_CAPTURED"
        by_url[source["url"]]["basis"] = "hash_verified_complete_eligible_owned_body"
        for stale in (
            "represented_source_url",
            "represented_source_id",
            "exact_alias_evidence",
        ):
            by_url[source["url"]].pop(stale, None)
        key = (
            source["domain"],
            source["language"],
            search_normalize(source["title"]),
            tuple(source["taxonomy"]["country_codes"]),
            source["taxonomy"].get("pathway"),
            source["body_sha256"],
            source["structure_sha256"],
        )
        groups[key].append(source)
    for members in groups.values():
        ordered = sorted(
            members,
            key=lambda s: (
                bool(by_url[s["url"]].get("discovery_binding_correction")),
                s["url"] not in historical_urls,
                len(s["url"]),
                s["url"],
            ),
        )
        target = ordered[0]
        for source in ordered[1:]:
            proof = {
                "source_id": source["source_id"],
                "source_url": source["url"],
                "represented_source_id": target["source_id"],
                "represented_source_url": target["url"],
                "body_sha256": source["body_sha256"],
                "structure_sha256": source["structure_sha256"],
                "publisher": source["domain"],
                "locale": source["language"],
                "country_codes": source["taxonomy"]["country_codes"],
                "pathway": source["taxonomy"].get("pathway"),
                "basis": "exact_body_structure_title_publisher_locale_and_scope_match; every_original_capture_and_source_row_retained",
                "all_original_source_rows_and_blocks_preserved": True,
            }
            aliases.append(proof)
            by_url[source["url"]].update(
                disposition="EXACT_DUPLICATE",
                basis=proof["basis"],
                represented_source_url=target["url"],
                represented_source_id=target["source_id"],
                exact_alias_evidence=proof,
            )
    write_jsonl(directory / "inventory.jsonl.gz", inventory)
    write_jsonl(
        directory / "exact-source-aliases.jsonl.gz",
        sorted(aliases, key=lambda r: r["source_url"]),
    )
    summary_path = directory / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["eligible_complete_source_urls"] = len(sources)
    summary["eligible_unique_source_pages"] = len(groups)
    summary["exact_source_alias_urls"] = len(aliases)
    summary["dispositions"] = dict(
        sorted(Counter(r["disposition"] for r in inventory).items())
    )
    save_json(summary_path, summary)
    return {
        "eligible_complete_source_urls": len(sources),
        "eligible_unique_source_pages": len(groups),
        "exact_source_alias_urls": len(aliases),
    }


def repair(directory, output, bundle):
    output.mkdir(parents=True, exist_ok=True)
    recovery = Recovery(bundle, output)
    old_inventory = read_jsonl(directory / "inventory.jsonl.gz")
    old_urls = {r["url"] for r in old_inventory}
    recovery.frontier.update(old_urls)
    recovery.captures = read_jsonl(directory / "capture-versions.jsonl.gz")
    recovery.observations = read_jsonl(directory / "network-observations.jsonl.gz")
    recovery.media = read_jsonl(directory / "media-inventory.jsonl.gz")
    recovery.references = read_jsonl(directory / "pagination-inventory.jsonl.gz")
    previous = json.loads((directory / "summary.json").read_text(encoding="utf-8"))
    recovery.collector.circuit.update(previous["host_circuit"])
    raw_sources = defaultdict(list)
    for capture in recovery.captures:
        recovery.by_url[capture["url"]].append(capture)
        if capture.get("raw_html_asset"):
            raw_sources[capture["raw_html_asset"]].append(capture)
    metadata = []
    for path in sorted((directory / "network").glob("*.html.json")):
        row = json.loads(path.read_text(encoding="utf-8"))
        row["asset"] = path.with_suffix(".gz").as_posix()
        metadata.append(row)
        raw_sources[row["asset"]].append(
            {"url": row["url"], "raw_html_sha256": row["raw_sha256"]}
        )
    corrections, raw_index = {}, []
    # Identical raw error pages need one parse, while each HTTP URL retains
    # its own immutable source/capture identity and request timestamps.
    parsed_cache, extraction_errors, added = {}, [], []
    for index, row in enumerate(metadata):
        asset = row["asset"]
        raw = gzip.decompress(Path(asset).read_bytes())
        key = (
            row["raw_sha256"],
            document_base(raw, row["final_url"], row.get("content_type", "")),
        )
        try:
            if key not in parsed_cache:
                parsed_cache[key] = capture_from_raw(raw, row["url"], row, asset)
            captures = [
                clone_capture(c, row["url"], row, asset) for c in parsed_cache[key]
            ]
            recovery.by_url[row["url"]].extend(captures)
            added.extend(captures)
        except (ValueError, UnicodeError, LookupError, RecursionError) as exc:
            extraction_errors.append(
                {
                    "url": row["url"],
                    "raw_html_sha256": row["raw_sha256"],
                    "error": type(exc).__name__ + ":" + str(exc),
                    "raw_asset": asset,
                }
            )
        if index % 100 == 0:
            print(
                "CACHED_EXTRACTIONS",
                index,
                "complete",
                sum(c["completeness"] == FULL for c in added),
                flush=True,
            )
    canonical_output = recovery.output
    recovery.output = output.with_name(output.name + "-source-checkpoint")
    recovery.output.mkdir(parents=True, exist_ok=True)
    checkpoint = recovery.finish()
    checkpoint["source_checkpoint_only"] = True
    checkpoint["discovery_bindings_not_yet_reconciled"] = True
    save_json(recovery.output / "summary.json", checkpoint)
    print("SOURCE_CHECKPOINT", checkpoint["complete_source_pages"], flush=True)
    recovery.output = canonical_output
    for scans, (asset, references) in enumerate(sorted(raw_sources.items()), 1):
        path = Path(asset).resolve()
        raw = gzip.decompress(path.read_bytes())
        checksum = hashlib.sha256(raw).hexdigest()
        if any(r["raw_html_sha256"] != checksum for r in references):
            raise ValueError("repair_input_raw_hash_mismatch")
        recovery.verified_raw[path] = checksum
        raw_index.append({"asset": asset, "sha256": checksum, "bytes": len(raw)})
        for url in sorted({r["url"] for r in references}):
            for edge in anchor_evidence(raw, url):
                recovery.frontier.add(edge["correct_target_url"])
                old = edge["incorrect_target_url"]
                if old != edge["correct_target_url"] and old in old_urls:
                    corrections.setdefault(
                        old, {**edge, "raw_asset": asset, "raw_html_sha256": checksum}
                    )
        if scans % 100 == 0:
            print("RAW_BINDINGS", scans, "corrections", len(corrections), flush=True)
    summary = recovery.finish()
    inventory = read_jsonl(output / "inventory.jsonl.gz")
    source_by_url = {s["url"]: s for s in read_jsonl(output / "sources.jsonl.gz")}
    for row in inventory:
        proof = corrections.get(row["url"])
        if proof:
            row["discovery_binding_correction"] = proof
            row["corrected_source_url"] = proof["correct_target_url"]
            if (
                row["url"] not in recovery.master
                and row["disposition"] != "CONTENT_CAPTURED"
            ):
                row["disposition"] = "DISCOVERY_ARTIFACT_ALIAS"
                row["basis"] = (
                    "original_href_document_base_and_archive_wrapper_prove_discovery_construction_error"
                )
        if row["url"] in source_by_url:
            row["retained_body_sha256"] = source_by_url[row["url"]]["body_sha256"]
    write_jsonl(output / "inventory.jsonl.gz", inventory)
    unresolved = [r for r in inventory if r["disposition"] == "SOURCE_UNRESOLVED"]
    write_jsonl(output / "unresolved-sources.jsonl.gz", unresolved)
    write_jsonl(
        output / "discovery-corrections.jsonl.gz",
        sorted(corrections.values(), key=lambda r: r["incorrect_target_url"]),
    )
    write_jsonl(output / "raw-integrity-index.jsonl.gz", raw_index)
    write_jsonl(output / "cached-extraction-errors.jsonl.gz", extraction_errors)
    write_jsonl(
        output / "fresh-complete-captures.jsonl.gz",
        [c for c in added if c["completeness"] == FULL],
    )
    write_jsonl(
        output / "real-frontier-inventory.jsonl.gz",
        [r for r in inventory if r["disposition"] != "DISCOVERY_ARTIFACT_ALIAS"],
    )
    summary.update(
        correction_version="rad-recovery-bindings-v4.1",
        inventory_urls=len(inventory),
        dispositions=dict(sorted(Counter(r["disposition"] for r in inventory).items())),
        corrected_discovery_bindings=len(corrections),
        real_frontier_urls=sum(
            r["disposition"] != "DISCOVERY_ARTIFACT_ALIAS" for r in inventory
        ),
        cached_HTTP_successes_reparsed=len(metadata),
        new_complete_capture_instances=sum(c["completeness"] == FULL for c in added),
        extraction_failures=len(extraction_errors),
        new_network_requests=0,
        input_recovery_summary=previous,
    )
    save_json(output / "summary.json", summary)
    return summary


def reassess_checkpoint(directory, output, bundle):
    """Reassess existing owned blocks; no HTML parsing, network or text changes."""
    recovery = Recovery(bundle, output)
    recovery.captures = read_jsonl(directory / "capture-versions.jsonl.gz")
    inventory = read_jsonl(directory / "inventory.jsonl.gz")
    recovery.frontier.update(r["url"] for r in inventory)
    recovery.observations = read_jsonl(directory / "network-observations.jsonl.gz")
    recovery.media = read_jsonl(directory / "media-inventory.jsonl.gz")
    recovery.references = read_jsonl(directory / "pagination-inventory.jsonl.gz")
    prior_summary = json.loads((directory / "summary.json").read_text(encoding="utf-8"))
    recovery.collector.circuit.update(prior_summary["host_circuit"])
    decisions = []
    for capture in recovery.captures:
        recovery.by_url[capture["url"]].append(capture)
        if capture.get("completeness") != "incomplete_or_nonarticle":
            continue
        if not substantive_owned_body(
            capture
        ) or "mixed_markup_text_comparison_requires_review" in capture.get(
            "warnings", []
        ):
            continue
        if known_nonarticle_route(capture["url"]) or known_nonarticle_route(
            capture.get("resolved_url") or capture["url"]
        ):
            continue
        assessed = copy.deepcopy(capture)
        assessed["capture_id"] = uid("v4.1-owned-reassessment:" + capture["capture_id"])
        assessed["origin_capture_id"] = capture["capture_id"]
        assessed["original_capture_completeness"] = capture["completeness"]
        assessed["completeness"] = FULL
        assessed["parser_version"] = "rad-owned-completeness-v4.1"
        recovery.by_url[capture["url"]].append(assessed)
        decisions.append(
            {
                "source_id": capture["source_id"],
                "url": capture["url"],
                "original_capture_id": capture["capture_id"],
                "assessed_capture_id": assessed["capture_id"],
                "raw_html_sha256": capture["raw_html_sha256"],
                "body_sha256": capture["body_sha256"],
                "original_completeness": capture["completeness"],
                "assessed_completeness": FULL,
                "basis": "recognized_owned_container_with_complete_block_text_no_mixed_markup_warning; broad_about_country_taxonomy_and_300_character_cutoff_do_not_define_eligibility",
                "original_blocks_unchanged": True,
            }
        )
    summary = recovery.finish()
    old_by_url = {r["url"]: r for r in inventory}
    revised = read_jsonl(output / "inventory.jsonl.gz")
    for row in revised:
        prior = old_by_url.get(row["url"], {})
        if prior.get("discovery_binding_correction"):
            row["discovery_binding_correction"] = prior["discovery_binding_correction"]
            row["corrected_source_url"] = prior["corrected_source_url"]
            if (
                row["disposition"] != "CONTENT_CAPTURED"
                and prior["disposition"] == "DISCOVERY_ARTIFACT_ALIAS"
            ):
                row["disposition"] = prior["disposition"]
                row["basis"] = prior["basis"]
    write_jsonl(output / "inventory.jsonl.gz", revised)
    write_jsonl(
        output / "unresolved-sources.jsonl.gz",
        [r for r in revised if r["disposition"] == "SOURCE_UNRESOLVED"],
    )
    write_jsonl(output / "owned-completeness-reassessment.jsonl.gz", decisions)
    summary["dispositions"] = dict(
        sorted(Counter(r["disposition"] for r in revised).items())
    )
    summary["owned_completeness_metadata_reassessments"] = len(decisions)
    summary["new_network_requests"] = 0
    summary["input_checkpoint"] = directory.as_posix()
    summary["source_checkpoint_only"] = prior_summary.get(
        "source_checkpoint_only", False
    )
    save_json(output / "summary.json", summary)
    language = correct_export_languages(output)
    summary.update(language)
    summary.update(reconcile_exact_source_aliases(output, set(recovery.master)))
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--directory",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-repaired"),
    )
    parser.add_argument(
        "--bundle",
        type=Path,
        default=Path("_audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028"),
    )
    parser.add_argument("--language-only", action="store_true")
    parser.add_argument("--reassess-checkpoint", action="store_true")
    args = parser.parse_args()
    result = (
        reassess_checkpoint(args.directory, args.output, args.bundle)
        if args.reassess_checkpoint
        else correct_export_languages(args.output)
        if args.language_only
        else repair(args.directory, args.output, args.bundle)
    )
    print(json.dumps(result, sort_keys=True))
