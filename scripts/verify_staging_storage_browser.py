#!/usr/bin/env python3
"""Targeted local staging Chrome journey after Storage API is enabled."""

import argparse
import asyncio
import json
from pathlib import Path

from playwright.async_api import async_playwright

from verify_stage2_browser_e2e import (
    BrowserAcceptance, LocalSupabaseFixtures, load_local_environment,
    require, serve_web,
)


async def run(fixtures, identity, web_root, artifacts):
    requests = []
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(channel="chrome", headless=True)
        try:
            with serve_web(web_root, 3302) as base_url:
                acceptance = BrowserAcceptance(browser, base_url, artifacts, fixtures,
                                               identity, identity, identity, identity)
                context, page, problems = await acceptance.new_context(1280, 800)
                try:
                    page.on("response", lambda response: requests.append({
                        "method": response.request.method,
                        "status": response.status,
                        "path": response.url.split("/storage/v1", 1)[-1],
                    }) if "/storage/v1" in response.url else None)
                    await acceptance.goto(page, "/consultation")
                    require("/login" in page.url, "guest consultation route did not require sign-in")
                    await acceptance.sign_in(page, identity)
                    await acceptance.document_upload_delete(page)
                    target = artifacts / "documents-after-upload-delete.png"
                    await page.screenshot(path=target, full_page=False)
                    require(not problems, "browser console errors: " + " | ".join(problems))
                    return {"result": "PASS_LOCAL_STAGING", "guest_gate": "PASS",
                            "auth_login": "PASS", "document_upload_delete": "PASS",
                            "storage_responses": requests, "console_errors": problems,
                            "screenshot": str(target)}
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
    try:
        identity = fixtures.create_identity("user")
        fixtures.seed_user_records(identity)
        result = asyncio.run(run(fixtures, identity, args.web_root.resolve(), artifacts))
    finally:
        fixtures.cleanup()
    (artifacts / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": result["result"],
                      "storage_responses": result["storage_responses"]}))


if __name__ == "__main__":
    main()
