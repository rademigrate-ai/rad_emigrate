"""Reaudit the entire portable source inventory and resume first-party recovery.

Existing inputs are immutable. New requests respect robots and per-host limits.
An unavailable policy or exhausted frontier remains an explicit limitation, never
proof that a source is unrecoverable. No database or publication operations exist.
"""

from __future__ import annotations

import argparse
import codecs
import copy
import gzip
import hashlib
import html
import json
import re
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict, deque
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import parse_qs, unquote, urlsplit, urlunsplit
from urllib.robotparser import RobotFileParser

from tools.content_completion.guarded_crawl import GuardedCollector
from tools.content_completion.phase_bundle import save_json
from tools.content_completion.source_evidence import (
    country_evidence,
    original_url,
    parse_mohajer,
)
from tools.content_consolidation.parser import extract_primary
from tools.plan3_content.crawl import disposition, now, stable_id
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import HOSTS, digest, normalize_url, text
from tools.plan3_content.taxonomy import classify

VERSION = "rad-full-recovery-v4"
FULL = "complete_owned_article_container"
DEFAULT_BUNDLE = Path("_audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028")
DEFAULT_OUTPUT = Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery")


def route_disposition(url):
    """Distinguish media from exclusions and admit read-only Joomla articles."""
    p = urlsplit(url)
    path = unquote(p.path).lower()
    if re.search(r"\.(?:pdf|docx?|xlsx?|zip|rar|png|jpe?g|webp|gif|svg|mp[34])$", path):
        return "ATTACHMENT_REFERENCE", "media_or_document_reference"
    query = parse_qs(p.query)
    if (
        query.get("option") == ["com_content"]
        and query.get("view") == ["article"]
        and query.get("id")
        and not any(k in query for k in ("task", "action", "do", "delete", "logout"))
    ):
        return None
    reason = disposition(url)
    return ("NONCONTENT_ROUTE", reason) if reason else None


def known_nonarticle_route(url):
    """Exact endpoint evidence, never broad about/country/title substrings."""
    reason = route_disposition(url)
    if reason:
        return reason
    parsed_url = urlsplit(url)
    path = unquote(parsed_url.path).rstrip("/").casefold()
    if path in ("", "/fa", "/en", "/404.htm", "/404.html"):
        return "NONCONTENT_ROUTE", "explicit_home_or_error_endpoint"
    if not parsed_url.query and path in (
        "/index.aspx",
        "/index.php",
        "/index.htm",
        "/index.html",
    ):
        return "NONCONTENT_ROUTE", "explicit_default_index_home_endpoint"
    leaf = path.rsplit("/", 1)[-1]
    leaf = re.sub(r"\.(?:html?|aspx)$", "", leaf)
    if leaf in {
        "about-us",
        "about",
        "aboutus",
        "contact-us",
        "contactus",
        "contact",
        "contacts",
        "تماس-با-ما",
        "درباره-ما",
    }:
        return "NONCONTENT_ROUTE", "explicit_company_about_or_contact_endpoint"
    if re.search(r"^/(?:catarticle|catnews|formid|search)(?:/|$)", path):
        return "NONCONTENT_ROUTE", "explicit_archive_or_form_endpoint"
    return None


def explicit_placeholder_reason(source):
    body = text(
        " ".join(
            b.get("text", "")
            for b in source.get("blocks", [])
            if b.get("type") != "heading"
        )
    )
    if re.fullmatch(
        r"(?:به زودی|under construction|coming soon|no faq found)[\s.!…]*",
        body,
        re.IGNORECASE,
    ) or re.fullmatch(
        r"متن سوالات متداول در حال تدوین است[.\s]*لطفا بعدا مجددا مراجعه نمایید[.\s]*",
        body,
    ):
        return (
            "NONCONTENT_ROUTE",
            "captured_explicit_placeholder_message_contains_no_substantive_article_body",
        )
    return None


