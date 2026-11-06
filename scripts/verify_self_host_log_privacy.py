#!/usr/bin/env python3
"""Probe real signed-object access and inspect owned logs without printing secrets."""

from __future__ import annotations

import argparse
import json
import secrets
import time
import urllib.parse
from pathlib import Path

from self_host_stack import compose, run
from self_host_test_target import load_target, target_root
from verify_self_host_document_deletion import PDF, call, make_user, require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    require(
        not output.exists()
        and not output.is_relative_to(Path(__file__).resolve().parents[1]),
        "new evidence output outside Git",
    )
    root = target_root()
    api, anon, service = load_target()
    owner, bearer = make_user(api, service, anon, "log-privacy-" + secrets.token_hex(6))
    path = owner + "/synthetic-private-" + secrets.token_hex(8) + ".pdf"
    report = {
        "scope": "OWNED_GATEWAY_STORAGE_AUTH_REST_FUNCTION_LOGS",
        "production_affected": False,
    }
    try:
        status, _ = call(
            api + "/storage/v1/object/documents/" + path,
            "POST",
            raw=PDF,
            token=bearer,
            apikey=anon,
            content_type="application/pdf",
        )
        require(status < 300, "synthetic private upload")
        status, body = call(
            api + "/storage/v1/object/sign/documents/" + path,
            "POST",
            {"expiresIn": 60},
            token=bearer,
            apikey=anon,
        )
        require(status == 200, "normal owner signs preview")
        signed = api + "/storage/v1" + json.loads(body)["signedURL"]
        preview_token = urllib.parse.parse_qs(urllib.parse.urlsplit(signed).query)[
            "token"
        ][0]
        status, body = call(signed, token=bearer, apikey=anon)
        require(status == 200 and body == PDF, "real signed GET succeeds")
        status, _ = call(
            api
            + "/storage/v1/object/sign/documents/"
            + path
            + "?token=synthetic-invalid-token",
            token=bearer,
            apikey=anon,
        )
        require(status >= 400, "invalid signed GET exercises error logging")
        # Envoy buffers access-log writes; an immediate read gave false negatives.
        time.sleep(5)
        results = {}
        for name in ("api-gw", "storage", "auth", "rest", "functions"):
            captured = run(compose(root, "logs", "--since", "2m", name))
            logs = captured.stdout + captured.stderr
            results[name] = {
                "preview_token_absent": preview_token.encode() not in logs,
                "owner_bearer_absent": bearer.encode() not in logs,
                "service_key_absent": service.encode() not in logs,
                "private_object_path_absent": path.encode() not in logs,
            }
        report["services"] = results
        report["success"] = all(all(checks.values()) for checks in results.values())
        output.write_bytes(json.dumps(report, indent=2).encode())
        require(
            report["success"],
            "private bearer URLs and paths must not be retained in request logs",
        )
    finally:
        status, _ = call(
            api + "/storage/v1/object/documents/" + path, "DELETE", apikey=service
        )
        require(status in (200, 204), "remove only synthetic unregistered probe object")
        status, _ = call(
            api + "/auth/v1/admin/users/" + owner, "DELETE", apikey=service
        )
        require(status < 300, "remove synthetic log probe identity")
    print("PASS signed preview success/error and secret-free owned request logs")


if __name__ == "__main__":
    main()
