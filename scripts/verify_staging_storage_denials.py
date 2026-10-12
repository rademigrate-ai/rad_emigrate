#!/usr/bin/env python3
"""Negative Storage API checks against the disposable loopback stack only."""

import json
import urllib.error
import urllib.request
import uuid

from verify_stage2_browser_e2e import LocalSupabaseFixtures, load_local_environment, require
from verify_prepilot_consultation import access_token


def storage_request(fixtures, method, path, token, body=None, mime="application/pdf", upsert=False):
    headers = {"apikey": fixtures.anon_key, "Authorization": f"Bearer {token}"}
    if body is not None:
        headers["Content-Type"] = mime
    if upsert:
        headers["x-upsert"] = "true"
    request = urllib.request.Request(
        f"{fixtures.api_url}/storage/v1{path}", data=body, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def main():
    env = load_local_environment()
    require(env["API_URL"] == "http://127.0.0.1:55321", "unexpected stack")
    fixtures = LocalSupabaseFixtures(env)
    uploaded = False
    owner = other = None
    checks = {}
    try:
        owner = fixtures.create_identity("user")
        other = fixtures.create_identity("user")
        own_token = access_token(fixtures, owner)
        other_token = access_token(fixtures, other)
        path = f"{owner.user_id}/{uuid.uuid4()}/acceptance.pdf"
        body = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n"
        status, _ = storage_request(fixtures, "POST", f"/object/documents/{path}", own_token, body)
        require(status == 200, f"owner upload HTTP {status}")
        uploaded = True
        checks["owner_upload"] = status

        cases = {
            "cross_owner_signed_url": storage_request(
                fixtures, "POST", f"/object/sign/documents/{path}", other_token,
                json.dumps({"expiresIn": 60}).encode(), "application/json"),
            "cross_owner_upsert": storage_request(
                fixtures, "POST", f"/object/documents/{path}", other_token, body, upsert=True),
            "cross_owner_insert_path": storage_request(
                fixtures, "POST", f"/object/documents/{owner.user_id}/{uuid.uuid4()}/foreign.pdf",
                other_token, body),
            "unsupported_mime": storage_request(
                fixtures, "POST", f"/object/documents/{owner.user_id}/{uuid.uuid4()}/bad.txt",
                own_token, b"bad", "text/plain"),
        }
        expected = {
            "cross_owner_signed_url": "NoSuchKey",
            "cross_owner_upsert": "AccessDenied",
            "cross_owner_insert_path": "AccessDenied",
            "unsupported_mime": "InvalidMimeType",
        }
        for label, (code, response) in cases.items():
            decoded = json.loads(response)
            require(code == 400 and decoded.get("code") == expected[label],
                    f"{label} unexpected response HTTP {code}: {decoded}")
            checks[label] = {"status": code, "body": response.decode("utf-8", "replace")[:300]}
        print(json.dumps({"result": "PASS_LOCAL_STAGING", "checks": checks}, indent=2))
    finally:
        if uploaded:
            status, response = storage_request(
                fixtures, "DELETE", "/object/documents", own_token,
                json.dumps({"prefixes": [path]}).encode(), "application/json")
            require(status == 200, f"fixture object cleanup HTTP {status}: {response[:100]!r}")
        fixtures.cleanup()


if __name__ == "__main__":
    main()
