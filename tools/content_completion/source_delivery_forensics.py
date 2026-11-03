"""Reproduce raw-capture classification and source-to-proposed-revision evidence.

No network, hosted writes, editorial approvals or original-seal modifications.
Capture classification describes the observed response, never historical absence.
"""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import json
import os
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from tools.content_completion.full_audit_v4 import audit
from tools.content_completion.full_recovery_v4 import decode_html
from tools.content_completion.source_limitations_v42 import _raw_path
from tools.plan3_content.dataset import read_jsonl, write_jsonl

POLICY = "RAD_CONTENT_PRECEDENCE_V4.1"


def sha(value):
    if not isinstance(value, (str, bytes)):
        value = json.dumps(
            value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )
    return hashlib.sha256(
        value.encode() if isinstance(value, str) else value
    ).hexdigest()


def propose_dubai_country_correction(ready, source_id, excerpt, reference):
    """Prepare an identity/body-preserving country correction, never an approval."""
    item = ready["item"]
    if item["country_codes"] or not re.search(
        r"(?<!\w)(?:دبی|دوبی|Dubai)(?!\w)", item["title"], re.I
    ):
        raise ValueError("unambiguous_unassigned_dubai_title_required")
    source = next(
        s
        for s in ready["sources"]
        if s.get("source_variant_id", s["source_id"]) == source_id
    )
    if (
        sha(source["body_text"]) != source["body_sha256"]
        or not excerpt
        or excerpt not in source["body_text"]
    ):
        raise ValueError("literal_original_country_excerpt_required")
    if not re.search(r"امارات|United Arab Emirates|UAE", excerpt, re.I):
        raise ValueError("explicit_source_country_context_required")
    if reference.get(
        "url"
    ) != "https://www.moet.gov.ae/en/web/guest/emirates-of-the-uae" or not re.fullmatch(
        r"[a-f0-9]{64}", reference.get("captured_page_sha256", "")
    ):
        raise ValueError("bound_official_geography_reference_required")
    result = copy.deepcopy(ready)
    result["item"]["country_codes"] = ["AE"]
    result["item"]["country_source_evidence"] = {
        "country_code": "AE",
        "city": "Dubai",
        "source_variant_id": source_id,
        "source_body_sha256": source["body_sha256"],
        "excerpt": excerpt,
        "start": source["body_text"].index(excerpt),
        "geography_reference": reference,
        "factual_immigration_verification_changed": False,
    }
    if (
        result["item"]["draft_request"] != item["draft_request"]
        or result["item"]["sections"] != item["sections"]
    ):
        raise ValueError("country_correction_must_preserve_full_body_and_identity")
    return result


def space(value):
    return " ".join(unicodedata.normalize("NFC", value).split())


def owned_region(soup):
    for selector in (
        '[itemprop="articleBody"]',
        ".item-page .article-body",
        "article .entry-content",
    ):
        region = soup.select_one(selector)
        if region is not None:
            return region, selector
    heading = soup.find("h1")
    box = heading.find_parent(class_="Box") if heading else None
    region = box.find(class_="BoxCenter", recursive=False) if box else None
    return (
        (region, "h1 ancestor .Box > .BoxCenter")
        if region is not None
        else (None, None)
    )


def decode_capture(capture, raw):
    if sha(raw) != capture["raw_html_sha256"]:
        raise ValueError("original_raw_capture_hash_mismatch")
    try:
        decoded, encoding = decode_html(raw)
        document = decoded.decode("utf8")
    except UnicodeDecodeError:
        document = raw.decode("utf8", errors="surrogateescape")
        encoding = "utf8-surrogateescape-evidence-only-no-byte-repair"
    return BeautifulSoup(document, "html.parser"), encoding


