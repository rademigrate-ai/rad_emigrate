#!/usr/bin/env python3
"""Observe real short-TTL expiry/refresh, restoring the owned Auth config exactly."""

from __future__ import annotations

import argparse
import base64
import json
import secrets
import time
from pathlib import Path
from uuid import UUID

from self_host_stack import compose, run
from self_host_test_target import load_target, target_root
from verify_self_host_document_deletion import call, require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    require(
        not output.exists()
        and not output.is_relative_to(Path(__file__).resolve().parents[1]),
        "new private evidence file outside Git",
    )
    root = target_root()
    api, anon, service = load_target()
    database_container = run(compose(root, "ps", "-q", "db")).stdout.strip()
    require(bool(database_container), "owned database container must exist")
    env_file = root / ".env"
    original = env_file.read_bytes()
    lines = original.decode("utf8").splitlines()
    require(
        sum(line.startswith("JWT_EXPIRY=") for line in lines) == 1,
        "one explicit owned JWT expiry setting",
    )
    changed = (
        "\n".join(
            "JWT_EXPIRY=60" if line.startswith("JWT_EXPIRY=") else line
            for line in lines
        )
        + "\n"
    )

    def auth_ready():
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if call(api + "/auth/v1/health", apikey=anon)[0] == 200:
                return
            time.sleep(2)
        raise AssertionError("owned Auth did not become ready")

    report = {
        "scope": "REAL_60_SECOND_TOKEN_EXPIRY_NOT_A_3600_SECOND_WAIT",
        "production_affected": False,
    }
    actor = None
    try:
        env_file.write_bytes(changed.encode())
        run(compose(root, "up", "-d", "--no-deps", "--force-recreate", "auth"))
        auth_ready()
        address = "expiry-" + secrets.token_hex(6) + "@example.invalid"
        password = secrets.token_urlsafe(32)
        status, body = call(
            api + "/auth/v1/admin/users",
            "POST",
            {"email": address, "password": password, "email_confirm": True},
            apikey=service,
        )
        require(status == 200, "synthetic expiry identity")
        actor = str(UUID(json.loads(body)["id"]))
        status, body = call(
            api + "/auth/v1/token?grant_type=password",
            "POST",
            {"email": address, "password": password},
            apikey=anon,
        )
        require(status == 200, "normal expiry-fixture login")
        session = json.loads(body)
        token = session["access_token"]
        segment = token.split(".")[1]
        claims = json.loads(
            base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))
        )
        require(
            claims["exp"] - claims["iat"] == 60, "actual issued token uses60-second TTL"
        )
        profile = api + f"/rest/v1/profiles?id=eq.{actor}&select=id"
        initial_status, initial_body = call(profile, token=token, apikey=anon)
        report["initial_verifier_status"] = initial_status
        report["initial_token_seconds_remaining"] = round(
            claims["exp"] - time.time(), 3
        )
        report["initial_response_mentions_expiry"] = b"expir" in initial_body.lower()
        output.write_bytes(json.dumps(report, indent=2).encode())
        require(
            initial_status == 200,
            "real verifier accepts unexpired bearer",
        )
        print(
            "Waiting for natural60-second bearer expiry and verifier clock tolerance",
            flush=True,
        )
        deadline = claims["exp"] + 90
        while time.time() <= deadline:
            status, body = call(profile, token=token, apikey=anon)
            if status == 401 and b"expir" in body.lower():
                break
            require(status == 200, "unexpected verifier error cannot prove expiry")
            time.sleep(2)
        require(
            status == 401 and b"expir" in body.lower(),
            "expired bearer rejected explicitly",
        )
        report["observed_verifier_grace_seconds"] = round(
            time.time() - claims["exp"], 3
        )
        status, body = call(
            api + "/auth/v1/token?grant_type=refresh_token",
            "POST",
            {"refresh_token": session["refresh_token"]},
            apikey=anon,
        )
        require(status == 200, "refresh still recovers expired access session")
        refreshed = json.loads(body)["access_token"]
        require(
            call(profile, token=refreshed, apikey=anon)[0] == 200,
            "refreshed normal bearer works",
        )
        report.update(expired_bearer_denied=True, refresh_recovery=True)
    finally:
        env_file.write_bytes(original)
        run(compose(root, "up", "-d", "--no-deps", "--force-recreate", "auth"))
        auth_ready()
        require(
            env_file.read_bytes() == original,
            "original private Auth configuration restored byte-for-byte",
        )
        require(
            run(compose(root, "ps", "-q", "db")).stdout.strip() == database_container,
            "Auth expiry test must never recreate the database dependency",
        )
        if actor:
            status, _ = call(
                api + "/auth/v1/admin/users/" + actor, "DELETE", apikey=service
            )
            require(200 <= status < 300, "synthetic expiry identity cleanup")
    report["original_auth_configuration_restored"] = True
    report["database_container_preserved"] = True
    output.write_bytes(json.dumps(report, indent=2).encode())
    print(
        "PASS real expiry, explicit verifier refusal, refresh and exact Auth configuration recovery"
    )


if __name__ == "__main__":
    main()
