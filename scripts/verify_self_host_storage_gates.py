#!/usr/bin/env python3
"""Storage gate negatives on an owned loopback self-host stack.

Closes the remaining ledger-24 gaps that the two-user suite does not cover:
signed-URL expiry and replay-after-expiry, disallowed MIME rejection, and the
bucket size limit. These need a real Storage service with real enforcement --
a mocked client cannot refuse an upload the server would have accepted.

Asserts the deployed bucket policy itself (private, 10 MiB, three MIME types)
rather than hardcoding those numbers, so the test tracks configuration drift
instead of silently passing against a loosened bucket.
Synthetic disposable users and objects only; never a hosted project.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from self_host_stack import sql  # noqa: E402
from self_host_test_target import load_target, target_root  # noqa: E402

BUCKET = "documents"
# Minimal real files; Storage sniffs/validates content type from the header we send.
PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"


def fail(label: str, detail: str = "") -> None:
    raise AssertionError(
        f"self-host storage gate check failed: {label}"
        + (f" ({detail})" if detail else "")
    )


def require(condition: bool, label: str) -> None:
    if not condition:
        fail(label)


def call(
    url: str,
    method: str = "GET",
    body: bytes | None = None,
    token: str | None = None,
    apikey: str | None = None,
    content_type: str | None = None,
) -> tuple[int, bytes]:
    req = urllib.request.Request(url, data=body, method=method)
    if content_type:
        req.add_header("Content-Type", content_type)
    if apikey:
        req.add_header("apikey", apikey)
    if token or apikey:
        req.add_header("Authorization", f"Bearer {token or apikey}")
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(req, timeout=60) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def json_call(
    url: str, payload: object, token: str, apikey: str, method: str = "POST"
) -> tuple[int, bytes]:
    return call(
        url,
        method,
        json.dumps(payload).encode(),
        token=token,
        apikey=apikey,
        content_type="application/json",
    )


def bucket_policy(root: Path) -> tuple[bool, int, list[str]]:
    row = (
        sql(
            root,
            b"select public::text||'|'||file_size_limit::text||'|'||"
            b"array_to_string(allowed_mime_types,',') from storage.buckets where id='documents';",
        )
        .stdout.decode()
        .strip()
    )
    if not row:
        fail("documents bucket must exist")
    is_public, limit, mimes = row.split("|", 2)
    return is_public == "true", int(limit), mimes.split(",")


def main() -> None:
    root = target_root()
    api, anon_key, service_key = load_target()

    # The gates under test are bucket configuration; assert it rather than assume it.
    is_public, size_limit, allowed = bucket_policy(root)
    require(not is_public, "documents bucket must stay private")
    require(size_limit > 0, "documents bucket must declare a size limit")
    require(
        bool(allowed) and "application/pdf" in allowed,
        "documents bucket must allowlist MIME types",
    )
    require("text/html" not in allowed, "documents bucket must not allow text/html")

    seed = secrets.token_hex(6)
    address = f"gates-{seed}@example.invalid"
    password = secrets.token_urlsafe(32)

    status, body = call(
        f"{api}/auth/v1/admin/users",
        "POST",
        json.dumps(
            {"email": address, "password": password, "email_confirm": True}
        ).encode(),
        apikey=service_key,
        content_type="application/json",
    )
    require(200 <= status < 300, "disposable storage fixture user created")
    user_id = json.loads(body)["id"]

    status, body = call(
        f"{api}/auth/v1/token?grant_type=password",
        "POST",
        json.dumps({"email": address, "password": password}).encode(),
        apikey=anon_key,
        content_type="application/json",
    )
    require(200 <= status < 300, "fixture user authenticates")
    token = json.loads(body)["access_token"]

    base = f"{api}/storage/v1/object"
    owned = f"{user_id}/gates-{seed}.pdf"

    status, _ = call(
        f"{base}/{BUCKET}/{owned}",
        "POST",
        PDF,
        token=token,
        apikey=anon_key,
        content_type="application/pdf",
    )
    require(200 <= status < 300, "allowed MIME upload succeeds for the owner")

    # --- MIME gate negative -------------------------------------------------
    status, _ = call(
        f"{base}/{BUCKET}/{user_id}/gates-{seed}.html",
        "POST",
        b"<html><body>disallowed</body></html>",
        token=token,
        apikey=anon_key,
        content_type="text/html",
    )
    require(status >= 400, "disallowed MIME type must be rejected")

    # --- size gate negative -------------------------------------------------
    oversize = b"%PDF-1.4\n" + (b"\0" * (size_limit + 1024))
    status, _ = call(
        f"{base}/{BUCKET}/{user_id}/gates-{seed}-big.pdf",
        "POST",
        oversize,
        token=token,
        apikey=anon_key,
        content_type="application/pdf",
    )
    require(status >= 400, "upload over the bucket size limit must be rejected")

    # --- signed URL expiry and replay --------------------------------------
    status, body = json_call(
        f"{api}/storage/v1/object/sign/{BUCKET}/{owned}",
        {"expiresIn": 1},
        token,
        anon_key,
    )
    require(200 <= status < 300, "signed URL issued for an owned object")
    signed = json.loads(body)["signedURL"]
    signed_url = (
        signed
        if signed.startswith("http")
        else f"{api}/storage/v1/" + signed.lstrip("/")
    )
    require(
        urllib.parse.urlsplit(signed_url).netloc == urllib.parse.urlsplit(api).netloc,
        "signed read must stay on the owned loopback API",
    )

    status, fetched = call(signed_url, apikey=anon_key)
    require(
        200 <= status < 300 and fetched == PDF,
        "signed URL reads the object before expiry",
    )

    # Expire it for real rather than trusting the parameter.
    time.sleep(3)
    status, _ = call(signed_url, apikey=anon_key)
    require(status >= 400, "signed URL must stop working after it expires")
    status, _ = call(signed_url, apikey=anon_key)
    require(status >= 400, "expired signed URL must not be replayable")

    # --- unauthenticated and cross-path denial ------------------------------
    status, _ = call(f"{base}/{BUCKET}/{owned}", apikey=anon_key)
    require(status >= 400, "anonymous direct object read must be denied")

    call(f"{base}/{BUCKET}/{owned}", "DELETE", token=token, apikey=anon_key)
    call(f"{api}/auth/v1/admin/users/{user_id}", "DELETE", apikey=service_key)

    print(
        "PASS: self-hosted Storage gates -- deployed bucket asserted private with a size limit "
        f"and {len(allowed)} allowlisted MIME types; disallowed MIME rejected, over-limit upload "
        "rejected, signed URL readable before expiry, dead after expiry and not replayable, "
        "anonymous direct read denied. SYNTHETIC DISPOSABLE FIXTURES ONLY."
    )


if __name__ == "__main__":
    if not os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        raise SystemExit(
            "set RAD_SELF_HOST_TEST_ROOT to an owned disposable self-host install"
        )
    main()
