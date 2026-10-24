"""Rate-limited first-party discovery. No form submission or hosted writes."""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import re
import threading
import time
import uuid
import xml.etree.ElementTree as ET
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, unquote, urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
from urllib.robotparser import RobotFileParser

from .parser import HOSTS, extract, normalize_url

AGENT = "RAD-Content-Review/1.0 (+https://radvisa.com; draft-only source inventory)"
NAMESPACE = uuid.UUID("67ef6686-5f55-4ce9-9efa-d03045f46589")
MAX_BYTES = 3_000_000


def stable_id(url: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "source:" + normalize_url(url)))


def now() -> str:
    return dt.datetime.now(dt.UTC).isoformat().replace("+00:00", "Z")


def disposition(url: str) -> str | None:
    p = urlsplit(url)
    if p.hostname not in HOSTS:
        return "external_reference_not_crawled"
    path = unquote(p.path).lower()
    # Observed legacy Joomla template links recursively append demo/category
    # routes to country URLs. They are retained as dispositions, never treated
    # as immigration articles or an unbounded navigation frontier.
    if re.search(r"/(?:\d+-demo)(?:/|$)", path):
        return "legacy_template_demo_route_excluded"
    if re.search(
        r"/(?:administrator|admin|login|logout|signin|signup|register|cart|checkout|search|component|modules|plugins|media|images|templates)(?:/|$)",
        path,
    ):
        return "noneditorial_or_stateful_path_excluded"
    if re.search(
        r"\.(?:pdf|docx?|xlsx?|zip|rar|png|jpe?g|webp|gif|svg|ico|woff2?|ttf|css|js|mp[34])$",
        path,
    ):
        return "attachment_reference_not_fetched"
    if p.query and re.search(
        r"(?:^|&)(?:action|task|format|option|do|logout|delete|sort|search)=",
        p.query,
        re.IGNORECASE,
    ):
        return "noneditorial_query_excluded"
    if p.query and re.search(
        r"(?:^|&)view=(?:form|login|registration)(?:&|$)", p.query, re.IGNORECASE
    ):
        return "noneditorial_or_stateful_path_excluded"
    return None


class SafeRedirect(HTTPRedirectHandler):
    def __init__(self, allowed, can_fetch, redirects, throttle=None):
        self.allowed, self.can_fetch, self.redirects = allowed, can_fetch, redirects
        self.throttle = throttle

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if len(self.redirects) >= 5:
            raise ValueError("redirect_limit")
        target = normalize_url(newurl, req.full_url)
        if urlsplit(target).hostname not in self.allowed or not self.can_fetch(target):
            raise ValueError("redirect_out_of_scope_or_robots_denied")
        if disposition(target):
            raise ValueError("redirect_noneditorial_or_stateful_denied")
        if urlsplit(newurl).scheme == "http":
            raise ValueError("https_downgrade_redirect_denied")
        self.redirects.append({"from": req.full_url, "to": target, "status": code})
        if self.throttle:
            self.throttle(target)
        # Preserve the server's trailing slash on the wire; canonical identity
        # normalization must not turn a valid redirect into a redirect loop.
        wire = quote(urljoin(req.full_url, newurl), safe="/%:@!$&'()*+,;=-._~?[]")
        return super().redirect_request(req, fp, code, msg, headers, wire)


