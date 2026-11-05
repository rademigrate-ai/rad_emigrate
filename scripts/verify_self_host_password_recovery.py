#!/usr/bin/env python3
"""Mailbox-verified password recovery against an owned loopback self-host stack.

Closes the "no verified mailbox or live password recovery credential change"
gap: the managed project could not be used for this (no owned mailbox, no
authorization to mutate real user credentials), but a disposable self-hosted
stack ships its own SMTP sink, so the whole flow is exercisable for real.

Proves, end to end: recovery email is actually delivered, its token performs a
real credential change, the NEW password authenticates, the OLD one stops
working, and an unauthenticated caller cannot reuse the consumed token.
Synthetic disposable users only; never a hosted or production project.
"""

from __future__ import annotations

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
        f"self-host recovery check failed: {label}" + (f" ({detail})" if detail else "")
    )


def require(condition: bool, label: str) -> None:
    if not condition:
        fail(label)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):  # noqa: D102
        return None


def request(
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


def await_recovery_token(mailbox: str, address: str) -> str:
    # Auth delivers asynchronously; poll the owned sink rather than sleeping blind.
    deadline = time.monotonic() + 60
    query = urllib.parse.quote(f"to:{address}")
    while time.monotonic() < deadline:
        status, body, _ = request(f"{mailbox}/api/v1/search?query={query}")
        if status == 200:
            for message in json.loads(body).get("messages", []):
                status_m, raw, _ = request(f"{mailbox}/api/v1/message/{message['ID']}")
                if status_m != 200:
                    continue
                payload = json.loads(raw)
                found = re.search(
                    r"[?&]token=([0-9a-f]+)[^\s]*type=recovery",
                    (payload.get("Text") or "") + (payload.get("HTML") or ""),
                )
                if found:
                    return found.group(1)
        time.sleep(2)
    fail("recovery email was not delivered to the owned mailbox", address)
    raise AssertionError  # unreachable, keeps type checkers honest


def main() -> None:
    root = target_root()
    api, anon_key, service_key = load_target()
    mailbox = mailbox_url(root)

    seed = secrets.token_hex(6)
    address = f"recovery-{seed}@example.invalid"
    original = secrets.token_urlsafe(32)
    replacement = secrets.token_urlsafe(32)

    status, body, _ = request(
        f"{api}/auth/v1/admin/users",
        "POST",
        {"email": address, "password": original, "email_confirm": True},
        apikey=service_key,
    )
    require(200 <= status < 300, "disposable recovery fixture user created")
    user_id = json.loads(body)["id"]

    status, _, _ = request(
        f"{api}/auth/v1/token?grant_type=password",
        "POST",
        {"email": address, "password": original},
        apikey=anon_key,
    )
    require(200 <= status < 300, "original password authenticates before recovery")

    status, _, _ = request(
        f"{api}/auth/v1/recover", "POST", {"email": address}, apikey=anon_key
    )
    require(200 <= status < 300, "recovery request accepted")

    token = await_recovery_token(mailbox, address)

    # The emailed link is a GET that 303s with the session in the URL fragment,
    # exactly as a user's browser would follow it.
    verify = (
        f"{api}/auth/v1/verify?token={token}&type=recovery"
        f"&redirect_to={urllib.parse.quote('http://127.0.0.1:58080', safe='')}"
    )
    status, _, headers = request(verify, apikey=anon_key, follow_redirects=False)
    require(status in (302, 303), "emailed recovery link redirects with a session")
    fragment = urllib.parse.urlsplit(headers.get("location", "")).fragment
    recovery_session = urllib.parse.parse_qs(fragment).get("access_token", [""])[0]
    require(bool(recovery_session), "recovery redirect carries an access token")

    status, _, _ = request(
        f"{api}/auth/v1/user",
        "PUT",
        {"password": replacement},
        token=recovery_session,
        apikey=anon_key,
    )
    require(200 <= status < 300, "recovery session performs a real credential change")

    status, _, _ = request(
        f"{api}/auth/v1/token?grant_type=password",
        "POST",
        {"email": address, "password": replacement},
        apikey=anon_key,
    )
    require(200 <= status < 300, "new password authenticates after recovery")

    status, _, _ = request(
        f"{api}/auth/v1/token?grant_type=password",
        "POST",
        {"email": address, "password": original},
        apikey=anon_key,
    )
    require(status >= 400, "old password must stop authenticating after recovery")

    status, _, headers = request(verify, apikey=anon_key, follow_redirects=False)
    replayed = urllib.parse.parse_qs(
        urllib.parse.urlsplit(headers.get("location", "")).fragment
    ).get("access_token", [""])[0]
    require(not replayed, "consumed recovery token must not mint another session")

    request(f"{api}/auth/v1/admin/users/{user_id}", "DELETE", apikey=service_key)
    print(
        "PASS: self-hosted mailbox-verified password recovery -- email delivered to the "
        "owned SMTP sink, emailed token performed a real credential change, new password "
        "authenticates, old password rejected, consumed token not replayable. "
        "SYNTHETIC DISPOSABLE USER ONLY; no hosted or Production project was involved."
    )


if __name__ == "__main__":
    if not os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        raise SystemExit(
            "set RAD_SELF_HOST_TEST_ROOT to an owned disposable self-host install"
        )
    main()
