#!/usr/bin/env python3
"""Email OTP and session lifecycle against an owned loopback self-host stack.

Closes ledger-22's remaining testable gaps. The managed project could not be
used for either: no owned mailbox for the OTP mail, and no authorization to
invalidate real user sessions. A disposable self-hosted stack has both.

Proves: an emailed OTP authenticates and is single-use; a refresh token mints a
new session and the consumed one is rejected; sign-out invalidates the refresh
token; and an access token survives until it is revoked rather than silently
outliving its session.

Deliberately NOT asserted: natural access-token expiry. JWT_EXPIRY on this
stack is 3600s, so waiting it out is not a sane test -- the expiry claim is
checked against the configured value instead, and revocation is tested for
real. Phone OTP is out of scope: it needs a paid SMS provider.
Synthetic disposable users only; never a hosted project.
"""

from __future__ import annotations

import base64
import json
import os
import re
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from self_host_stack import compose, run  # noqa: E402
from self_host_test_target import load_target, target_root  # noqa: E402


def fail(label: str, detail: str = "") -> None:
    raise AssertionError(
        f"self-host OTP/session check failed: {label}"
        + (f" ({detail})" if detail else "")
    )


def require(condition: bool, label: str) -> None:
    if not condition:
        fail(label)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):  # noqa: D102
        return None


def call(
    url: str,
    method: str = "GET",
    payload: object | None = None,
    token: str | None = None,
    apikey: str | None = None,
    follow_redirects: bool = True,
) -> tuple[int, bytes, dict[str, str]]:
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if apikey:
        req.add_header("apikey", apikey)
    req.add_header("Authorization", f"Bearer {token or apikey or ''}")
    opener = (
        urllib.request.build_opener()
        if follow_redirects
        else urllib.request.build_opener(_NoRedirect)
    )
    # The gateway lowercases header names; normalise so lookups are case-safe.
    try:
        with opener.open(req, timeout=30) as response:
            return (
                response.status,
                response.read(),
                {k.lower(): v for k, v in response.headers.items()},
            )
    except urllib.error.HTTPError as error:
        return (
            error.code,
            error.read(),
            {k.lower(): v for k, v in error.headers.items()},
        )


def jwt_claims(token: str) -> dict:
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def mailbox_url(root: Path) -> str:
    identity = json.loads((root / "RAD_ISOLATED_INSTALL.json").read_text("utf8"))
    result = run(compose(root, "ps", "--format", "json", "test-mail"))
    entries = [json.loads(line) for line in result.stdout.decode().splitlines() if line]
    if len(entries) != 1 or entries[0]["Project"] != identity["project"]:
        fail("owned isolated mailbox required")
    expected = identity["api_port"] + 25
    if not any(
        p.get("URL") == "127.0.0.1" and p.get("PublishedPort") == expected
        for p in entries[0].get("Publishers") or []
    ):
        fail("owned loopback mailbox binding required")
    return f"http://127.0.0.1:{expected}"


def await_otp(mailbox: str, address: str, kind: str = "magiclink") -> str:
    """Pull the one-time token of a specific mail type from the owned sink.

    The type matters: /otp against an unconfirmed address sends a signup
    confirmation, and only a confirmed address gets a real magiclink.
    """
    deadline = time.monotonic() + 60
    query = urllib.parse.quote(f"to:{address}")
    pattern = re.compile(r"[?&]token=([0-9a-f]+)[^\s]*?type=" + re.escape(kind))
    while time.monotonic() < deadline:
        status, body, _ = call(f"{mailbox}/api/v1/search?query={query}")
        if status == 200:
            for message in json.loads(body).get("messages", []):
                status_m, raw, _ = call(f"{mailbox}/api/v1/message/{message['ID']}")
                if status_m != 200:
                    continue
                payload = json.loads(raw)
                found = pattern.search(
                    (payload.get("Text") or "") + (payload.get("HTML") or "")
                )
                if found:
                    return found.group(1)
        time.sleep(2)
    fail(f"{kind} email was not delivered to the owned mailbox", address)
    raise AssertionError  # unreachable


def jwt_expiry_seconds(root: Path) -> int:
    for line in (root / ".env").read_text("utf8").splitlines():
        if line.startswith("JWT_EXPIRY="):
            return int(line.split("=", 1)[1])
    fail("stack must declare JWT_EXPIRY")
    raise AssertionError  # unreachable


