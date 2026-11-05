#!/usr/bin/env python3
"""Real, loopback-only GoTrue/PostgREST acceptance for owner-scoped case notes.

No JWT injection, mocked HTTP, Production API or real personal data.
Synthetic users are created only in a verified disposable CLI/self-host stack.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import urllib.parse
import uuid
from pathlib import Path


def verify_marker(marker_file: Path) -> int:
    marker = json.loads(marker_file.read_text(encoding="utf8"))
    if os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        from self_host_test_target import target_root

        target = target_root()
        if marker_file.resolve() != (target / "RAD_ISOLATED_INSTALL.json").resolve():
            raise ValueError("marker must match the owned self-host install")
        return int(marker["api_port"])

    checkout = Path(__file__).resolve().parents[1]
    if (
        Path(marker.get("owner_checkout", "")).resolve() != checkout
        or marker.get("project") != "rad_emigrate"
    ):
        raise ValueError("marker must identify this disposable CLI checkout")
    return int(marker["port"]) - 1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-disposable-write", action="store_true", required=True)
    parser.add_argument("--runtime-marker", type=Path, required=True)
    args = parser.parse_args()
    expected_port = verify_marker(args.runtime_marker)

    import verify_local_auth_isolation as api

    url = urllib.parse.urlsplit(api.API_URL)
    if url.hostname not in ("127.0.0.1", "localhost", "::1"):
        parser.error("refusing a non-loopback API")
    if url.port != expected_port:
        parser.error("API endpoint and disposable marker differ")

    users: list[str] = []
    app_id: str | None = None

    def rpc(name: str, token: str, params: dict) -> object:
        result, _ = api.expect_success(
            "POST",
            "/rest/v1/rpc/" + name,
            token,
            params,
            label="case checklist " + name,
        )
        return result

    try:
        tokens = []
        emails = []
        passwords = []
        for label in ("owner", "other"):
            email = f"rad-case-{label}-{uuid.uuid4().hex}@example.invalid"
            password = secrets.token_urlsafe(28)
            user_id = api.create_test_user(email, password)
            users.append(user_id)
            token, _ = api.sign_in(email, password)
            api.require(
                api.jwt_claims(token).get("sub") == user_id,
                "actual verified Auth identity",
            )
            tokens.append(token)
            emails.append(email)
            passwords.append(password)

        owner, stranger = tokens
        rows = api.rows(
            "POST",
            "/rest/v1/applications",
            owner,
            [
                {
                    "user_id": users[0],
                    "visa_type": "synthetic_no_immigration_advice",
                    "status": "draft",
                }
            ],
        )
        api.require(len(rows) == 1, "one disposable application")
        app_id = str(rows[0]["id"])
        params = {"p_application_id": app_id}
        api.require(
            rpc("get_application_case_checklist", owner, params) is None,
            "an unsaved checklist is absent",
        )

        first = rpc(
            "put_application_case_checklist",
            owner,
            {
                **params,
                "p_items": [
                    {
                        "id": "synthetic-item",
                        "title": "SYNTHETIC planning note, not visa advice",
                        "status": "notStarted",
                    }
                ],
                "p_expected_revision": 0,
            },
        )
        api.require(
            isinstance(first, dict) and first.get("revision") == 1,
            "new checklist persisted with first revision",
        )
        fetched = rpc("get_application_case_checklist", owner, params)
        api.require(
            isinstance(fetched, dict)
            and fetched.get("revision") == 1
            and fetched["items"][0]["title"].startswith("SYNTHETIC"),
            "owner reads durable Postgres checklist",
        )

        stale = {**params, "p_items": [], "p_expected_revision": 0}
        status, body = api.expect_denied(
            "POST", "/rest/v1/rpc/put_application_case_checklist", owner, stale
        )
        api.require(
            status == 409 and api.json_body(body).get("code") == "PT409",
            "stale write fails rather than overwrite a newer revision",
        )

        for rpc_name, payload in (
            ("get_application_case_checklist", params),
            ("put_application_case_checklist", stale),
        ):
            for credential in (stranger, api.ANON_KEY):
                status, _ = api.expect_denied(
                    "POST",
                    "/rest/v1/rpc/" + rpc_name,
                    credential,
                    payload,
                )
                api.require(
                    status in (401, 403, 404),
                    "foreign/anonymous RPC must be denied or hidden",
                )

        status, _ = api.expect_denied(
            "GET",
            "/rest/v1/application_case_checklists?application_id=eq." + app_id,
            owner,
        )
        api.require(
            status in (401, 403, 404),
            "private checklist table must not expose rows directly",
        )

        second = rpc(
            "put_application_case_checklist",
            owner,
            {
                **params,
                "p_items": [
                    {
                        "id": "synthetic-item",
                        "title": "SYNTHETIC edited note",
                        "status": "completed",
                    }
                ],
                "p_expected_revision": 1,
            },
        )
        api.require(
            isinstance(second, dict) and second.get("revision") == 2,
            "second version persisted",
        )
        renewed, _ = api.sign_in(emails[0], passwords[0])
        api.require(
            api.jwt_claims(renewed).get("sub") == users[0],
            "fresh login corresponds to original owner",
        )
        recovered = rpc("get_application_case_checklist", renewed, params)
        api.require(
            isinstance(recovered, dict)
            and recovered.get("revision") == 2
            and recovered["items"][0]["title"] == "SYNTHETIC edited note",
            "relogin recovers the latest persisted checklist",
        )
        print(
            "PASS: real Auth + PostgREST case checklist persistence, "
            "owner isolation, direct-table denial, stale edits and fresh "
            "JWT recovery. Synthetic disposable fixtures only."
        )
    finally:
        if app_id is not None:
            status, _, _ = api.request(
                "DELETE",
                "/rest/v1/applications?id=eq." + urllib.parse.quote(app_id),
                api.SERVICE_ROLE_KEY,
            )
            api.require(200 <= status < 300, "synthetic application cleanup")
        for user_id in users:
            api.expect_success(
                "DELETE",
                "/auth/v1/admin/users/" + user_id,
                api.SERVICE_ROLE_KEY,
                label="remove disposable Auth user",
            )


if __name__ == "__main__":
    main()