def classify_capture(capture, raw):
    soup, encoding = decode_capture(capture, raw)
    region, selector = owned_region(soup)
    main = soup.select_one("main")
    title_node = soup.find("title")
    title = space(title_node.get_text(" ", strip=True)) if title_node else ""
    canonical = soup.select_one('link[rel="canonical"][href]')
    canonical_url = urljoin(capture["url"], canonical["href"]) if canonical else None
    body = space(region.get_text(" ", strip=True)) if region is not None else ""
    media = []
    if region is not None:
        for node in region.select("video[src],audio[src],source[src],iframe[src]"):
            media.append(
                {
                    "tag": node.name,
                    "literal_src": node["src"],
                    "public_render_allowed": False,
                }
            )
    error = bool(
        re.search(r"صفحه مورد نظر یافت نشد|page not found|^404(?:\s|$)", title, re.I)
    )
    paragraphs = (
        [
            space(p.get_text(" ", strip=True))
            for p in region.select("p,h1,h2,h3,h4,h5,h6")
        ]
        if region
        else []
    )
    placeholder = re.compile(
        r"در حال (?:بروز\s?رسانی|به روز\s?رسانی|تدوین)|در حال بروزرسانی|no faq found|under construction|coming soon",
        re.I,
    )
    placeholder_nodes_only = bool(paragraphs) and all(
        not p or p == title or placeholder.search(p) for p in paragraphs
    )
    placeholder_remainder = body
    if placeholder_nodes_only:
        for fragment in sorted(
            [title]
            + [p for p in paragraphs if len(p) <= 160 and placeholder.search(p)],
            key=len,
            reverse=True,
        ):
            if fragment:
                placeholder_remainder = placeholder_remainder.replace(fragment, "")
    only_placeholder = placeholder_nodes_only and not space(placeholder_remainder)
    if error:
        kind = "ERROR_RESPONSE_HISTORICAL_IDENTITY_UNDETERMINED"
    elif (
        region is not None
        and region.select_one(".Paging") is not None
        and len(region.select(".ProductShow .ItemAds .ItemTitle2")) >= 2
    ):
        kind = "CATEGORY_LIST_WITH_PARTIAL_EXCERPTS"
    elif region is None and soup.select_one(".blog,.category-list,.categories-list"):
        kind = "CATEGORY_LIST_WITH_PARTIAL_EXCERPTS"
    elif region is None and soup.select_one(".rsseo-sitemap-menu"):
        kind = "SITEMAP_NAVIGATION"
    elif region is None and main is not None and main.select_one("form"):
        kind = "SERVICE_FORM_NOT_AN_AUTHORED_ARTICLE"
    elif region is None and main is not None and main.select_one("a[href]"):
        kind = "NAVIGATION_OR_UNRECOGNIZED_CONTAINER"
    elif (
        region is not None
        and media
        and (not body or body == "Your browser does not support video")
    ):
        kind = "MEDIA_ONLY_NO_AUTHORED_TRANSCRIPT"
    elif region is not None and not body:
        kind = "EMPTY_OWNED_CONTAINER"
    elif only_placeholder:
        kind = "EXPLICIT_PUBLISHER_PLACEHOLDER"
    elif placeholder_nodes_only:
        kind = "AUTHORED_TEXT_WITH_PUBLISHER_UPDATE_NOTICE"
    elif body and body == title:
        kind = "TITLE_ONLY_NO_ARTICLE_BODY"
    elif region is not None:
        kind = "AUTHORED_TEXT_REQUIRES_COMPLETE_BODY_PROOF"
    else:
        kind = "NO_RECOGNIZED_AUTHORED_CONTAINER"
    return {
        "capture_id": capture["capture_id"],
        "source_id": capture["source_id"],
        "original_url": capture["url"],
        "raw_html_sha256": sha(raw),
        "raw_html_asset": capture["raw_html_asset"],
        "decoded_encoding": encoding,
        "http_status": capture.get("http_status"),
        "captured_at": capture.get("acquisition_timestamp"),
        "captured_at_status": capture.get("acquisition_timestamp_status"),
        "title": title,
        "canonical_url": canonical_url,
        "owned_selector": selector,
        "observed_content_kind": kind,
        "owned_text_sha256": sha(body),
        "owned_text_characters": len(body),
        "literal_owned_text": body,
        "placeholder_evidence": [p for p in paragraphs if placeholder.search(p)],
        "media_references": media,
        "original_historical_body_proved_absent": False,
        "publication_allowed": False,
    }


