"""Interactive smoke test and visual verification for the REAL production build of RAD Emigrate."""

import asyncio
import json
from pathlib import Path
from playwright.async_api import async_playwright

BASE_URL = "http://127.0.0.1:8794"
OUT_DIR = Path("docs/qa/pr54/real_app")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


async def run_smoke_tests():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    results = []

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=CHROME,
            headless=True,
            args=["--disable-gpu-sandbox"],
        )

        # ----------------------------------------------------------------------
        # TEST 1: Mobile Persian (RTL) - Launch & Dashboard
        # ----------------------------------------------------------------------
        context_mobile = await browser.new_context(
            viewport={"width": 390, "height": 844},
            locale="fa-IR",
        )
        page = await context_mobile.new_page()
        console_logs = []
        page.on("console", lambda msg: console_logs.append(f"[{msg.type}] {msg.text}"))

        print("1. Launching real app on mobile (390x844)...")
        await page.goto(f"{BASE_URL}/", wait_until="networkidle", timeout=60000)
        # Wait for Flutter app to bootstrap and transition from /splash to /dashboard
        await page.wait_for_timeout(5000)

        # Capture Dashboard
        dash_path = OUT_DIR / "real-mobile-dashboard.png"
        await page.screenshot(path=str(dash_path))
        print(f"Captured: {dash_path}")
        results.append({
            "test": "Real App Mobile Dashboard",
            "url": page.url,
            "screenshot": str(dash_path),
            "console_errors": [l for l in console_logs if "[error]" in l]
        })

        # ----------------------------------------------------------------------
        # TEST 2: Real App Mobile World Clock (/world-clock)
        # ----------------------------------------------------------------------
        print("2. Navigating to /world-clock...")
        await page.goto(f"{BASE_URL}/world-clock", wait_until="networkidle", timeout=30000)
        await page.wait_for_timeout(4000)
        wc_path = OUT_DIR / "real-mobile-world-clock.png"
        await page.screenshot(path=str(wc_path))
        print(f"Captured: {wc_path}")
        results.append({
            "test": "Real App Mobile World Clock",
            "url": page.url,
            "screenshot": str(wc_path),
        })

        # ----------------------------------------------------------------------
        # TEST 3: Real App Mobile Visa Discovery (/visa)
        # ----------------------------------------------------------------------
        print("3. Navigating to /visa...")
        await page.goto(f"{BASE_URL}/visa", wait_until="networkidle", timeout=30000)
        await page.wait_for_timeout(4000)
        visa_path = OUT_DIR / "real-mobile-visa.png"
        await page.screenshot(path=str(visa_path))
        print(f"Captured: {visa_path}")
        results.append({
            "test": "Real App Mobile Visa",
            "url": page.url,
            "screenshot": str(visa_path),
        })

        # ----------------------------------------------------------------------
        # TEST 4: Real App Mobile Profile (/profile)
        # ----------------------------------------------------------------------
        print("4. Navigating to /profile...")
        await page.goto(f"{BASE_URL}/profile", wait_until="networkidle", timeout=30000)
        await page.wait_for_timeout(3000)
        profile_path = OUT_DIR / "real-mobile-profile.png"
        await page.screenshot(path=str(profile_path))
        print(f"Captured: {profile_path}")
        results.append({
            "test": "Real App Mobile Profile (Guest)",
            "url": page.url,
            "screenshot": str(profile_path),
        })

        # ----------------------------------------------------------------------
        # TEST 5: Real App Mobile AI Assistant (/ai-assistant)
        # ----------------------------------------------------------------------
        print("5. Navigating to /ai-assistant...")
        await page.goto(f"{BASE_URL}/ai-assistant", wait_until="networkidle", timeout=30000)
        await page.wait_for_timeout(4000)
        ai_path = OUT_DIR / "real-mobile-ai-assistant.png"
        await page.screenshot(path=str(ai_path))
        print(f"Captured: {ai_path}")
        results.append({
            "test": "Real App Mobile AI Assistant",
            "url": page.url,
            "screenshot": str(ai_path),
        })

        # ----------------------------------------------------------------------
        # TEST 6: Real App Mobile Consultation (/consultation)
        # ----------------------------------------------------------------------
        print("6. Navigating to /consultation...")
        await page.goto(f"{BASE_URL}/consultation", wait_until="networkidle", timeout=30000)
        await page.wait_for_timeout(3000)
        consult_path = OUT_DIR / "real-mobile-consultation.png"
        await page.screenshot(path=str(consult_path))
        print(f"Captured: {consult_path}")
        results.append({
            "test": "Real App Mobile Consultation",
            "url": page.url,
            "screenshot": str(consult_path),
        })

        await page.close()
        await context_mobile.close()

        # ----------------------------------------------------------------------
        # TEST 7: Desktop English - Wide Layout (1440x900)
        # ----------------------------------------------------------------------
        context_desktop = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            locale="en-US",
        )
        page_desktop = await context_desktop.new_page()
        print("7. Launching real app on desktop (1440x900)...")
        await page_desktop.goto(f"{BASE_URL}/dashboard", wait_until="networkidle", timeout=30000)
        await page_desktop.wait_for_timeout(4000)
        desk_dash_path = OUT_DIR / "real-desktop-dashboard.png"
        await page_desktop.screenshot(path=str(desk_dash_path))
        print(f"Captured: {desk_dash_path}")
        results.append({
            "test": "Real App Desktop Dashboard",
            "url": page_desktop.url,
            "screenshot": str(desk_dash_path),
        })

        # Desktop World Clock
        print("8. Desktop navigating to /world-clock...")
        await page_desktop.goto(f"{BASE_URL}/world-clock", wait_until="networkidle", timeout=30000)
        await page_desktop.wait_for_timeout(4000)
        desk_wc_path = OUT_DIR / "real-desktop-world-clock.png"
        await page_desktop.screenshot(path=str(desk_wc_path))
        print(f"Captured: {desk_wc_path}")
        results.append({
            "test": "Real App Desktop World Clock",
            "url": page_desktop.url,
            "screenshot": str(desk_wc_path),
        })

        await page_desktop.close()
        await context_desktop.close()

        await browser.close()

    manifest_path = OUT_DIR / "real-app-smoke-manifest.json"
    manifest_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Smoke test complete. Manifest saved to {manifest_path}")


if __name__ == "__main__":
    asyncio.run(run_smoke_tests())

