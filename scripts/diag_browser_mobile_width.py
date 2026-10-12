#!/usr/bin/env python3
"""Read-only viewport geometry probe against a disposable local browser fixture."""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

from playwright.async_api import async_playwright

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_stage2_browser_e2e import (  # noqa: E402
    BrowserAcceptance,
    LocalSupabaseFixtures,
    load_local_environment,
    serve_web,
)


async def probe(base_url: str, fixtures: LocalSupabaseFixtures, identity: object) -> None:
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(channel="chrome", headless=True)
        try:
            acceptance = BrowserAcceptance(
                browser, base_url, Path("."), fixtures,
                identity, identity, identity, identity, False,
            )
            context, page, problems = await acceptance.new_context(390, 844)
            try:
                await acceptance.sign_in(page, identity)
                for route in ("/dashboard", "/consultation", "/ai-assistant", "/profile"):
                    await acceptance.goto(page, route)
                    geometry = await page.evaluate("""() => ({
                      innerWidth: window.innerWidth,
                      documentScrollWidth: document.documentElement.scrollWidth,
                      bodyScrollWidth: document.body.scrollWidth,
                      glassWidth: document.querySelector('flt-glass-pane')?.getBoundingClientRect().width,
                      horizontalScrollMax: document.documentElement.scrollWidth - window.innerWidth,
                    })""")
                    geometry["route"] = route
                    print(json.dumps(geometry, sort_keys=True))
                    if geometry["bodyScrollWidth"] > geometry["innerWidth"]:
                        spill = await page.evaluate("""() => [...document.body.querySelectorAll('*')]
                          .map(e => ({e, r: e.getBoundingClientRect()}))
                          .filter(x => x.r.width > 0 && x.r.right > window.innerWidth + 1)
                          .slice(0, 12)
                          .map(x => ({tag: x.e.tagName.toLowerCase(),
                            className: String(x.e.className).slice(0, 80),
                            right: Math.round(x.r.right), width: Math.round(x.r.width),
                            role: x.e.getAttribute('role'),
                            ariaHidden: x.e.getAttribute('aria-hidden')}))""")
                        print(json.dumps({"route": route, "overflow_elements": spill}, sort_keys=True))
                print(json.dumps({"unexpected_console_errors": problems}, sort_keys=True))
            finally:
                await context.close()
        finally:
            await browser.close()


def main() -> None:
    environment = load_local_environment()
    fixtures = LocalSupabaseFixtures(environment)
    try:
        identity = fixtures.create_identity("user")
        with serve_web(Path(sys.argv[1]).resolve(), 3001) as base_url:
            asyncio.run(probe(base_url, fixtures, identity))
    finally:
        fixtures.cleanup()


if __name__ == "__main__":
    main()