def classify_inventory(dispositions, captures, roots):
    expected = {(r["source_id"], r["url"]) for r in dispositions}
    if len(expected) != len(dispositions):
        raise ValueError("duplicate_original_url_identity")
    evidence = defaultdict(list)
    for capture in captures:
        key = (capture["source_id"], capture["url"])
        if key not in expected or not capture.get("raw_html_asset"):
            continue
        raw = gzip.decompress(_raw_path(capture["raw_html_asset"], roots).read_bytes())
        evidence[key].append(classify_capture(capture, raw))
    result = []
    for row in dispositions:
        proof = evidence[(row["source_id"], row["url"])]
        kinds = sorted({p["observed_content_kind"] for p in proof})
        result.append(
            {
                "source_id": row["source_id"],
                "original_url": row["url"],
                "previous_disposition": row["disposition"],
                "capture_evidence": proof,
                "observed_content_kinds": kinds,
                "classification_status": "CAPTURE_CONTENT_CLASSIFIED"
                if proof
                else "NO_ORIGINAL_BODY_EVIDENCE",
                "historical_coverage": "RECOVERED_ORIGINAL_BODY"
                if row["disposition"] == "RECOVERED_FULL_BODY"
                else "HISTORICAL_BODY_NOT_CERTIFIED",
                "silently_excluded": False,
                "publication_allowed": False,
            }
        )
    return result


def table_shape(table):
    return [
        [
            {
                "text": space(cell.get_text(" ", strip=True)),
                "header": cell.name == "th",
                "colspan": str(cell.get("colspan", "1")),
                "rowspan": str(cell.get("rowspan", "1")),
            }
            for cell in row.find_all(["td", "th"], recursive=False)
        ]
        for row in table.find_all("tr")
        if row.find_parent("table") is table
    ]


def list_shape(node):
    result = []
    for item in node.find_all("li", recursive=False):
        own, children = [], []
        for part in item.children:
            if getattr(part, "name", None) in ("ul", "ol"):
                children.append(
                    {"ordered": part.name == "ol", "items": list_shape(part)}
                )
            else:
                own.append(
                    part.get_text(" ", strip=True)
                    if getattr(part, "name", None)
                    else str(part)
                )
        result.append({"text": space(" ".join(own)), "children": children})
    return result


def raw_block_proof(source, raw):
    soup, _ = decode_capture(source, raw)
    body, selector = owned_region(soup)
    if body is None:
        return [
            {"block_index": i, "status": "OWNED_CONTAINER_NOT_LOCATED"}
            for i in range(len(source["blocks"]))
        ]
    raw_text = space(body.get_text(" ", strip=True))
    if any(0xD800 <= ord(c) <= 0xDFFF for c in raw_text):
        return [
            {"block_index": i, "status": "ENCODING_DAMAGE_IN_OWNED_BODY"}
            for i in range(len(source["blocks"]))
        ]
    tables = body.find_all("table")
    proofs = []
    cursor = 0
    for index, block in enumerate(source["blocks"]):
        if block["type"] == "table":
            candidate = next(
                (
                    t
                    for t in tables
                    if table_shape(t) == block["rows"]
                    and (
                        space(t.caption.get_text(" ", strip=True))
                        if t.caption
                        else None
                    )
                    == block.get("caption")
                    and raw_text.find(space(t.get_text(" ", strip=True)), cursor) >= 0
                ),
                None,
            )
            needle = (
                space(candidate.get_text(" ", strip=True))
                if candidate is not None
                else None
            )
            matched = candidate is not None
            method = "exact_dom_rows_cells_spans_and_header_flags"
        else:
            needle = space(block["text"])
            matched = bool(needle) and raw_text.find(needle, cursor) >= 0
            if block["type"] in ("bullet_list", "numbered_list"):
                tag = "ol" if block["type"] == "numbered_list" else "ul"
                matched = matched and any(
                    list_shape(n) == block["items"] for n in body.find_all(tag)
                )
            method = "ordered_exact_nfc_whitespace_text_and_structured_list"
        offset = raw_text.find(needle, cursor) if needle is not None else -1
        if matched:
            cursor = offset + len(needle)
        proofs.append(
            {
                "block_index": index,
                "source_structure_sha256": sha(block),
                "status": "RAW_DOM_MATCH" if matched else "RAW_DOM_REQUIRES_REVIEW",
                "method": method,
                "selector": selector,
                "normalized_dom_offsets": [offset, offset + len(needle)]
                if matched
                else None,
            }
        )
    return proofs


