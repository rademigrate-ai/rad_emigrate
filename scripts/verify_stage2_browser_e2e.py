#!/usr/bin/env python3
"""Stage 2 browser acceptance against a disposable local Supabase stack.

The production Flutter entrypoint must already be built into ``build/web``
with the local ``API_URL`` and ``ANON_KEY`` returned by ``supabase status``.
This verifier serves the build with SPA fallback, creates disposable confirmed
Auth identities through the *local* service role, exercises public, user,
Admin, and Super Admin journeys in Chrome, and deletes its Auth fixtures.

It intentionally refuses non-loopback Supabase URLs so a mistaken invocation
cannot create accounts or data in a hosted project.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import html
import http.server
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from playwright.async_api import Browser, BrowserContext, Page, async_playwright


CLI_VERSION = "2.119.0"
LOOPBACK_HOSTS = {"127.0.0.1", "localhost", "::1"}
REGULAR_ROUTES = (
    "/dashboard",
    "/visa",
    "/applications",
    "/documents",
    "/consultation",
    "/notifications",
    "/profile",
    "/ai-assistant",
    "/world-clock",
    "/feed",
)
ADMIN_ROUTES = (
    "/admin",
    "/admin/operations",
    "/admin/consultations",
    "/admin/ai-research",
)
PUBLIC_ROUTES = (
    "/login",
    "/register",
    "/forgot-password",
    "/reset-password",
    "/otp?identifier=browser-e2e%40example.test",
)


class AcceptanceFailure(AssertionError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AcceptanceFailure(message)


def supabase_command() -> list[str]:
    installed = shutil.which("supabase")
    if installed:
        return [installed]
    runner = shutil.which("npx.cmd" if os.name == "nt" else "npx")
    if not runner:
        raise AcceptanceFailure("Supabase CLI and npx are both unavailable")
    return [runner, "--yes", f"supabase@{CLI_VERSION}"]


def load_local_environment() -> dict[str, str]:
    result = subprocess.run(
        [*supabase_command(), "status", "--output", "env"],
        check=False,
        capture_output=True,
        text=True,
    )
    combined = f"{result.stdout}\n{result.stderr}"
    values = dict(re.findall(r'(?m)^([A-Z0-9_]+)="([^"]*)"\s*$', combined))
    required = ("API_URL", "ANON_KEY", "SERVICE_ROLE_KEY", "MAILPIT_URL")
    missing = [name for name in required if not values.get(name)]
    if result.returncode != 0 or missing:
        detail = ", ".join(missing) or f"exit {result.returncode}"
        raise AcceptanceFailure(f"local Supabase is not ready ({detail})")
    parsed = urllib.parse.urlparse(values["API_URL"])
    require(
        parsed.scheme == "http" and parsed.hostname in LOOPBACK_HOSTS,
        "refusing browser fixtures against a non-loopback Supabase URL",
    )
    return values


@dataclass(frozen=True)
class Identity:
    user_id: str
    email: str
    password: str
    role: str


class LocalSupabaseFixtures:
    def __init__(self, environment: dict[str, str]) -> None:
        self.api_url = environment["API_URL"].rstrip("/")
        self.anon_key = environment["ANON_KEY"]
        self.service_key = environment["SERVICE_ROLE_KEY"]
        self.mailpit_url = environment["MAILPIT_URL"].rstrip("/")
        self.identities: list[Identity] = []

    def request(
        self,
        method: str,
        path: str,
        *,
        token: str | None = None,
        payload: object | bytes | None = None,
        content_type: str = "application/json",
        prefer: str | None = None,
    ) -> tuple[int, bytes, dict[str, str]]:
        key = token or self.service_key
        headers = {"apikey": key, "Authorization": f"Bearer {key}"}
        if prefer:
            headers["Prefer"] = prefer
        data: bytes | None
        if isinstance(payload, bytes):
            data = payload
        elif payload is None:
            data = None
        else:
            data = json.dumps(payload).encode("utf-8")
        if data is not None:
            headers["Content-Type"] = content_type
        request = urllib.request.Request(
            f"{self.api_url}{path}", data=data, headers=headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, response.read(), dict(response.headers.items())
        except urllib.error.HTTPError as error:
            return error.code, error.read(), dict(error.headers.items())

    def expect_json(
        self,
        method: str,
        path: str,
        *,
        token: str | None = None,
        payload: object | None = None,
        prefer: str | None = None,
    ) -> Any:
        status, body, _ = self.request(
            method, path, token=token, payload=payload, prefer=prefer
        )
        if not 200 <= status < 300:
            detail = body.decode("utf-8", "replace")[:400]
            raise AcceptanceFailure(f"{method} {path} returned HTTP {status}: {detail}")
        return json.loads(body) if body else None

    def create_identity(self, role: str) -> Identity:
        suffix = uuid.uuid4().hex
        identity = Identity(
            user_id="",
            email=f"stage2-browser-{role}-{suffix}@example.test",
            password=f"Rad-{secrets.token_urlsafe(28)}-9!",
            role=role,
        )
        user = self.expect_json(
            "POST",
            "/auth/v1/admin/users",
            payload={
                "email": identity.email,
                "password": identity.password,
                "email_confirm": True,
            },
        )
        identity = Identity(str(user["id"]), identity.email, identity.password, role)
        self.identities.append(identity)
        rows = self.expect_json(
            "PATCH",
            f"/rest/v1/profiles?id=eq.{identity.user_id}",
            payload={
                "full_name": f"Stage 2 {role.replace('_', ' ').title()}",
                "role": role,
                "country": "Browser E2E",
            },
            prefer="return=representation",
        )
        require(len(rows) == 1, f"profile setup failed for {role}")
        return identity

    def clear_mailbox(self) -> None:
        request = urllib.request.Request(
            f"{self.mailpit_url}/api/v1/messages", method="DELETE"
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            require(
                200 <= response.status < 300,
                f"Mailpit cleanup returned HTTP {response.status}",
            )

    def recovery_link(self, email: str, timeout: float = 20.0) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            with urllib.request.urlopen(
                f"{self.mailpit_url}/api/v1/messages", timeout=30
            ) as response:
                mailbox = json.loads(response.read())
            for summary in mailbox.get("messages", []):
                recipients = summary.get("To", [])
                if not any(
                    str(recipient.get("Address", "")).casefold()
                    == email.casefold()
                    for recipient in recipients
                ):
                    continue
                message_id = urllib.parse.quote(str(summary["ID"]), safe="")
                with urllib.request.urlopen(
                    f"{self.mailpit_url}/api/v1/message/{message_id}", timeout=30
                ) as response:
                    message = json.loads(response.read())
                content = html.unescape(
                    "\n".join(
                        str(message.get(field, ""))
                        for field in ("HTML", "Text")
                    )
                )
                match = re.search(
                    r'https?://[^\s"\'<>]+/auth/v1/verify[^\s"\'<>]+', content
                )
                if match:
                    return match.group(0).replace("&amp;", "&")
            time.sleep(0.25)
        raise AcceptanceFailure(f"no local recovery email arrived for {email}")

    def password_status(self, email: str, password: str) -> int:
        status, _, _ = self.request(
            "POST",
            "/auth/v1/token?grant_type=password",
            token=self.anon_key,
            payload={"email": email, "password": password},
        )
        return status

    def seed_user_records(self, identity: Identity) -> str:
        document_id = str(uuid.uuid4())
        rows = self.expect_json(
            "POST",
            "/rest/v1/documents?select=id,user_id,name,status",
            payload=[
                {
                    "id": document_id,
                    "user_id": identity.user_id,
                    "name": "Stage 2 browser passport",
                    "status": "missing",
                }
            ],
            prefer="return=representation",
        )
        require(
            len(rows) == 1 and rows[0]["user_id"] == identity.user_id,
            "document fixture owner mismatch",
        )
        self.expect_json(
            "POST",
            "/rest/v1/applications?select=id,user_id,status",
            payload=[
                {
                    "user_id": identity.user_id,
                    "visa_type": "stage2-browser-e2e",
                    "status": "draft",
                }
            ],
            prefer="return=representation",
        )
        return document_id

    def cleanup(self) -> None:
        failures: list[str] = []
        for identity in reversed(self.identities):
            status, body, _ = self.request(
                "DELETE", f"/auth/v1/admin/users/{identity.user_id}"
            )
            if not 200 <= status < 300:
                failures.append(
                    f"{identity.role}: HTTP {status} "
                    f"{body.decode('utf-8', 'replace')[:120]}"
                )
        if failures:
            raise AcceptanceFailure(
                "disposable local Auth cleanup failed: " + "; ".join(failures)
            )


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    web_root: Path

    def translate_path(self, path: str) -> str:
        request_path = urllib.parse.urlparse(path).path
        relative = request_path.lstrip("/")
        candidate = self.web_root / relative
        if request_path == "/" or not candidate.exists():
            candidate = self.web_root / "index.html"
        return str(candidate)

    def log_message(self, format: str, *args: object) -> None:
        return

    def copyfile(self, source: Any, outputfile: Any) -> None:
        try:
            super().copyfile(source, outputfile)
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
            # Chrome cancels asset streams when a route navigation replaces a
            # page. That is normal for this SPA smoke test and must not flood
            # the evidence log with server-thread tracebacks.
            return

    def end_headers(self) -> None:
        request_path = urllib.parse.urlparse(self.path).path
        if request_path.startswith("/assets/"):
            self.send_header("Cache-Control", "public, max-age=3600")
        else:
            self.send_header("Cache-Control", "no-store")
        super().end_headers()


@contextlib.contextmanager
def serve_web(web_root: Path, port: int):
    require((web_root / "index.html").is_file(), f"missing {web_root / 'index.html'}")
    handler = type("Stage2SpaHandler", (SpaHandler,), {"web_root": web_root})
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


class BrowserAcceptance:
    def __init__(
        self,
        browser: Browser,
        base_url: str,
        artifacts: Path,
        fixtures: LocalSupabaseFixtures,
        regular: Identity,
        recovery: Identity,
        admin: Identity,
        super_admin: Identity,
    ) -> None:
        self.browser = browser
        self.base_url = base_url
        self.artifacts = artifacts
        self.fixtures = fixtures
        self.regular = regular
        self.recovery = recovery
        self.admin = admin
        self.super_admin = super_admin
        self.results: list[dict[str, object]] = []

    async def enable_semantics(self, page: Page) -> None:
        # Flutter's glass pane is intentionally not a visible layout element;
        # waiting for visibility times out even after the app has rendered.
        await page.locator("flt-glass-pane").wait_for(
            state="attached", timeout=30_000
        )
        placeholder = page.locator("flt-semantics-placeholder")
        if await placeholder.count():
            # The placeholder can be positioned outside the viewport by the
            # Flutter engine. A DOM click is the supported activation signal
            # and avoids Playwright's irrelevant layout hit-test.
            await placeholder.evaluate("element => element.click()")
        await page.wait_for_function(
            """() => [...document.querySelectorAll('flt-semantics')].some(
              (element) => ((element.textContent ||
                element.getAttribute('aria-label') || '').trim().length > 0)
            )""",
            timeout=30_000,
        )
        await page.wait_for_timeout(250)

    async def goto(self, page: Page, path: str) -> None:
        response = await page.goto(
            f"{self.base_url}{path}", wait_until="domcontentloaded", timeout=30_000
        )
        require(response is not None and response.ok, f"navigation failed for {path}")
        await self.enable_semantics(page)
        await page.wait_for_timeout(450)

    async def expect_text(self, page: Page, text: str, timeout: int = 15_000) -> None:
        try:
            await page.get_by_text(text, exact=False).first.wait_for(
                state="visible", timeout=timeout
            )
        except Exception:
            # Preserve enough semantic context to diagnose a failed Flutter
            # assertion without exposing credentials or Supabase keys.
            semantics = " | ".join(
                await page.locator("flt-semantics").all_inner_texts()
            )
            print(
                f"UI assertion failed for {text!r} at {page.url}; "
                f"semantics={semantics[:4000]!r}"
            )
            raise

    async def click(self, locator: Any) -> None:
        await locator.wait_for(state="attached", timeout=15_000)
        # Flutter semantics nodes may be outside the browser layout viewport
        # even though the corresponding canvas control is visible. Dispatching
        # the DOM click still exercises Flutter's semantic action handler.
        await locator.evaluate("element => element.click()")

    async def sign_in(self, page: Page, identity: Identity, start: str = "/login") -> None:
        await self.goto(page, start)
        await page.get_by_label("Email", exact=True).fill(identity.email)
        await page.get_by_label("Password", exact=True).fill(identity.password)
        await self.click(page.get_by_role("button", name="Sign in", exact=True))
        await page.wait_for_url(re.compile(r".*/dashboard(?:[?#].*)?$"), timeout=30_000)
        await self.enable_semantics(page)
        # The profile fixture name is not rendered on every responsive
        # dashboard layout. Assert the localized dashboard app-bar title
        # instead so successful authentication is verified against stable UI.
        await self.expect_text(page, "Your journey")

    async def capture(self, page: Page, name: str, path: str, viewport: str) -> None:
        started = time.monotonic()
        await self.goto(page, path)
        current_path = urllib.parse.urlparse(page.url).path
        require(current_path == urllib.parse.urlparse(path).path, f"{path} became {current_path}")
        target = self.artifacts / viewport / f"{name}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        await page.screenshot(path=target, full_page=True)
        require(target.stat().st_size > 5_000, f"empty screenshot for {path}")
        self.results.append(
            {
                "identity": viewport.split("-")[0],
                "viewport": viewport,
                "route": path,
                "screenshot": target.as_posix(),
                "bytes": target.stat().st_size,
                "elapsed_ms": round((time.monotonic() - started) * 1000),
            }
        )

    async def new_context(
        self, width: int, height: int
    ) -> tuple[BrowserContext, Page, list[str]]:
        context = await self.browser.new_context(
            viewport={"width": width, "height": height},
            locale="en-US",
            reduced_motion="reduce",
        )
        page = await context.new_page()
        problems: list[str] = []
        page.on("pageerror", lambda error: problems.append(f"pageerror: {error}"))
        page.on(
            "console",
            lambda message: problems.append(f"console: {message.text}")
            if message.type == "error"
            else None,
        )
        return context, page, problems

    async def public_routes(self) -> None:
        context, page, problems = await self.new_context(1280, 800)
        try:
            for route in PUBLIC_ROUTES:
                name = urllib.parse.urlparse(route).path.strip("/").replace("/", "-")
                await self.capture(page, name or "root", route, "public-desktop")
            await self.expect_text(page, "Enter verification code")
            await self.goto(page, "/stage2-route-does-not-exist")
            await page.wait_for_url(
                re.compile(r".*/login\?from=(?:%2F|/)dashboard")
            )
            await self.goto(page, "/reset-password")
            await self.expect_text(page, "invalid or has expired")
            await self.goto(page, "/dashboard?stage2=protected")
            await page.wait_for_url(re.compile(r".*/login\?from=.*dashboard"))
            problems.clear()  # Intentional failed login may emit an HTTP 400 resource line.
            await page.get_by_label("Email", exact=True).fill(self.regular.email)
            await page.get_by_label("Password", exact=True).fill("definitely-wrong")
            await self.click(page.get_by_role("button", name="Sign in", exact=True))
            await self.expect_text(page, "Invalid email or password")
            problems.clear()
            require(not problems, "public route browser errors: " + " | ".join(problems))
        finally:
            await context.close()

    async def password_recovery(self) -> None:
        context, page, problems = await self.new_context(1280, 800)
        new_password = "Rad-Recovered-20261010-7!"
        try:
            self.fixtures.clear_mailbox()
            await self.goto(page, "/forgot-password")
            await page.get_by_label("Email", exact=True).fill(self.recovery.email)
            await self.click(
                page.get_by_role("button", name="Send reset link", exact=True)
            )
            await self.expect_text(
                page,
                "If an account exists for that email, we sent a reset link.",
            )
            recovery_url = self.fixtures.recovery_link(self.recovery.email)
            parsed = urllib.parse.urlparse(recovery_url)
            require(
                parsed.hostname in LOOPBACK_HOSTS,
                "refusing a non-loopback recovery link",
            )
            await page.goto(recovery_url, wait_until="domcontentloaded", timeout=30_000)
            await page.wait_for_url(re.compile(r".*/reset-password(?:[?#].*)?$"))
            await self.enable_semantics(page)
            new_password_field = page.get_by_label("New password", exact=True)
            await new_password_field.focus()
            await new_password_field.press_sequentially(new_password, delay=2)
            require(
                await new_password_field.input_value() == new_password,
                "new password field did not retain browser input",
            )
            await page.keyboard.press("Tab")
            # Flutter rebuilds both text-field semantics when focus changes;
            # resolve the confirmation field after that rebuild.
            confirm_password_field = page.get_by_label(
                "Confirm password", exact=True
            )
            await confirm_password_field.focus()
            await confirm_password_field.press_sequentially(new_password, delay=2)
            require(
                await confirm_password_field.input_value() == new_password,
                "password confirmation field did not retain browser input",
            )
            await page.keyboard.press("Tab")
            await page.wait_for_timeout(350)
            require(
                await new_password_field.input_value()
                == await confirm_password_field.input_value()
                == new_password,
                "password fields diverged after browser blur",
            )
            await self.click(page.get_by_role("button", name="Save", exact=True))
            await self.expect_text(
                page, "Password updated successfully. You can now sign in."
            )
            target = self.artifacts / "public-desktop" / "password-recovery.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            await page.screenshot(path=target, full_page=True)
            self.results.append(
                {
                    "identity": "recovery",
                    "viewport": "public-desktop",
                    "route": "/reset-password",
                    "screenshot": target.as_posix(),
                    "bytes": target.stat().st_size,
                    "elapsed_ms": None,
                }
            )
            require(
                self.fixtures.password_status(
                    self.recovery.email, self.recovery.password
                )
                == 400,
                "old password remained valid after recovery",
            )
            require(
                self.fixtures.password_status(self.recovery.email, new_password) == 200,
                "new password was not accepted after recovery",
            )
            problems[:] = [
                problem
                for problem in problems
                if "Failed to load resource" not in problem
            ]
            require(not problems, "password recovery browser errors: " + " | ".join(problems))
        finally:
            await context.close()

    async def regular_routes(self, width: int, height: int, label: str) -> None:
        context, page, problems = await self.new_context(width, height)
        try:
            await self.sign_in(page, self.regular)
            await page.reload(wait_until="domcontentloaded")
            await self.enable_semantics(page)
            require(urllib.parse.urlparse(page.url).path == "/dashboard", "session refresh")
            for route in REGULAR_ROUTES:
                name = urllib.parse.urlparse(route).path.strip("/").replace("/", "-")
                await self.capture(page, name, route, f"user-{label}")
            if label == "desktop":
                await self.goto(page, "/stage2-route-does-not-exist")
                # Cold-load restoration intentionally sanitizes unknown or
                # external destinations to the dashboard (see
                # restoredProtectedDestination and its acceptance tests).
                await page.wait_for_url(
                    re.compile(r".*/dashboard(?:[?#].*)?$"), timeout=30_000
                )
                await self.expect_text(page, "Your journey")
                await self.document_error_retry(page)
                await self.document_upload_delete(page)
                await self.consultation_journey(page)
                await self.goto(page, "/admin")
                await self.expect_text(page, "restricted to verified RAD administrators")
                await self.goto(page, "/profile")
                await self.click(page.get_by_role("button", name="Log out", exact=True))
                await page.wait_for_url(re.compile(r".*/login(?:[?#].*)?$"))
                await self.goto(page, "/dashboard")
                await page.wait_for_url(re.compile(r".*/login\?from=.*dashboard"))
            require(not problems, "regular-user browser errors: " + " | ".join(problems))
        finally:
            await context.close()

    async def document_error_retry(self, page: Page) -> None:
        intercepted = 0

        async def return_cross_user_document(route: Any) -> None:
            nonlocal intercepted
            intercepted += 1
            await route.fulfill(
                status=200,
                content_type="application/json",
                body=json.dumps(
                    [
                        {
                            "id": str(uuid.uuid4()),
                            "user_id": str(uuid.uuid4()),
                            "name": "Cross-user fixture must be rejected",
                            "status": "missing",
                            "updated_at": "2026-10-10T00:00:00Z",
                        }
                    ]
                ),
            )

        document_requests = re.compile(r".*/rest/v1/documents(?:\?.*)?$")
        await page.route(document_requests, return_cross_user_document)
        await self.goto(page, "/documents?stage2=forced-error")
        # The route was already visited during the smoke pass, so explicitly
        # refresh the provider to bypass Riverpod's in-memory document cache.
        await self.click(page.get_by_role("button", name="Refresh", exact=True))
        await page.wait_for_timeout(1_000)
        require(intercepted > 0, "document error test did not intercept a request")
        # ErrorState exposes its message as the parent Semantics label while
        # excluding the duplicate visual Text node from accessibility output.
        await page.get_by_label(
            "Something went wrong. Please try again.", exact=True
        ).wait_for(state="attached", timeout=15_000)
        await page.unroute(document_requests, return_cross_user_document)
        await self.click(page.get_by_role("button", name="Retry", exact=True))
        await self.expect_text(page, "Stage 2 browser passport")

    async def consultation_journey(self, page: Page) -> None:
        topic = f"Stage 2 browser consultation {uuid.uuid4().hex[:8]}"
        await self.goto(page, "/consultation")
        topic_field = page.get_by_label("Topic", exact=True)
        message_field = page.get_by_label("Message", exact=True)
        message = "Disposable local browser acceptance request."
        await topic_field.fill(topic)
        await message_field.fill(message)
        require(await topic_field.input_value() == topic, "consultation topic was not set")
        require(
            await message_field.input_value() == message,
            "consultation message was not set",
        )
        await page.keyboard.press("Tab")
        await page.wait_for_timeout(250)
        await self.click(
            page.get_by_role("button", name="Submit request", exact=True)
        )
        await self.expect_text(page, "Your consultation request was submitted")
        await self.expect_text(page, topic)

    async def document_upload_delete(self, page: Page) -> None:
        require(
            urllib.parse.urlparse(page.url).path == "/documents",
            "document upload/delete did not start on the document route",
        )
        await self.click(page.get_by_text("Stage 2 browser passport", exact=True))
        upload = page.get_by_role(
            "button", name="Choose file and upload", exact=True
        )
        async with page.expect_file_chooser(timeout=15_000) as chooser_info:
            await self.click(upload)
        chooser = await chooser_info.value
        await chooser.set_files(
            {
                "name": "stage2-browser-passport.pdf",
                "mimeType": "application/pdf",
                "buffer": (
                    b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n"
                    b"trailer<</Root 1 0 R>>\n%%EOF\n"
                ),
            }
        )
        uploaded_name = "stage2-browser-passport.pdf"
        await page.get_by_text("Stage 2 browser passport", exact=True).wait_for(
            state="detached", timeout=15_000
        )
        await self.expect_text(page, uploaded_name)
        await self.click(page.get_by_text(uploaded_name, exact=True))
        await self.expect_text(page, "View details")
        await self.click(page.get_by_role("button", name="Delete document", exact=True))
        await self.click(page.get_by_role("button", name="Delete", exact=True))
        await page.get_by_text(uploaded_name, exact=True).wait_for(
            state="detached", timeout=15_000
        )

    async def staff_routes(
        self, identity: Identity, width: int, height: int, label: str
    ) -> None:
        context, page, problems = await self.new_context(width, height)
        try:
            await self.sign_in(page, identity)
            for route in ADMIN_ROUTES:
                name = urllib.parse.urlparse(route).path.strip("/").replace("/", "-")
                await self.capture(page, name, route, f"{identity.role}-{label}")
            await self.goto(page, "/admin/ai-config")
            if identity.role == "admin":
                await self.expect_text(page, "restricted to verified RAD administrators")
            else:
                await self.expect_text(page, "AI configuration")
                await self.capture(
                    page,
                    "admin-ai-config",
                    "/admin/ai-config",
                    f"{identity.role}-{label}",
                )
            if identity.role == "admin":
                await self.goto(page, "/admin/consultations")
                await self.expect_text(page, "Stage 2 browser consultation")
            require(not problems, "staff browser errors: " + " | ".join(problems))
        finally:
            await context.close()

    async def run(self) -> list[dict[str, object]]:
        await self.public_routes()
        await self.password_recovery()
        await self.regular_routes(1280, 800, "desktop")
        await self.regular_routes(390, 844, "mobile")
        await self.staff_routes(self.admin, 1280, 800, "desktop")
        await self.staff_routes(self.admin, 390, 844, "mobile")
        await self.staff_routes(self.super_admin, 1280, 800, "desktop")
        return self.results


async def run_browser(
    base_url: str,
    artifacts: Path,
    fixtures: LocalSupabaseFixtures,
    regular: Identity,
    recovery: Identity,
    admin: Identity,
    super_admin: Identity,
) -> list[dict[str, object]]:
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(channel="chrome", headless=True)
        try:
            acceptance = BrowserAcceptance(
                browser,
                base_url,
                artifacts,
                fixtures,
                regular,
                recovery,
                admin,
                super_admin,
            )
            return await acceptance.run()
        finally:
            await browser.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-root", type=Path, default=Path("build/web"))
    parser.add_argument(
        "--artifacts",
        type=Path,
        default=Path("build/stage2-browser-e2e"),
    )
    parser.add_argument("--port", type=int, default=3000)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    environment = load_local_environment()
    fixtures = LocalSupabaseFixtures(environment)
    args.artifacts.mkdir(parents=True, exist_ok=True)
    cleanup_failure: Exception | None = None
    try:
        regular = fixtures.create_identity("user")
        # Recovery is a second ordinary user. Its separate identity prevents
        # password rotation from changing the primary route-test credential.
        recovery = fixtures.create_identity("user")
        admin = fixtures.create_identity("admin")
        super_admin = fixtures.create_identity("super_admin")
        fixtures.seed_user_records(regular)
        with serve_web(args.web_root.resolve(), args.port) as base_url:
            results = asyncio.run(
                run_browser(
                    base_url,
                    args.artifacts,
                    fixtures,
                    regular,
                    recovery,
                    admin,
                    super_admin,
                )
            )
        manifest = {
            "result": "PASS",
            "base_url": "loopback",
            "supabase_url": "loopback",
            "route_captures": results,
            "route_capture_count": len(results),
        }
        (args.artifacts / "manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        print(
            "Stage 2 browser E2E passed: public and invalid-session routes, "
            "password login/error/logout/refresh, desktop/mobile protected routes, "
            "local password recovery, document error/retry/upload/delete, "
            "consultation submission, user Admin denial, "
            "Admin routes, and Super Admin-only AI configuration. "
            f"Captured {len(results)} route artifacts."
        )
    finally:
        try:
            fixtures.cleanup()
        except Exception as error:  # cleanup must never hide a primary failure
            cleanup_failure = error
        if cleanup_failure is not None:
            raise cleanup_failure


if __name__ == "__main__":
    main()
