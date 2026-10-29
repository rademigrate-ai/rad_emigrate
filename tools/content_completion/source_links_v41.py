"""Recover original owned-link targets, including fragments, without body edits."""

import argparse
import gzip
import hashlib
import html
import json
import re
from collections import defaultdict
from pathlib import Path
from urllib.parse import urljoin, urlsplit

from tools.content_completion.full_recovery_v4 import decode_html, owned_document_base
from tools.content_completion.phase_bundle import save_json
from tools.content_completion.recovery_cache_repair_v4 import ATTR
from tools.content_completion.source_evidence import original_url
from tools.plan3_content.dataset import read_jsonl, write_jsonl
from tools.plan3_content.parser import text

LINK = re.compile(
    r"<!--.*?-->|<script\b.*?</script\s*>|<style\b.*?</style\s*>|<a\b(?P<attrs>[^>]*?)>(?P<inner>.*?)</a\s*>",
    re.IGNORECASE | re.DOTALL,
)


def original_target(href, base):
    joined = urljoin(base, html.unescape(href))
    parsed = urlsplit(joined)
    if parsed.hostname in (
        "web.archive.org",
        "www.web.archive.org",
    ) or parsed.path.startswith("/web/"):
        match = re.match(r"^/web/\d{1,14}(?:[a-z_]+)?/(https?://.+)$", parsed.path)
        if not match:
            raise ValueError("unsupported_archive_link")
        joined = (
            match[1]
            + ("?" + parsed.query if parsed.query else "")
            + ("#" + parsed.fragment if parsed.fragment else "")
        )
        parsed = urlsplit(joined)
    if (
        parsed.scheme not in ("https", "http")
        or not parsed.hostname
        or parsed.username
        or parsed.password
    ):
        raise ValueError("unsafe_original_target")
    if any(ord(c) < 32 or 0xD800 <= ord(c) <= 0xDFFF for c in joined):
        raise ValueError("invalid_original_target_characters")
    return joined


def raw_links(raw, source_url, allowed_labels=None):
    try:
        decoded, encoding = decode_html(raw)
        document = decoded.decode("utf-8")
    except (UnicodeError, LookupError):
        document, encoding = (
            raw.decode("utf-8", errors="surrogateescape"),
            "utf-8-surrogateescape-evidence-only",
        )
    base = owned_document_base(raw, source_url)
    found = defaultdict(list)
    for match in LINK.finditer(document):
        if match["attrs"] is None:
            continue
        attrs = {
            k.lower(): html.unescape(a or b or c)
            for k, a, b, c in ATTR.findall(match["attrs"])
        }
        href = attrs.get("href")
        if not href:
            continue
        label = text(html.unescape(re.sub(r"<[^>]*>", " ", match["inner"])))
        if allowed_labels is not None and label not in allowed_labels:
            continue
        try:
            target, canonical = original_target(href, base), original_url(href, base)
        except (ValueError, UnicodeError):
            continue
        raw_tag = match.group()
        if any(0xD800 <= ord(c) <= 0xDFFF for c in raw_tag):
            continue
        found[(canonical, label)].append(
            {
                "url": target,
                "original_href": href,
                "raw_anchor_tag": raw_tag,
                "raw_anchor_sha256": hashlib.sha256(
                    raw_tag.encode("utf-8")
                ).hexdigest(),
                "decoded_character_start": match.start(),
                "decoded_character_end": match.end(),
                "decoded_encoding": encoding,
            }
        )
    return found, base


def build(directory, output):
    manifest = directory / "source-input-manifest.json"
    before = hashlib.sha256(manifest.read_bytes()).hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    sources = read_jsonl(directory / "sources.jsonl.gz") + read_jsonl(
        directory / "version-supplements.jsonl.gz"
    )
    groups = defaultdict(list)
    for source in sources:
        groups[source["raw_html_asset"]].append(source)
    rows = []
    for index, (asset, members) in enumerate(sorted(groups.items())):
        raw = gzip.decompress(Path(asset).read_bytes())
        if any(
            hashlib.sha256(raw).hexdigest() != s["raw_html_sha256"] for s in members
        ):
            raise ValueError("source_link_raw_checksum_mismatch")
        for source in members:
            owned_links = source.get("body_links", source.get("links", []))
            if not owned_links:
                continue
            links, base = raw_links(
                raw,
                source.get("resolved_url") or source["url"],
                {text(l.get("label", "")) for l in owned_links},
            )
            for owned in owned_links:
                canonical = owned["url"]
                label = text(owned.get("label", ""))
                candidates = links.get((canonical, label), [])
                targets = {(r["url"], r["original_href"]) for r in candidates}
                if owned.get("original_href"):
                    try:
                        targets.add(
                            (
                                original_target(owned["original_href"], base),
                                owned["original_href"],
                            )
                        )
                    except (ValueError, UnicodeError):
                        pass
                unique_urls = {url for url, _ in targets}
                rows.append(
                    {
                        "source_id": source["source_id"],
                        "capture_id": source["capture_id"],
                        "raw_html_sha256": source["raw_html_sha256"],
                        "canonical_url": canonical,
                        "label": label,
                        "original_targets": [
                            {"url": u, "original_href": h} for u, h in sorted(targets)
                        ],
                        "confirmed": len(unique_urls) == 1,
                        "status": "unique_owned_target_raw_href_preserved"
                        if len(unique_urls) == 1
                        else "ambiguous_distinct_raw_targets_retained"
                        if targets
                        else "canonical_only_original_fragment_unconfirmed",
                        "raw_matches": candidates,
                        "body_blocks_and_original_structure_unchanged": True,
                    }
                )
        if index % 200 == 0:
            print("SOURCE_LINKS", index, "of", len(groups), flush=True)
    path = output / "source-link-evidence.jsonl.gz"
    write_jsonl(path, rows)
    if hashlib.sha256(manifest.read_bytes()).hexdigest() != before:
        raise ValueError("sealed_source_manifest_changed")
    summary = {
        "version": "rad-source-links-v4.1",
        "source_input_manifest_sha256": before,
        "owned_link_rows": len(rows),
        "confirmed": sum(r["confirmed"] for r in rows),
        "unconfirmed": sum(not r["confirmed"] for r in rows),
        "original_fragment_targets": sum(
            bool(urlsplit(t["url"]).fragment)
            for r in rows
            for t in r["original_targets"]
        ),
        "source_link_evidence_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "source_input_modified": False,
        "new_network_requests": 0,
    }
    save_json(output / "manifest.json", summary)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--directory",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-source-input"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-source-links-v41"
        ),
    )
    args = parser.parse_args()
    print(json.dumps(build(args.directory, args.output), sort_keys=True))
