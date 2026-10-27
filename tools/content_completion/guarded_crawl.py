"""Run the sealed collector with a per-host access-failure circuit breaker.

This wrapper does not change the historical collector or its frozen artifacts.
Once a host refuses access or repeatedly disconnects, it makes no more network
requests to that host during this invocation; remaining URLs stay dispositions.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlsplit

from tools.plan3_content.crawl import Collector
from tools.plan3_content.dataset import read_jsonl


class GuardedCollector(Collector):
    def __init__(self, *args, skip_hosts=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.failures = {}
        self.circuit = {host: "previous_access_failure" for host in skip_hosts}

    def request(self, url, robots_request=False):
        host = urlsplit(url).hostname
        if host in self.circuit:
            raise ValueError("host_circuit_open:" + self.circuit[host])
        try:
            result = super().request(url, robots_request=robots_request)
        except HTTPError as exc:
            if exc.code in (401, 403, 429, 503):
                self.circuit[host] = "http_" + str(exc.code)
            raise
        except (OSError, ValueError):
            count = self.failures.get(host, 0) + 1
            self.failures[host] = count
            if count >= 3:
                self.circuit[host] = "three_consecutive_transport_failures"
            raise
        self.failures[host] = 0
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--historical-sources", type=Path, required=True)
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--max-pages-per-host", type=int, default=10000)
    parser.add_argument("--skip-host", action="append", default=[])
    args = parser.parse_args()
    if args.output.exists() or (args.output.parent / "discovery.json").exists():
        parser.error("output must be in a new directory without a discovery.json")
    records = read_jsonl(args.historical_sources)
    collector = GuardedCollector(
        args.cache, args.interval, args.max_pages_per_host, skip_hosts=args.skip_host
    )
    collector.run(None, args.output, [row["url"] for row in records])


if __name__ == "__main__":
    main()
