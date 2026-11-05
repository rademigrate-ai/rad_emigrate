#!/usr/bin/env python3
"""Real Flutter/Chromium journeys on an owned disposable backend.

Requires Playwright and a local Chromium executable. No intercepted APIs,
recorded Auth traces, hosted credentials, paid providers or live publication.
Generated fixture credentials stay in memory and never enter report output.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import secrets
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path
from uuid import UUID

sys.path.insert(0, str(Path(__file__).resolve().parent))

from self_host_stack import compose, run, sql
from self_host_test_target import load_target, target_root
from verify_self_host_document_deletion import PDF, call, require


def wait_for(check, timeout=40):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        if check():
            return
        time.sleep(0.5)
    raise AssertionError("persisted state did not reach the required condition")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-url", required=True)
    parser.add_argument("--browser", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--only-documents", action="store_true")
    args = parser.parse_args()
    web = urllib.parse.urlsplit(args.web_url)
    require(
        web.scheme == "http" and web.hostname in {"127.0.0.1", "localhost"},
        "loopback web origin",
    )
    repo = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    require(not output.is_relative_to(repo), "private evidence output outside Git")
    output.mkdir(parents=True, exist_ok=False)
    root = target_root()
    api, anon, service = load_target()
    seed = secrets.token_hex(6)
    email = "browser-" + seed + "@example.invalid"
    password = secrets.token_urlsafe(32)
    status, body = call(
        api + "/auth/v1/admin/users",
        "POST",
        {"email": email, "password": password, "email_confirm": True},
        apikey=service,
    )
    require(status == 200, "synthetic browser fixture creation")
    actor = str(UUID(json.loads(body)["id"]))
    report = {
        "scope": "REAL_FLUTTER_DEBUG_WEB_AND_DISPOSABLE_BACKEND",
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repo, text=True
        ).strip(),
        "results": [],
        "paid_provider_called": False,
        "production_touched": False,
    }
    from playwright.sync_api import sync_playwright

    def scalar(statement):
        return sql(root, statement.encode()).stdout.decode().strip()

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=str(args.browser), headless=True
        )
        context = browser.new_context(viewport={"width": 1440, "height": 1000})
        page = context.new_page()
        page.set_default_timeout(45000)

        def enable_semantics():
            page.locator(
                "flt-semantics-placeholder, flt-semantics-host flt-semantics"
            ).first.wait_for(state="attached", timeout=90000)
            placeholder = page.locator("flt-semantics-placeholder")
            if placeholder.count():
                placeholder.evaluate("(element) => element.click()")

        def visit(path):
            page.goto(args.web_url.rstrip("/") + path, wait_until="domcontentloaded")
            enable_semantics()

        def enter(label, value, clear=False):
            report["last_action"] = "type-" + label
            field = page.get_by_role("textbox", name=label, exact=True)
            field.click()
            if clear:
                page.keyboard.press("ControlOrMeta+A")
                page.keyboard.press("Backspace")
            # Flutter's semantic proxy inputs need real keyboard events, not
            # DOM value assignment through fill().
            field.press_sequentially(value, delay=20)

        def shot(name):
            page.screenshot(path=str(output / (name + ".png")))

        def step(name, action):
            start = time.monotonic()
            try:
                action()
                result = {"scenario": name, "status": "PASS"}
            except Exception as error:
                # Playwright assertion messages may include input values.
                # Store only the exception class, never Auth snapshots/traces.
                result = {
                    "scenario": name,
                    "status": "FAIL",
                    "error_class": type(error).__name__,
                }
                if "/login" not in page.url and "/register" not in page.url:
                    shot("failed-" + name)
            result["seconds"] = round(time.monotonic() - start, 3)
            report["results"].append(result)
            (output / "web_results.json").write_bytes(
                json.dumps(report, indent=2).encode()
            )
            print(result["status"] + " " + name, flush=True)
            return result["status"] == "PASS"

        def login():
            visit("/login")
            enter("Email", email)
            enter("Password", password)
            report["last_action"] = "submit-login"
            page.get_by_role("button", name="Sign in", exact=True).click()
            page.wait_for_url(lambda address: "/dashboard" in address)
            page.get_by_role(
                "button", name="Documents Documents", exact=True
            ).wait_for()
            shot("dashboard-en-desktop")

        if not step("login-and-dashboard", login):
            browser.close()
            raise SystemExit(1)

        def restore():
            visit("/dashboard")
            page.get_by_role(
                "button", name="Documents Documents", exact=True
            ).wait_for()
            require(
                "/login" not in page.url, "browser refresh restores normal Auth session"
            )

        step("browser-refresh-session-restoration", restore)

        def profile():
            visit("/profile")
            page.get_by_role("button", name="Edit profile", exact=True).click()
            enter("First name", "Browser " + seed, clear=True)
            enter("Last name", "Traveler", clear=True)
            page.get_by_role("button", name="Save", exact=True).click()
            wait_for(
                lambda: (
                    scalar(f"select full_name from public.profiles where id='{actor}';")
                    == "Browser " + seed + " Traveler"
                )
            )
            shot("profile-saved-en-desktop")

        step("profile-edit-persistence", profile)

        def consultation():
            visit("/consultation")
            enter("Topic", "Synthetic " + seed)
            enter("Message", "Synthetic integration request; no immigration advice.")
            page.get_by_role("button", name="Submit request", exact=True).click()
            wait_for(
                lambda: (
                    scalar(
                        f"select count(*) from public.consultation_requests where user_id='{actor}' and topic='Synthetic {seed}';"
                    )
                    == "1"
                )
            )
            shot("consultation-persisted-en-desktop")

        if not args.only_documents:
            step("consultation-persistence", consultation)

        def application():
            visit("/applications")
            page.get_by_role("button", name="New draft", exact=True).first.click()
            wait_for(
                lambda: (
                    scalar(
                        f"select count(*) from public.applications where user_id='{actor}';"
                    )
                    == "1"
                )
            )
            shot("application-persisted-en-desktop")

        if not args.only_documents:
            step("application-creation-persistence", application)

        def upload():
            visit("/documents")
            page.get_by_role("button", name="Add type", exact=True).click()
            page.get_by_role("button", name=re.compile(r"^New document\b")).click()
            with page.expect_file_chooser() as selected:
                page.get_by_role(
                    "button", name="Choose file and upload", exact=True
                ).click()
            selected.value.set_files(
                {
                    "name": "synthetic-" + seed + ".pdf",
                    "mimeType": "application/pdf",
                    "buffer": PDF,
                }
            )
            wait_for(
                lambda: (
                    scalar(
                        f"select count(*) from public.documents where user_id='{actor}' and file_path is not null;"
                    )
                    == "1"
                )
            )
            page.get_by_role(
                "button", name=re.compile(re.escape("synthetic-" + seed + ".pdf"))
            ).wait_for()
            shot("document-uploaded-en-desktop")

        uploaded = step("document-upload-persistence", upload)

        if uploaded:

            def preview():
                page.get_by_role(
                    "button", name=re.compile(re.escape("synthetic-" + seed + ".pdf"))
                ).click()
                with context.expect_page() as opened:
                    page.get_by_role("button", name="Open file", exact=True).click()
                popup = opened.value
                popup.wait_for_url(
                    lambda address: "/storage/v1/object/sign/" in address, timeout=30000
                )
                status, content = call(popup.url, apikey=anon)
                require(
                    status == 200
                    and hashlib.sha256(content).digest()
                    == hashlib.sha256(PDF).digest(),
                    "real private preview bytes",
                )
                popup.close()
                page.bring_to_front()

            step("document-preview", preview)

            def deletion():
                if not page.get_by_role(
                    "button", name="Delete document", exact=True
                ).count():
                    page.get_by_role(
                        "button",
                        name=re.compile(re.escape("synthetic-" + seed + ".pdf")),
                    ).click()
                page.get_by_role("button", name="Delete document", exact=True).click()
                page.get_by_role("button", name="Delete", exact=True).click()
                page.get_by_text(
                    "Deletion requested. File removal is pending.", exact=False
                ).wait_for()
                require(
                    scalar(
                        f"select status from public.documents where user_id='{actor}';"
                    )
                    == "pending_deletion",
                    "accepted request is not physical deletion",
                )
                shot("document-deletion-pending-en-desktop")
                # Inject a real service outage only on this owned disposable
                # stack. The queue and normal user identity remain untouched.
                run(compose(root, "stop", "storage"))
                try:
                    status, _ = call(
                        api + "/functions/v1/document-deletion",
                        "POST",
                        {},
                        apikey=service,
                    )
                    require(status >= 400, "real worker failure is observable")
                    page.get_by_text(
                        "File removal failed. The server will retry.", exact=False
                    ).wait_for(timeout=20000)
                    shot("document-deletion-retrying-en-desktop")
                finally:
                    run(compose(root, "up", "-d", "storage"))
                wait_for(
                    lambda: call(api + "/storage/v1/status", apikey=service)[0] == 200,
                    timeout=60,
                )
                status, body = call(
                    api + "/functions/v1/document-deletion", "POST", {}, apikey=service
                )
                require(
                    status == 200 and json.loads(body).get("state") == "finalized",
                    "real worker retry finalizes",
                )
                page.get_by_text(
                    "File removed. Deletion receipt saved.", exact=False
                ).wait_for(timeout=20000)
                require(
                    scalar(
                        f"select count(*) from public.documents where user_id='{actor}';"
                    )
                    == "0",
                    "physical removal finalizes row",
                )
                require(
                    scalar(
                        f"select count(*) from public.document_deletion_receipts where owner_id='{actor}';"
                    )
                    == "1",
                    "receipt persisted",
                )
                shot("document-deletion-completed-en-desktop")

            step("document-pending-failure-retry-completion", deletion)

        def nonadmin():
            visit("/admin")
            page.get_by_role("group").filter(
                has_text="Administrator access is required."
            ).wait_for()
            require(
                page.get_by_role("button", name="AI configuration", exact=True).count()
                == 0,
                "privileged controls must not be mounted for a normal user",
            )

        step("nonadmin-protected-route", nonadmin)
        report["fixtures_retained_on_owned_stack"] = True
        browser.close()
    report["passed"] = sum(r["status"] == "PASS" for r in report["results"])
    report["total"] = len(report["results"])
    (output / "web_results.json").write_bytes(json.dumps(report, indent=2).encode())
    raise SystemExit(0 if report["passed"] == report["total"] else 1)


if __name__ == "__main__":
    main()
