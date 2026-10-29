"""Explicit bounded transport-error recovery; no discovery, denial bypass or DB writes."""

from __future__ import annotations

import argparse
import copy
import gzip
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.robotparser import RobotFileParser

from .crawl import Collector, disposition, now, stable_id
from .dataset import digest_bytes, read_jsonl, write_jsonl
from .parser import HOSTS, extract


def retry_records(records, collector, max_attempts=10000):
    rows = copy.deepcopy(records)
    attempts = []
    for row in rows:
        if row["fetch_status"] != "fetch_or_parse_error" or not row.get(
            "error", ""
        ).startswith("URLError:"):
            continue
        if len(attempts) >= max_attempts:
            break
        url = row["url"]
        if urlsplit(url).hostname not in HOSTS or disposition(url):
            raise ValueError("unsafe_retry_target")
        prior = {
            k: row[k]
            for k in ("fetch_status", "status", "error", "retrieved_at")
            if row.get(k) is not None
        }
        row["fetch_history"] = row.get("fetch_history", []) + [prior]
        try:
            if not collector.allowed(url):
                raise ValueError("robots_denied")
            key = stable_id(url)
            raw_path = collector.cache / (key + ".html.gz")
            meta_path = collector.cache / (key + ".json")
            if raw_path.exists() and meta_path.exists():
                body = gzip.decompress(raw_path.read_bytes())
                meta = json.loads(meta_path.read_text(encoding="utf8"))
                if digest_bytes(body) != meta["raw_sha256"]:
                    raise ValueError("cache_hash_mismatch")
            else:
                body, meta = collector.request(url)
                meta["raw_sha256"] = digest_bytes(body)
            if not any(
                t in meta["content_type"].lower()
                for t in ("text/html", "application/xhtml")
            ):
                raise ValueError("non_html_response")
            parsed = extract(body, meta["final_url"])
            parsed.pop("links", None)
            row.update(meta)
            row.update(fetch_status="fetched", error=None, extraction=parsed)
            raw_path.write_bytes(gzip.compress(body, mtime=0))
            meta_path.write_text(
                json.dumps(meta, ensure_ascii=False) + "\n", encoding="utf8"
            )
        except (OSError, ValueError, RecursionError) as exc:
            row.update(
                fetch_status="http_error"
                if isinstance(exc, HTTPError)
                else "fetch_or_parse_error",
                status=exc.code if isinstance(exc, HTTPError) else None,
                error=type(exc).__name__ + ": " + str(exc),
                retrieved_at=now(),
            )
            if isinstance(exc, HTTPError):
                exc.close()
        attempts.append(
            {
                k: row.get(k)
                for k in (
                    "url",
                    "fetch_status",
                    "status",
                    "error",
                    "retrieved_at",
                    "raw_sha256",
                )
            }
        )
        if (
            row.get("status") in (403, 429, 503)
            or len(attempts) >= 3
            and all(a["fetch_status"] != "fetched" for a in attempts[-3:])
        ):
            break
    return rows, attempts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--max-attempts", type=int, default=10000)
    args = parser.parse_args()
    if (
        args.output.resolve() == args.capture.resolve()
        or args.output.exists()
        or args.report.exists()
    ):
        parser.error(
            "new owned output/report paths required; original capture is preserved"
        )
    if not 1 <= args.max_attempts <= 10000:
        parser.error("max-attempts must be between 1 and 10000")
    records = read_jsonl(args.capture)
    collector = Collector(args.cache, minimum_interval=2)
    robots = []
    for host in sorted(
        {
            urlsplit(r["url"]).hostname
            for r in records
            if r["fetch_status"] == "fetch_or_parse_error"
            and r.get("error", "").startswith("URLError:")
        }
    ):
        if host not in HOSTS:
            raise ValueError("unsafe_retry_host")
        url = "https://" + host + "/robots.txt"
        body, metadata = collector.request(url, robots_request=True)
        rp = RobotFileParser(url)
        rp.parse(body.decode("utf-8-sig", errors="replace").splitlines())
        collector.robots[host] = rp
        robots.append({"url": url, **metadata, "body_sha256": digest_bytes(body)})
    rows, attempts = retry_records(records, collector, args.max_attempts)
    write_jsonl(args.output, rows)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(
            {
                "robots": robots,
                "attempts": attempts,
                "original_capture_sha256": digest_bytes(args.capture.read_bytes()),
                "new_capture_sha256": digest_bytes(args.output.read_bytes()),
                "hosted_mutations": False,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf8",
    )
    print(
        json.dumps(
            {
                "attempted": len(attempts),
                "retrieved": sum(a["fetch_status"] == "fetched" for a in attempts),
                "hosted_mutations": False,
            }
        )
    )


if __name__ == "__main__":
    main()
