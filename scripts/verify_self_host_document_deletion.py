#!/usr/bin/env python3
"""Hard document deletion end to end against an owned loopback self-host stack.

Proves the acceptance criteria on a real Storage service, which a mocked client
cannot: after an authorized deletion the document row AND the Storage object are
gone, the object is no longer readable, and a minimal immutable receipt remains.

Also exercises the paths that matter more than the happy one: a non-owner cannot
request deletion, the document becomes inaccessible the moment the request is
accepted, a repeat request is idempotent, the receipt cannot be altered or
deleted, and direct client DELETE on the table is refused so the previous
orphaning path is closed.
Synthetic disposable users and objects only; never a hosted project.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from self_host_stack import sql  # noqa: E402
from self_host_test_target import load_target, target_root  # noqa: E402

BUCKET = "documents"
PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"


def fail(label: str, detail: str = "") -> None:
    raise AssertionError(
        f"document deletion check failed: {label}" + (f" ({detail})" if detail else "")
    )


def require(condition: bool, label: str) -> None:
    if not condition:
        fail(label)


def call(
    url: str,
    method: str = "GET",
    payload: object | None = None,
    raw: bytes | None = None,
    token: str | None = None,
    apikey: str | None = None,
    content_type: str | None = None,
) -> tuple[int, bytes]:
    body = (
        raw
        if raw is not None
        else (None if payload is None else json.dumps(payload).encode())
    )
    req = urllib.request.Request(url, data=body, method=method)
    # Storage rejects a JSON content-type with an empty body, so only set it
    # when there is something to send.
    if body is not None:
        req.add_header("Content-Type", content_type or "application/json")
    if apikey:
        req.add_header("apikey", apikey)
    req.add_header("Authorization", f"Bearer {token or apikey or ''}")
    try:
        # This helper is restricted to an owned loopback test target. Windows
        # proxy settings can otherwise send 127.0.0.1 requests off-machine.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(req, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def make_user(api: str, service_key: str, anon_key: str, label: str) -> tuple[str, str]:
    address = f"{label}@example.invalid"
    password = secrets.token_urlsafe(32)
    status, body = call(
        f"{api}/auth/v1/admin/users",
        "POST",
        {"email": address, "password": password, "email_confirm": True},
        apikey=service_key,
    )
    require(200 <= status < 300, f"fixture user {label} created")
    user_id = json.loads(body)["id"]
    status, body = call(
        f"{api}/auth/v1/token?grant_type=password",
        "POST",
        {"email": address, "password": password},
        apikey=anon_key,
    )
    require(200 <= status < 300, f"fixture user {label} authenticates")
    return user_id, json.loads(body)["access_token"]


def run_worker(root: Path, api: str, service_key: str) -> tuple[int, dict]:
    """Drive a real Edge Function or the same RPC+Storage steps on the test stack.

    Set RAD_SELF_HOST_TEST_EDGE_FUNCTION=1 only after installing the current
    document-deletion Edge Function on this owned disposable self-host stack.
    The default verifies the SQL/Storage workflow without assuming deployment.
    """
    if os.environ.get("RAD_SELF_HOST_TEST_EDGE_FUNCTION") == "1":
        status, body = call(
            f"{api}/functions/v1/document-deletion",
            "POST",
            {},
            apikey=service_key,
        )
        require(200 <= status < 300, "deployed Edge Function worker completes")
        result = json.loads(body or b"{}")
        if result.get("processed") == 0:
            return 0, result
        require(
            result.get("processed") == 1 and result.get("state") == "finalized",
            "deployed Edge Function must finalize a Storage deletion",
        )
        return 1, result

    status, body = call(
        f"{api}/rest/v1/rpc/claim_document_deletion", "POST", {}, apikey=service_key
    )
    require(200 <= status < 300, "service role claims a deletion work item")
    claimed = json.loads(body or b"null")
    if not claimed:
        return 0, {}
    encoded_path = urllib.parse.quote(claimed["object_path"], safe="/")
    target = f"{api}/storage/v1/object/{claimed['bucket_id']}/{encoded_path}"
    removed, _ = call(target, "DELETE", apikey=service_key)
    require(removed in (200, 204, 404), f"storage object deleted (got {removed})")
    probe, probe_body = call(target, apikey=service_key)
    error = json.loads(probe_body) if probe == 400 else {}
    absent = probe == 404 or (
        probe == 400
        and error.get("statusCode") == "404"
        and error.get("error") == "not_found"
        and error.get("code") == "NoSuchKey"
    )
    require(
        absent,
        "storage must prove NoSuchKey or 404, not merely return 403/500",
    )
    status, body = call(
        f"{api}/rest/v1/rpc/finalize_document_deletion",
        "POST",
        {
            "p_request_id": claimed["request_id"],
            "p_lease_token": claimed["lease_token"],
        },
        apikey=service_key,
    )
    require(200 <= status < 300, "deletion finalized after storage confirmation")
    return 1, json.loads(body)


def main() -> None:
    root = target_root()
    api, anon_key, service_key = load_target()
    seed = secrets.token_hex(6)

    owner_id, owner_token = make_user(api, service_key, anon_key, f"del-owner-{seed}")
    other_id, other_token = make_user(api, service_key, anon_key, f"del-other-{seed}")

    object_path = f"{owner_id}/doc-{seed}.pdf"
    status, _ = call(
        f"{api}/storage/v1/object/{BUCKET}/{object_path}",
        "POST",
        raw=PDF,
        token=owner_token,
        apikey=anon_key,
        content_type="application/pdf",
    )
    require(200 <= status < 300, "owner uploads the document object")

    status, body = call(
        f"{api}/rest/v1/documents",
        "POST",
        [
            {
                "user_id": owner_id,
                "name": f"deletion fixture {seed}",
                "file_path": object_path,
                "status": "uploaded",
            }
        ],
        token=owner_token,
        apikey=anon_key,
        content_type="application/json",
    )
    require(200 <= status < 300, "owner creates the document row")
    document_id = (
        sql(
            root,
            f"select id from public.documents where file_path='{object_path}';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(bool(document_id), "document row is present before deletion")

    # --- authorization: a non-owner cannot request deletion -----------------
    status, _ = call(
        f"{api}/rest/v1/rpc/request_document_deletion",
        "POST",
        {"p_document_id": document_id},
        token=other_token,
        apikey=anon_key,
    )
    require(status >= 400, "a non-owner must not be able to request deletion")

    status, _ = call(
        f"{api}/rest/v1/rpc/request_document_deletion",
        "POST",
        {"p_document_id": document_id},
        apikey=anon_key,
    )
    require(status >= 400, "an anonymous caller must not be able to request deletion")

    # A registered object's own Storage DELETE must also be denied, since
    # deleting it directly would leave an unusable documents row.
    storage_url = f"{api}/storage/v1/object/{BUCKET}/{object_path}"
    status, _ = call(storage_url, token=owner_token, apikey=anon_key)
    require(status == 200, "owner can read the registered object before deletion")
    status, _ = call(storage_url, "DELETE", token=owner_token, apikey=anon_key)
    require(status >= 400, "registered object cannot bypass audited Storage deletion")
    status, _ = call(storage_url, token=owner_token, apikey=anon_key)
    require(status == 200, "failed direct Storage delete preserved the object")

    # --- the owner's direct DELETE is now refused (the old orphan path) -----
    status, _ = call(
        f"{api}/rest/v1/documents?id=eq.{document_id}",
        "DELETE",
        token=owner_token,
        apikey=anon_key,
    )
    remaining = (
        sql(
            root,
            f"select count(*) from public.documents where id='{document_id}';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(
        remaining == "1",
        "direct client DELETE must not remove the row (it orphaned the object before)",
    )

    # --- owner requests deletion; access is denied immediately --------------
    status, body = call(
        f"{api}/rest/v1/rpc/request_document_deletion",
        "POST",
        {"p_document_id": document_id},
        token=owner_token,
        apikey=anon_key,
    )
    require(200 <= status < 300, "owner's authorized deletion request is accepted")
    accepted = json.loads(body)
    require(accepted.get("already_requested") is False, "first request is not a repeat")

    state = (
        sql(
            root,
            f"select status from public.documents where id='{document_id}';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(
        state == "pending_deletion", "document is marked pending_deletion immediately"
    )

    status, body = call(
        f"{api}/rest/v1/documents?id=eq.{document_id}&select=id",
        token=owner_token,
        apikey=anon_key,
    )
    require(
        json.loads(body or b"[]") == [],
        "owner must not be able to read a pending_deletion document",
    )

    status, _ = call(storage_url, token=owner_token, apikey=anon_key)
    require(
        status >= 400,
        "owner must immediately lose direct Storage read access during deletion",
    )
    status, _ = call(storage_url, "DELETE", token=owner_token, apikey=anon_key)
    require(
        status >= 400,
        "owner must not directly delete Storage during the pending cleanup",
    )

    # --- idempotency: a repeat request returns the in-flight item -----------
    status, body = call(
        f"{api}/rest/v1/rpc/request_document_deletion",
        "POST",
        {"p_document_id": document_id},
        token=owner_token,
        apikey=anon_key,
    )
    require(200 <= status < 300, "repeat request is accepted idempotently")
    require(
        json.loads(body).get("already_requested") is True, "repeat request is flagged"
    )

    # --- worker performs the real storage deletion and finalizes ------------
    # The queue is FIFO, so drain it until this document's request is done
    # rather than assuming it is the only item -- leftovers from an earlier run
    # are legitimately processed first.
    for _ in range(20):
        remaining_rows = (
            sql(
                root,
                f"select count(*) from public.documents where id='{document_id}';".encode(),
            )
            .stdout.decode()
            .strip()
        )
        if remaining_rows == "0":
            break
        processed, _ = run_worker(root, api, service_key)
        require(
            processed == 1, "worker had a claimable item while this request was pending"
        )
    else:
        fail("worker did not reach this document's deletion request")

    # --- acceptance criteria ------------------------------------------------
    row = (
        sql(
            root,
            f"select count(*) from public.documents where id='{document_id}';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(row == "0", "document row is gone after deletion")

    status, _ = call(
        f"{api}/storage/v1/object/{BUCKET}/{object_path}", apikey=service_key
    )
    require(status >= 400, "storage object is no longer readable, even to service role")

    receipt = (
        sql(
            root,
            f"select result||'|'||storage_reference from public.document_deletion_receipts "
            f"where document_id='{document_id}';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(bool(receipt), "an immutable receipt remains")
    result, reference = receipt.split("|", 1)
    require(result == "deleted", "receipt records the deletion result")
    require(
        object_path not in reference and reference.startswith(BUCKET + "/"),
        "receipt stores a non-sensitive hashed storage reference, not the live path",
    )

    # --- the receipt is immutable ------------------------------------------
    for statement in (
        f"update public.document_deletion_receipts set result='failed' where document_id='{document_id}';",
        f"delete from public.document_deletion_receipts where document_id='{document_id}';",
    ):
        try:
            sql(root, statement.encode())
            fail("receipt must reject " + statement.split()[0].upper())
        except RuntimeError:
            pass

    # --- owner can read their own receipt, a stranger cannot ---------------
    status, body = call(
        f"{api}/rest/v1/rpc/get_document_deletion_receipt",
        "POST",
        {"p_document_id": document_id},
        token=owner_token,
        apikey=anon_key,
    )
    require(200 <= status < 300 and json.loads(body), "owner reads their own receipt")
    status, _ = call(
        f"{api}/rest/v1/rpc/get_document_deletion_receipt",
        "POST",
        {"p_document_id": document_id},
        token=other_token,
        apikey=anon_key,
    )
    require(status >= 400, "a stranger must not read another owner's receipt")

    # A document-type placeholder that has never had a Storage object also
    # needs a legitimate, audited deletion path from the Flutter client.
    placeholder_name = f"missing placeholder {seed}"
    status, _ = call(
        f"{api}/rest/v1/documents",
        "POST",
        [{"user_id": owner_id, "name": placeholder_name, "status": "missing"}],
        token=owner_token,
        apikey=anon_key,
    )
    require(200 <= status < 300, "owner can create an objectless placeholder")
    placeholder_id = (
        sql(
            root,
            f"select id from public.documents where name='{placeholder_name}' and user_id='{owner_id}';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(bool(placeholder_id), "placeholder persisted")
    status, body = call(
        f"{api}/rest/v1/rpc/request_document_deletion",
        "POST",
        {"p_document_id": placeholder_id},
        token=owner_token,
        apikey=anon_key,
    )
    require(
        200 <= status < 300 and json.loads(body).get("state") == "finalized",
        "objectless placeholder deletes synchronously with an audit receipt",
    )
    persisted = (
        sql(
            root,
            f"select count(*) from public.document_deletion_receipts where document_id='{placeholder_id}' and storage_reference='no_storage_object';".encode(),
        )
        .stdout.decode()
        .strip()
    )
    require(persisted == "1", "objectless placeholder has an immutable receipt")

    # Receipts remain immutable; the synthetic Auth users must still be
    # removable after hard deletion, or the queue has accidentally installed
    # a cross-service FK that blocks legitimate account lifecycle operations.
    for user_id in (owner_id, other_id):
        user_status, _ = call(
            f"{api}/auth/v1/admin/users/{user_id}", "DELETE", apikey=service_key
        )
        require(
            200 <= user_status < 300,
            "synthetic Auth user can be deleted after document cleanup",
        )

    print(
        "PASS: self-hosted hard document deletion -- non-owner and anonymous requests refused; "
        "direct client DELETE refused so the object cannot be orphaned; the document becomes "
        "unreadable the moment the request is accepted; a repeat request is idempotent; the real "
        "Storage object is deleted and unreadable even to service_role; the row is gone; and a "
        "minimal immutable receipt remains that stores a hashed reference, rejects UPDATE and "
        "DELETE, and is readable only by its owner. SYNTHETIC DISPOSABLE FIXTURES ONLY."
    )


if __name__ == "__main__":
    if not os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        raise SystemExit(
            "set RAD_SELF_HOST_TEST_ROOT to an owned disposable self-host install"
        )
    main()
