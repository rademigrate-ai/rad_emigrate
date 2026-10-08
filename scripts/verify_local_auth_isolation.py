#!/usr/bin/env python3
"""Exercise local Supabase Auth, PostgREST RLS, and Storage with two real JWTs.

This script is called only by the clean-schema CI job while its disposable local
Supabase stack is running. It creates random, confirmed Auth users in that local
stack. The parent CI job stops the stack with --no-backup after this script.
No production URL, credentials, or data are used.
"""
from __future__ import annotations

import json
import secrets
import shlex
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid


def fail(label: str, detail: str = "") -> None:
    suffix = f" ({detail})" if detail else ""
    raise AssertionError(f"Local Supabase acceptance check failed: {label}{suffix}")


def require(condition: bool, label: str) -> None:
    if not condition:
        fail(label)


def load_local_keys() -> tuple[str, str, str]:
    result = subprocess.run(
        ["supabase", "status", "--output", "env"],
        check=True,
        capture_output=True,
        text=True,
    )
    values: dict[str, str] = {}
    for line in result.stdout.splitlines():
        try:
            key, value = shlex.split(line, comments=True)[0].split("=", 1)
        except (IndexError, ValueError):
            continue
        values[key.removeprefix("export ")] = value

    api_url = values.get("API_URL") or values.get("SUPABASE_URL")
    anon_key = values.get("ANON_KEY") or values.get("SUPABASE_ANON_KEY")
    service_key = values.get("SERVICE_ROLE_KEY") or values.get(
        "SUPABASE_SERVICE_ROLE_KEY"
    )
    missing = [
        name
        for name, value in (
            ("API_URL", api_url),
            ("ANON_KEY", anon_key),
            ("SERVICE_ROLE_KEY", service_key),
        )
        if not value
    ]
    if missing:
        fail("local Supabase status is missing " + ", ".join(missing))
    return api_url.rstrip("/"), anon_key, service_key


API_URL, ANON_KEY, SERVICE_ROLE_KEY = load_local_keys()