class Links(HTMLParser):
    def __init__(self, raw, url):
        super().__init__(convert_charrefs=True)
        self.url, self.links, self.media, self.pagination = url, set(), set(), set()
        self.base_url = url
        # HTMLParser only discovers URLs. The full extractor below performs
        # encoding validation and retains original bytes independently.
        self.feed(raw.decode("utf-8-sig", errors="replace"))

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "base" and values.get("href"):
            try:
                target = resolve_html_base(values["href"], self.url)
                if urlsplit(target).hostname in HOSTS:
                    self.base_url = target
            except (ValueError, UnicodeError):
                pass
            return
        attr = "href" if tag in ("a", "link") else "src"
        if attr not in values or not values[attr]:
            return
        try:
            target = original_url(values[attr], self.base_url)
        except (ValueError, UnicodeError):
            return
        if tag in ("img", "video", "audio", "source", "iframe"):
            self.media.add(target)
        elif urlsplit(target).hostname in HOSTS:
            self.links.add(target)
            rel = values.get("rel", "").split()
            if (
                "next" in rel
                or "prev" in rel
                or re.search(r"(?:[?&](?:start|limitstart|page)=|/page/\d+)", target)
            ):
                self.pagination.add(target)


def decode_html(raw, content_type=""):
    """Honor explicit supported character encodings without replacing bytes."""
    declared = re.search(r"charset\s*=\s*[\"']?([\w-]+)", content_type, re.IGNORECASE)
    if not declared:
        declared = re.search(
            rb"charset\s*=\s*[\"']?([\w-]+)", raw[:8192], re.IGNORECASE
        )
    encoding = declared[1] if declared else "utf-8-sig"
    if isinstance(encoding, bytes):
        encoding = encoding.decode("ascii")
    encoding = codecs.lookup(encoding).name
    return raw.decode(encoding, errors="strict").encode("utf-8"), encoding


def parse_owned(raw, url, content_type=""):
    raw, encoding = decode_html(raw, content_type)
    base_url = owned_document_base(raw, url)
    if urlsplit(url).hostname == "radmohajer.ir":
        parsed = parse_mohajer(raw, base_url)
        for article in parsed["articles"]:
            article["decoded_encoding"] = encoding
            if article[
                "completeness"
            ] == "thin_or_placeholder_requires_review" and substantive_owned_body(
                article
            ):
                article["completeness"] = FULL
                article["completeness_basis"] = (
                    "owned_article_container_title_and_substantive_blocks_no_arbitrary_length_threshold"
                )
        return parsed["articles"], parsed["page_kind"]
    parsed = extract_primary(raw, base_url)
    body = parsed.get("body_text", "")
    complete = bool(
        parsed.get("body_status") == "complete_source_container"
        and substantive_owned_body(parsed)
        and "\ufffd" not in body
    )
    if re.search(r"^/(?:catarticle|catnews|formid|search)(?:/|$)", urlsplit(url).path):
        complete = False
    if urlsplit(url).path.lower() in ("/404.htm", "/404.html"):
        complete = False
    parsed["completeness"] = FULL if complete else "incomplete_or_nonarticle"
    parsed["parser_version"] = VERSION
    parsed["assets"] = parsed.get("source_assets", [])
    parsed["original_links"] = parsed.get("body_links", [])
    parsed["decoded_encoding"] = encoding
    return [parsed], "article" if complete else "incomplete_or_nonarticle"


def resolve_html_base(value, url):
    target = original_url(value, url)
    if urlsplit(value).path.endswith("/"):
        parsed = urlsplit(target)
        target = urlunsplit(
            (
                parsed.scheme,
                parsed.netloc,
                parsed.path.rstrip("/") + "/",
                parsed.query,
                "",
            )
        )
    return target


def owned_document_base(raw, url):
    match = re.search(
        rb"""<base\b[^>]*?href\s*=\s*["']([^"']+)["']""", raw, re.IGNORECASE
    )
    if match:
        try:
            base = resolve_html_base(html.unescape(match[1].decode("utf-8")), url)
            if urlsplit(base).hostname in HOSTS:
                return base
        except (ValueError, UnicodeError):
            pass
    return url


def substantive_owned_body(parsed):
    """Short original articles survive; explicit placeholders remain unresolved."""
    if not parsed.get("title"):
        return False
    values = [
        b["text"]
        for b in parsed.get("blocks", [])
        if b["type"] != "heading" and b.get("text", "").strip()
    ]
    body = " ".join(values).strip()
    if not body or body == parsed["title"]:
        return False
    if re.fullmatch(r"[\W\d_]+", body, re.UNICODE):
        return False
    if re.search(
        r"در حال (?:بروز|به روز)|به زودی|متن سوالات متداول در حال تدوین|under construction|coming soon|no faq found",
        body,
        re.IGNORECASE,
    ):
        return False
    return bool(re.search(r"[A-Za-z\u0600-\u06ff]", body))