def source_crosswalk(sources, articles, bindings, raw_proofs):
    index = {(s["source_id"], s["snapshot_id"]): s for s in sources}
    expected = {
        (s["source_id"], s["snapshot_id"], i)
        for s in sources
        for i in range(len(s["blocks"]))
    }
    covered = set()
    destination_seen = set()
    for article in articles:
        identity = (article["article_id"], article["locale"])
        binding = bindings.get(identity)
        blocks = {
            b["id"]: b for section in article["sections"] for b in section["blocks"]
        }
        for ledger in article["segment_ledger"]:
            key = (ledger["source_id"], ledger["snapshot_id"], ledger["block_index"])
            if key not in expected or (identity, key) in destination_seen:
                raise ValueError("missing_or_duplicate_source_segment_identity")
            source = index[key[:2]]
            block = source["blocks"][key[2]]
            target = blocks[ledger["represented_block_id"]]
            if ledger["structure_sha256"] != sha(block) or ledger["sha256"] != sha(
                block["text"]
            ):
                raise ValueError("source_segment_hash_mismatch")
            if not any(
                (p["source_id"], p["snapshot_id"], p["block_index"]) == key
                for p in target["provenance"]
            ):
                raise ValueError("source_segment_target_not_proven")
            covered.add(key)
            destination_seen.add((identity, key))
            yield {
                "original_url": source["url"],
                "source_id": key[0],
                "snapshot_id": key[1],
                "capture_id": source["capture_id"],
                "raw_html_asset": source["raw_html_asset"],
                "raw_html_sha256": source["raw_html_sha256"],
                "captured_at": source.get("acquisition_timestamp"),
                "captured_at_status": source.get("acquisition_timestamp_status"),
                "source_block_index": key[2],
                "source_block_sha256": sha(block),
                "original_body_offsets": [ledger["start"], ledger["end"]],
                "raw_dom_proof": raw_proofs[key[:2]][key[2]],
                "consolidation_decision": ledger["status"],
                "equivalence_evidence": ledger.get("equivalence_evidence"),
                "selected_origin": ledger["selected_origin"],
                "target_block_id": target["id"],
                "target_article_id": identity[0],
                "locale": identity[1],
                "country_codes": article["country_codes"],
                "visa_category": article["visa_category"],
                "placement": "Other Titles"
                if not article["country_codes"]
                else "Visa country content",
                "radmohajer_independent": source["domain"] == "radmohajer.ir"
                and article["source_publishers"] == ["radmohajer.ir"],
                "expected_cms_revision": binding["revision_id"] if binding else None,
                "operation_id": binding["operation_id"] if binding else None,
                "binding_status": "SEALED_PROPOSED_REVISION"
                if binding
                else "ADDITIVE_DELTA_REQUIRES_PRODUCTION_BINDING",
                "installed_or_published": False,
            }
    if covered != expected:
        raise ValueError("unexplained_source_segment_loss")


def known_url_register(inventory, limitations, crosswalk):
    """Keep the discovery frontier separate from proved authored article bodies."""
    entries = {r["url"]: r for r in inventory}
    if len(entries) != len(inventory):
        raise ValueError("duplicate_discovery_inventory_url")
    limits = {r["original_url"]: r for r in limitations}
    targets = defaultdict(dict)
    for row in crosswalk:
        identity = (
            row["target_article_id"],
            row["locale"],
            row["expected_cms_revision"],
        )
        targets[row["original_url"]][identity] = {
            "article_id": identity[0],
            "locale": identity[1],
            "proposed_revision": identity[2],
            "country_codes": row["country_codes"],
            "placement": row["placement"],
        }
    for url in sorted(entries.keys() | limits.keys() | targets.keys()):
        prior = entries.get(url, {})
        limitation = limits.get(url)
        yield {
            "original_url": url,
            "source_id": prior.get("source_id") or (limitation or {}).get("source_id"),
            "in_sealed_discovery_frontier": url in entries,
            "legacy_inventory_disposition": prior.get("disposition"),
            "legacy_inventory_basis": prior.get("basis"),
            "original_capture_ids": prior.get("capture_ids", []),
            "in_historical_421_gap_scope": limitation is not None,
            "body_evidence": "BOUND_ORIGINAL_BODY"
            if url in targets
            else "NO_COMPLETE_BODY_PROOF_IN_THIS_CORPUS",
            "capture_content_kinds": (limitation or {}).get(
                "observed_content_kinds", []
            ),
            "proposed_targets": list(targets[url].values()),
            "legacy_noncontent_label_is_independent_proof": False,
            "historical_absence_claimed": False,
            "published_actual": False,
        }


