#!/usr/bin/env python3
"""Isolated document upload/delete diagnostic for local loopback only.

Validates UI flow plus real backend effects:
  - documents row owner/status/file_path
  - Storage object present after upload
  - cross-user REST denial (HTTP 200 + empty JSON array only)
  - row + storage confirmed absent after delete
  - test-owned Storage/row cleanup even on assertion failure

Storage delete contract (Supabase Storage API):
  DELETE /storage/v1/object/{bucket}
  Content-Type: application/json
  Body: {"prefixes": ["userId/docId/file.pdf", ...]}

  Confirmed against Supabase self-hosting Storage reference
  (delete multiple objects body field "prefixes") and JS remove([...]).
  A bare JSON array body is not used.

Never logs passwords, tokens, service-role keys, signed URLs, or full
file paths that embed user IDs (only lengths / booleans).

Does not modify the main E2E suite, migrations, or production.
Usage (repo root):
  python scripts/diag_document_upload_delete_e2e.py --web-root build/web
"""

from __future__ import annotations

import argparse
import asyncio
import importlib.util
import json
import re
import sys
import traceback
import urllib.parse
from pathlib import Path
from typing import Any

from playwright.async_api import async_playwright

_SUITE_PATH = Path(__file__).resolve().parent / "verify_stage2_browser_e2e.py"
if not _SUITE_PATH.is_file():
    _alt = (
        Path(__file__).resolve().parent.parent
        / "scripts"
        / "verify_stage2_browser_e2e.py"
    )
    _SUITE_PATH = _alt if _alt.is_file() else _SUITE_PATH

if not _SUITE_PATH.is_file():
    print(f"missing suite helper: {_SUITE_PATH}", file=sys.stderr)
    raise SystemExit(2)

_MODULE_NAME = "verify_stage2_browser_e2e"
_spec = importlib.util.spec_from_file_location(_MODULE_NAME, _SUITE_PATH)
if _spec is None or _spec.loader is None:
    print(f"cannot load suite helper: {_SUITE_PATH}", file=sys.stderr)
    raise SystemExit(2)
_suite = importlib.util.module_from_spec(_spec)
sys.modules[_MODULE_NAME] = _suite
_spec.loader.exec_module(_suite)

load_local_environment = _suite.load_local_environment
LocalSupabaseFixtures = _suite.LocalSupabaseFixtures
serve_web = _suite.serve_web
require = _suite.require
AcceptanceFailure = _suite.AcceptanceFailure
LOOPBACK_HOSTS = _suite.LOOPBACK_HOSTS

SEED_NAME = "Stage 2 browser passport"
UPLOAD_NAME = "stage2-browser-passport.pdf"
MINIMAL_PDF = (
    b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n"
    b"trailer<</Root 1 0 R>>\n%%EOF\n"
)
STORAGE_BUCKET = "documents"


def _error_category(exc: BaseException) -> str:
    name = type(exc).__name__
    msg = str(exc).lower()
    if "timeout" in name.lower() or "timeout" in msg:
        return "timeout"
    if isinstance(exc, AcceptanceFailure):
        return "acceptance"
    if "net" in msg or "connection" in msg:
        return "network"
    return name


