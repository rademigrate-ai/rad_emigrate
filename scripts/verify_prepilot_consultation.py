#!/usr/bin/env python3
"""Targeted consultation acceptance against an isolated, loopback Supabase stack.

Run from the disposable Supabase workdir, with --web-root pointing to a web
build compiled for that stack. Never accepts a hosted API URL.
"""

import argparse
import asyncio
import json
import urllib.parse
from pathlib import Path

from playwright.async_api import async_playwright

from verify_stage2_browser_e2e import (
    BrowserAcceptance,
    LocalSupabaseFixtures,
    load_local_environment,
    require,
    serve_web,
)


def redact_response(body: bytes) -> str:
    return body.decode("utf-8", "replace")[:500]


def access_token(fixtures: LocalSupabaseFixtures, identity) -> str:
    data = fixtures.expect_json(
        "POST", "/auth/v1/token?grant_type=password",
        token=fixtures.anon_key,
        payload={"email": identity.email, "password": identity.password},
    )
    return data["access_token"]


def feed_count(fixtures: LocalSupabaseFixtures) -> int:
    return len(fixtures.expect_json("GET", "/rest/v1/feed_items?select=id"))


async def browser_submit(fixtures, identity, web_root, artifacts):
    events = []
    console_errors = []
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(channel="chrome", headless=True)
        try:
            with serve_web(web_root, 3302) as base_url:
                acceptance = BrowserAcceptance(
                    browser, base_url, artifacts, fixtures,
                    identity, identity, identity, identity,
                )
                context, page, problems = await acceptance.new_context(1280, 800)
                try:
                    page.on("response", lambda response: events.append(response)
                            if "/rest/v1/rpc/submit_consultation_request" in response.url
                            else None)
                    await acceptance.sign_in(page, identity)
                    await acceptance.goto(page, "/consultation")
                    form = artifacts / "consultation-before-submit.png"
                    await page.screenshot(path=form, full_page=True)
                    labels = await page.locator("flt-semantics").evaluate_all(
                        "nodes => nodes.map(n => n.getAttribute('aria-label') || n.textContent || '').filter(Boolean).slice(0,80)"
                    )
                    focus_order = []
                    await page.get_by_label("Topic", exact=True).focus()
                    for _ in range(4):
                        focus_order.append(await page.evaluate(
                            "() => ({tag: document.activeElement?.tagName, label: document.activeElement?.getAttribute('aria-label'), role: document.activeElement?.getAttribute('role')})"
                        ))
                        await page.keyboard.press("Tab")
                    await acceptance.consultation_journey(page)
                    await page.wait_for_timeout(500)
                    after = artifacts / "consultation-after-submit.png"
                    await page.screenshot(path=after, full_page=True)
                    require(len(events) == 1, f"expected one consultation RPC, got {len(events)}")
                    response = events[0]
                    body = await response.body()
                    require(response.status == 200, f"browser RPC HTTP {response.status}: {redact_response(body)}")
                    request_id = json.loads(body)
                    require(isinstance(request_id, str), "RPC did not return a UUID string")
                    console_errors = problems
                    return {
                        "http_status": response.status,
                        "request_id": request_id,
                        "request_method": response.request.method,
                        "request_path": urllib.parse.urlparse(response.url).path,
                        "request_body": json.loads(response.request.post_data or "{}"),
                        "response_body": request_id,
                        "screenshots": [str(form), str(after)],
                        "semantic_labels": labels,
                        "keyboard_focus_observation": focus_order,
                        "console_errors": console_errors,
                    }
                finally:
                    await context.close()
        finally:
            await browser.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-root", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    artifacts = args.artifacts.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    env = load_local_environment()
    require(env["API_URL"] == "http://127.0.0.1:55321", "unexpected local stack")
    fixtures = LocalSupabaseFixtures(env)
    results = {"api_url": env["API_URL"], "checks": {}}
    try:
        owner = fixtures.create_identity("user")
        other = fixtures.create_identity("user")
        owner_token = access_token(fixtures, owner)
        other_token = access_token(fixtures, other)
        initial_feed_count = feed_count(fixtures)
        anon_status, anon_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request",
            token=fixtures.anon_key,
            payload={"p_topic": "Anon topic", "p_message": "Anonymous message"},
        )
        require(anon_status in (401, 403, 404), f"anonymous RPC returned {anon_status}")
        results["checks"]["anonymous_denied"] = {"status": anon_status, "body": redact_response(anon_body)}
        invalid_status, invalid_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request",
            token=owner_token,
            payload={"p_topic": "x", "p_message": "Valid message here"},
        )
        require(invalid_status == 400 and b"invalid_consultation_topic" in invalid_body,
                f"invalid topic returned {invalid_status}: {redact_response(invalid_body)}")
        results["checks"]["invalid_topic"] = {"status": invalid_status, "body": redact_response(invalid_body)}
        message_status, message_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request",
            token=owner_token,
            payload={"p_topic": "Valid topic", "p_message": "short"},
        )
        require(message_status == 400 and b"invalid_consultation_message" in message_body,
                f"invalid message returned {message_status}: {redact_response(message_body)}")
        results["checks"]["invalid_message"] = {"status": message_status, "body": redact_response(message_body)}
        other_application = fixtures.expect_json(
            "POST", "/rest/v1/applications?select=id,user_id",
            payload={"user_id": other.user_id, "visa_type": "prepilot-isolation", "status": "draft"},
            prefer="return=representation",
        )[0]["id"]
        related_status, related_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request",
            token=owner_token,
            payload={"p_topic": "Valid topic", "p_message": "Valid consultation message",
                     "p_related_application_id": other_application},
        )
        require(related_status == 403 and b"related_application_forbidden" in related_body,
                f"cross-owner application returned {related_status}: {redact_response(related_body)}")
        results["checks"]["cross_owner_application_denied"] = {
            "status": related_status, "body": redact_response(related_body)}
        direct_status, direct_body, _ = fixtures.request(
            "POST", "/rest/v1/consultation_requests",
            token=owner_token,
            payload={"user_id": owner.user_id, "topic": "Direct insert", "message": "Must be rejected"},
        )
        require(direct_status in (401, 403), f"direct INSERT returned {direct_status}")
        results["checks"]["direct_insert_denied"] = {"status": direct_status, "body": redact_response(direct_body)}
        results["browser"] = asyncio.run(browser_submit(fixtures, owner, args.web_root.resolve(), artifacts))
        request_id = results["browser"]["request_id"]
        owner_rows = fixtures.expect_json(
            "GET", f"/rest/v1/consultation_requests?select=id,user_id,topic,status&id=eq.{request_id}", token=owner_token)
        other_rows = fixtures.expect_json(
            "GET", f"/rest/v1/consultation_requests?select=id,user_id,topic,status&id=eq.{request_id}", token=other_token)
        require(len(owner_rows) == 1 and owner_rows[0]["user_id"] == owner.user_id,
                "owner cannot see submitted request")
        require(other_rows == [], "another user can read owner's request")
        results["checks"]["owner_isolation"] = {"owner_rows": len(owner_rows), "other_rows": len(other_rows)}
        note_status, note_body, _ = fixtures.request(
            "GET", f"/rest/v1/consultation_requests?select=admin_note&id=eq.{request_id}", token=owner_token)
        require(note_status in (401, 403), f"admin_note SELECT returned {note_status}")
        results["checks"]["admin_note_denied"] = {"status": note_status, "body": redact_response(note_body)}
        for n in (2, 3):
            status, body, _ = fixtures.request(
                "POST", "/rest/v1/rpc/submit_consultation_request", token=owner_token,
                payload={"p_topic": f"Rate check {n}", "p_message": "Disposable local rate-limit check"})
            require(status == 200, f"request {n} returned {status}: {redact_response(body)}")
        limited_status, limited_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request", token=owner_token,
            payload={"p_topic": "Rate check 4", "p_message": "Disposable local rate-limit check"})
        require(limited_status == 400 and b"consultation_rate_limited" in limited_body,
                f"fourth request returned {limited_status}: {redact_response(limited_body)}")
        results["checks"]["rate_limit_3_per_hour"] = {"status": limited_status, "body": redact_response(limited_body)}
        final_feed_count = feed_count(fixtures)
        require(final_feed_count == initial_feed_count,
                f"Feed changed from {initial_feed_count} to {final_feed_count}")
        results["checks"]["feed_not_published"] = {"before": initial_feed_count, "after": final_feed_count}
        results["result"] = "PASS"
    finally:
        fixtures.cleanup()
        results["fixtures_cleaned"] = True
        (artifacts / "result.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": results["result"], "checks": list(results["checks"]), "browser_http": results["browser"]["http_status"]}))


if __name__ == "__main__":
    main()