def restore_capture_identities(value, source_bindings):
    if isinstance(value, list):
        return [restore_capture_identities(v, source_bindings) for v in value]
    if not isinstance(value, dict):
        return value
    result = {
        k: restore_capture_identities(v, source_bindings) for k, v in value.items()
    }
    if "source_variant_id" in result:
        variant = result.pop("source_variant_id")
        binding = source_bindings[variant]
        if result.get("source_id") != binding["source_id"]:
            raise ValueError("stored_source_variant_binding_mismatch")
        result["source_id"] = variant
        for name in ("snapshot_id", "source_snapshot_id"):
            if name in result:
                if result[name] != binding["snapshot_id"]:
                    raise ValueError("stored_snapshot_variant_binding_mismatch")
                result[name] = binding["original_snapshot_id"]
    return result


def verify_package_articles(package, articles, sources=()):
    plan = json.loads((package / "plan.json").read_text("utf8"))
    bound = dict(plan)
    expected = bound.pop("package_sha256")
    if sha(bound) != expected:
        raise ValueError("production_plan_seal_mismatch")
    wanted = {(a["article_id"], a["locale"]): a for a in articles}
    originals = {s["source_id"]: s for s in sources}
    result = {}
    seals = {r["operation_id"]: r for r in plan["operation_bindings"]}
    with gzip.open(package / "operations.jsonl.gz", "rt", encoding="utf8") as stream:
        for line in stream:
            op = json.loads(line)
            if {k: v for k, v in op.items() if k != "payload"} != seals[
                op["operation_id"]
            ] or sha(op["payload"]) != op["payload_sha256"]:
                raise ValueError("production_operation_payload_mismatch")
            key = (op["article_id"], op["locale"])
            if key in wanted:
                if key in result:
                    raise ValueError("duplicate_target_locale")
                source_bindings = {}
                for source in op["payload"]["sources"]:
                    variant = source.get("source_variant_id", source["source_id"])
                    original = originals[variant]
                    for field in ("body_text", "body_sha256", "title", "url"):
                        if source[field] != original[field]:
                            raise ValueError(
                                "original_source_payload_mismatch:" + field
                            )
                    if (
                        source.get("source_evidence", {}).get(
                            "captured_raw_html_sha256", source["raw_html_sha256"]
                        )
                        != original["raw_html_sha256"]
                    ):
                        raise ValueError("original_raw_capture_payload_mismatch")
                    source_bindings[variant] = source | {
                        "original_snapshot_id": original["snapshot_id"]
                    }
                for field in (
                    "sections",
                    "segment_ledger",
                    "country_codes",
                    "title",
                    "locale",
                    "composition_policy",
                ):
                    if (
                        restore_capture_identities(
                            op["payload"]["item"][field], source_bindings
                        )
                        != wanted[key][field]
                    ):
                        raise ValueError(
                            "source_composition_operation_destination_mismatch:" + field
                        )
                result[key] = seals[op["operation_id"]]
    if set(result) != set(wanted):
        raise ValueError("complete_proposed_revision_bindings_required")
    return result, expected