def capture_from_raw(raw, url, metadata, asset):
    articles, kind = parse_owned(
        raw, metadata.get("final_url", url), metadata.get("content_type", "")
    )
    rows = []
    for parsed in articles:
        body = parsed.get("body_text", "")
        checksum = digest(body) if body else None
        raw_hash = hashlib.sha256(raw).hexdigest()
        sid = stable_id(url)
        rows.append(
            {
                "capture_id": uid(f"{VERSION}:{sid}:{raw_hash}:{checksum}"),
                "source_id": sid,
                "snapshot_id": uid(f"snapshot:{sid}:{checksum}") if checksum else None,
                "url": url,
                "title": parsed.get("title", ""),
                "language": parsed.get("language") or "fa",
                "blocks": parsed.get("blocks", []),
                "body_text": body,
                "body_sha256": checksum,
                "structure_sha256": digest(parsed.get("blocks", [])),
                "raw_html_sha256": raw_hash,
                "raw_html_asset": asset,
                "raw_html_bytes": len(raw),
                "completeness": parsed["completeness"],
                "parser_version": VERSION,
                "owned_container_status": parsed.get("body_status"),
                "source_container_text_chars": parsed.get(
                    "source_container_text_chars"
                ),
                "decoded_encoding": parsed.get("decoded_encoding"),
                "acquisition_method": metadata.get("method", "fresh_public_fetch"),
                "acquisition_timestamp": metadata.get("retrieved_at"),
                "acquisition_timestamp_status": "recorded"
                if metadata.get("retrieved_at")
                else "not_recorded_do_not_infer_from_file_timestamp",
                "http_status": metadata.get("status"),
                "resolved_url": metadata.get("final_url", url),
                "links": parsed.get("original_links", []),
                "assets": parsed.get("assets", []),
                "warnings": parsed.get("warnings", []),
                "page_kind": kind,
                "publication_allowed": False,
            }
        )
    return rows


def composition_source(capture):
    """A full original body in the existing composition input shape."""
    row = copy.deepcopy(capture)
    row["original_capture_language"] = row.get("language")
    row["language"], row["language_evidence"] = source_language_evidence(row)
    # Only title/URL evidence may establish a country destination. Scanning
    # every paragraph for incidental neighboring-country mentions cannot alter
    # that decision, and is unnecessarily costly across long versioned bodies.
    countries = country_evidence(row["title"], row["url"], "")
    taxonomy = classify(row["title"], row["url"])
    taxonomy.update(
        country_codes=countries["country_codes"],
        country_evidence=countries["evidence"],
        country_disagreement=countries["disagreement"],
    )
    row.update(
        domain=urlsplit(row["url"]).hostname,
        taxonomy=taxonomy,
        complete_article_body=True,
        consolidation_disposition="body_ready_for_unreviewed_composition",
        body_links=row.get("links", []),
        source_assets=row.get("assets", []),
        retrieved_at=row.get("acquisition_timestamp")
        or row.get("evidence_intake_timestamp"),
        retrieved_at_semantics="original_HTTP_capture"
        if row.get("acquisition_timestamp")
        else "recorded_local_evidence_intake_not_original_HTTP_fetch",
        fetch_status="fetched",
    )
    return row


def source_language_evidence(source):
    """Original route/title/narrative evidence outranks Latin proper-name tables."""
    path = unquote(urlsplit(source["url"]).path).casefold()
    explicit_en = bool(re.search(r"(?:^|/)(?:en)(?:/|$)|/lang/2(?:/|$)", path))
    explicit_fa = bool(re.search(r"(?:^|/)fa(?:/|$)", path))
    persian_letters = (
        r"[\u0621-\u063a\u0641-\u064a\u067e\u0686\u0698\u06a9\u06af\u06cc]"
    )
    title_persian = bool(re.search(persian_letters, source.get("title", "")))
    narrative = " ".join(
        [
            b.get("text", "")
            for b in source.get("blocks", [])
            if b.get("type") not in ("heading", "table", "bullet_list", "numbered_list")
            and b.get("text", "").strip()
        ][:3]
    )
    lead_persian = len(re.findall(persian_letters, narrative[:1200])) > len(
        re.findall(r"[A-Za-z]", narrative[:1200])
    )
    language = source.get("language") or "fa"
    basis = "preserved_original_capture_classification"
    if explicit_en and title_persian and lead_persian:
        language, basis = (
            "fa",
            "English_route_served_original_Persian_title_and_narrative_no_English_translation_exists",
        )
    elif explicit_en:
        language, basis = "en", "explicit_original_English_route_no_translation"
    elif explicit_fa and (title_persian or lead_persian):
        language, basis = "fa", "explicit_Persian_route_and_Persian_title_or_narrative"
    elif title_persian and lead_persian:
        language, basis = (
            "fa",
            "Persian_title_and_opening_narrative_Latin_tables_are_proper_names",
        )
    return language, {
        "basis": basis,
        "original_capture_language": source.get("language"),
        "explicit_fa_route": explicit_fa,
        "explicit_en_route": explicit_en,
        "route_content_language_conflict": explicit_en
        and title_persian
        and lead_persian,
        "Persian_title": title_persian,
        "Persian_narrative_lead": lead_persian,
        "narrative_lead_excerpt": narrative[:200],
        "translation_created": False,
    }


