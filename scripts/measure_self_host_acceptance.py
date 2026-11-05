#!/usr/bin/env python3
"""Bounded synthetic latency/resource sample on an owned disposable backend."""

from __future__ import annotations

import argparse
import json
import math
import secrets
import statistics
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import UUID

try:
    from .self_host_stack import compose, run, sql
    from .self_host_test_target import load_target, target_root
    from .verify_self_host_document_deletion import PDF, call, require
except ImportError:
    from self_host_stack import compose, run, sql
    from self_host_test_target import load_target, target_root
    from verify_self_host_document_deletion import PDF, call, require


def percentile95(values: list[float]) -> float:
    if not values:
        raise ValueError("percentile requires measured observations")
    return sorted(values)[math.ceil(len(values) * 0.95) - 1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    require(
        not output.is_relative_to(Path(__file__).resolve().parents[1]),
        "evidence outside Git",
    )
    require(not output.exists(), "new evidence file")
    root = target_root()
    api, anon, service = load_target()
    samples = {}

    def measured(label, action):
        start = time.perf_counter()
        result = action()
        elapsed = (time.perf_counter() - start) * 1000
        samples.setdefault(label, []).append(elapsed)
        return result

    seed = secrets.token_hex(6)
    email, password = f"measure-{seed}@example.invalid", secrets.token_urlsafe(32)
    status, body = call(
        api + "/auth/v1/admin/users",
        "POST",
        {"email": email, "password": password, "email_confirm": True},
        apikey=service,
    )
    require(status == 200, "synthetic measurement account")
    actor = str(UUID(json.loads(body)["id"]))
    token = ""
    for _ in range(5):
        status, body = measured(
            "password_login",
            lambda: call(
                api + "/auth/v1/token?grant_type=password",
                "POST",
                {"email": email, "password": password},
                apikey=anon,
            ),
        )
        require(status == 200, "normal measured login")
        token = json.loads(body)["access_token"]

    def profile(_):
        status, _ = measured(
            "owner_profile_read_concurrency4",
            lambda: call(
                api + f"/rest/v1/profiles?id=eq.{actor}&select=id",
                token=token,
                apikey=anon,
            ),
        )
        require(status == 200, "concurrent owner read")

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(profile, range(20)))
    path = f"{actor}/measure-{seed}.pdf"
    status, _ = measured(
        "private_upload",
        lambda: call(
            api + "/storage/v1/object/documents/" + path,
            "POST",
            raw=PDF,
            token=token,
            apikey=anon,
            content_type="application/pdf",
        ),
    )
    require(200 <= status < 300, "measured upload")
    status, data = measured(
        "private_download",
        lambda: call(
            api + "/storage/v1/object/authenticated/documents/" + path,
            token=token,
            apikey=anon,
        ),
    )
    require(status == 200 and data == PDF, "measured download bytes")
    status, _ = call(
        api + "/rest/v1/documents",
        "POST",
        [
            {
                "user_id": actor,
                "name": "Synthetic measurement",
                "status": "pending_review",
                "file_path": path,
            }
        ],
        token=token,
        apikey=anon,
    )
    require(200 <= status < 300, "register measured document")
    document = (
        sql(root, f"select id from public.documents where user_id='{actor}';".encode())
        .stdout.decode()
        .strip()
    )
    status, _ = call(
        api + "/rest/v1/rpc/request_document_deletion",
        "POST",
        {"p_document_id": document},
        token=token,
        apikey=anon,
    )
    require(status == 200, "authorize measured erasure")
    status, body = measured(
        "edge_physical_deletion_and_finalize",
        lambda: call(
            api + "/functions/v1/document-deletion", "POST", {}, apikey=service
        ),
    )
    require(
        status == 200 and json.loads(body).get("state") == "finalized",
        "measured worker finalized",
    )
    ids = run(compose(root, "ps", "-q")).stdout.decode().split()
    stats = run(
        ["docker", "stats", "--no-stream", "--format", "{{json .}}", *ids]
    ).stdout.decode()
    result = {
        "scope": "SMALL_SYNTHETIC_SAMPLE_NOT_CAPACITY_OR_SLO_ACCEPTANCE",
        "conditions": "Windows Docker Desktop; shared host and other stacks; 4 concurrent owner reads; tiny PDF; no paid AI",
        "latency_ms": {
            label: {
                "samples": len(values),
                "p50": round(statistics.median(values), 3),
                "p95": round(percentile95(values), 3),
                "maximum": round(max(values), 3),
            }
            for label, values in samples.items()
        },
        "container_sample": [json.loads(line) for line in stats.splitlines() if line],
        "success": True,
    }
    status, _ = call(api + "/auth/v1/admin/users/" + actor, "DELETE", apikey=service)
    require(200 <= status < 300, "cleanup synthetic measurement identity")
    output.write_bytes(json.dumps(result, indent=2).encode())
    print(
        "PASS bounded API/Storage/worker measurements; evidence saved without credentials"
    )


if __name__ == "__main__":
    main()
