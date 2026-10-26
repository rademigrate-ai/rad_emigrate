"""Offline, versioned original-link capture around the sealed body library.

No fetch, legal verification, approval, or publication occurs here. Source body
and raw HTML hashes are required; old import manifests/snapshots stay unchanged.
"""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
from urllib.parse import quote, unquote, urljoin, urlsplit, urlunsplit

from bs4 import BeautifulSoup

from tools.plan3_content.dataset import read_jsonl, write_jsonl
from tools.plan3_content.parser import normalize_url, text


def safe_url(value, base):
    value = urljoin(base, value)
    p = urlsplit(value)
    if (
        p.scheme not in ("http", "https")
        or not p.hostname
        or p.username
        or p.password
        or p.port not in (None, 80, 443)
    ):
        raise ValueError("unsafe_reference")
    if any(ord(c) < 32 for c in value):
        raise ValueError("unsafe_reference")
    return urlunsplit(
        (
            p.scheme,
            p.netloc,
            quote(p.path, safe="/%:@!$&'()*+,;=-._~"),
            quote(p.query, safe="%=&?/:@!$'()*+,;-._~"),
            quote(p.fragment, safe="%:@!$&'()*+,;=/?-._~"),
        )
    )


def extract_references(raw, source):
    soup = BeautifulSoup(raw, "html.parser", from_encoding="utf-8")
    if source["parser_selector"] == ".BoxSizeAsli .Box > .BoxCenter":
        h1 = soup.find("h1")
        box = h1.find_parent(class_="Box") if h1 else None
        body = box.find(class_="BoxCenter", recursive=False) if box else None
    else:
        nodes = soup.select(source["parser_selector"])
        body = (
            max(nodes, key=lambda n: len(n.get_text(" ", strip=True)))
            if nodes
            else None
        )
    if body is None:
        raise ValueError("source_reference_region_not_bound")
    base = source.get("resolved_url") or source["url"]
    if soup.base and soup.base.get("href"):
        base = safe_url(str(soup.base["href"]), base)
    allowed = {(r["url"], r["label"]) for r in source.get("body_links", [])}
    links = []
    seen = set()
    for node in body.select("a[href]"):
        raw_href = str(node["href"])
        label = text(node.get_text(" ", strip=True))
        try:
            target = safe_url(raw_href, base)
            if (normalize_url(target), label) not in allowed:
                continue
        except (ValueError, UnicodeError):
            continue
        key = (target, label)
        if key in seen:
            continue
        seen.add(key)
        links.append(
            {
                "url": target,
                "label": label,
                "original_href": raw_href,
                "source_snapshot_id": source["snapshot_id"],
                "source_url": source["url"],
                "verification_state": "unverified",
                "target_block_id": None,
            }
        )
    anchors = {}
    for node in body.select("[id],[name]"):
        label = text(node.get_text(" ", strip=True))
        matches = [
            i for i, b in enumerate(source["blocks"]) if label and b["text"] == label
        ]
        for value in [node.get("id"), node.get("name")]:
            if value:
                anchors.setdefault(str(value), []).extend(matches)
    anchors = {
        key: values[0] for key, values in anchors.items() if len(set(values)) == 1
    }
    return {
        "source_id": source["source_id"],
        "snapshot_id": source["snapshot_id"],
        "body_sha256": source["body_sha256"],
        "raw_html_sha256": source["raw_html_sha256"],
        "url": source["url"],
        "links": links,
        "anchors": anchors,
        "capture_status": "complete",
    }


def build(library, caches, output):
    manifest = json.loads((library / "manifest.json").read_text(encoding="utf8"))
    for name in ["sources.jsonl.gz", "articles.jsonl.gz"]:
        if (
            hashlib.sha256((library / name).read_bytes()).hexdigest()
            != manifest["files"][name]
        ):
            raise ValueError("source_library_checksum")
    sources = {
        s["source_id"]: s
        for s in read_jsonl(library / "sources.jsonl.gz")
        if s.get("consolidation_disposition") == "body_ready_for_unreviewed_composition"
    }
    captures = {}
    for source_id, s in sources.items():
        raw = None
        for cache in caches:
            path = cache / (s["collector_id"] + ".html.gz")
            if path.resolve().parent != cache.resolve():
                raise ValueError("unsafe_cache_identity")
            if path.is_file():
                with gzip.open(path, "rb") as stream:
                    value = stream.read(16 * 1024 * 1024 + 1)
                if (
                    len(value) <= 16 * 1024 * 1024
                    and hashlib.sha256(value).hexdigest() == s["raw_html_sha256"]
                ):
                    raw = value
                    break
        if raw is None:
            raise ValueError("hash_verified_raw_html_missing:" + source_id)
        captures[source_id] = extract_references(raw, s)
    by_url = {normalize_url(s["url"]): s for s in sources.values()}
    maps = []
    for article in read_jsonl(library / "articles.jsonl.gz"):
        positions = {
            (r["snapshot_id"], r["block_index"]): b["id"]
            for sec in article["sections"]
            for b in sec["blocks"]
            for r in b["provenance"]
        }
        links = []
        bound = []
        for source_id in article["source_ids"]:
            capture = captures[source_id]
            bound.append(
                {
                    k: capture[k]
                    for k in ("snapshot_id", "body_sha256", "raw_html_sha256")
                }
            )
            for original in capture["links"]:
                link = dict(original)
                target_source = by_url.get(normalize_url(link["url"]))
                fragment = unquote(urlsplit(link["url"]).fragment)
                if target_source is not None and fragment:
                    target_capture = captures[target_source["source_id"]]
                    block = target_capture["anchors"].get(fragment)
                    if block is not None:
                        link["target_block_id"] = positions.get(
                            (target_source["snapshot_id"], block)
                        )
                links.append(link)
        maps.append(
            {
                "article_id": article["article_id"],
                "locale": article["locale"],
                "expected_revision": 1,
                "map": {
                    "capture_status": "complete",
                    "sources": bound,
                    "links": links,
                    "media_reuse": "not_authorized",
                    "legal_verification": "not_inferred_from_links",
                },
            }
        )
    output.mkdir(parents=True, exist_ok=True)
    write_jsonl(output / "source_references.jsonl.gz", list(captures.values()))
    write_jsonl(output / "article_reference_maps.jsonl.gz", maps)
    summary = {
        "schema_version": "rad-original-references-1",
        "body_library_manifest_sha256": hashlib.sha256(
            (library / "manifest.json").read_bytes()
        ).hexdigest(),
        "source_captures": len(captures),
        "article_locales": len(maps),
        "original_links": sum(len(c["links"]) for c in captures.values()),
        "links_with_fragments": sum(
            bool(urlsplit(link["url"]).fragment)
            for c in captures.values()
            for link in c["links"]
        ),
        "mapped_in_article_targets": sum(
            link["target_block_id"] is not None
            for m in maps
            for link in m["map"]["links"]
        ),
        "verified_legal_claims": 0,
        "human_approvals": 0,
        "publication_ready": 0,
        "extractor_sha256": hashlib.sha256(
            Path(__file__).read_bytes().replace(b"\r\n", b"\n")
        ).hexdigest(),
        "files": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in output.glob("*.gz")
        },
    }
    (output / "manifest.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
    )
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--cache", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.library, args.cache, args.output)))
