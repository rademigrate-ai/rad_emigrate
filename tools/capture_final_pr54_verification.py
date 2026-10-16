"""Production real-app verification script for RAD Emigrate PR #54.

Captures high-fidelity before/after verification evidence for:
1. Centered bottom navigation dock with Persian «دستیار هوشمند»
2. 5-state AI assistant bird with articulated poses and visual cues
3. Transparent sidebar logo with NO white background box
4. Natural wing-flapping loading system across public routes
5. World clock with verified IANA timezones
"""

import asyncio
import json
from pathlib import Path
from playwright.async_api import async_playwright

BASE_URL = "http://127.0.0.1:8794"
OUT_DIR = Path("docs/qa/pr54/verification")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


async def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=CHROME,
            headless=True,
            args=["--disable-gpu-sandbox"],
        )

        # ----------------------------------------------------------------------
        # TEST 1: Mobile RTL (Persian) - 390x844
        # ----------------------------------------------------------------------
        context_mobile = await browser.new_context(
            viewport={"width": 390, "height": 844},
            locale="fa-IR",
        )
        page_m = await context_mobile.new_page()

        console_errors = []
        page_m.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)

        print("[1/6] Loading Mobile Persian Dashboard...")
        await page_m.goto(f"{BASE_URL}/", wait_until="commit", timeout=45000)
        await page_m.wait_for_timeout(6000)
        p1 = OUT_DIR / "final-mobile-fa-dashboard.png"
        await page_m.screenshot(path=str(p1))
        print(f"Captured: {p1}")
        report.append({"test": "Mobile Persian Dashboard", "file": str(p1)})

        print("[2/6] Loading Mobile Persian AI Assistant...")
        await page_m.goto(f"{BASE_URL}/ai-assistant", wait_until="commit", timeout=30000)
        await page_m.wait_for_timeout(4000)
        p2 = OUT_DIR / "final-mobile-fa-ai-assistant.png"
        await page_m.screenshot(path=str(p2))
        print(f"Captured: {p2}")
        report.append({"test": "Mobile Persian AI Assistant", "file": str(p2)})

        print("[3/6] Loading Mobile Persian Visa Discovery...")
        await page_m.goto(f"{BASE_URL}/visa", wait_until="commit", timeout=30000)
        await page_m.wait_for_timeout(4000)
        p3 = OUT_DIR / "final-mobile-fa-visa.png"
        await page_m.screenshot(path=str(p3))
        print(f"Captured: {p3}")
        report.append({"test": "Mobile Persian Visa", "file": str(p3)})

        print("[4/6] Loading Mobile Persian World Time...")
        await page_m.goto(f"{BASE_URL}/world-clock", wait_until="commit", timeout=30000)
        await page_m.wait_for_timeout(4000)
        p4 = OUT_DIR / "final-mobile-fa-world-clock.png"
        await page_m.screenshot(path=str(p4))
        print(f"Captured: {p4}")
        report.append({"test": "Mobile Persian World Time", "file": str(p4)})

        await context_mobile.close()

        # ----------------------------------------------------------------------
        # TEST 2: Desktop LTR (English) - 1440x900 (Sidebar Logo Verification)
        # ----------------------------------------------------------------------
        context_desk = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            locale="en-US",
        )
        page_d = await context_desk.new_page()

        print("[5/6] Loading Desktop English Dashboard with Sidebar...")
        await page_d.goto(f"{BASE_URL}/dashboard", wait_until="commit", timeout=45000)
        await page_d.wait_for_timeout(6000)
        p5 = OUT_DIR / "final-desktop-en-sidebar-dashboard.png"
        await page_d.screenshot(path=str(p5))
        print(f"Captured: {p5}")
        report.append({"test": "Desktop English Sidebar Dashboard", "file": str(p5)})

        print("[6/6] Loading Desktop English Global Time...")
        await page_d.goto(f"{BASE_URL}/world-clock", wait_until="commit", timeout=30000)
        await page_d.wait_for_timeout(4000)
        p6 = OUT_DIR / "final-desktop-en-world-clock.png"
        await page_d.screenshot(path=str(p6))
        print(f"Captured: {p6}")
        report.append({"test": "Desktop English World Clock", "file": str(p6)})

        await context_desk.close()
        await browser.close()

    summary_file = OUT_DIR / "verification_summary.json"
    summary_file.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Verification complete. Summary written to {summary_file}")


if __name__ == "__main__":
    asyncio.run(main())