class Collector:
    def __init__(
        self, cache: Path, minimum_interval=1.0, max_pages=10000, retry_failures=False
    ):
        self.cache, self.interval, self.max_pages = (
            cache,
            max(0.5, minimum_interval),
            max_pages,
        )
        cache.mkdir(parents=True, exist_ok=True)
        self.robots = {}
        self.last = {}
        self.host_locks = {h: threading.Lock() for h in HOSTS}
        self.results, self.lock = {}, threading.Lock()
        self.host_counts = {h: 0 for h in HOSTS}
        self.retry_failures = retry_failures

    def allowed(self, url):
        host = urlsplit(url).hostname
        return host in self.robots and self.robots[host].can_fetch(AGENT, url)

    def throttle(self, url):
        host = urlsplit(url).hostname
        if host not in HOSTS:
            raise ValueError("scope_violation")
        parser = self.robots.get(host)
        delay = (
            max(
                self.interval, parser.crawl_delay(AGENT) or parser.crawl_delay("*") or 0
            )
            if parser
            else self.interval
        )
        with self.host_locks[host]:
            time.sleep(max(0, delay - (time.monotonic() - self.last.get(host, 0))))
            self.last[host] = time.monotonic()

    def request(self, url, robots_request=False):
        self.throttle(url)
        redirects = []
        opener = build_opener(
            SafeRedirect(
                HOSTS,
                lambda u: robots_request or self.allowed(u),
                redirects,
                self.throttle,
            )
        )
        with opener.open(
            Request(
                url,
                headers={
                    "User-Agent": AGENT,
                    "Accept": "text/html,application/xml,text/plain;q=0.8",
                },
            ),
            timeout=20,
        ) as response:
            body = response.read(MAX_BYTES + 1)
            if len(body) > MAX_BYTES:
                raise ValueError("response_size_limit")
            return body, {
                "status": response.status,
                "final_url": normalize_url(response.url),
                "content_type": response.headers.get("Content-Type", ""),
                "last_modified_header": response.headers.get("Last-Modified"),
                "etag": response.headers.get("ETag"),
                "redirects": redirects,
                "retrieved_at": now(),
            }

    def bootstrap(self, initial: Path | None):
        prior = json.loads(initial.read_text(encoding="utf8")) if initial else []
        discovery = []
        for host in sorted(HOSTS):
            robots_url = "https://" + host + "/robots.txt"
            old = next(
                (x for x in prior if x["url"] == robots_url and x.get("status") == 200),
                None,
            )
            try:
                if old:
                    body, meta = (
                        old["body"].encode("utf8"),
                        {k: v for k, v in old.items() if k != "body"},
                    )
                else:
                    body, meta = self.request(robots_url, True)
                rp = RobotFileParser(robots_url)
                rp.parse(body.decode("utf-8-sig", errors="replace").splitlines())
                self.robots[host] = rp
                discovery.append(
                    {
                        "kind": "robots",
                        "host": host,
                        "body": body.decode("utf-8-sig", errors="replace"),
                        **meta,
                    }
                )
                sitemap_urls = rp.site_maps() or ["https://" + host + "/sitemap.xml"]
                pending, visited = deque(sitemap_urls), set()
                while pending:
                    url = normalize_url(pending.popleft())
                    if url in visited:
                        continue
                    visited.add(url)
                    if len(visited) > 50:
                        raise ValueError("sitemap_index_budget_exceeded")
                    if not self.allowed(url):
                        discovery.append(
                            {"kind": "sitemap", "url": url, "error": "robots_denied"}
                        )
                        continue
                    old = next(
                        (
                            x
                            for x in prior
                            if x["url"] == url and x.get("status") == 200
                        ),
                        None,
                    )
                    if old:
                        data, metadata = (
                            old["body"].encode("utf8"),
                            {k: v for k, v in old.items() if k != "body"},
                        )
                    else:
                        data, metadata = self.request(url)
                    root = ET.fromstring(data.decode("utf-8-sig"))
                    entries = []
                    for el in root:
                        fields = {n.tag.split("}")[-1]: n.text for n in el}
                        if fields.get("loc"):
                            target = normalize_url(fields["loc"])
                            entries.append(
                                {
                                    "url": target,
                                    "original_url": fields["loc"],
                                    "lastmod": fields.get("lastmod"),
                                }
                            )
                            if root.tag.endswith("sitemapindex"):
                                pending.append(target)
                    discovery.append(
                        {"kind": "sitemap", "url": url, "entries": entries, **metadata}
                    )
            except (OSError, ValueError, ET.ParseError) as exc:
                discovery.append(
                    {
                        "kind": "robots_or_sitemap",
                        "host": host,
                        "error": type(exc).__name__ + ": " + str(exc),
                        "retrieved_at": now(),
                    }
                )
        return discovery

    def host_walk(self, host, seeds):
        queue = deque(sorted(seeds))
        queued = set(seeds)
        seen = {u for u in self.results if urlsplit(u).hostname == host}
        while queue:
            url = queue.popleft()
            queued.discard(url)
            if url in seen:
                continue
            seen.add(url)
            source_id = stable_id(url)
            meta_path = self.cache / (source_id + ".json")
            raw_path = self.cache / (source_id + ".html.gz")
            failure_path = self.cache / (source_id + ".failure.json")
            row = {
                "id": source_id,
                "url": url,
                "domain": host,
                "discovered_via": seeds.get(url, ["article_link"]),
                "fetch_status": "not_requested",
            }
            reason = disposition(url)
            if reason:
                row["fetch_status"] = reason
            elif not self.allowed(url):
                row["fetch_status"] = "robots_denied_or_unavailable"
            elif (
                failure_path.exists()
                and not self.retry_failures
                and not (meta_path.exists() and raw_path.exists())
            ):
                cached = json.loads(failure_path.read_text(encoding="utf8"))
                if cached["url"] != url:
                    raise ValueError("failure_cache_identity")
                row.update(
                    {
                        k: cached[k]
                        for k in ("fetch_status", "status", "error", "retrieved_at")
                        if k in cached
                    }
                )
            elif self.host_counts[host] >= self.max_pages:
                row["fetch_status"] = "crawl_budget_exceeded"
            else:
                self.host_counts[host] += 1
                try:
                    if meta_path.exists() and raw_path.exists():
                        meta = json.loads(meta_path.read_text(encoding="utf8"))
                        body = gzip.decompress(raw_path.read_bytes())
                        if hashlib.sha256(body).hexdigest() != meta["raw_sha256"]:
                            raise ValueError("cache_hash_mismatch")
                    else:
                        body, meta = self.request(url)
                        meta["raw_sha256"] = hashlib.sha256(body).hexdigest()
                        raw_path.write_bytes(gzip.compress(body, mtime=0))
                        meta_path.write_text(
                            json.dumps(meta, ensure_ascii=False) + "\n", encoding="utf8"
                        )
                    row.update(meta)
                    if not any(
                        t in meta["content_type"].lower()
                        for t in ["text/html", "application/xhtml"]
                    ):
                        row["fetch_status"] = "non_html_response"
                    else:
                        row["fetch_status"] = "fetched"
                        parsed = extract(body, meta["final_url"])
                        row["extraction"] = parsed
                        for link in parsed["links"]:
                            target = link["url"]
                            if (
                                urlsplit(target).hostname == host
                                and target not in seen
                                and target not in queued
                            ):
                                queue.append(target)
                                queued.add(target)
                except HTTPError as exc:
                    row.update(
                        fetch_status="http_error",
                        status=exc.code,
                        error=str(exc),
                        retrieved_at=now(),
                    )
                    if exc.code in (429, 503):
                        retry = exc.headers.get("Retry-After", "30")
                        time.sleep(
                            min(120, max(1, int(retry))) if retry.isdigit() else 30
                        )
                    exc.close()
                except (OSError, ValueError, UnicodeError, RecursionError) as exc:
                    row.update(
                        fetch_status="fetch_or_parse_error",
                        error=type(exc).__name__ + ": " + str(exc),
                        retrieved_at=now(),
                    )
                if row["fetch_status"] in ("http_error", "fetch_or_parse_error"):
                    failure_path.write_text(
                        json.dumps(row, ensure_ascii=False) + "\n", encoding="utf8"
                    )
            with self.lock:
                self.results[url] = row
            if len(seen) % 25 == 0:
                print(host, "disposed", len(seen), "queued", len(queue), flush=True)
            # Persist every disposition. A restart reuses verified raw cache, not old reported success.
            with (self.cache / (host + ".progress.jsonl")).open(
                "a", encoding="utf8"
            ) as f:
                f.write(
                    json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n"
                )

    def run(self, initial, output, extra_urls=()):
        discovery = self.bootstrap(initial)
        seeds = {h: {} for h in HOSTS}
        for h in HOSTS:
            seeds[h]["https://" + h + "/"] = ["homepage"]
        for row in discovery:
            if row.get("kind") == "sitemap":
                for item in row.get("entries", []):
                    host = urlsplit(item["url"]).hostname
                    if host in HOSTS:
                        seeds[host].setdefault(item["url"], []).append(
                            {
                                "sitemap": row["url"],
                                "original_url": item["original_url"],
                                "lastmod": item["lastmod"],
                            }
                        )
        for raw in extra_urls:
            try:
                url = normalize_url(raw)
            except ValueError:
                continue
            host = urlsplit(url).hostname
            if host in HOSTS:
                seeds[host].setdefault(url, []).append(
                    "existing_repository_or_production_source"
                )
        output.parent.mkdir(parents=True, exist_ok=True)
        (output.parent / "discovery.json").write_text(
            json.dumps(discovery, indent=2, ensure_ascii=False) + "\n", encoding="utf8"
        )
        with ThreadPoolExecutor(max_workers=3) as pool:
            list(
                pool.map(lambda host: self.host_walk(host, seeds[host]), sorted(HOSTS))
            )
        # Cross-site references may expose public RAD pages absent from sitemaps.
        # Complete the finite frontier rather than silently dropping those links.
        for _ in range(20):
            frontier = {h: {} for h in HOSTS}
            for row in list(self.results.values()):
                for link in row.get("extraction", {}).get("links", []):
                    u = link["url"]
                    h = urlsplit(u).hostname
                    if h in HOSTS and u not in self.results:
                        frontier[h][u] = ["cross_site_article_link"]
            if not any(frontier.values()):
                break
            with ThreadPoolExecutor(max_workers=3) as pool:
                list(
                    pool.map(
                        lambda host, current=frontier: self.host_walk(
                            host, current[host]
                        ),
                        sorted(HOSTS),
                    )
                )
        # Even an exhausted safety bound must leave an explicit disposition.
        for row in list(self.results.values()):
            for link in row.get("extraction", {}).get("links", []):
                u = link["url"]
                h = urlsplit(u).hostname
                if h in HOSTS and u not in self.results:
                    self.results[u] = {
                        "id": stable_id(u),
                        "url": u,
                        "domain": h,
                        "discovered_via": ["cross_site_article_link"],
                        "fetch_status": "cross_site_frontier_budget_exceeded",
                    }
        with gzip.GzipFile(filename=str(output), mode="wb", mtime=0) as f:
            for url in sorted(self.results):
                f.write(
                    (
                        json.dumps(
                            self.results[url], ensure_ascii=False, separators=(",", ":")
                        )
                        + "\n"
                    ).encode("utf8")
                )
        print("COLLECTION_COMPLETE", len(self.results), flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--cache", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--initial", type=Path)
    p.add_argument("--production-metadata", type=Path)
    p.add_argument("--interval", type=float, default=1)
    p.add_argument("--max-pages-per-host", type=int, default=10000)
    p.add_argument(
        "--retry-failures",
        action="store_true",
        help="Explicitly retry retained failed fetches; prior logs remain evidence.",
    )
    a = p.parse_args()
    extra = []
    if a.production_metadata:
        extra = [
            s["url"]
            for s in json.loads(a.production_metadata.read_text(encoding="utf8")).get(
                "sources", []
            )
        ]
    Collector(a.cache, a.interval, a.max_pages_per_host, a.retry_failures).run(
        a.initial, a.output, extra
    )


if __name__ == "__main__":
    main()
