#!/usr/bin/env python3
"""Focused Chrome keyboard, semantics, viewport and locale observations.

Runs only against the isolated loopback Supabase stack and never submits a form.
This is not a screen-reader test.
"""

import argparse
import asyncio
import json
from pathlib import Path

from playwright.async_api import async_playwright

from verify_stage2_browser_e2e import (
    BrowserAcceptance, LocalSupabaseFixtures, load_local_environment,
    require, serve_web,
)


async def inspect(fixtures, identity, web_root, artifacts):
    observations = []
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(channel="chrome", headless=True)
        try:
            with serve_web(web_root, 3302) as base_url:
                acceptance = BrowserAcceptance(browser, base_url, artifacts, fixtures,
                                               identity, identity, identity, identity)
                for width, height in ((1280, 800), (390, 844)):
                    context, page, problems = await acceptance.new_context(width, height)
                    try:
                        await acceptance.goto(page, "/login")
                        email = page.get_by_label("Email", exact=True)
                        password = page.get_by_label("Password", exact=True)
                        require(await email.count() == 1 and await password.count() == 1,
                                "English login input labels missing")
                        await email.focus()
                        await page.keyboard.press("Tab")
                        focus_after_email = await page.evaluate(
                            "() => document.activeElement?.getAttribute('aria-label')")
                        english_box = await page.get_by_text("Sign in", exact=True).last.bounding_box()
                        require(english_box is not None, "English login heading missing")
                        en_path = artifacts / f"login-en-{width}.png"
                        await page.screenshot(path=en_path, full_page=True)
                        await acceptance.click(page.get_by_role("button", name="فارسی", exact=True))
                        await acceptance.expect_text(page, "ورود")
                        persian_box = await page.get_by_text("ورود", exact=True).last.bounding_box()
                        require(persian_box is not None, "Persian login heading missing")
                        fa_path = artifacts / f"login-fa-{width}.png"
                        await page.screenshot(path=fa_path, full_page=True)
                        await acceptance.click(page.get_by_role("button", name="English", exact=True))
                        await page.get_by_label("Email", exact=True).wait_for(state="attached")
                        observations.append({
                            "viewport": f"{width}x{height}",
                            "login_email_label": True,
                            "login_password_label": True,
                            "focus_after_email_tab": focus_after_email,
                            "english_heading_x": round(english_box["x"]),
                            "persian_heading_x": round(persian_box["x"]),
                            "rtl_mirror_delta_px": round(english_box["x"] - persian_box["x"]),
                            "english_restored": True,
                            "screenshots": [str(en_path), str(fa_path)],
                            "console_errors": list(problems),
                        })
                        require(focus_after_email == "Password",
                                f"login Tab from Email did not focus Password at {width}px")
                        if width == 390:
                            await acceptance.sign_in(page, identity)
                            await acceptance.goto(page, "/consultation")
                            require(await page.get_by_label("Topic", exact=True).count() == 1,
                                    "Topic label missing at mobile width")
                            require(await page.get_by_label("Message", exact=True).count() == 1,
                                    "Message label missing at mobile width")
                            await page.get_by_label("Topic", exact=True).focus()
                            await page.keyboard.press("Tab")
                            topic_tab = await page.evaluate(
                                "() => document.activeElement?.getAttribute('aria-label')")
                            mobile_path = artifacts / "consultation-mobile-390.png"
                            geometry = await page.evaluate(
                                "() => ({innerWidth, documentScrollWidth: document.documentElement.scrollWidth, bodyScrollWidth: document.body.scrollWidth, horizontalScrollMax: document.documentElement.scrollWidth - innerWidth})"
                            )
                            await page.screenshot(path=mobile_path, full_page=False)
                            observations[-1]["consultation_topic_tab_focus"] = topic_tab
                            observations[-1]["consultation_geometry"] = geometry
                            observations[-1]["screenshots"].append(str(mobile_path))
                            observations[-1]["consultation_submit_executed"] = False
                            require(topic_tab == "Message", "consultation Topic Tab did not focus Message")
                            require(geometry["horizontalScrollMax"] == 0,
                                    "consultation has horizontal document scroll")
                    finally:
                        await context.close()
        finally:
            await browser.close()
    return observations


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
        result = {"result": "PASS_AUTOMATED_CHROME_ONLY",
                  "screen_reader": "NOT_RUN_NO_ASSISTIVE_TECH",
                  "observations": asyncio.run(inspect(fixtures, identity, args.web_root.resolve(), artifacts))}
    finally:
        fixtures.cleanup()
    (artifacts / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": result["result"], "viewports": len(result["observations"])}))


if __name__ == "__main__":
    main()