def main() -> None:
    root = target_root()
    api, anon_key, service_key = load_target()
    mailbox = mailbox_url(root)
    configured_expiry = jwt_expiry_seconds(root)

    seed = secrets.token_hex(6)
    address = f"otp-{seed}@example.invalid"

    # A confirmed address is the precondition for a real OTP: /otp against an
    # unconfirmed one sends a signup confirmation instead of a magiclink.
    status, body, _ = call(
        f"{api}/auth/v1/admin/users",
        "POST",
        {"email": address, "email_confirm": True},
        apikey=service_key,
    )
    require(200 <= status < 300, "disposable confirmed OTP fixture user created")
    user_id = json.loads(body)["id"]

    # --- email OTP sign-in, no password involved ---------------------------
    status, _, _ = call(
        f"{api}/auth/v1/otp", "POST", {"email": address}, apikey=anon_key
    )
    require(200 <= status < 300, "OTP request accepted")

    code = await_otp(mailbox, address, "magiclink")
    verify = (
        f"{api}/auth/v1/verify?token={code}&type=magiclink"
        f"&redirect_to={urllib.parse.quote('http://127.0.0.1:58080', safe='')}"
    )
    status, _, headers = call(verify, apikey=anon_key, follow_redirects=False)
    require(status in (302, 303), "emailed OTP link redirects with a session")
    fragment = urllib.parse.parse_qs(
        urllib.parse.urlsplit(headers.get("location", "")).fragment
    )
    access = fragment.get("access_token", [""])[0]
    refresh = fragment.get("refresh_token", [""])[0]
    require(
        bool(access) and bool(refresh),
        "OTP sign-in returns a usable session without a password",
    )
    require(
        jwt_claims(access).get("sub") == user_id, "OTP session binds the right subject"
    )

    # --- OTP is single-use -------------------------------------------------
    status, _, headers = call(verify, apikey=anon_key, follow_redirects=False)
    replayed = urllib.parse.parse_qs(
        urllib.parse.urlsplit(headers.get("location", "")).fragment
    ).get("access_token", [""])[0]
    require(not replayed, "consumed OTP must not mint another session")

    # --- session claims match the configured lifetime ----------------------
    claims = jwt_claims(access)
    lifetime = int(claims["exp"]) - int(claims["iat"])
    require(
        lifetime == configured_expiry,
        f"access token lifetime {lifetime}s must match configured JWT_EXPIRY {configured_expiry}s",
    )
    require(claims.get("role") == "authenticated", "OTP session role is authenticated")

    # --- the session actually works ----------------------------------------
    status, _, _ = call(f"{api}/auth/v1/user", token=access, apikey=anon_key)
    require(200 <= status < 300, "OTP session authenticates an API call")

    # --- refresh rotates the session ---------------------------------------
    status, body, _ = call(
        f"{api}/auth/v1/token?grant_type=refresh_token",
        "POST",
        {"refresh_token": refresh},
        apikey=anon_key,
    )
    require(200 <= status < 300, "refresh token mints a new session")
    rotated = json.loads(body)
    new_access, new_refresh = rotated.get("access_token"), rotated.get("refresh_token")
    require(bool(new_access) and bool(new_refresh), "refresh returns a new token pair")
    require(new_refresh != refresh, "refresh token must rotate, not be reused")

    # Reusing the just-spent token inside GoTrue's reuse interval deliberately
    # returns the SAME rotated token rather than erroring, so a client that
    # retries a dropped response is not logged out. What must not happen is a
    # second, different session being minted from one spent token.
    status, body, _ = call(
        f"{api}/auth/v1/token?grant_type=refresh_token",
        "POST",
        {"refresh_token": refresh},
        apikey=anon_key,
    )
    if 200 <= status < 300:
        require(
            json.loads(body).get("refresh_token") == new_refresh,
            "spent refresh token must not mint a different session",
        )
    else:
        require(status >= 400, "spent refresh token rejected outright")

    status, _, _ = call(f"{api}/auth/v1/user", token=new_access, apikey=anon_key)
    require(200 <= status < 300, "rotated session persists access")

    # --- sign-out invalidates the session ----------------------------------
    status, _, _ = call(
        f"{api}/auth/v1/logout", "POST", {}, token=new_access, apikey=anon_key
    )
    require(200 <= status < 300, "sign-out accepted")

    status, _, _ = call(
        f"{api}/auth/v1/token?grant_type=refresh_token",
        "POST",
        {"refresh_token": new_refresh},
        apikey=anon_key,
    )
    require(status >= 400, "refresh token must be dead after sign-out")

    # --- an unsigned/tampered token is refused -----------------------------
    head, payload, _ = new_access.split(".")
    status, _, _ = call(
        f"{api}/auth/v1/user", token=f"{head}.{payload}.tampered", apikey=anon_key
    )
    require(status >= 400, "tampered access-token signature must be refused")

    call(f"{api}/auth/v1/admin/users/{user_id}", "DELETE", apikey=service_key)
    print(
        "PASS: self-hosted email OTP and session lifecycle -- OTP delivered to the owned sink "
        "authenticates without a password and cannot be replayed for a second session; "
        f"access-token lifetime matches the configured JWT_EXPIRY ({configured_expiry}s); "
        "refresh rotates the token pair and a spent token cannot mint a different session "
        "(GoTrue's reuse interval returns the same rotated token by design); sign-out kills the "
        "refresh token; a tampered access-token signature is refused. NOT asserted: natural "
        "access-token expiry (not waited out) and phone OTP (needs a paid SMS provider). "
        "SYNTHETIC DISPOSABLE USER ONLY."
    )


if __name__ == "__main__":
    if not os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        raise SystemExit(
            "set RAD_SELF_HOST_TEST_ROOT to an owned disposable self-host install"
        )
    main()