def request(
    method: str,
    path: str,
    token: str | None = None,
    payload: object | bytes | None = None,
    content_type: str | None = None,
    extra_headers: dict[str, str] | None = None,
) -> tuple[int, bytes, dict[str, str]]:
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token or ANON_KEY}",
    }
    data: bytes | None = None
    if isinstance(payload, bytes):
        data = payload
    elif payload is not None:
        data = json.dumps(payload).encode()
        content_type = content_type or "application/json"
    if content_type:
        headers["Content-Type"] = content_type
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(
        API_URL + path,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return response.status, response.read(), dict(response.headers.items())
    except urllib.error.HTTPError as error:
        return error.code, error.read(), dict(error.headers.items())


def json_body(body: bytes) -> object:
    if not body:
        return None
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        fail("expected JSON response")
        raise AssertionError("unreachable")


def expect_success(
    method: str,
    path: str,
    token: str | None = None,
    payload: object | bytes | None = None,
    content_type: str | None = None,
    extra_headers: dict[str, str] | None = None,
    label: str = "request",
) -> tuple[object, bytes]:
    status, body, _ = request(
        method, path, token, payload, content_type, extra_headers
    )
    if status < 200 or status >= 300:
        detail = body.decode("utf-8", "replace")[:400]
        fail(label, f"HTTP {status} for {method} {path}: {detail}")
    return json_body(body), body


def expect_denied(
    method: str,
    path: str,
    token: str,
    payload: object | bytes | None = None,
    content_type: str | None = None,
    extra_headers: dict[str, str] | None = None,
    label: str = "unauthorized request",
) -> tuple[int, bytes]:
    status, body, _ = request(
        method, path, token, payload, content_type, extra_headers
    )
    if status < 400:
        fail(label, f"unexpected HTTP {status}")
    return status, body


def create_test_user(email: str, password: str) -> str:
    user, _ = expect_success(
        "POST",
        "/auth/v1/admin/users",
        SERVICE_ROLE_KEY,
        {"email": email, "password": password, "email_confirm": True},
        label="create disposable local Auth user",
    )
    require(isinstance(user, dict) and bool(user.get("id")), "Auth user id")
    return str(user["id"])


def sign_in(email: str, password: str) -> tuple[str, str]:
    response, _ = expect_success(
        "POST",
        "/auth/v1/token?grant_type=password",
        payload={"email": email, "password": password},
        label="valid password login",
    )
    require(isinstance(response, dict), "login response")
    access_token = response.get("access_token")
    refresh_token = response.get("refresh_token")
    user = response.get("user")
    require(bool(access_token) and bool(refresh_token), "login session tokens")
    require(isinstance(user, dict) and bool(user.get("id")), "login user")
    return str(access_token), str(refresh_token)


def jwt_claims(token: str) -> dict[str, object]:
    import base64

    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def rows(method: str, path: str, token: str, payload: object | None = None) -> list:
    result, _ = expect_success(
        method,
        path,
        token,
        payload,
        extra_headers={"Prefer": "return=representation"},
        label=f"PostgREST {method} {path.split('?')[0]}",
    )
    require(isinstance(result, list), "PostgREST row response")
    return result


def encoded(path: str) -> str:
    return urllib.parse.quote(path, safe="/")


def expect_upload(path: str, token: str, data: bytes, mime: str, label: str) -> None:
    expect_success(
        "POST",
        "/storage/v1/object/documents/" + encoded(path),
        token,
        data,
        mime,
        {"x-upsert": "false"},
        label=label,
    )


def main() -> None:
    seed = uuid.uuid4().hex
    password_a = secrets.token_urlsafe(32)
    password_b = secrets.token_urlsafe(32)
    email_a = f"rad-e2e-a-{seed}@example.test"
    email_b = f"rad-e2e-b-{seed}@example.test"
    user_a = create_test_user(email_a, password_a)
    user_b = create_test_user(email_b, password_b)
    require(user_a != user_b, "separate disposable Auth identities")

    token_a, refresh_a = sign_in(email_a, password_a)
    token_b, refresh_b = sign_in(email_b, password_b)
    claims_a = jwt_claims(token_a)
    claims_b = jwt_claims(token_b)
    require(claims_a.get("sub") == user_a and claims_a.get("role") == "authenticated", "user A access-token claims")
    require(claims_b.get("sub") == user_b and claims_b.get("role") == "authenticated", "user B access-token claims")
    status, _, _ = request(
        "POST",
        "/auth/v1/token?grant_type=password",
        payload={"email": email_a, "password": secrets.token_urlsafe(32)},
    )
    require(status >= 400, "wrong password must not authenticate")

    profile_a = rows(
        "GET",
        f"/rest/v1/profiles?select=id,email,full_name&id=eq.{user_a}",
        token_a,
    )
    require(len(profile_a) == 1 and profile_a[0]["id"] == user_a, "profile bootstrap")
    updated_profile = rows(
        "PATCH",
        f"/rest/v1/profiles?id=eq.{user_a}",
        token_a,
        {"full_name": "Temporary E2E User A"},
    )
    require(
        len(updated_profile) == 1
        and updated_profile[0]["full_name"] == "Temporary E2E User A",
        "owner profile update",
    )
    require(
        rows(
            "GET",
            f"/rest/v1/profiles?select=id&id=eq.{user_a}",
            token_b,
        )
        == [],
        "cross-user profile read",
    )
    require(
        rows(
            "PATCH",
            f"/rest/v1/profiles?id=eq.{user_a}",
            token_b,
            {"full_name": "Unauthorized"},
        )
        == [],
        "cross-user profile update",
    )

    app_rows = rows(
        "POST",
        "/rest/v1/applications?select=id,user_id,visa_type,status",
        token_a,
        [{"user_id": user_a, "visa_type": "e2e-temporary", "status": "draft"}],
    )
    require(len(app_rows) == 1 and app_rows[0]["user_id"] == user_a, "owner application create")
    application_id = str(app_rows[0]["id"])
    require(
        len(
            rows(
                "GET",
                f"/rest/v1/applications?select=id&id=eq.{application_id}",
                token_a,
            )
        )
        == 1,
        "owner application read",
    )
    # Stage 7 contract: ordinary users may only transition draft → submitted.
    # Other status changes must be forbidden (42501) and leave DB status unchanged.
    forbidden_status, forbidden_body, _forbidden_headers = request(
        "PATCH",
        f"/rest/v1/applications?id=eq.{application_id}&select=id,status",
        token_a,
        {"status": "in_progress"},
        extra_headers={"Prefer": "return=representation"},
    )
    require(forbidden_status >= 400, "owner forbidden status transition denied")
    detail = forbidden_body.decode("utf-8", "replace").lower()
    require(
        "42501" in detail or "forbidden" in detail or "application status" in detail,
        "owner forbidden status transition reports application status change forbidden",
    )
    still_draft = rows(
        "GET",
        f"/rest/v1/applications?select=id,status&id=eq.{application_id}",
        token_a,
    )
    require(
        len(still_draft) == 1 and still_draft[0]["status"] == "draft",
        "owner forbidden status transition leaves draft unchanged",
    )
    # Permitted user transition: draft → submitted
    app_submit = rows(
        "PATCH",
        f"/rest/v1/applications?id=eq.{application_id}&select=id,status",
        token_a,
        {"status": "submitted"},
    )
    require(
        len(app_submit) == 1 and app_submit[0]["status"] == "submitted",
        "owner application draft to submitted",
    )
    require(
        rows(
            "GET",
            f"/rest/v1/applications?select=id&id=eq.{application_id}",
            token_b,
        )
        == [],
        "cross-user application read",
    )
    require(
        rows(
            "PATCH",
            f"/rest/v1/applications?id=eq.{application_id}",
            token_b,
            {"status": "unauthorized"},
        )
        == [],
        "cross-user application update",
    )

    object_pdf = f"{user_a}/e2e-{seed}.pdf"
    documents = rows(
        "POST",
        "/rest/v1/documents?select=id,user_id,application_id,file_path",
        token_a,
        [{
            "user_id": user_a,
            "application_id": application_id,
            "name": "Temporary E2E PDF",
            "file_path": object_pdf,
        }],
    )
    require(len(documents) == 1 and documents[0]["user_id"] == user_a, "owner document metadata create")
    document_id = str(documents[0]["id"])
    require(
        rows(
            "GET",
            f"/rest/v1/documents?select=id&id=eq.{document_id}",
            token_b,
        )
        == [],
        "cross-user document metadata read",
    )

    session_rows = rows(
        "POST",
        "/rest/v1/ai_sessions?select=id,user_id",
        token_a,
        [{"user_id": user_a, "question_count": 1}],
    )
    require(len(session_rows) == 1 and session_rows[0]["user_id"] == user_a, "owner AI session create")
    session_id = str(session_rows[0]["id"])
    message_rows = rows(
        "POST",
        "/rest/v1/ai_session_messages?select=id,user_id,session_id",
        token_a,
        [{
            "user_id": user_a,
            "session_id": session_id,
            "role": "user",
            "content": "Temporary E2E persistence check",
        }],
    )
    require(len(message_rows) == 1, "owner AI message create")
    require(
        rows(
            "GET",
            f"/rest/v1/ai_sessions?select=id&id=eq.{session_id}",
            token_b,
        )
        == [],
        "cross-user AI session read",
    )
    require(
        rows(
            "GET",
            f"/rest/v1/ai_session_messages?select=id&id=eq.{message_rows[0]['id']}",
            token_b,
        )
        == [],
        "cross-user AI message read",
    )
    expect_denied(
        "POST",
        "/rest/v1/ai_session_messages",
        token_b,
        [{
            "user_id": user_b,
            "session_id": session_id,
            "role": "user",
            "content": "Unauthorized cross-session attachment",
        }],
        extra_headers={"Prefer": "return=representation"},
        label="message cannot attach to another user's AI session",
    )

    pdf = b"%PDF-1.4\n% temporary local fixture\n"
    jpg = bytes.fromhex("ffd8ffe000104a46494600010100000100010000ffd9")
    png = bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c636000020000050001a5f645400000000049454e44ae426082")
    object_jpg = f"{user_a}/e2e-{seed}.jpg"
    object_png = f"{user_a}/e2e-{seed}.png"
    expect_upload(object_pdf, token_a, pdf, "application/pdf", "PDF upload")
    expect_upload(object_jpg, token_a, jpg, "image/jpeg", "JPEG upload")
    expect_upload(object_png, token_a, png, "image/png", "PNG upload")

    for path, content in ((object_pdf, pdf), (object_jpg, jpg), (object_png, png)):
        status, downloaded, _ = request(
            "GET",
            "/storage/v1/object/authenticated/documents/" + encoded(path),
            token_a,
        )
        require(200 <= status < 300 and downloaded == content, "owner Storage read")

    signed, _ = expect_success(
        "POST",
        "/storage/v1/object/sign/documents/" + encoded(object_pdf),
        token_a,
        {"expiresIn": 60},
        label="owner signed read",
    )
    require(isinstance(signed, dict) and bool(signed.get("signedURL")), "signed URL created")
    signed_path = str(signed["signedURL"])
    if signed_path.startswith("http://") or signed_path.startswith("https://"):
        signed_url = signed_path
    elif signed_path.startswith("/storage/v1/"):
        signed_url = API_URL + signed_path
    else:
        signed_url = API_URL + "/storage/v1/" + signed_path.lstrip("/")
    req = urllib.request.Request(signed_url, headers={"apikey": ANON_KEY})
    with urllib.request.urlopen(req, timeout=30) as response:
        require(response.read() == pdf, "owner signed URL read")

    expect_denied(
        "GET",
        "/storage/v1/object/authenticated/documents/" + encoded(object_pdf),
        token_b,
        label="cross-user Storage read",
    )
    expect_denied(
        "POST",
        "/storage/v1/object/sign/documents/" + encoded(object_pdf),
        token_b,
        {"expiresIn": 60},
        label="cross-user signed URL",
    )
    expect_denied(
        "POST",
        "/storage/v1/object/documents/" + encoded(f"{user_a}/b-attack-{seed}.bin"),
        token_b,
        b"unauthorized",
        "application/pdf",
        {"x-upsert": "false"},
        "cross-user Storage upload into A namespace",
    )
    expect_denied(
        "POST",
        "/storage/v1/object/documents/" + encoded(object_pdf),
        token_b,
        b"overwrite",
        "application/pdf",
        {"x-upsert": "true"},
        "cross-user Storage overwrite",
    )
    request(
        "DELETE",
        "/storage/v1/object/documents",
        token_b,
        {"prefixes": [object_pdf]},
    )
    status, downloaded, _ = request(
        "GET",
        "/storage/v1/object/authenticated/documents/" + encoded(object_pdf),
        token_a,
    )
    require(200 <= status < 300 and downloaded == pdf, "cross-user delete did not remove A object")

    expect_denied(
        "POST",
        "/storage/v1/object/documents/" + encoded(f"{user_a}/invalid-{seed}.txt"),
        token_a,
        b"not a permitted type",
        "text/plain",
        {"x-upsert": "false"},
        "unsupported Storage MIME rejected",
    )
    expect_denied(
        "POST",
        "/storage/v1/object/documents/" + encoded(f"{user_a}/large-{seed}.pdf"),
        token_a,
        b"%PDF-1.4\n" + (b"0" * (10 * 1024 * 1024 + 1)),
        "application/pdf",
        {"x-upsert": "false"},
        "Storage object above 10 MiB rejected",
    )
    status, _, _ = request(
        "DELETE",
        "/storage/v1/object/documents",
        token_a,
        {"prefixes": [object_pdf, object_jpg, object_png]},
    )
    require(200 <= status < 300, "owner Storage delete")
    status, _, _ = request(
        "GET",
        "/storage/v1/object/authenticated/documents/" + encoded(object_pdf),
        token_a,
    )
    require(status >= 400, "owner Storage delete took effect")

    expect_success(
        "POST",
        "/auth/v1/logout",
        token_a,
        label="owner logout",
    )
    revoked_status, _, _ = request(
        "POST",
        "/auth/v1/token?grant_type=refresh_token",
        payload={"refresh_token": refresh_a},
    )
    require(revoked_status >= 400, "logout revokes refresh token")
    expect_success(
        "POST",
        "/auth/v1/logout",
        token_b,
        label="second user logout",
    )
    revoked_status, _, _ = request(
        "POST",
        "/auth/v1/token?grant_type=refresh_token",
        payload={"refresh_token": refresh_b},
    )
    require(revoked_status >= 400, "second logout revokes refresh token")
    print(
        "Local Supabase E2E passed: two authenticated users, password login/logout, "
        "profile/application/document/AI RLS, and Storage ownership/validation."
    )


if __name__ == "__main__":
    main()