class Recovery:
    def __init__(self, bundle, output, interval=2, budget=10000, fresh=False):
        self.bundle, self.output, self.fresh = bundle, output, fresh
        self.output.mkdir(parents=True, exist_ok=True)
        self.collector = GuardedCollector(output / "network", interval, budget)
        self.budget = budget
        self.master = {
            r["url"]: r for r in read_jsonl(bundle / "source-master.jsonl.gz")
        }
        self.captures = read_jsonl(bundle / "source-captures.jsonl.gz")
        self.by_url = defaultdict(list)
        self.frontier = set(self.master)
        self.references, self.observations, self.media = [], [], []
        self.verified_raw = {}
        self.original_unresolved = {
            u
            for u, r in self.master.items()
            if r["recovery_status"]
            not in (
                "full_body_and_verified_raw",
                "excluded_noneditorial_query_stateful_or_legacy_template_route",
            )
        }

    def ingest_existing(self):
        for row in self.captures:
            if "\n\n".join(b["text"] for b in row["blocks"]) != row["body_text"]:
                raise ValueError("capture_body_and_blocks_disagree")
            if digest(row["blocks"]) != row["structure_sha256"]:
                raise ValueError("capture_structure_checksum_mismatch")
            if row["body_text"] and digest(row["body_text"]) != row["body_sha256"]:
                raise ValueError("capture_body_checksum_mismatch")
            self.by_url[row["url"]].append(row)
            relative = row.get("raw_html_asset")
            if not relative:
                continue
            path = (self.bundle / relative).resolve()
            if not path.is_relative_to(self.bundle.resolve()):
                raise ValueError("raw_asset_escapes_bundle")
            if path not in self.verified_raw:
                raw = gzip.decompress(path.read_bytes())
                if hashlib.sha256(raw).hexdigest() != row["raw_html_sha256"]:
                    raise ValueError("raw_asset_checksum_mismatch")
                self.verified_raw[path] = row["raw_html_sha256"]
                discovered = Links(raw, row["url"])
                self.frontier.update(discovered.links)
                self.references.extend(
                    {
                        "source_url": row["url"],
                        "target_url": u,
                        "raw_sha256": row["raw_html_sha256"],
                    }
                    for u in sorted(discovered.pagination)
                )
                self.media.extend(
                    {
                        "source_url": row["url"],
                        "url": u,
                        "raw_sha256": row["raw_html_sha256"],
                    }
                    for u in sorted(discovered.media)
                )
            elif self.verified_raw[path] != row["raw_html_sha256"]:
                raise ValueError("shared_raw_asset_checksum_disagrees")
            # Reparse every unresolved raw version using the current adapters.
            if row["url"] in self.original_unresolved:
                raw = gzip.decompress(path.read_bytes())
                reparsed = capture_from_raw(
                    raw,
                    row["url"],
                    {
                        "method": "immutable_prior_raw_reparsed",
                        "retrieved_at": row.get("acquisition_timestamp"),
                        "status": row.get("http_status"),
                    },
                    path.relative_to(Path.cwd()).as_posix(),
                )
                self.by_url[row["url"]].extend(reparsed)

    def bootstrap_host(self, host):
        collector = self.collector
        robots = f"https://{host}/robots.txt"
        try:
            raw, metadata = collector.request(robots, True)
            decoded = raw.decode("utf-8-sig", errors="strict")
            if "<html" in decoded.lower():
                raise ValueError("robots_returned_html")
            policy = RobotFileParser(robots)
            policy.parse(decoded.splitlines())
            collector.robots[host] = policy
            self.observations.append(
                {"kind": "robots", "url": robots, "body": decoded, **metadata}
            )
            pending = deque(policy.site_maps() or [f"https://{host}/sitemap.xml"])
            seen = set()
            while pending and len(seen) < 100:
                url = normalize_url(pending.popleft())
                if url in seen:
                    continue
                seen.add(url)
                if urlsplit(url).hostname != host or not collector.allowed(url):
                    self.observations.append(
                        {
                            "kind": "sitemap",
                            "url": url,
                            "error": "scope_or_robots_denied",
                        }
                    )
                    continue
                try:
                    data, meta = collector.request(url)
                    root = ET.fromstring(data)
                    targets = [
                        normalize_url(node.text)
                        for node in root.iter()
                        if node.tag.endswith("}loc") and node.text
                    ]
                    if root.tag.endswith("sitemapindex"):
                        pending.extend(targets)
                    else:
                        self.frontier.update(
                            u for u in targets if urlsplit(u).hostname in HOSTS
                        )
                    self.observations.append(
                        {
                            "kind": "sitemap",
                            "url": url,
                            "entries": targets,
                            "body_sha256": hashlib.sha256(data).hexdigest(),
                            **meta,
                        }
                    )
                except (OSError, ValueError, ET.ParseError) as exc:
                    self.observations.append(
                        {
                            "kind": "sitemap",
                            "url": url,
                            "error": str(exc),
                            "status": getattr(exc, "code", None),
                        }
                    )
            if pending:
                self.observations.append(
                    {
                        "kind": "discovery_limitation",
                        "host": host,
                        "reason": "sitemap_budget_exhausted",
                        "pending": list(pending),
                    }
                )
        except (OSError, ValueError, UnicodeError) as exc:
            collector.circuit[host] = collector.circuit.get(
                host, "robots_policy_unavailable"
            )
            self.observations.append(
                {
                    "kind": "robots",
                    "url": robots,
                    "error": str(exc),
                    "status": getattr(exc, "code", None),
                }
            )

    def fetch_host(self, host):
        collector = self.collector
        pending = deque(
            sorted(u for u in self.frontier.copy() if urlsplit(u).hostname == host)
        )
        seen, fetched = set(), 0
        full = {
            u
            for u, captures in self.by_url.items()
            if any(c["completeness"] == FULL for c in captures)
        }
        while pending:
            url = pending.popleft()
            if url in seen:
                continue
            seen.add(url)
            if url in full or route_disposition(url):
                continue
            observation = {"url": url, "kind": "article_fetch", "retrieved_at": now()}
            if host in collector.circuit:
                observation["error"] = "host_access_hold:" + collector.circuit[host]
            elif not collector.allowed(url):
                observation["error"] = "robots_denied_or_policy_unavailable"
            elif fetched >= self.budget:
                observation["error"] = "host_fetch_budget_exhausted"
            else:
                fetched += 1
                sid = stable_id(url)
                asset = self.output / "network" / (sid + ".html.gz")
                meta_path = asset.with_suffix(".json")
                try:
                    if asset.exists() and meta_path.exists():
                        metadata = json.loads(meta_path.read_text(encoding="utf-8"))
                        raw = gzip.decompress(asset.read_bytes())
                        if (
                            metadata["url"] != url
                            or hashlib.sha256(raw).hexdigest() != metadata["raw_sha256"]
                        ):
                            raise ValueError("fresh_cache_integrity_failure")
                        observation["cache_reused"] = True
                    else:
                        raw, metadata = collector.request(url)
                        metadata.update(
                            url=url, raw_sha256=hashlib.sha256(raw).hexdigest()
                        )
                        asset.write_bytes(gzip.compress(raw, mtime=0))
                        save_json(meta_path, metadata)
                    observation.update(metadata)
                    captures = capture_from_raw(
                        raw,
                        url,
                        metadata,
                        asset.resolve().relative_to(Path.cwd()).as_posix(),
                    )
                    self.by_url[url].extend(captures)
                    discovered = Links(raw, metadata.get("final_url", url))
                    for target in sorted(discovered.links):
                        if target not in self.frontier:
                            self.frontier.add(target)
                        if urlsplit(target).hostname == host and target not in seen:
                            pending.append(target)
                    self.references.extend(
                        {
                            "source_url": url,
                            "target_url": u,
                            "raw_sha256": metadata["raw_sha256"],
                        }
                        for u in sorted(discovered.pagination)
                    )
                    self.media.extend(
                        {
                            "source_url": url,
                            "url": u,
                            "raw_sha256": metadata["raw_sha256"],
                        }
                        for u in sorted(discovered.media)
                    )
                    observation["capture_ids"] = [c["capture_id"] for c in captures]
                except (OSError, ValueError, UnicodeError, RecursionError) as exc:
                    observation.update(
                        error=type(exc).__name__ + ":" + str(exc),
                        status=getattr(exc, "code", None),
                    )
                    if isinstance(exc, HTTPError):
                        exc.close()
            self.observations.append(observation)
            with (self.output / "network" / (host + ".progress.jsonl")).open(
                "a", encoding="utf-8"
            ) as stream:
                stream.write(
                    json.dumps(observation, ensure_ascii=False, sort_keys=True) + "\n"
                )
        return len(seen)

    def finish(self):
        ledger, sources, versions, supplements = [], [], [], []
        nonarticle_captures, full_owned_urls = [], set()
        original_capture_ids = {c["capture_id"] for c in self.captures}
        observations = defaultdict(list)
        for observation in self.observations:
            if observation.get("url"):
                observations[observation["url"]].append(observation)
        for url in sorted(self.frontier):
            prior = self.master.get(url, {})
            captures = {c["capture_id"]: c for c in self.by_url[url]}
            full = [
                c
                for c in captures.values()
                if c["completeness"] == FULL and c.get("body_text")
            ]
            if full:
                full_owned_urls.add(url)
            eligible = []
            exclusion = known_nonarticle_route(url)
            capture_exclusion_reason = None
            for capture in full:
                reason = (
                    exclusion
                    or known_nonarticle_route(capture.get("resolved_url") or url)
                    or explicit_placeholder_reason(capture)
                )
                if reason:
                    capture_exclusion_reason = reason
                    nonarticle_captures.append(
                        {
                            "source_id": capture["source_id"],
                            "url": url,
                            "capture_id": capture["capture_id"],
                            "raw_html_sha256": capture["raw_html_sha256"],
                            "body_sha256": capture["body_sha256"],
                            "disposition": reason[0],
                            "basis": reason[1],
                            "body_and_original_blocks_retained_in_capture_versions": True,
                        }
                    )
                else:
                    eligible.append(capture)
            all_owned_ids = sorted(c["capture_id"] for c in full)
            full = eligible
            for c in captures.values():
                preserved = copy.deepcopy(c)
                if c["capture_id"] in original_capture_ids and c.get(
                    "raw_html_asset", ""
                ).startswith("assets/raw/"):
                    preserved["raw_html_asset"] = (
                        self.bundle / c["raw_html_asset"]
                    ).as_posix()
                versions.append(preserved)
            reason = exclusion or (capture_exclusion_reason if not full else None)
            status, basis = reason if reason else (None, None)
            if full:
                # Selection is a deterministic preview default. ALL distinct
                # complete versions remain in capture-versions and are flagged.
                selected = max(
                    full,
                    key=lambda c: (
                        c.get("acquisition_timestamp") or "",
                        c["capture_id"],
                    ),
                )
                source = composition_source(selected)
                source["available_complete_capture_ids"] = sorted(
                    c["capture_id"] for c in full
                )
                source["distinct_body_versions"] = len({c["body_sha256"] for c in full})
                source["version_conflict_preserved"] = (
                    source["distinct_body_versions"] > 1
                )
                if selected["capture_id"] in original_capture_ids and selected.get(
                    "raw_html_asset", ""
                ).startswith("assets/raw/"):
                    source["raw_html_asset"] = (
                        self.bundle / selected["raw_html_asset"]
                    ).as_posix()
                sources.append(source)
                distinct = {}
                for capture in sorted(full, key=lambda c: c["capture_id"]):
                    distinct.setdefault(
                        (capture["body_sha256"], capture["structure_sha256"]), capture
                    )
                selected_signature = (
                    selected["body_sha256"],
                    selected["structure_sha256"],
                )
                for signature, capture in sorted(distinct.items()):
                    if signature == selected_signature:
                        continue
                    supplement = composition_source(capture)
                    supplement["origin_source_id"] = supplement["source_id"]
                    supplement["source_id"] = uid(
                        "v4-source-version:"
                        + supplement["source_id"]
                        + ":"
                        + ":".join(signature)
                    )
                    supplement["version_role"] = (
                        "complete_alternate_capture_preserve_unique_blocks"
                    )
                    if capture["capture_id"] in original_capture_ids and capture.get(
                        "raw_html_asset", ""
                    ).startswith("assets/raw/"):
                        supplement["raw_html_asset"] = (
                            self.bundle / capture["raw_html_asset"]
                        ).as_posix()
                    supplements.append(supplement)
                status, basis = "CONTENT_CAPTURED", "hash_verified_complete_owned_body"
            elif status is None:
                path = urlsplit(url).path
                empty_listing = (
                    bool(captures)
                    and any(
                        c.get("completeness") == "listing" for c in captures.values()
                    )
                    and all(not c.get("body_text") for c in captures.values())
                )
                if (
                    path in ("/", "/fa", "/en", "/404.htm")
                    or re.search(r"^/(?:catarticle|catnews|formid|search)(?:/|$)", path)
                    or empty_listing
                ):
                    status, basis = (
                        "NONCONTENT_ROUTE",
                        "captured_empty_listing_container_with_article_links"
                        if empty_listing
                        else "explicit_home_error_or_listing_route_retained_for_discovery",
                    )
                else:
                    status, basis = (
                        "SOURCE_UNRESOLVED",
                        "no_verified_complete_body; failure_is_not_proof_of_irrecoverability",
                    )
            ledger.append(
                {
                    "url": url,
                    "source_id": prior.get("source_id") or stable_id(url),
                    "disposition": status,
                    "basis": basis,
                    "prior_recovery_status": prior.get("recovery_status"),
                    "prior_exclusion_reaudited": prior.get(
                        "recovery_status", ""
                    ).startswith("excluded"),
                    "capture_ids": sorted(captures),
                    "complete_capture_ids": sorted(c["capture_id"] for c in full),
                    "full_owned_capture_ids": all_owned_ids,
                    "network_observations": observations[url],
                    "publication_allowed": False,
                }
            )
        write_jsonl(self.output / "sources.jsonl.gz", sources)
        write_jsonl(self.output / "version-supplements.jsonl.gz", supplements)
        write_jsonl(
            self.output / "owned-nonarticle-captures.jsonl.gz", nonarticle_captures
        )
        write_jsonl(
            self.output / "capture-versions.jsonl.gz",
            sorted(versions, key=lambda c: (c["url"], c["capture_id"])),
        )
        write_jsonl(self.output / "inventory.jsonl.gz", ledger)
        write_jsonl(
            self.output / "media-inventory.jsonl.gz",
            sorted(self.media, key=lambda r: (r["source_url"], r["url"])),
        )
        write_jsonl(
            self.output / "pagination-inventory.jsonl.gz",
            sorted(self.references, key=lambda r: (r["source_url"], r["target_url"])),
        )
        write_jsonl(self.output / "network-observations.jsonl.gz", self.observations)
        write_jsonl(
            self.output / "unresolved-sources.jsonl.gz",
            [r for r in ledger if r["disposition"] == "SOURCE_UNRESOLVED"],
        )
        summary = {
            "version": VERSION,
            "inventory_urls": len(ledger),
            "prior_urls": len(self.master),
            "newly_discovered_urls": len(self.frontier - self.master.keys()),
            "dispositions": dict(
                sorted(Counter(r["disposition"] for r in ledger).items())
            ),
            "complete_source_pages": len(sources),
            "eligible_complete_source_pages": len(sources),
            "full_owned_body_count": len(full_owned_urls),
            "owned_nonarticle_capture_count": len(nonarticle_captures),
            "complete_source_blocks": sum(len(s["blocks"]) for s in sources),
            "distinct_complete_capture_versions": sum(
                c["completeness"] == FULL for c in versions
            ),
            "alternate_complete_source_versions": len(supplements),
            "alternate_version_blocks_preserved": sum(
                len(s["blocks"]) for s in supplements
            ),
            "prior_406_exclusions_reaudited": sum(
                r["prior_exclusion_reaudited"] for r in ledger
            ),
            "original_264_unresolved_reaudited": len(self.original_unresolved),
            "original_unresolved_now_complete": sum(
                s["url"] in self.original_unresolved for s in sources
            ),
            "verified_prior_raw_assets": len(self.verified_raw),
            "fresh_network_enabled": self.fresh,
            "host_circuit": self.collector.circuit,
            "discovery_complete": False,
            "discovery_limitations": "Finite first-party robots/sitemap/internal traversal; source inaccessible, fetch budget, unresolved multipart and unlinked pages remain explicit. No unavailable fetch is labeled irrecoverable.",
            "unrecoverable_claimed": 0,
            "hosted_writes": 0,
            "publication_allowed": False,
        }
        save_json(self.output / "summary.json", summary)
        return summary

    def ingest_recovery_checkpoint(self):
        """Resume preserved evidence without repeating the full HTML discovery scan."""
        self.captures = read_jsonl(self.output / "capture-versions.jsonl.gz")
        self.frontier.update(
            r["url"] for r in read_jsonl(self.output / "inventory.jsonl.gz")
        )
        self.observations = read_jsonl(self.output / "network-observations.jsonl.gz")
        self.media = read_jsonl(self.output / "media-inventory.jsonl.gz")
        self.references = read_jsonl(self.output / "pagination-inventory.jsonl.gz")
        previous_summary = json.loads(
            (self.output / "summary.json").read_text(encoding="utf-8")
        )
        self.collector.circuit.update(previous_summary["host_circuit"])
        for observation in self.observations:
            if observation.get("kind") == "robots" and observation.get("body"):
                host = urlsplit(observation["url"]).hostname
                policy = RobotFileParser(observation["url"])
                policy.parse(observation["body"].splitlines())
                self.collector.robots[host] = policy
        for capture in self.captures:
            self.by_url[capture["url"]].append(capture)
            relative = capture.get("raw_html_asset")
            if not relative:
                continue
            path = Path(relative).resolve()
            if path not in self.verified_raw:
                raw = gzip.decompress(path.read_bytes())
                checksum = hashlib.sha256(raw).hexdigest()
                if checksum != capture["raw_html_sha256"]:
                    raise ValueError("checkpoint_raw_checksum_mismatch")
                self.verified_raw[path] = checksum
            elif self.verified_raw[path] != capture["raw_html_sha256"]:
                raise ValueError("checkpoint_shared_raw_checksum_disagrees")
        for metadata_path in sorted((self.output / "network").glob("*.html.json")):
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            asset = metadata_path.with_suffix(".gz")
            raw = gzip.decompress(asset.read_bytes())
            if hashlib.sha256(raw).hexdigest() != metadata["raw_sha256"]:
                raise ValueError("checkpoint_network_raw_checksum_mismatch")
            url = metadata["url"]
            self.by_url[url].extend(
                capture_from_raw(
                    raw,
                    url,
                    metadata,
                    asset.resolve().relative_to(Path.cwd()).as_posix(),
                )
            )
            discovered = Links(raw, metadata.get("final_url", url))
            self.frontier.update(discovered.links)
            self.references.extend(
                {
                    "source_url": url,
                    "target_url": u,
                    "raw_sha256": metadata["raw_sha256"],
                }
                for u in sorted(discovered.pagination)
            )
            self.media.extend(
                {"source_url": url, "url": u, "raw_sha256": metadata["raw_sha256"]}
                for u in sorted(discovered.media)
            )
            self.observations.append(
                {
                    "kind": "verified_cache_reparse",
                    "url": url,
                    "raw_sha256": metadata["raw_sha256"],
                    "new_network_request": False,
                }
            )

    def run(self, resume=False):
        if resume:
            self.ingest_recovery_checkpoint()
        else:
            self.ingest_existing()
        if self.fresh:
            if not resume:
                with ThreadPoolExecutor(max_workers=3) as pool:
                    list(pool.map(self.bootstrap_host, sorted(HOSTS)))
            # Run the cross-site frontier again until no new URLs appear.
            for _ in range(5):
                before = len(self.frontier)
                with ThreadPoolExecutor(max_workers=3) as pool:
                    list(
                        pool.map(
                            self.fetch_host,
                            sorted(h for h in HOSTS if h not in self.collector.circuit),
                        )
                    )
                if len(self.frontier) == before:
                    break
        return self.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--fresh-network", action="store_true")
    parser.add_argument("--resume-checkpoint", action="store_true")
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--max-pages-per-host", type=int, default=10000)
    args = parser.parse_args()
    print(
        json.dumps(
            Recovery(
                args.bundle,
                args.output,
                args.interval,
                args.max_pages_per_host,
                args.fresh_network,
            ).run(args.resume_checkpoint),
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
