"""Fetch only missing full articles discovered in preserved listing excerpts.

No root crawl, sitemap crawl, recursive discovery, forms, authentication or
access-control bypass. A robots/access refusal stops that host immediately.
"""

import argparse
import gzip
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.robotparser import RobotFileParser

from tools.content_completion.guarded_crawl import GuardedCollector
from tools.content_completion.phase_bundle import save_json, sha
from tools.plan3_content.crawl import AGENT, disposition, stable_id
from tools.plan3_content.dataset import read_jsonl, write_jsonl


def recover(bundle, cache, output, interval=3):
    master = {r["url"]: r for r in read_jsonl(bundle / "source-master.jsonl.gz")}
    urls = sorted(
        {
            r["url"]
            for r in read_jsonl(bundle / "listing-excerpts.jsonl.gz")
            if master[r["url"]]["recovery_status"] != "full_body_and_verified_raw"
        }
    )
    collector = GuardedCollector(cache, max(3, interval), len(urls))
    robots = []
    for host in sorted({urlsplit(u).hostname for u in urls}):
        try:
            raw, metadata = collector.request("https://" + host + "/robots.txt", True)
            text = raw.decode("utf-8-sig", errors="replace")
            if "<html" in text.lower():
                raise ValueError("robots_returned_html_not_policy")
            policy = RobotFileParser("https://" + host + "/robots.txt")
            policy.parse(text.splitlines())
            collector.robots[host] = policy
            robots.append({"host": host, "body": text, **metadata})
        except (HTTPError, OSError, ValueError) as exc:
            robots.append(
                {"host": host, "status": getattr(exc, "code", None), "error": str(exc)}
            )
            collector.circuit[host] = collector.circuit.get(
                host, "robots_policy_unavailable"
            )
    rows = []
    output.parent.mkdir(parents=True, exist_ok=True)
    journal = output.with_suffix(".progress.jsonl")
    for url in urls:
        sid = stable_id(url)
        meta = cache / (sid + ".json")
        raw_path = cache / (sid + ".html.gz")
        row = {
            "url": url,
            "id": sid,
            "discovery": "retained_partial_listing_excerpt",
            "fetch_status": "not_requested",
        }
        reason = disposition(url)
        host = urlsplit(url).hostname
        if meta.exists() and raw_path.exists():
            prior = json.loads(meta.read_text(encoding="utf-8"))
            raw = gzip.decompress(raw_path.read_bytes())
            if prior["url"] != url or sha(raw) != prior["raw_sha256"]:
                raise ValueError("targeted_cache_integrity_failure")
            row.update(prior)
            row["cache_reused"] = True
        elif reason:
            row.update(fetch_status=reason)
        elif host in collector.circuit or host not in collector.robots:
            row.update(
                fetch_status="host_access_hold",
                error=collector.circuit.get(host, "robots_policy_unavailable"),
            )
        elif not collector.robots[host].can_fetch(AGENT, url):
            row.update(fetch_status="robots_denied")
        else:
            try:
                raw, metadata = collector.request(url)
                row.update(
                    metadata,
                    fetch_status="fetched",
                    raw_sha256=sha(raw),
                    raw_cache_file=raw_path.name,
                )
                raw_path.write_bytes(gzip.compress(raw, mtime=0))
                save_json(meta, row)
            except (HTTPError, OSError, ValueError) as exc:
                row.update(
                    fetch_status="fetch_failed",
                    status=getattr(exc, "code", None),
                    error=str(exc),
                )
        rows.append(row)
        with journal.open("a", encoding="utf-8", newline="\n") as stream:
            stream.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    write_jsonl(output, rows)
    save_json(
        output.with_name("targeted-recovery-policy.json"),
        {
            "targets": len(urls),
            "robots_observations": robots,
            "minimum_interval_seconds": max(3, interval),
            "host_circuit": collector.circuit,
            "recursive_crawl": False,
            "authentication_or_bypass": False,
            "cached_successes_reused": True,
        },
    )
    return {
        "targets": len(urls),
        "fetched": sum(r["fetch_status"] == "fetched" for r in rows),
        "held": sum(r["fetch_status"] == "host_access_hold" for r in rows),
        "host_circuit": collector.circuit,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--interval", type=float, default=3)
    args = parser.parse_args()
    print(json.dumps(recover(args.bundle, args.cache, args.output, args.interval)))
