#!/usr/bin/env python3
"""Real Flutter/Chromium journeys on an owned disposable backend.

Requires Playwright and a local Chromium executable. No intercepted APIs,
recorded Auth traces, hosted credentials, paid providers or live publication.
Generated fixture credentials stay in memory and never enter report output.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import secrets
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from uuid import UUID

sys.path.insert(0, str(Path(__file__).resolve().parent))

from self_host_stack import compose, run, sql
from self_host_test_target import load_target, target_root
from verify_self_host_document_deletion import PDF, call, make_user, require


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
    parser.add_argument("--ui-matrix", action="store_true")
    parser.add_argument("--admin-flow", action="store_true")
    parser.add_argument("--build-mode", choices=("debug", "release"), default="debug")
    parser.add_argument("--matrix-only", action="store_true")
    parser.add_argument("--require-cache-revalidation", action="store_true")
    parser.add_argument("--recovery-flow", action="store_true")
    args = parser.parse_args()
    if args.matrix_only:
        args.only_documents = True
        args.ui_matrix = True
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
    status, health_body = call(
        api + "/rest/v1/rpc/document_deletion_queue_health", "POST", {}, apikey=service
    )
    require(
        status == 200 and json.loads(health_body).get("pending") == 0,
        "browser worker test requires an empty queue; recover existing authorized jobs first",
    )
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
    package_manifest = repo / "DELIVERY_MANIFEST.json"
    source_head = (
        json.loads(package_manifest.read_text("utf8"))["commit"]
        if package_manifest.exists()
        else subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repo, text=True
        ).strip()
    )
    report = {
        "scope": "REAL_FLUTTER_WEB_AND_DISPOSABLE_BACKEND",
        "build_mode": args.build_mode,
        "head": source_head,
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
        layout_errors = []
        page.on(
            "console",
            lambda message: (
                layout_errors.append("render_overflow")
                if "A RenderFlex overflowed" in message.text
                else None
            ),
        )

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

        def semantic_label(label):
            return page.locator(
                "flt-semantics[aria-label*="
                + json.dumps(label, ensure_ascii=False)
                + "]"
            ).first

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
                if type(error) is AssertionError:
                    # require() labels below are fixed strings, never input
                    # values or Playwright assertion messages.
                    result["failed_check"] = str(error)[:200]
                if not any(
                    path in page.url
                    for path in (
                        "/login",
                        "/register",
                        "/reset-password",
                        "/forgot-password",
                    )
                ):
                    shot("failed-" + name)
                if name.startswith(
                    ("documents-en-", "documents-fa-", "switch-language")
                ):
                    (output / (name + ".aria.txt")).write_text(
                        page.locator("flt-semantics-host").aria_snapshot(),
                        encoding="utf8",
                    )
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

        def conversation_history():
            status, body = call(
                api + "/auth/v1/token?grant_type=password",
                "POST",
                {"email": email, "password": password},
                apikey=anon,
            )
            require(status == 200, "normal conversation owner login")
            owner_token = json.loads(body)["access_token"]
            status, body = call(
                api + "/rest/v1/ai_sessions?select=id",
                "POST",
                {
                    "user_id": actor,
                    "scope": "user",
                    "title": "SYNTHETIC history " + seed,
                },
                token=owner_token,
                apikey=anon,
            )
            require(
                status == 201, "normal owner creates persisted synthetic conversation"
            )
            # PostgREST insert defaults to minimal response; obtain the owner's
            # exact fixture through their own JWT, never privileged reads.
            status, body = call(
                api + "/rest/v1/ai_sessions?select=id&user_id=eq." + actor,
                token=owner_token,
                apikey=anon,
            )
            require(
                status == 200 and len(json.loads(body)) == 1,
                "owner sees their conversation",
            )
            session = str(UUID(json.loads(body)[0]["id"]))
            message = "SYNTHETIC persisted question " + seed
            status, _ = call(
                api + "/rest/v1/ai_session_messages",
                "POST",
                {
                    "session_id": session,
                    "user_id": actor,
                    "role": "user",
                    "content": message,
                },
                token=owner_token,
                apikey=anon,
            )
            require(
                status == 201, "owner saves a synthetic message without a provider call"
            )
            other, other_token = make_user(api, service, anon, "history-other-" + seed)
            try:
                for method, payload in (
                    ("PATCH", {"title": "foreign"}),
                    ("DELETE", None),
                ):
                    status, _ = call(
                        api + "/rest/v1/ai_sessions?id=eq." + session,
                        method,
                        payload,
                        token=other_token,
                        apikey=anon,
                    )
                    require(
                        status in (200, 204),
                        "foreign history operation returns no authorized rows",
                    )
                    require(
                        scalar(
                            f"select title from public.ai_sessions where id='{session}';"
                        )
                        == "SYNTHETIC history " + seed,
                        "foreign history mutation denied by RLS",
                    )
                visit("/ai-assistant")
                page.get_by_text(message, exact=True).wait_for()
                page.get_by_role("button", name="Show menu", exact=True).first.click()
                page.get_by_role("menuitem", name="تغییر نام", exact=True).click()
                renamed = "SYNTHETIC renamed " + seed
                enter("عنوان جدید", renamed, clear=True)
                page.get_by_role("button", name="ذخیره", exact=True).click()
                wait_for(
                    lambda: (
                        scalar(
                            f"select title from public.ai_sessions where id='{session}';"
                        )
                        == renamed
                    )
                )
                visit("/ai-assistant")
                page.get_by_text(renamed, exact=False).first.wait_for()
                page.get_by_text(message, exact=True).wait_for()
                shot("conversation-renamed-after-refresh")
                page.get_by_role("button", name="Show menu", exact=True).first.click()
                page.get_by_role("menuitem", name="حذف", exact=True).click()
                page.get_by_role("button", name="حذف", exact=True).click()
                wait_for(
                    lambda: (
                        scalar(
                            f"select count(*) from public.ai_sessions where id='{session}';"
                        )
                        == "0"
                    )
                )
                require(
                    scalar(
                        f"select count(*) from public.ai_session_messages where session_id='{session}';"
                    )
                    == "0",
                    "owner deletion cascades only their conversation messages",
                )
                visit("/ai-assistant")
                page.get_by_text("هنوز گفتگویی ثبت نشده است.", exact=True).wait_for()
                require(
                    page.get_by_text(message, exact=True).count() == 0,
                    "deleted history remains absent after refresh",
                )
                shot("conversation-deleted-after-refresh")
            finally:
                call(api + "/auth/v1/admin/users/" + other, "DELETE", apikey=service)

        if not args.only_documents:
            step(
                "conversation-owner-history-rename-delete-refresh", conversation_history
            )

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

        uploaded = (
            False if args.matrix_only else step("document-upload-persistence", upload)
        )

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
                require(
                    popup.url.startswith(api + "/storage/v1/object/sign/documents/"),
                    "owned signed preview origin",
                )
                opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                with opener.open(popup.url, timeout=30) as response:
                    status, content = response.status, response.read()
                    cache = response.headers.get("Cache-Control", "").lower()
                report["preview_cache_control"] = cache
                require(
                    status == 200
                    and hashlib.sha256(content).digest()
                    == hashlib.sha256(PDF).digest(),
                    "real private preview bytes",
                )
                if args.require_cache_revalidation:
                    require(
                        any(
                            value in cache
                            for value in ("max-age=0", "no-cache", "no-store")
                        ),
                        "new private upload preview requires cache revalidation",
                    )
                report["preview_cache_revalidation_verified"] = (
                    args.require_cache_revalidation
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
                    run(compose(root, "restart", "functions"))
                    require(
                        scalar(
                            f"select count(*) from private.rad_document_deletions q join public.documents d on d.id=q.document_id where d.user_id='{actor}' and q.state='pending_storage' and q.attempts=1 and q.last_error_code is not null and q.object_path<>'[erased]';"
                        )
                        == "1",
                        "pending authorized work survives an actual worker restart",
                    )
                finally:
                    run(compose(root, "up", "-d", "storage"))
                wait_for(
                    lambda: call(api + "/storage/v1/status", apikey=service)[0] == 200,
                    timeout=120,
                )
                for attempt in range(3):
                    status, body = call(
                        api + "/functions/v1/document-deletion",
                        "POST",
                        {},
                        apikey=service,
                    )
                    if status == 200:
                        break
                    if attempt < 2:
                        time.sleep(2)
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
        if args.ui_matrix:
            translations = {
                language: json.loads(
                    (repo / "lib/l10n" / ("app_" + language + ".arb")).read_text("utf8")
                )
                for language in ("en", "fa")
            }
            for language in ("en", "fa"):
                facade = "\n".join(
                    path.read_text("utf8")
                    for path in (repo / "lib/l10n").glob(
                        f"app_localizations_{language}*.dart"
                    )
                )
                for key in ("addType", "noDocuments", "english", "persian", "language"):
                    translations[language][key] = re.search(
                        r"String get " + key + r" => '([^']+)';", facade
                    ).group(1)

            def document_layout(language, width):
                page.set_viewport_size({"width": width, "height": 1000})
                visit("/documents")
                page.get_by_role("group").filter(
                    has_text=translations[language]["noDocuments"]
                ).wait_for()
                page.get_by_role(
                    "button", name=translations[language]["addType"], exact=True
                ).wait_for()
                require(
                    page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
                    "viewport has no horizontal page scroll",
                )
                page.keyboard.press("Tab")
                shot(f"documents-{language}-{width}")
                require(not layout_errors, "no Flutter RenderFlex overflow observed")

            for width in (390, 768, 1440):
                step(
                    f"documents-en-{width}",
                    lambda width=width: document_layout("en", width),
                )

            def persian():
                visit("/profile")
                page.get_by_role("button", name=re.compile(r"^Language\b")).click()
                semantic_label("Persian").evaluate("element => element.click()")
                page.get_by_role(
                    "button",
                    name=re.compile("^" + re.escape(translations["fa"]["language"])),
                ).wait_for()

            if step("switch-language-through-profile", persian):
                for width in (390, 768, 1440):
                    step(
                        f"documents-fa-{width}",
                        lambda width=width: document_layout("fa", width),
                    )
                visit("/profile")
                page.get_by_role(
                    "button",
                    name=re.compile("^" + re.escape(translations["fa"]["language"])),
                ).click()
                semantic_label(translations["fa"]["english"]).evaluate(
                    "element => element.click()"
                )
                page.get_by_role("button", name=re.compile(r"^Language\b")).wait_for()

        if args.admin_flow:
            admin_state = {}

            def admin_visibility():
                admin_email = "browser-admin-" + seed + "@example.invalid"
                admin_password = secrets.token_urlsafe(32)
                admin_state.update(email=admin_email, password=admin_password)
                status, body = call(
                    api + "/auth/v1/admin/users",
                    "POST",
                    {
                        "email": admin_email,
                        "password": admin_password,
                        "email_confirm": True,
                    },
                    apikey=service,
                )
                require(status == 200, "synthetic admin fixture")
                admin_id = str(UUID(json.loads(body)["id"]))
                # Fixture setup only: ordinary clients have no role-write path.
                status, _ = call(
                    api + "/rest/v1/profiles?id=eq." + admin_id,
                    "PATCH",
                    {"role": "admin", "full_name": "Synthetic Browser Admin"},
                    apikey=service,
                )
                require(200 <= status < 300, "audited server-only fixture bootstrap")
                visit("/profile")
                page.get_by_role("button", name="Log out", exact=True).first.click()
                # Auth state can rebuild the current profile as a guest before
                # the old page callback navigates. Wait for actual sign-out,
                # then use the guest's normal sign-in action.
                page.get_by_role("button", name="Sign in", exact=True).wait_for()
                if "/login" not in page.url:
                    page.get_by_role("button", name="Sign in", exact=True).click()
                enter("Email", admin_email, clear=True)
                enter("Password", admin_password, clear=True)
                page.get_by_role("button", name="Sign in", exact=True).click()
                page.wait_for_url(lambda address: "/login" not in address)
                page.get_by_role("button", name="Edit profile", exact=True).wait_for()
                report["last_action"] = "admin-consultation-list"
                visit("/admin/consultations")
                page.get_by_role(
                    "button",
                    name=re.compile("^" + re.escape("Synthetic " + seed) + r"\b"),
                ).wait_for()
                require(
                    scalar(
                        f"select count(*) from public.consultation_requests where user_id='{actor}' and topic='Synthetic {seed}';"
                    )
                    == "1",
                    "admin views the persisted client consultation",
                )
                shot("admin-consultation-visible")
                visit("/admin/ai-research")
                page.get_by_role(
                    "heading", name="Research assistant", exact=True
                ).wait_for()
                shot("admin-research-workspace")

            if not args.only_documents:
                admin_ready = step(
                    "admin-login-and-consultation-visibility", admin_visibility
                )

                def cms_edit_and_recover():
                    # Only the prior API suite's explicitly synthetic ZZ article
                    # may be edited. No employer/source-library article qualifies.
                    article = scalar("""select a.id from public.visa_articles a
                      join public.visa_article_heads h on h.article_id=a.id and h.locale='en'
                      join public.visa_article_revisions r on r.id=h.head_id
                      join auth.users u on u.id=a.created_by
                      where a.country_code='ZZ' and h.published_id is null
                        and r.title like 'SYNTHETIC%'
                        and u.email like 'research-cms-admin-%@example.test'
                      order by a.created_at desc limit 1;""")
                    article = str(UUID(article))
                    feed_before = scalar("select count(*) from public.feed_items;")
                    count_before = int(
                        scalar(
                            f"select count(*) from public.visa_article_revisions where article_id='{article}';"
                        )
                    )
                    route = "/admin/cms/canonical/" + article + "?locale=en"
                    visit(route)
                    edited_title = "SYNTHETIC browser human edit " + seed
                    edited_summary = (
                        "SYNTHETIC unpublished draft; no immigration advice."
                    )
                    enter("عنوان", edited_title, clear=True)
                    enter("خلاصه", edited_summary, clear=True)
                    page.get_by_role("button", name="ذخیره پیش‌نویس", exact=True).click()
                    wait_for(
                        lambda: (
                            scalar(
                                f"select count(*) from public.visa_article_revisions where article_id='{article}' and title='{edited_title}' and summary='{edited_summary}';"
                            )
                            == "1"
                        )
                    )
                    require(
                        int(
                            scalar(
                                f"select count(*) from public.visa_article_revisions where article_id='{article}';"
                            )
                        )
                        == count_before + 1,
                        "one browser-authored immutable draft revision",
                    )
                    require(
                        scalar(
                            f"select count(*) from public.visa_article_heads where article_id='{article}' and published_id is not null;"
                        )
                        == "0",
                        "saving a CMS draft never publishes",
                    )
                    require(
                        scalar("select count(*) from public.feed_items;")
                        == feed_before,
                        "CMS draft edit leaves Feed unchanged",
                    )
                    shot("cms-human-edit-saved-unpublished")
                    visit("/profile")
                    page.get_by_role("button", name="Log out", exact=True).first.click()
                    page.get_by_role("button", name="Sign in", exact=True).wait_for()
                    if "/login" not in page.url:
                        page.get_by_role("button", name="Sign in", exact=True).click()
                    enter("Email", admin_state["email"], clear=True)
                    enter("Password", admin_state["password"], clear=True)
                    page.get_by_role("button", name="Sign in", exact=True).click()
                    page.wait_for_url(lambda address: "/login" not in address)
                    visit(route)
                    title_field = page.get_by_role("textbox", name="عنوان", exact=True)
                    title_field.click()
                    require(
                        page.evaluate("document.activeElement.value") == edited_title,
                        "browser re-login recovers the persisted draft title",
                    )
                    shot("cms-draft-recovered-after-relogin")

                if admin_ready:
                    step(
                        "cms-human-edit-save-and-relogin-recovery", cms_edit_and_recover
                    )
        if args.recovery_flow:

            def browser_recovery():
                from verify_self_host_password_recovery import mailbox_url, request

                visit("/profile")
                page.get_by_role("button", name="Log out", exact=True).first.click()
                page.get_by_role("button", name="Sign in", exact=True).wait_for()
                visit("/forgot-password")
                enter("Email", email, clear=True)
                page.get_by_role("button", name="Send reset link", exact=True).click()
                mailbox = mailbox_url(root)
                verify_url = None
                deadline = time.monotonic() + 60
                query = urllib.parse.quote("to:" + email)
                while time.monotonic() < deadline and verify_url is None:
                    status, raw, _ = request(mailbox + "/api/v1/search?query=" + query)
                    if status == 200:
                        for message in json.loads(raw).get("messages", []):
                            status, raw, _ = request(
                                mailbox + "/api/v1/message/" + message["ID"]
                            )
                            if status != 200:
                                continue
                            content = json.loads(raw)
                            text = html.unescape(
                                (content.get("HTML") or "")
                                + (content.get("Text") or "")
                            )
                            for link in re.findall(r"""https?://[^\s<>"']+""", text):
                                parsed = urllib.parse.urlsplit(link)
                                if (
                                    parsed.netloc == urllib.parse.urlsplit(api).netloc
                                    and parsed.path == "/auth/v1/verify"
                                    and urllib.parse.parse_qs(parsed.query).get("type")
                                    == ["recovery"]
                                ):
                                    verify_url = link
                                    break
                    if verify_url is None:
                        time.sleep(2)
                require(
                    verify_url is not None,
                    "real browser recovery email delivered to owned mailbox",
                )
                report["last_action"] = "open-owned-recovery-email-link"
                page.goto(verify_url, wait_until="domcontentloaded")
                enable_semantics()
                replacement = secrets.token_urlsafe(32)
                enter("New password", replacement, clear=True)
                enter("Confirm password", replacement, clear=True)
                page.get_by_role("button", name="Save", exact=True).click()
                page.get_by_role("button", name="Sign in", exact=True).wait_for()
                old_status, _ = call(
                    api + "/auth/v1/token?grant_type=password",
                    "POST",
                    {"email": email, "password": password},
                    apikey=anon,
                )
                require(
                    old_status >= 400, "browser recovery rejects the original password"
                )
                status, body = call(
                    api + "/auth/v1/token?grant_type=password",
                    "POST",
                    {"email": email, "password": replacement},
                    apikey=anon,
                )
                require(
                    status == 200 and json.loads(body)["user"]["id"] == actor,
                    "browser recovery persisted the replacement credential for the owner",
                )
                report["recovery_link_logged"] = False

            step("real-mailbox-browser-recovery-deep-link", browser_recovery)
        report["fixtures_retained_on_owned_stack"] = True
        browser.close()
    report["passed"] = sum(r["status"] == "PASS" for r in report["results"])
    report["total"] = len(report["results"])
    (output / "web_results.json").write_bytes(json.dumps(report, indent=2).encode())
    raise SystemExit(0 if report["passed"] == report["total"] else 1)


if __name__ == "__main__":
    main()