def build(args):
    args.output.mkdir(parents=True, exist_ok=False)
    triage = json.loads(args.triage.read_text("utf8"))
    dispositions_path = Path(triage["input_file"])
    if sha(dispositions_path.read_bytes()) != triage["input_sha256"]:
        raise ValueError("original_421_disposition_input_changed")
    dispositions = read_jsonl(dispositions_path)
    if len(dispositions) != 421:
        raise ValueError("complete_421_original_identities_required")
    seal = json.loads(
        (args.source_input / "source-input-manifest.json").read_text("utf8")
    )
    for name, expected in seal["files"].items():
        if sha((args.source_input / name).read_bytes()) != expected:
            raise ValueError("source_input_seal_mismatch:" + name)
    classified = classify_inventory(
        dispositions,
        read_jsonl(args.source_input / "capture-versions.jsonl.gz"),
        args.asset_root,
    )
    write_jsonl(args.output / "original-url-evidence.jsonl.gz", classified)
    print("CLASSIFIED_ORIGINAL_URLS", len(classified), flush=True)
    sources, articles = [], []
    composition_inputs = {}
    for directory in args.composition:
        for name, target in (
            ("sources.jsonl.gz", sources),
            ("articles.jsonl.gz", articles),
        ):
            path = directory / name
            target.extend(read_jsonl(path))
            composition_inputs[str(path)] = sha(path.read_bytes())
    previous_cwd = Path.cwd()
    try:
        os.chdir(args.audit_asset_root)
        proof = audit(sources, articles)
    finally:
        os.chdir(previous_cwd)
    (args.output / "independent-source-audit.json").write_text(
        json.dumps(proof, indent=2) + "\n", encoding="utf8"
    )
    print("INDEPENDENT_COMPOSITION_PROOF", proof["composition_status"], flush=True)
    bindings, package_hash = verify_package_articles(args.package, articles, sources)
    print("BOUND_PROPOSED_REVISIONS", len(bindings), flush=True)
    raw_proofs = {}
    source_capture_kinds = []
    raw_cache = {}
    for source in sources:
        path = _raw_path(source["raw_html_asset"], args.asset_root)
        if path not in raw_cache:
            raw_cache[path] = gzip.decompress(path.read_bytes())
        raw_proofs[(source["source_id"], source["snapshot_id"])] = raw_block_proof(
            source, raw_cache[path]
        )
        source_capture_kinds.append(classify_capture(source, raw_cache[path]))
        if len(raw_proofs) % 250 == 0:
            print("RAW_SOURCE_VARIANTS_CHECKED", len(raw_proofs), flush=True)
    write_jsonl(
        args.output / "raw-source-block-proofs.jsonl.gz",
        [
            {"source_id": sid, "snapshot_id": snap, "block_proofs": proofs}
            for (sid, snap), proofs in sorted(raw_proofs.items())
        ],
    )
    write_jsonl(args.output / "source-capture-kinds.jsonl.gz", source_capture_kinds)
    rows = list(source_crosswalk(sources, articles, bindings, raw_proofs))
    write_jsonl(args.output / "source-to-proposed-revision.jsonl.gz", rows)
    inventory = read_jsonl(args.source_input / "inventory.jsonl.gz")
    known_urls = list(known_url_register(inventory, classified, rows))
    write_jsonl(args.output / "all-known-url-register.jsonl.gz", known_urls)
    raw_status = Counter(p["status"] for proofs in raw_proofs.values() for p in proofs)
    summary = {
        "status": "PASS_SOURCE_MAPPING"
        if set(raw_status) == {"RAW_DOM_MATCH"}
        else "MAPPING_PASS_RAW_DOM_EXCEPTIONS_RETAINED",
        "policy": POLICY,
        "historical_original_urls": len(dispositions),
        "original_url_evidence_states": dict(
            Counter(r["classification_status"] for r in classified)
        ),
        "observed_content_kinds": dict(
            Counter(tuple(r["observed_content_kinds"]) for r in classified)
        ),
        "composition_proof": proof,
        "raw_dom_block_proof": dict(raw_status),
        "crosswalk_rows": len(rows),
        "unique_source_segments": len(
            {(r["source_id"], r["snapshot_id"], r["source_block_index"]) for r in rows}
        ),
        "bound_article_locales": len(bindings),
        "complete_corpus_capture_kinds": dict(
            Counter(r["observed_content_kind"] for r in source_capture_kinds)
        ),
        "capture_kinds_are_not_editorial_clearance": True,
        "original_source_urls_in_composition": len({s["url"] for s in sources}),
        "sealed_discovery_frontier_urls": len(inventory),
        "known_url_register_rows": len(known_urls),
        "legacy_frontier_dispositions_not_recertified": dict(
            Counter(r["disposition"] for r in inventory)
        ),
        "production_package_sha256": package_hash,
        "composition_inputs": composition_inputs,
        "source_input_manifest_sha256": sha(
            (args.source_input / "source-input-manifest.json").read_bytes()
        ),
        "publication_allowed": False,
        "hosted_writes": 0,
        "all_historical_webpages_claimed": False,
    }
    summary["observed_content_kinds"] = {
        " | ".join(k) or "NO_CAPTURE": v
        for k, v in summary["observed_content_kinds"].items()
    }
    summary["files"] = {p.name: sha(p.read_bytes()) for p in args.output.glob("*.gz")}
    (args.output / "manifest.json").write_text(
        json.dumps(summary, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf8",
    )
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--triage", type=Path, required=True)
    parser.add_argument("--source-input", type=Path, required=True)
    parser.add_argument("--composition", type=Path, action="append", required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--asset-root", type=Path, action="append", required=True)
    parser.add_argument("--audit-asset-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    print(json.dumps(build(parser.parse_args()), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
