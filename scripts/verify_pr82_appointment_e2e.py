#!/usr/bin/env python3
"""Real GoTrue/PostgREST acceptance in owned disposable CI only, never browser E2E.

No JWT injection or response mocks. Missing backend is a failure, not a PASS.
Credentials remain in memory; fixtures explicitly synthetic and removed.
"""

from __future__ import annotations

import argparse
import json
import secrets
import urllib.parse
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-disposable-write", action="store_true", required=True)
    parser.add_argument("--runtime-marker", type=Path, required=True)
    args = parser.parse_args()
    marker = json.loads(args.runtime_marker.read_text(encoding="utf8"))
    root = Path(__file__).resolve().parents[1]
    if (
        Path(marker["owner_checkout"]).resolve() != root
        or marker.get("project") != "rad_emigrate"
    ):
        parser.error("runtime marker does not belong to this checkout/project")
    # Existing loader obtains keys from local CLI status and refuses non-loopback.
    import verify_local_auth_isolation as api

    if urllib.parse.urlsplit(api.API_URL).port != int(marker["port"]) - 1:
        parser.error("API port does not match the owned runtime marker")

    users: list[str] = []
    try:
        tokens = []
        for label in ("a", "b"):
            email = f"pr82-{label}-{uuid.uuid4().hex}@example.invalid"
            password = secrets.token_urlsafe(32)
            user = api.create_test_user(email, password)
            users.append(user)
            token, _ = api.sign_in(email, password)
            api.require(
                api.jwt_claims(token).get("sub") == user, "verified login subject"
            )
            tokens.append(token)

        def rpc(name, token, body):
            result, _ = api.expect_success(
                "POST", "/rest/v1/rpc/" + name, token, body, label="PR82 " + name
            )
            return result

        payload = {
            "p_title": "SYNTHETIC NOT ADVICE request",
            "p_start_utc": "2030-01-01T10:00:00Z",
            "p_end_utc": None,
            "p_time_zone": "Asia/Tehran",
            "p_notes": "SYNTHETIC ONLY",
            "p_idempotency_key": str(uuid.uuid4()),
        }
        with ThreadPoolExecutor(max_workers=4) as pool:
            receipts = list(
                pool.map(
                    lambda _: rpc("submit_rad_appointment", tokens[0], payload),
                    range(4),
                )
            )
        api.require(
            all(isinstance(r, list) and len(r) == 1 for r in receipts),
            "one receipt each",
        )
        first = receipts[0][0]
        api.require(
            all(r[0] == first for r in receipts),
            "concurrent same-key persisted receipt",
        )
        api.require(
            first["user_id"] == users[0]
            and first["status"] == "requested"
            and first["title"] == payload["p_title"]
            and first["kind"] == "radSession",
            "server receipt identity and request-only state",
        )
        owned = rpc("list_rad_appointments", tokens[0], {})
        api.require(
            len(owned) == 1 and owned[0]["id"] == first["id"], "one persisted owner row"
        )
        api.require(
            rpc("list_rad_appointments", tokens[1], {}) == [], "B list isolation"
        )
        for name, body in [
            (
                "cancel_rad_appointment",
                {"p_appointment_id": first["id"], "p_reason": "SYNTHETIC"},
            ),
            (
                "reschedule_rad_appointment",
                {
                    "p_appointment_id": first["id"],
                    "p_start_utc": "2030-01-02T10:00:00Z",
                    "p_end_utc": None,
                    "p_time_zone": None,
                    "p_notes": "SYNTHETIC",
                },
            ),
        ]:
            status, raw = api.expect_denied(
                "POST", "/rest/v1/rpc/" + name, tokens[1], body
            )
            api.require(
                api.json_body(raw).get("code") == "P0002", "cross-user hidden receipt"
            )
        status, raw = api.expect_denied(
            "POST",
            "/rest/v1/rpc/submit_rad_appointment",
            tokens[0],
            {**payload, "p_title": "SYNTHETIC changed"},
        )
        api.require(
            status == 409 and api.json_body(raw).get("code") == "PT409",
            "changed-body conflict",
        )
        for token in (api.ANON_KEY, api.SERVICE_ROLE_KEY):
            api.expect_denied(
                "POST", "/rest/v1/rpc/submit_rad_appointment", token, payload
            )
        status, raw = api.expect_denied(
            "POST",
            "/rest/v1/rpc/submit_rad_appointment",
            tokens[0],
            {**payload, "p_idempotency_key": "not-a-uuid"},
        )
        api.require(
            api.json_body(raw).get("code") == "22P02", "malformed UUID rejected"
        )
        moved = rpc(
            "reschedule_rad_appointment",
            tokens[0],
            {
                "p_appointment_id": first["id"],
                "p_start_utc": "2030-01-02T10:00:00Z",
                "p_end_utc": None,
                "p_time_zone": None,
                "p_notes": "SYNTHETIC moved",
            },
        )[0]
        api.require(
            moved["status"] == "rescheduled" and moved["notes"] == "SYNTHETIC moved",
            "persisted reschedule",
        )
        cancelled = rpc(
            "cancel_rad_appointment",
            tokens[0],
            {"p_appointment_id": first["id"], "p_reason": "SYNTHETIC cancel"},
        )[0]
        api.require(
            cancelled["id"] == first["id"] and cancelled["status"] == "cancelled",
            "persisted cancel",
        )
        api.require(
            rpc("list_rad_appointments", tokens[0], {})[0] == cancelled,
            "mutation agrees with read",
        )
        api.expect_denied(
            "PATCH",
            "/rest/v1/interview_requests?id=eq." + first["id"],
            tokens[0],
            {"status": "confirmed"},
        )
        print(
            "PASS: PR82 actual GoTrue password login, PostgREST named contracts, concurrent retry, "
            "receipt persistence, UUID validation, A/B isolation, state transitions and privilege denials. "
            "This is backend acceptance, not browser UI acceptance."
        )
    finally:
        for user in users:
            api.expect_success(
                "DELETE",
                "/auth/v1/admin/users/" + user,
                api.SERVICE_ROLE_KEY,
                label="remove owned synthetic Auth fixture",
            )


if __name__ == "__main__":
    main()