def _redact_message(text: str) -> str:
    text = re.sub(
        r"[?&#](access_token|refresh_token|token|key|apikey)=[^&\s]+",
        r"\1=REDACTED",
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(
        r"\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-"
        r"[0-9a-f]{12}\b",
        "<uuid>",
        text,
        flags=re.IGNORECASE,
    )
    return text[:300]


async def _enable_semantics(page: Any) -> None:
    await page.locator("flt-glass-pane").wait_for(state="attached", timeout=30_000)
    placeholder = page.locator("flt-semantics-placeholder")
    if await placeholder.count():
        await placeholder.evaluate("element => element.click()")
    await page.wait_for_function(
        """() => [...document.querySelectorAll('flt-semantics')].some(
          (el) => ((el.textContent || el.getAttribute('aria-label') || '')
            .trim().length > 0)
        )""",
        timeout=30_000,
    )


async def _click(locator: Any) -> None:
    await locator.wait_for(state="attached", timeout=15_000)
    await locator.evaluate("element => element.click()")


class BackendProbe:
    """Service-role and user-JWT probes against local loopback only."""

    def __init__(self, fixtures: Any) -> None:
        self.fx = fixtures
        self.allowed_user_ids: set[str] = set()
        self.tracked_documents: list[tuple[str, str]] = []
        self.tracked_storage_paths: list[str] = []

    def allow_user(self, user_id: str) -> None:
        if user_id:
            self.allowed_user_ids.add(user_id)

    def track_document(self, document_id: str, owner_user_id: str) -> None:
        if not document_id or not owner_user_id:
            return
        if owner_user_id not in self.allowed_user_ids:
            return
        pair = (document_id, owner_user_id)
        if pair not in self.tracked_documents:
            self.tracked_documents.append(pair)

    def track_storage_path(self, path: str, owner_user_id: str) -> None:
        if not path or not owner_user_id:
            return
        if owner_user_id not in self.allowed_user_ids:
            return
        if not any(
            owner == owner_user_id and path.startswith(f"{owner}/{doc_id}/")
            for doc_id, owner in self.tracked_documents
        ):
            return
        if path.startswith("/") or ".." in path.split("/"):
            return
        if path not in self.tracked_storage_paths:
            self.tracked_storage_paths.append(path)

    def document_prefix(self, owner_user_id: str, document_id: str) -> str:
        return f"{owner_user_id}/{document_id}"

    def user_token(self, email: str, password: str) -> str:
        status, body, _ = self.fx.request(
            "POST",
            "/auth/v1/token?grant_type=password",
            token=self.fx.anon_key,
            payload={"email": email, "password": password},
        )
        require(status == 200, f"user token HTTP {status}")
        data = json.loads(body)
        token = data.get("access_token")
        require(isinstance(token, str) and len(token) > 20, "missing access_token")
        return token

    def document_row_probe(self, document_id: str) -> dict[str, Any]:
        status, body, _ = self.fx.request(
            "GET",
            f"/rest/v1/documents?id=eq.{document_id}"
            f"&select=id,user_id,name,status,file_path",
        )
        if status != 200:
            return {
                "state": "api_error",
                "error_category": "http_error",
                "http_status": status,
                "row": None,
            }
        try:
            rows = json.loads(body)
        except json.JSONDecodeError:
            return {
                "state": "api_error",
                "error_category": "invalid_json",
                "http_status": status,
                "row": None,
            }
        if not isinstance(rows, list):
            return {
                "state": "api_error",
                "error_category": "not_array",
                "http_status": status,
                "row": None,
            }
        if len(rows) == 0:
            return {
                "state": "absent",
                "http_status": status,
                "row": None,
                "row_count": 0,
            }
        if len(rows) > 1 or not isinstance(rows[0], dict):
            return {
                "state": "api_error",
                "error_category": "unexpected_rows",
                "http_status": status,
                "row": None,
                "row_count": len(rows),
            }
        return {
            "state": "present",
            "http_status": status,
            "row": rows[0],
            "row_count": 1,
        }

    def document_row_as_user(self, token: str, document_id: str) -> dict[str, Any]:
        status, body, _ = self.fx.request(
            "GET",
            f"/rest/v1/documents?id=eq.{document_id}"
            f"&select=id,user_id,name,status",
            token=token,
        )
        result: dict[str, Any] = {
            "http_status": status,
            "json_array": False,
            "row_count": None,
            "denied": False,
            "probe_ok": False,
        }
        if status != 200:
            result["error_category"] = "http_error"
            return result
        try:
            rows = json.loads(body)
        except json.JSONDecodeError:
            result["error_category"] = "invalid_json"
            return result
        if not isinstance(rows, list):
            result["error_category"] = "not_array"
            return result
        result["json_array"] = True
        result["row_count"] = len(rows)
        result["probe_ok"] = True
        result["denied"] = len(rows) == 0
        return result

    def list_storage_prefix(self, prefix: str) -> dict[str, Any]:
        """Exhaustively list a prefix; fail closed on pagination/API anomalies."""
        if not prefix or prefix.startswith("/") or ".." in prefix.split("/"):
            return {"state": "api_error", "error_category": "invalid_prefix", "names": []}
        names: list[str] = []
        limit = 100
        offset = 0
        # A bounded scan prevents a broken API from looping indefinitely.
        for _ in range(100):
            try:
                status, body, _ = self.fx.request(
                    "POST",
                    f"/storage/v1/object/list/{STORAGE_BUCKET}",
                    payload={"prefix": prefix, "limit": limit, "offset": offset},
                )
            except Exception as exc:
                return {"state": "api_error", "error_category": _error_category(exc), "names": []}
            if not 200 <= status < 300:
                return {"state": "api_error", "error_category": "list_http_error",
                        "http_status": status, "names": []}
            try:
                items = json.loads(body)
            except (ValueError, TypeError):
                return {"state": "api_error", "error_category": "list_invalid_json",
                        "http_status": status, "names": []}
            if not isinstance(items, list) or any(
                not isinstance(item, dict) or not isinstance(item.get("name"), str)
                for item in items
            ):
                return {"state": "api_error", "error_category": "list_invalid_items",
                        "http_status": status, "names": []}
            names.extend(item["name"] for item in items)
            if len(items) < limit:
                return {"state": "ok", "http_status": status,
                        "names": names, "list_count": len(names)}
            offset += len(items)
        return {"state": "api_error", "error_category": "pagination_limit",
                "names": [], "list_count": len(names)}

    def storage_object_state(self, path: str) -> dict[str, Any]:
        parent, _, leaf = path.rpartition("/")
        if not parent or not leaf:
            return {
                "state": "api_error",
                "error_category": "invalid_path_shape",
                "http_status": None,
            }
        listed = self.list_storage_prefix(parent)
        if listed.get("state") != "ok":
            return {
                "state": "api_error",
                "error_category": listed.get("error_category"),
                "http_status": listed.get("http_status"),
            }
        names = set(listed.get("names") or [])
        if leaf in names or path in names or any(
            n.endswith("/" + leaf) or n == leaf for n in names
        ):
            return {
                "state": "present",
                "http_status": listed.get("http_status"),
                "list_count": listed.get("list_count"),
            }
        return {
            "state": "absent",
            "http_status": listed.get("http_status"),
            "list_count": listed.get("list_count"),
        }

    def discover_under_document_prefix(
        self, owner_user_id: str, document_id: str
    ) -> dict[str, Any]:
        """List and track objects only under {userId}/{documentId}/."""
        if owner_user_id not in self.allowed_user_ids:
            return {
                "state": "api_error",
                "error_category": "owner_not_allowed",
                "path_count": 0,
            }
        prefix = self.document_prefix(owner_user_id, document_id)
        listed = self.list_storage_prefix(prefix)
        if listed.get("state") != "ok":
            return {
                "state": "api_error",
                "error_category": listed.get("error_category"),
                "http_status": listed.get("http_status"),
                "path_count": 0,
                "prefix_len": len(prefix),
            }
        count = 0
        for name in listed.get("names") or []:
            # Storage may return either leaf names or complete object keys.
            # Never reinterpret a different user's/document's absolute key as a leaf.
            if not name or name.startswith("/") or ".." in name.split("/"):
                return {"state": "api_error", "error_category": "unsafe_list_name",
                        "path_count": count, "prefix_len": len(prefix)}
            if name.startswith(prefix + "/"):
                full = name
            elif name.startswith(owner_user_id + "/"):
                return {"state": "api_error", "error_category": "out_of_scope_key",
                        "path_count": count, "prefix_len": len(prefix)}
            else:
                full = f"{prefix}/{name}"
            if not full.startswith(prefix + "/"):
                return {"state": "api_error", "error_category": "out_of_scope_key",
                        "path_count": count, "prefix_len": len(prefix)}
            self.track_storage_path(full, owner_user_id)
            count += 1
        return {
            "state": "ok",
            "http_status": listed.get("http_status"),
            "path_count": count,
            "prefix_len": len(prefix),
        }

    def remove_storage_path(self, path: str) -> dict[str, Any]:
        """DELETE /storage/v1/object/{bucket} body {"prefixes": [path]}."""
        result: dict[str, Any] = {
            "path_len": len(path),
            "delete_http_status": None,
            "delete_ok": False,
            "confirm_state": None,
            "confirmed_absent": False,
            "ok": False,
        }
        try:
            status, body, _ = self.fx.request(
                "DELETE",
                f"/storage/v1/object/{STORAGE_BUCKET}",
                payload={"prefixes": [path]},
            )
            result["delete_http_status"] = status
            result["delete_ok"] = 200 <= status < 300
            result["body_len"] = len(body or b"")
        except Exception as exc:  # noqa: BLE001
            result["delete_error_category"] = _error_category(exc)
            result["delete_error_type"] = type(exc).__name__
            return result

        try:
            confirm = self.storage_object_state(path)
            result["confirm_state"] = confirm.get("state")
            result["confirm_http_status"] = confirm.get("http_status")
            result["confirmed_absent"] = confirm.get("state") == "absent"
        except Exception as exc:  # noqa: BLE001
            result["confirm_error_category"] = _error_category(exc)
            result["confirm_error_type"] = type(exc).__name__
            return result

        if result["confirmed_absent"]:
            result["ok"] = True
        return result

    def delete_document_row(
        self, document_id: str, owner_user_id: str
    ) -> dict[str, Any]:
        result: dict[str, Any] = {
            "id_len": len(document_id),
            "delete_http_status": None,
            "delete_ok": False,
            "confirm_state": None,
            "confirmed_absent": False,
            "ok": False,
        }
        if owner_user_id not in self.allowed_user_ids:
            result["error_category"] = "owner_not_allowed"
            return result
        try:
            status, body, _ = self.fx.request(
                "DELETE",
                f"/rest/v1/documents?id=eq.{document_id}"
                f"&user_id=eq.{owner_user_id}",
            )
            result["delete_http_status"] = status
            result["delete_ok"] = 200 <= status < 300
            result["body_len"] = len(body or b"")
        except Exception as exc:  # noqa: BLE001
            result["delete_error_category"] = _error_category(exc)
            result["delete_error_type"] = type(exc).__name__
            return result

        try:
            probe = self.document_row_probe(document_id)
            result["confirm_state"] = probe.get("state")
            result["confirm_http_status"] = probe.get("http_status")
            if probe.get("state") == "absent":
                result["confirmed_absent"] = True
            elif probe.get("state") == "present":
                row = probe.get("row") or {}
                # Still present for this owner => not cleaned
                result["confirmed_absent"] = row.get("user_id") != owner_user_id
            else:
                result["confirmed_absent"] = False
        except Exception as exc:  # noqa: BLE001
            result["confirm_error_category"] = _error_category(exc)
            result["confirm_error_type"] = type(exc).__name__
            return result

        if result["confirmed_absent"]:
            result["ok"] = True
        return result

    def document_meta(self, row: dict[str, Any] | None) -> dict[str, Any]:
        if row is None:
            return {"present": False}
        path = row.get("file_path")
        return {
            "present": True,
            "status": row.get("status"),
            "name_len": len(str(row.get("name") or "")),
            "name_is_seed": row.get("name") == SEED_NAME,
            "name_is_upload": row.get("name") == UPLOAD_NAME,
            "has_file_path": bool(path),
            "file_path_len": len(str(path)) if path else 0,
            "owner_matches_path_prefix": (
                isinstance(path, str)
                and bool(row.get("user_id"))
                and path.startswith(str(row.get("user_id")) + "/")
            ),
        }

    def cleanup_test_artifacts(self) -> dict[str, Any]:
        discovery_results: list[dict[str, Any]] = []
        for document_id, owner_user_id in list(self.tracked_documents):
            try:
                discovered = self.discover_under_document_prefix(owner_user_id, document_id)
                discovery_results.append({"state": discovered.get("state"),
                                          "error_category": discovered.get("error_category"),
                                          "path_count": discovered.get("path_count")})
            except Exception as exc:
                discovery_results.append({"state": "api_error",
                                          "error_category": _error_category(exc)})
        discovery_ok = all(r.get("state") == "ok" for r in discovery_results)

        storage_results: list[dict[str, Any]] = []
        for path in list(self.tracked_storage_paths):
            try:
                storage_results.append(self.remove_storage_path(path))
            except Exception as exc:  # noqa: BLE001
                storage_results.append(
                    {
                        "path_len": len(path),
                        "ok": False,
                        "error_category": _error_category(exc),
                        "error_type": type(exc).__name__,
                    }
                )

        doc_results: list[dict[str, Any]] = []
        for document_id, owner_user_id in list(self.tracked_documents):
            try:
                doc_results.append(
                    self.delete_document_row(document_id, owner_user_id)
                )
            except Exception as exc:  # noqa: BLE001
                doc_results.append(
                    {
                        "id_len": len(document_id),
                        "ok": False,
                        "error_category": _error_category(exc),
                        "error_type": type(exc).__name__,
                    }
                )

        storage_ok = (
            all(r.get("ok") for r in storage_results) if storage_results else True
        )
        docs_ok = all(r.get("ok") for r in doc_results) if doc_results else True
        return {
            "storage_targets": len(self.tracked_storage_paths),
            "storage_attempts": len(storage_results),
            "storage_ok": storage_ok,
            "document_targets": len(self.tracked_documents),
            "document_attempts": len(doc_results),
            "documents_ok": docs_ok,
            "discovery_ok": discovery_ok,
            "discovery_attempts": len(discovery_results),
            "ok": discovery_ok and storage_ok and docs_ok,
        }


async def _run(web_root: Path, artifacts: Path, port: int) -> dict[str, Any]:
    report: dict[str, Any] = {
        "result": "FAIL",
        "steps": [],
        "exception": None,
        "cleanup_ok": False,
    }

    def step(name: str, **data: Any) -> None:
        report["steps"].append({"name": name, **data})
        print(f"[diag] {name}: {json.dumps(data, default=str)[:500]}")

    environment = load_local_environment()
    fixtures = LocalSupabaseFixtures(environment)
    probe = BackendProbe(fixtures)
    owner = None
    other = None
    document_id: str | None = None
    assertions_passed = False

    try:
        owner = fixtures.create_identity("user")
        other = fixtures.create_identity("user")
        probe.allow_user(owner.user_id)
        probe.allow_user(other.user_id)
        step(
            "identities_created",
            owner_role=owner.role,
            other_role=other.role,
            email_domain=owner.email.split("@")[-1],
            allowed_user_count=len(probe.allowed_user_ids),
        )

        document_id = fixtures.seed_user_records(owner)
        probe.track_document(document_id, owner.user_id)
        seed_probe = probe.document_row_probe(document_id)
        seed_row = (
            seed_probe.get("row")
            if seed_probe.get("state") == "present"
            else None
        )
        if seed_row and seed_row.get("file_path"):
            probe.track_storage_path(str(seed_row["file_path"]), owner.user_id)
        step(
            "seed_document",
            probe_state=seed_probe.get("state"),
            **probe.document_meta(seed_row),
            seed_owner_ok=(
                seed_row is not None and seed_row.get("user_id") == owner.user_id
            ),
            tracked_documents=len(probe.tracked_documents),
        )
        require(
            seed_probe.get("state") == "present"
            and seed_row is not None
            and seed_row.get("status") == "missing"
            and seed_row.get("user_id") == owner.user_id,
            "seed document missing, wrong status, or probe error "
            f"(state={seed_probe.get('state')})",
        )

        with serve_web(web_root.resolve(), port) as base_url:
            step(
                "spa_server",
                host_is_loopback=urllib.parse.urlparse(base_url).hostname
                in LOOPBACK_HOSTS,
            )
            async with async_playwright() as playwright:
                browser = await playwright.chromium.launch(headless=True)
                context = await browser.new_context(
                    viewport={"width": 1280, "height": 800},
                    locale="en-US",
                    reduced_motion="reduce",
                )
                page = await context.new_page()
                browser_errors: list[str] = []
                failed_requests: list[dict[str, Any]] = []
                auth_statuses: list[int] = []
                document_mutations: list[dict[str, Any]] = []

                def capture_response(response: Any) -> None:
                    parsed = urllib.parse.urlparse(response.url)
                    if parsed.path.startswith("/auth/v1/"):
                        auth_statuses.append(response.status)
                    if (
                        response.request.method in {"POST", "PATCH", "DELETE"}
                        and (
                            parsed.path == "/rest/v1/documents"
                            or parsed.path.startswith("/storage/v1/object")
                        )
                    ):
                        document_mutations.append(
                            {
                                "method": response.request.method,
                                "path": parsed.path,
                                "status": response.status,
                            }
                        )
                    if response.status >= 400:
                        failed_requests.append(
                            {
                                "method": response.request.method,
                                "path": parsed.path,
                                "status": response.status,
                            }
                        )

                page.on("response", capture_response)
                page.on(
                    "requestfailed",
                    lambda request: failed_requests.append(
                        {
                            "method": request.method,
                            "path": urllib.parse.urlparse(request.url).path,
                            "status": "failed",
                        }
                    ),
                )
                page.on(
                    "pageerror",
                    lambda error: browser_errors.append(
                        _redact_message(f"pageerror: {error}")
                    ),
                )
                page.on(
                    "console",
                    lambda message: browser_errors.append(
                        _redact_message(f"console: {message.text}")
                    )
                    if message.type == "error"
                    else None,
                )
                try:
                    await page.goto(
                        f"{base_url}/login",
                        wait_until="domcontentloaded",
                        timeout=30_000,
                    )
                    await _enable_semantics(page)
                    email_field = page.get_by_label("Email", exact=True)
                    await email_field.focus()
                    await email_field.press_sequentially(owner.email, delay=1)
                    await page.keyboard.press("Tab")
                    await page.wait_for_timeout(200)
                    email_ok = await email_field.input_value() == owner.email
                    password_field = page.get_by_label("Password", exact=True)
                    await password_field.focus()
                    await password_field.press_sequentially(
                        owner.password, delay=1
                    )
                    await page.keyboard.press("Tab")
                    await page.wait_for_timeout(350)
                    password_ok = (
                        await password_field.input_value() == owner.password
                    )
                    step(
                        "login_input",
                        email_ok=email_ok,
                        password_ok=password_ok,
                        email_length=len(await email_field.input_value()),
                        password_length=len(await password_field.input_value()),
                    )
                    require(
                        email_ok and password_ok,
                        "Flutter login fields did not retain browser input",
                    )
                    await _click(
                        page.get_by_role("button", name="Sign in", exact=True)
                    )
                    try:
                        await page.wait_for_url(
                            re.compile(r".*/dashboard(?:[?#].*)?$"),
                            timeout=30_000,
                        )
                    except Exception:
                        semantics = " | ".join(
                            await page.locator("flt-semantics").all_inner_texts()
                        )
                        failure_shot = artifacts / "sign-in-failure.png"
                        artifacts.mkdir(parents=True, exist_ok=True)
                        await page.screenshot(path=failure_shot, full_page=True)
                        step(
                            "sign_in_failure",
                            path=urllib.parse.urlparse(page.url).path,
                            semantics=_redact_message(semantics),
                            auth_statuses=auth_statuses[-3:],
                            browser_errors=browser_errors[-10:],
                            failed_requests=failed_requests[-10:],
                            screenshot_written=failure_shot.is_file(),
                        )
                        raise
                    await _enable_semantics(page)
                    step(
                        "sign_in",
                        path=urllib.parse.urlparse(page.url).path,
                        ok=True,
                        auth_statuses=auth_statuses[-3:],
                    )

                    # A successful route transition is not enough: prove the
                    # web client persisted an Auth session before deliberately
                    # cold-loading the protected document route.
                    session_persisted = await page.evaluate(
                        """() => Object.keys(localStorage).some(
                          (key) => key.includes('auth-token')
                        )"""
                    )
                    step("auth_session", persisted=bool(session_persisted))
                    require(session_persisted, "browser Auth session was not persisted")

                    await page.goto(
                        f"{base_url}/documents",
                        wait_until="domcontentloaded",
                        timeout=30_000,
                    )
                    await _enable_semantics(page)
                    try:
                        await page.get_by_text(SEED_NAME, exact=False).last.wait_for(
                            state="attached", timeout=20_000
                        )
                    except Exception:
                        semantics = " | ".join(
                            await page.locator("flt-semantics").all_inner_texts()
                        )
                        failure_shot = artifacts / "documents-route-failure.png"
                        artifacts.mkdir(parents=True, exist_ok=True)
                        await page.screenshot(path=failure_shot, full_page=True)
                        step(
                            "documents_route_failure",
                            path=urllib.parse.urlparse(page.url).path,
                            semantics=_redact_message(semantics),
                            browser_errors=browser_errors[-10:],
                            failed_requests=failed_requests[-10:],
                            screenshot_written=failure_shot.is_file(),
                        )
                        raise
                    step("documents_list_seed", visible=True)

                    await _click(page.get_by_text(SEED_NAME, exact=False).last)
                    upload_btn = page.get_by_role(
                        "button", name="Choose file and upload", exact=True
                    )
                    await upload_btn.wait_for(state="attached", timeout=15_000)
                    async with page.expect_file_chooser(
                        timeout=15_000
                    ) as chooser_info:
                        await _click(upload_btn)
                    chooser = await chooser_info.value
                    await chooser.set_files(
                        {
                            "name": UPLOAD_NAME,
                            "mimeType": "application/pdf",
                            "buffer": MINIMAL_PDF,
                        }
                    )
                    step("file_chooser_set", bytes=len(MINIMAL_PDF))

                    try:
                        await page.get_by_text(SEED_NAME, exact=False).last.wait_for(
                            state="detached", timeout=30_000
                        )
                        seed_detached = True
                    except Exception:
                        seed_detached = False
                    try:
                        await page.get_by_text(UPLOAD_NAME, exact=False).last.wait_for(
                            state="attached", timeout=30_000
                        )
                        upload_visible = True
                    except Exception:
                        upload_visible = False
                    step(
                        "upload_ui",
                        seed_detached=seed_detached,
                        upload_visible=upload_visible,
                    )
                    require(
                        seed_detached and upload_visible,
                        "upload UI did not replace seed name with upload name",
                    )

                    after_probe = probe.document_row_probe(document_id)
                    row_after = (
                        after_probe.get("row")
                        if after_probe.get("state") == "present"
                        else None
                    )
                    meta_after = probe.document_meta(row_after)
                    storage_state: dict[str, Any] = {
                        "state": "api_error",
                        "error_category": "no_file_path",
                        "http_status": None,
                    }
                    if row_after and row_after.get("file_path"):
                        path = str(row_after["file_path"])
                        probe.track_storage_path(path, owner.user_id)
                        storage_state = probe.storage_object_state(path)
                    else:
                        discovered = probe.discover_under_document_prefix(
                            owner.user_id, document_id
                        )
                        step("upload_storage_discover", **discovered)
                        if discovered.get("path_count", 0) > 0:
                            storage_state = {
                                "state": "present",
                                "http_status": discovered.get("http_status"),
                            }
                    step(
                        "upload_backend",
                        row_probe_state=after_probe.get("state"),
                        **meta_after,
                        status_uploaded=(meta_after.get("status") == "uploaded"),
                        storage_state=storage_state.get("state"),
                        storage_http_status=storage_state.get("http_status"),
                        tracked_storage=len(probe.tracked_storage_paths),
                    )
                    require(
                        after_probe.get("state") == "present"
                        and meta_after.get("status") == "uploaded"
                        and meta_after.get("has_file_path")
                        and meta_after.get("owner_matches_path_prefix")
                        and storage_state.get("state") == "present",
                        "upload did not persist status/file_path/storage object "
                        f"(row={after_probe.get('state')}, "
                        f"storage={storage_state.get('state')})",
                    )

                    other_token = probe.user_token(other.email, other.password)
                    cross = probe.document_row_as_user(other_token, document_id)
                    step("cross_user_read", **cross)
                    require(
                        cross.get("probe_ok") is True
                        and cross.get("http_status") == 200
                        and cross.get("json_array") is True
                        and cross.get("row_count") == 0
                        and cross.get("denied") is True,
                        "cross-user document read was not a clean RLS denial",
                    )

                    await _click(page.get_by_text(UPLOAD_NAME, exact=False).last)
                    await page.get_by_text("View details", exact=False).wait_for(
                        state="attached", timeout=15_000
                    )
                    await _click(
                        page.get_by_role(
                            "button", name="Delete document", exact=True
                        )
                    )
                    await _click(
                        page.get_by_role("button", name="Delete", exact=True)
                    )
                    # Confirmation closes one Flutter semantic modal before
                    # the awaited repository deletion finishes. Poll the real
                    # row instead of treating that transient detachment as
                    # completion.
                    delete_deadline = asyncio.get_running_loop().time() + 20
                    final_probe = probe.document_row_probe(document_id)
                    while (
                        final_probe.get("state") != "absent"
                        and asyncio.get_running_loop().time() < delete_deadline
                    ):
                        await asyncio.sleep(0.25)
                        final_probe = probe.document_row_probe(document_id)
                    try:
                        await page.get_by_text(
                            UPLOAD_NAME, exact=False
                        ).last.wait_for(state="detached", timeout=5_000)
                        delete_ui = True
                    except Exception:
                        delete_ui = False
                    step("delete_ui", name_detached=delete_ui)
                    require(delete_ui, "upload name remained visible after delete")

                    storage_after: dict[str, Any] = {
                        "state": "api_error",
                        "error_category": "no_tracked_path",
                        "http_status": None,
                    }
                    if probe.tracked_storage_paths:
                        storage_after = probe.storage_object_state(
                            probe.tracked_storage_paths[0]
                        )
                    else:
                        discovered = probe.discover_under_document_prefix(
                            owner.user_id, document_id
                        )
                        if discovered.get("state") == "ok":
                            storage_after = {
                                "state": (
                                    "absent"
                                    if discovered.get("path_count", 0) == 0
                                    else "present"
                                ),
                                "http_status": discovered.get("http_status"),
                            }
                    step(
                        "delete_backend",
                        row_probe_state=final_probe.get("state"),
                        row_http_status=final_probe.get("http_status"),
                        storage_state=storage_after.get("state"),
                        storage_http_status=storage_after.get("http_status"),
                        browser_mutations=document_mutations[-6:],
                    )
                    direct_owner_delete: dict[str, Any] | None = None
                    if final_probe.get("state") != "absent":
                        owner_token = probe.user_token(owner.email, owner.password)
                        direct_status, direct_body, _ = fixtures.request(
                            "DELETE",
                            f"/rest/v1/documents?id=eq.{document_id}",
                            token=owner_token,
                            prefer="return=representation",
                        )
                        direct_owner_delete = {
                            "http_status": direct_status,
                            "returned_rows": (
                                len(json.loads(direct_body))
                                if direct_body and 200 <= direct_status < 300
                                else None
                            ),
                            "row_absent_after": (
                                probe.document_row_probe(document_id).get("state")
                                == "absent"
                            ),
                        }
                        step("direct_owner_delete_diagnostic", **direct_owner_delete)
                    require(
                        final_probe.get("state") == "absent"
                        and storage_after.get("state") == "absent",
                        "delete did not confirm row/storage absence "
                        f"(row={final_probe.get('state')}, "
                        f"storage={storage_after.get('state')})",
                    )

                    shot = artifacts / "diag-document-upload-delete.png"
                    await page.screenshot(path=shot, full_page=True)
                    step(
                        "screenshot",
                        written=shot.is_file(),
                        bytes=shot.stat().st_size if shot.is_file() else 0,
                    )
                    require(
                        shot.is_file() and shot.stat().st_size > 1000,
                        "screenshot missing or empty",
                    )

                    assertions_passed = True
                finally:
                    await context.close()
                    await browser.close()

    except BaseException as exc:
        report["result"] = "FAIL"
        report["exception"] = {
            "category": _error_category(exc),
            "type": type(exc).__name__,
            "message": _redact_message(str(exc)),
            "traceback_tail": _redact_message(traceback.format_exc()[-1200:]),
        }
        step(
            "exception",
            category=report["exception"]["category"],
            type=report["exception"]["type"],
        )
        assertions_passed = False
    finally:
        try:
            artifact_cleanup = probe.cleanup_test_artifacts()
        except Exception as exc:  # noqa: BLE001
            artifact_cleanup = {
                "ok": False,
                "error_category": _error_category(exc),
                "error_type": type(exc).__name__,
            }
        step(
            "artifact_cleanup",
            ok=artifact_cleanup.get("ok"),
            storage_ok=artifact_cleanup.get("storage_ok"),
            discovery_ok=artifact_cleanup.get("discovery_ok"),
            documents_ok=artifact_cleanup.get("documents_ok"),
            storage_targets=artifact_cleanup.get("storage_targets"),
            document_targets=artifact_cleanup.get("document_targets"),
            storage_attempts=artifact_cleanup.get("storage_attempts"),
            document_attempts=artifact_cleanup.get("document_attempts"),
        )

        auth_cleanup_ok = False
        try:
            fixtures.cleanup()
            auth_cleanup_ok = True
            step(
                "auth_cleanup",
                ok=True,
                identity_count=len(fixtures.identities),
            )
        except Exception as exc:  # noqa: BLE001
            step(
                "auth_cleanup",
                ok=False,
                category=_error_category(exc),
                type=type(exc).__name__,
            )
            report["cleanup_error"] = {
                "category": _error_category(exc),
                "type": type(exc).__name__,
            }

        cleanup_ok = bool(artifact_cleanup.get("ok")) and auth_cleanup_ok
        report["cleanup_ok"] = cleanup_ok
        step("cleanup_summary", cleanup_ok=cleanup_ok)

        if assertions_passed and cleanup_ok:
            report["result"] = "PASS"
        else:
            report["result"] = "FAIL"

        try:
            artifacts.mkdir(parents=True, exist_ok=True)
            out = artifacts / "diag-document-upload-delete.json"
            out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
            print(
                json.dumps(
                    {
                        "result": report["result"],
                        "cleanup_ok": report["cleanup_ok"],
                        "json": str(out),
                        "steps": len(report["steps"]),
                    },
                    indent=2,
                )
            )
        except Exception as exc:  # noqa: BLE001
            print(
                json.dumps(
                    {
                        "result": report.get("result", "FAIL"),
                        "json_write_error": type(exc).__name__,
                    }
                ),
                file=sys.stderr,
            )

    return report


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Loopback document upload/delete diagnostic with backend checks."
        )
    )
    parser.add_argument("--web-root", type=Path, default=Path("build/web"))
    parser.add_argument(
        "--artifacts",
        type=Path,
        default=Path("build/stage2-diag-documents"),
    )
    parser.add_argument("--port", type=int, default=3012)
    args = parser.parse_args()

    if not (args.web_root / "index.html").is_file():
        print(
            f"missing web build: {args.web_root / 'index.html'}",
            file=sys.stderr,
        )
        raise SystemExit(2)

    report = asyncio.run(_run(args.web_root, args.artifacts, args.port))
    if report.get("result") != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
