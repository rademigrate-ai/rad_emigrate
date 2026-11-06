"""Bind remaining source limitations to immutable, owned HTML evidence.

No publication, database access, broad title deduplication or source rewriting.
The original sealed input and previous verdict are never modified.
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
from functools import lru_cache
from html.parser import HTMLParser
from pathlib import Path

from bs4 import BeautifulSoup

from tools.content_completion.full_recovery_v4 import (
    FULL,
    composition_source,
    decode_html,
    known_nonarticle_route,
    parse_owned,
)
from tools.content_completion.source_links_v41 import original_target
from tools.plan3_content.crawl import stable_id
from tools.plan3_content.dataset import read_jsonl, write_jsonl
from tools.plan3_content.parser import digest, normalize_url, text


class _Spans(HTMLParser):
    def __init__(self, document):
        super().__init__(convert_charrefs=False)
        self.document = document
        self.lines = [0]
        self.lines.extend(m.end() for m in re.finditer("\n", document))
        self.stack, self.nodes = [], []
        self.feed(document)

    def position(self):
        line, column = self.getpos()
        return self.lines[line - 1] + column

    def handle_starttag(self, tag, attrs):
        start = self.position()
        row = {"tag": tag, "start": start, "end": None, "attrs": dict(attrs)}
        self.nodes.append(row)
        if tag in {
            "area",
            "base",
            "br",
            "col",
            "embed",
            "hr",
            "img",
            "input",
            "link",
            "meta",
            "param",
            "source",
            "track",
            "wbr",
        }:
            row["end"] = start + len(self.get_starttag_text())
        else:
            self.stack.append(row)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if self.stack and self.stack[-1]["start"] == self.position():
            self.stack.pop()["end"] = self.position() + len(self.get_starttag_text())

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i]["tag"] == tag:
                end = self.document.find(">", self.position())
                self.stack[i]["end"] = end + 1 if end >= 0 else None
                self.stack = self.stack[:i]
                return


def _decode(raw):
    try:
        decoded, encoding = decode_html(raw)
        return decoded.decode("utf8"), encoding
    except (UnicodeError, LookupError):
        return raw.decode(
            "utf8", errors="surrogateescape"
        ), "utf8-surrogateescape-evidence-only"


@lru_cache(maxsize=12)
def _owned(raw):
    document, encoding = _decode(raw)
    soup = BeautifulSoup(document, "html.parser")
    candidates = soup.select(".BoxSizeAsli .Box > .BoxCenter")
    if candidates:
        h1 = soup.find("h1")
        box = h1.find_parent(class_="Box") if h1 else None
        body = box.find(class_="BoxCenter", recursive=False) if box else None
    else:
        body = soup.select_one(
            '[itemprop="articleBody"], .item-page .article-body, article .entry-content, .item-page'
        )
    spans = _Spans(document)
    node = None
    if body is not None and body.sourceline and body.sourcepos is not None:
        position = spans.lines[body.sourceline - 1] + body.sourcepos
        node = next(
            (
                n
                for n in spans.nodes
                if n["start"] == position
                and n["tag"] == body.name
                and n["end"] is not None
            ),
            None,
        )
    return document, encoding, body, node, spans


def _raw_check(source, raw):
    if hashlib.sha256(raw).hexdigest() != source["raw_html_sha256"]:
        raise ValueError("raw_checksum_mismatch")
    if digest(source.get("body_text", "")) != source.get("body_sha256"):
        raise ValueError("body_checksum_mismatch")
    if digest(source.get("blocks", [])) != source.get("structure_sha256"):
        raise ValueError("structure_checksum_mismatch")


@lru_cache(maxsize=12)
def _parsed_owned(raw, source_url, title):
    document, encoding, _, node, _ = _owned(raw)
    if node is None:
        return []
    body_document = document[node["start"] : node["end"]]
    if any(0xD800 <= ord(c) <= 0xDFFF for c in body_document):
        return []
    primary = (
        f"<html><h1>{html.escape(title)}</h1>{body_document}</html>".encode()
        if "surrogateescape" in encoding
        else document.encode()
    )
    return parse_owned(primary, source_url)[0]


def _shape(blocks):
    return [{k: v for k, v in b.items() if k != "level"} for b in blocks]


def _body_identity(source, raw):
    _raw_check(source, raw)
    document, encoding, body, node, spans = _owned(raw)
    if node is None:
        return False, document, encoding, body, node, spans
    body_document = document[node["start"] : node["end"]]
    if any(0xD800 <= ord(c) <= 0xDFFF for c in body_document):
        return False, document, encoding, body, node, spans
    parsed = _parsed_owned(
        raw, source.get("resolved_url") or source["url"], source.get("title", "")
    )
    exact = any(
        digest(p.get("body_text", "")) == source.get("body_sha256")
        and digest(_shape(p.get("blocks", [])))
        == digest(_shape(source.get("blocks", [])))
        for p in parsed
    )
    return exact, document, encoding, body, node, spans


def _span_for(tag, spans):
    if not tag.sourceline or tag.sourcepos is None:
        return None
    start = spans.lines[tag.sourceline - 1] + tag.sourcepos
    return next(
        (
            n
            for n in spans.nodes
            if n["start"] == start and n["tag"] == tag.name and n["end"] is not None
        ),
        None,
    )


def _in_article(tag, body):
    for p in tag.parents:
        if p is body:
            return True
        if p.name in {"nav", "script", "style", "form", "button"} or set(
            p.get("class", [])
        ).intersection(
            {
                "article-info",
                "item-page-title",
                "comments",
                "comment-list",
                "social-share",
                "pagination",
            }
        ):
            return False
    return False


def heading_disposition(source, limitation, raw):
    exact, document, encoding, body, node, spans = _body_identity(source, raw)
    index = limitation["block_index"]
    block = source["blocks"][index]
    result = {
        "source_id": source["source_id"],
        "capture_id": source["capture_id"],
        "block_index": index,
        "raw_html_sha256": source["raw_html_sha256"],
        "text_sha256": digest(block["text"]),
        "complete_body_identity_verified": exact,
        "level": block.get("level"),
        "resolved": False,
        "raw_markup_verified": False,
        "raw_matches": [],
        "decoded_encoding": encoding,
    }
    if not exact or body is None or node is None:
        return {**result, "disposition": "BODY_IDENTITY_REQUIRES_REVIEW"}
    candidates = []
    for tag in body.find_all(["h1", "h2", "h3", "h4", "h5", "h6", "p"]):
        if (
            not _in_article(tag, body)
            or text(tag.get_text(" ", strip=True)) != block["text"]
        ):
            continue
        emphasis = (
            tag.name == "p" and len(block["text"]) <= 180 and tag.find(["strong", "b"])
        )
        if tag.name == "p" and not (
            emphasis and text(tag.get_text()) == text(emphasis.get_text())
        ):
            continue
        span = _span_for(tag, spans)
        if span and node["start"] <= span["start"] < span["end"] <= node["end"]:
            candidates.append((tag, span))
    occurrence = sum(
        b.get("type") == "heading" and b.get("text") == block["text"]
        for b in source["blocks"][:index]
    )
    expected = sum(
        b.get("type") == "heading" and b.get("text") == block["text"]
        for b in source["blocks"]
    )
    if len(candidates) != expected or occurrence >= len(candidates):
        return {**result, "disposition": "HEADING_OCCURRENCE_REQUIRES_REVIEW"}
    tag, span = candidates[occurrence]
    raw_tag = document[span["start"] : span["end"]]
    level = int(tag.name[1]) if tag.name.startswith("h") else None
    result.update(
        resolved=True,
        raw_markup_verified=True,
        level=level,
        raw_matches=[
            {
                "raw_heading_tag": raw_tag,
                "raw_heading_sha256": digest(raw_tag),
                "decoded_character_start": span["start"],
                "decoded_character_end": span["end"],
            }
        ],
    )
    result["disposition"] = (
        "VERIFIED_OWNED_NUMERIC_HEADING"
        if level
        else "VERIFIED_UNLEVELED_EMPHASIS_HEADING"
    )
    return result


def link_disposition(source, limitation, raw):
    exact, document, encoding, body, node, spans = _body_identity(source, raw)
    result = {
        "source_id": source["source_id"],
        "capture_id": source["capture_id"],
        "canonical_url": limitation["canonical_url"],
        "label": limitation["label"],
        "raw_html_sha256": source["raw_html_sha256"],
        "complete_body_identity_verified": exact,
        "resolved": False,
        "original_targets": [],
        "raw_matches": [],
        "decoded_encoding": encoding,
    }
    if not exact or body is None or node is None:
        return {**result, "disposition": "BODY_IDENTITY_REQUIRES_REVIEW"}
    base_tag = BeautifulSoup(document, "html.parser").find("base", href=True)
    base = source.get("resolved_url") or source["url"]
    if base_tag:
        try:
            base = original_target(str(base_tag["href"]), base)
        except ValueError:
            return {**result, "disposition": "DOCUMENT_BASE_REQUIRES_REVIEW"}
    for tag in body.find_all("a", href=True):
        if (
            not _in_article(tag, body)
            or text(tag.get_text(" ", strip=True)) != limitation["label"]
        ):
            continue
        href = str(tag["href"])
        try:
            target = original_target(href, base)
            canonical = normalize_url(target)
        except (ValueError, UnicodeError):
            continue
        if canonical != normalize_url(limitation["canonical_url"]):
            continue
        span = _span_for(tag, spans)
        if span and node["start"] <= span["start"] < span["end"] <= node["end"]:
            entry = {"url": target, "original_href": href}
            if entry not in result["original_targets"]:
                result["original_targets"].append(entry)
            raw_tag = document[span["start"] : span["end"]]
            result["raw_matches"].append(
                {
                    "raw_anchor_tag": raw_tag,
                    "raw_anchor_sha256": digest(raw_tag),
                    "decoded_character_start": span["start"],
                    "decoded_character_end": span["end"],
                }
            )
    result["resolved"] = len({v["url"] for v in result["original_targets"]}) == 1
    result["disposition"] = (
        "VERIFIED_OWNED_ORIGINAL_LINK_TARGET"
        if result["resolved"]
        else "OWNED_LINK_TARGET_REQUIRES_REVIEW"
    )
    return result


def capture_disposition(capture, raw, complete_sources):
    if (capture.get("http_status") or 0) >= 400 or re.search(
        r"صفحه مورد نظر یافت نشد|صفحه.*پیدا نشد|page not found|^404(?:\s|$)",
        capture.get("title", ""),
        re.IGNORECASE,
    ):
        if hashlib.sha256(raw).hexdigest() != capture["raw_html_sha256"]:
            raise ValueError("raw_checksum_mismatch")
        return {
            "capture_id": capture["capture_id"],
            "source_id": capture["source_id"],
            "url": capture["url"],
            "raw_html_sha256": capture["raw_html_sha256"],
            "disposition": "EXPLICIT_ERROR_PAGE_NOT_RECOVERED_ARTICLE",
            "publication_allowed": False,
        }
    if not capture.get("blocks") or not capture.get("body_sha256"):
        if hashlib.sha256(raw).hexdigest() != capture["raw_html_sha256"]:
            raise ValueError("raw_checksum_mismatch")
        return {
            "capture_id": capture["capture_id"],
            "source_id": capture["source_id"],
            "url": capture["url"],
            "raw_html_sha256": capture["raw_html_sha256"],
            "disposition": "NO_COMPLETE_OWNED_BODY_CAPTURED",
            "publication_allowed": False,
        }
    exact, _, _, _, node, _ = _body_identity(capture, raw)
    result = {
        "capture_id": capture["capture_id"],
        "source_id": capture["source_id"],
        "url": capture["url"],
        "raw_html_sha256": capture["raw_html_sha256"],
        "body_sha256": capture.get("body_sha256"),
        "structure_sha256": capture.get("structure_sha256"),
        "complete_body_identity_verified": exact,
        "publication_allowed": False,
    }
    if not exact or node is None:
        return {**result, "disposition": "BODY_IDENTITY_REQUIRES_REVIEW"}
    for source in complete_sources:
        if (
            source["raw_html_sha256"],
            source.get("body_sha256"),
            source.get("structure_sha256"),
        ) == (
            capture["raw_html_sha256"],
            capture.get("body_sha256"),
            capture.get("structure_sha256"),
        ) and source["url"] in {capture["url"], capture.get("resolved_url")}:
            return {
                **result,
                "disposition": "VERIFIED_EXACT_CAPTURE_ALIAS",
                "represented_source_id": source["source_id"],
            }
    body = capture.get("body_text", "")
    authored = text(" ".join(b.get("text", "") for b in capture.get("blocks", [])))
    if (
        not authored
        or authored == text(capture.get("title", ""))
        or re.search(
            r"در حال (?:بروز|به روز)|به زودی|متن سوالات متداول در حال تدوین|under construction|coming soon|no faq found",
            body,
            re.IGNORECASE,
        )
    ):
        return {**result, "disposition": "PLACEHOLDER_OR_TITLE_ONLY_REQUIRES_REVIEW"}
    if capture.get("completeness") != FULL and not all(
        b.get("type") == "heading" for b in capture.get("blocks", [])
    ):
        return {
            **result,
            "disposition": "THIN_NONHEADING_BODY_REQUIRES_HUMAN_CLASSIFICATION",
        }
    if "\ufffd" in body or capture.get("completeness") in {
        "partial_listing_excerpt",
        "multipart_article_requires_followup",
        "encoding_damage_requires_review",
    }:
        return {**result, "disposition": "INCOMPLETE_OR_DAMAGED_BODY_REQUIRES_REVIEW"}
    candidate = copy.deepcopy(capture)
    candidate.update(
        completeness=FULL,
        completeness_basis="exact_owned_container_all_authored_blocks_including_heading_only_no_translation",
        publication_allowed=False,
    )
    return {
        **result,
        "disposition": "VERIFIED_COMPLETE_OWNED_BODY",
        "candidate": candidate,
    }


def encoding_disposition(raw):
    document, encoding, _, node, _ = _owned(raw)
    defects = [i for i, c in enumerate(document) if 0xD800 <= ord(c) <= 0xDFFF]
    inside = [i for i in defects if node and node["start"] <= i < node["end"]]
    status = (
        "OWNED_BODY_ENCODING_REQUIRES_REVIEW"
        if inside or (defects and node is None)
        else "ENCODING_DEFECT_OUTSIDE_OWNED_BODY"
        if defects
        else "DECLARED_ENCODING_STRICTLY_DECODES"
    )
    return {
        "disposition": status,
        "raw_html_sha256": hashlib.sha256(raw).hexdigest(),
        "decoded_encoding": encoding,
        "defect_character_positions": defects,
        "owned_body_defect_positions": inside,
        "owned_body_span": {k: node[k] for k in ("start", "end")} if node else None,
        "original_bytes_changed": False,
        "encoding_inferred": False,
    }


def _raw_path(asset, roots):
    path = Path(asset)
    if path.is_absolute() and path.is_file():
        return path
    for root in roots:
        candidate = root / asset
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(asset)


def build(
    directory, link_evidence, output, roots, *, url_only=False, unresolved_ledger=None
):
    manifest_path = directory / "source-input-manifest.json"
    manifest_bytes = manifest_path.read_bytes()
    seal = json.loads(manifest_bytes)
    for name, expected in seal["files"].items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != expected:
            raise ValueError("input_seal_mismatch:" + name)
    output.mkdir(parents=True, exist_ok=True)
    sources = read_jsonl(directory / "sources.jsonl.gz")
    source_index = {s["capture_id"]: s for s in sources}
    inventory = read_jsonl(directory / "inventory.jsonl.gz")
    unresolved_ledger = (
        unresolved_ledger
        or directory.parent / "recovery-ready-sources/unresolved-sources.jsonl.gz"
    )
    unresolved = read_jsonl(unresolved_ledger)
    if len(unresolved) != 421 or any(
        r["disposition"] != "SOURCE_UNRESOLVED" for r in unresolved
    ):
        raise ValueError("exact_421_authoritative_unresolved_ledger_required")
    recovery_summary = json.loads(
        unresolved_ledger.with_name("summary.json").read_text(encoding="utf8")
    )
    if (
        recovery_summary.get("authoritative_source_manifest_sha256")
        != hashlib.sha256(manifest_bytes).hexdigest()
    ):
        raise ValueError("unresolved_ledger_source_seal_binding_required")
    if any(r["source_id"] != stable_id(r["url"]) for r in unresolved):
        raise ValueError("unresolved_original_url_identity_mismatch")
    sealed_urls = {r["url"] for r in inventory}
    unresolved_urls = {r["url"] for r in unresolved}
    captures_by_url = defaultdict(list)
    for row in read_jsonl(directory / "capture-versions.jsonl.gz"):
        if row["url"] in unresolved_urls:
            captures_by_url[row["url"]].append(row)

    @lru_cache(maxsize=12)
    def raw(asset):
        return gzip.decompress(_raw_path(asset, roots).read_bytes())

    heading_rows = []
    for row in (
        []
        if url_only
        else read_jsonl(directory / "heading-structure-unresolved.jsonl.gz")
    ):
        source = source_index[row["capture_id"]]
        heading_rows.append(
            {
                **heading_disposition(source, row, raw(source["raw_html_asset"])),
                "url": source["url"],
            }
        )
        if len(heading_rows) % 200 == 0:
            print("HEADING_PROOFS", len(heading_rows), flush=True)
    write_jsonl(output / "heading-dispositions.jsonl.gz", heading_rows)
    link_rows = []
    for row in [] if url_only else read_jsonl(link_evidence):
        if row.get("confirmed") is not False:
            continue
        source = source_index[row["capture_id"]]
        link_rows.append(
            {
                **link_disposition(source, row, raw(source["raw_html_asset"])),
                "url": source["url"],
                "previous_candidates": row.get("original_targets", []),
            }
        )
        if len(link_rows) % 200 == 0:
            print("LINK_PROOFS", len(link_rows), flush=True)
    write_jsonl(output / "link-dispositions.jsonl.gz", link_rows)
    url_rows, candidates = [], []
    for original in unresolved:
        assessments = []
        for capture in captures_by_url[original["url"]]:
            if capture.get("raw_html_asset"):
                result = capture_disposition(
                    capture, raw(capture["raw_html_asset"]), sources
                )
                candidate = result.pop("candidate", None)
                if candidate and not any(
                    c["source_id"] == candidate["source_id"]
                    and c["body_sha256"] == candidate["body_sha256"]
                    and c["structure_sha256"] == candidate["structure_sha256"]
                    for c in candidates
                ):
                    candidate["original_raw_html_asset"] = candidate["raw_html_asset"]
                    candidate["raw_html_asset"] = (
                        _raw_path(candidate["raw_html_asset"], roots)
                        .resolve()
                        .as_posix()
                    )
                    candidates.append(composition_source(candidate))
                assessments.append(result)
        recovered = any(
            a["disposition"] == "VERIFIED_COMPLETE_OWNED_BODY" for a in assessments
        )
        duplicate = any(
            a["disposition"] == "VERIFIED_EXACT_CAPTURE_ALIAS" for a in assessments
        )
        route = known_nonarticle_route(original["url"])
        disposition = (
            "RECOVERED_FULL_BODY"
            if recovered
            else "REPRESENTED_DUPLICATE"
            if duplicate
            else "NON_SUBSTANTIVE_SOURCE"
            if route
            else "REQUIRES_HUMAN_CLASSIFICATION"
            if assessments
            else "SOURCE_UNAVAILABLE"
        )
        url_rows.append(
            {
                **original,
                "prior_disposition": original["disposition"],
                "post_seal_discovery_identity": original["url"] not in sealed_urls,
                "disposition": disposition,
                "explanation": "complete owned body identity and exact structure preserved"
                if recovered
                else "exact evidence assessments retained; no title-based equivalence or irrecoverable claim",
                "capture_assessments": assessments,
                "original_capture_ids": [
                    c["capture_id"] for c in captures_by_url[original["url"]]
                ],
                "route_evidence": route,
                "current_live_verification": "NOT_YET_ATTEMPTED",
            }
        )
    write_jsonl(output / "url-dispositions.jsonl.gz", url_rows)
    write_jsonl(output / "recovered-sources.jsonl.gz", candidates)
    encoding_rows = []
    assets = {s["raw_html_asset"]: s for s in sources}
    for asset, source in assets.items():
        if "surrogateescape" in json.dumps(
            source.get("heading_structure_evidence", [])
        ):
            encoding_rows.append(encoding_disposition(raw(asset)))
    # The original discovery exception can belong to a non-source asset. Audit
    # its exact recorded raw identity rather than guessing which body was hurt.
    exception_paths = [
        r
        / "artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-ready-sources/encoding-discovery-exceptions.jsonl.gz"
        for r in roots
    ]
    for path in exception_paths:
        if path.exists():
            for row in read_jsonl(path):
                asset = row.get("raw_html_asset") or row.get("asset")
                if asset:
                    evidence = encoding_disposition(raw(asset))
                    if evidence not in encoding_rows:
                        encoding_rows.append(evidence)
    write_jsonl(output / "encoding-dispositions.jsonl.gz", encoding_rows)
    if manifest_path.read_bytes() != manifest_bytes:
        raise ValueError("sealed_input_changed_during_audit")
    result = {
        "version": "rad-source-limitations-v4.2",
        "scope": "url_only" if url_only else "all_recorded_limitations",
        "unresolved_ledger_sha256": hashlib.sha256(
            unresolved_ledger.read_bytes()
        ).hexdigest(),
        "source_input_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "input_files_verified": len(seal["files"]),
        "url_rows": len(url_rows),
        "url_dispositions": dict(Counter(r["disposition"] for r in url_rows)),
        "heading_rows": len(heading_rows),
        "heading_dispositions": dict(Counter(r["disposition"] for r in heading_rows)),
        "link_rows": len(link_rows),
        "link_dispositions": dict(Counter(r["disposition"] for r in link_rows)),
        "encoding_rows": len(encoding_rows),
        "recovered_sources": len(candidates),
        "recovered_blocks": sum(len(c["blocks"]) for c in candidates),
        "publication_allowed": False,
        "hosted_writes": 0,
        "original_seal_unchanged": True,
        "irrecoverable_claims": 0,
    }
    result["files"] = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(output.glob("*.jsonl.gz"))
    }
    (output / "manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
    )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-input", type=Path, required=True)
    parser.add_argument("--link-evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--asset-root", type=Path, action="append", required=True)
    parser.add_argument("--url-only", action="store_true")
    parser.add_argument("--unresolved-ledger", type=Path)
    args = parser.parse_args()
    print(
        json.dumps(
            build(
                args.source_input,
                args.link_evidence,
                args.output,
                args.asset_root,
                url_only=args.url_only,
                unresolved_ledger=args.unresolved_ledger,
            ),
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
