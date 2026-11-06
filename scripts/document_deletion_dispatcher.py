#!/usr/bin/env python3
"""Report queue health, or opt in to bounded worker calls on a disposable stack.

This dispatches individually authorized erasure requests, never a retention
sweep. No credentials, object names, worker bodies or exception details are logged.
The explicit test-target adapter refuses hosted and non-loopback destinations.
"""

from __future__ import annotations

import argparse
import json
import random
import time
import urllib.error
import urllib.request
from collections.abc import Callable

HEALTH = "/rest/v1/rpc/document_deletion_queue_health"
WORKER = "/functions/v1/document-deletion"


def dispatch(
    call: Callable,
    *,
    execute: bool = False,
    max_jobs: int = 10,
    interval: float = 2,
    stale_seconds: int = 300,
    sleep: Callable = time.sleep,
) -> dict:
    if not 1 <= max_jobs <= 100 or not 1 <= interval <= 60 or stale_seconds < 1:
        raise ValueError("bounded jobs, interval and health threshold required")
    report = {
        "mode": "EXECUTE_AUTHORIZED_REQUESTS" if execute else "REPORT_ONLY",
        "worker_calls": 0,
        "finalized": 0,
        "alerts": [],
        "healthy": True,
    }

    def alert(code):
        report["healthy"] = False
        if code not in report["alerts"]:
            report["alerts"].append(code)

    def read_health():
        try:
            status, body = call(HEALTH)
            keys = ("pending", "exhausted", "leased", "oldest_pending_seconds")
            if (
                status != 200
                or not isinstance(body, dict)
                or any(type(body.get(key)) is not int or body[key] < 0 for key in keys)
            ):
                raise ValueError("invalid health")
            report["queue"] = {key: body[key] for key in keys}
            if body["exhausted"]:
                alert("retries_exhausted")
            if body["oldest_pending_seconds"] > stale_seconds:
                alert("queue_stale")
            return True
        except Exception:
            alert("queue_health_unavailable")
            return False

    if not read_health() or not execute:
        return report
    failures = 0
    for index in range(max_jobs):
        report["worker_calls"] += 1
        try:
            status, body = call(WORKER)
            if status == 200 and isinstance(body, dict):
                if body.get("processed") == 0 and body.get("reason") == "queue_empty":
                    break
                if body.get("processed") == 1 and body.get("state") == "finalized":
                    report["finalized"] += 1
                    failures = 0
                else:
                    alert("worker_result_unconfirmed")
                    failures += 1
            else:
                alert("worker_http_failure")
                failures += 1
        except Exception:
            alert("worker_network_failure")
            failures += 1
        if index + 1 < max_jobs:
            sleep(min(60, interval * 2 ** min(failures, 5) + random.uniform(0, 0.5)))
    read_health()
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--max-jobs", type=int, default=10)
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--stale-seconds", type=int, default=300)
    args = parser.parse_args()
    from self_host_test_target import load_target

    api, _, service_key = load_target()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def call(path):
        request = urllib.request.Request(
            api + path,
            data=b"{}",
            method="POST",
            headers={
                "Content-Type": "application/json",
                "apikey": service_key,
                "Authorization": "Bearer " + service_key,
            },
        )

        # Do not follow a redirect with a privileged authorization header.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None

        opener.add_handler(NoRedirect())
        try:
            with opener.open(request, timeout=75) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, {}

    report = dispatch(
        call,
        execute=args.execute,
        max_jobs=args.max_jobs,
        interval=args.interval,
        stale_seconds=args.stale_seconds,
    )
    print(json.dumps(report, sort_keys=True))
    raise SystemExit(0 if report["healthy"] else 2)


if __name__ == "__main__":
    main()
