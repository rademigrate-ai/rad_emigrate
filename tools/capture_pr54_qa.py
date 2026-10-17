"""Capture deterministic PR #54 widget-fixture screenshots with console logs."""

import asyncio
import json
from pathlib import Path

from playwright.async_api import async_playwright


BASE_URL = "http://127.0.0.1:8794/"
OUT = Path("docs/qa/pr54")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

TARGETS = [
    ("after-mobile-fa-dark-visa.png", "visa", "dark", "fa", 390, 844),
    ("after-mobile-fa-light-profile.png", "profile", "light", "fa", 390, 844),
    ("after-tablet-en-light-world-time.png", "world-time", "light", "en", 834, 1112),
    ("after-tablet-fa-dark-consultation.png", "consultation", "dark", "fa", 834, 1112),
    ("after-desktop-en-dark-bird-states.png", "bird-states", "dark", "en", 1440, 900),
    ("after-desktop-en-dark-dashboard.png", "dashboard", "dark", "en", 1440, 900),
    ("after-desktop-fa-light-profile.png", "profile", "light", "fa", 1440, 900),
    ("after-mobile-en-dark-ai.png", "ai", "dark", "en", 390, 844),
    ("after-mobile-fa-dark-shell.png", "shell", "dark", "fa", 390, 844),
    ("after-desktop-en-dark-shell.png", "shell", "dark", "en", 1440, 900),
]


async def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=CHROME,
            headless=True,
            args=["--disable-gpu-sandbox"],
        )
        for filename, screen, theme, locale, width, height in TARGETS:
            page = await browser.new_page(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
            )
            console_errors = []
            page.on(
                "console",
                lambda message: console_errors.append(message.text)
                if message.type == "error"
                else None,
            )
            url = (
                f"{BASE_URL}?screen={screen}&theme={theme}"
                f"&locale={locale}&capture=1"
            )
            response = await page.goto(url, wait_until="networkidle", timeout=60000)
            await page.wait_for_timeout(3000)
            await page.screenshot(path=str(OUT / filename), full_page=False)
            records.append(
                {
                    "file": filename,
                    "screen": screen,
                    "theme": theme,
                    "locale": locale,
                    "viewport": f"{width}x{height}",
                    "http_status": response.status if response else None,
                    "console_errors": console_errors,
                    "evidence_type": "widget-fixture browser capture",
                }
            )
            await page.close()
        await browser.close()

    (OUT / "capture-manifest.json").write_text(
        json.dumps(records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(records, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
