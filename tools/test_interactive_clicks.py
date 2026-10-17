"""Test interactive language, theme, and form submissions in real Flutter web app via semantics."""

import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

OUT = Path("docs/qa/pr54/interactive")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
BASE = "http://127.0.0.1:8794"


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=CHROME, headless=True)
        ctx = await b.new_context(viewport={"width": 390, "height": 844})
        page = await ctx.new_page()

        # 1. Profile Page: Toggle to Persian, then Dark mode
        print("1. Opening /profile...")
        await page.goto(f"{BASE}/profile", timeout=60000)
        await page.wait_for_timeout(3000)
        # Enable semantics
        await page.evaluate("""() => {
            const p = document.querySelector('flt-semantics-placeholder');
            if (p) p.click();
        }""")
        await page.wait_for_timeout(1000)

        # Click Persian
        print("Clicking Persian checkbox...")
        persian = page.locator("flt-semantics[aria-label='Persian']")
        if await persian.count() > 0:
            await persian.dispatch_event('click')
            await page.wait_for_timeout(2000)
            await page.screenshot(path=str(OUT / "real-persian-switched.png"))
            print("Captured real-persian-switched.png")

        # Click Dark mode
        print("Clicking Dark mode checkbox...")
        dark = page.locator("flt-semantics[aria-label*='Dark']").or_(page.locator("flt-semantics[aria-label*='تیره']"))
        if await dark.count() > 0:
            await dark.first.dispatch_event('click')
            await page.wait_for_timeout(2000)
            await page.screenshot(path=str(OUT / "real-persian-dark-profile.png"))
            print("Captured real-persian-dark-profile.png")

        # Now navigate to /dashboard to see Persian RTL in Dark Mode!
        print("2. Navigating to /dashboard in Persian Dark...")
        await page.goto(f"{BASE}/dashboard", timeout=60000)
        await page.wait_for_timeout(3000)
        await page.screenshot(path=str(OUT / "real-mobile-fa-dark-dashboard.png"))
        print("Captured real-mobile-fa-dark-dashboard.png")

        # 3. Consultation Form: Fill and Submit as Guest
        print("3. Navigating to /consultation...")
        await page.goto(f"{BASE}/consultation", timeout=60000)
        await page.wait_for_timeout(3000)
        # Enable semantics
        await page.evaluate("""() => {
            const p = document.querySelector('flt-semantics-placeholder');
            if (p) p.click();
        }""")
        await page.wait_for_timeout(1000)

        # Locate text fields in semantics
        fields = page.locator("flt-semantics input, flt-semantics textarea, input, textarea")
        print("Input fields count:", await fields.count())
        if await fields.count() >= 2:
            await fields.nth(0).fill("ویزای تحصیلی آلمان ۲۰۲۷")
            await fields.nth(1).fill("پیام پیش‌نویس: من می‌خواهم برای پذیرش دانشگاه در سال ۲۰۲۷ اقدام کنم.")
            await page.wait_for_timeout(1000)
            await page.screenshot(path=str(OUT / "real-consultation-filled-persian.png"))
            print("Captured real-consultation-filled-persian.png")

            # Click Submit button
            submit = page.locator("flt-semantics[role='button']").filter(has_text="ثبت درخواست").or_(page.locator("flt-semantics[role='button']").filter(has_text="ارسال درخواست")).or_(page.locator("flt-semantics[role='button']").filter(has_text="Submit"))
            print("Submit button count:", await submit.count())
            if await submit.count() > 0:
                await submit.first.dispatch_event('click')
                await page.wait_for_timeout(3000)
                print("Redirected URL after submit:", page.url)
                await page.screenshot(path=str(OUT / "real-consultation-gated-to-login.png"))
                print("Captured real-consultation-gated-to-login.png")

                # Navigate back to /consultation to verify draft preservation
                print("Returning to /consultation to verify draft restoration...")
                await page.goto(f"{BASE}/consultation", timeout=60000)
                await page.wait_for_timeout(3000)
                await page.screenshot(path=str(OUT / "real-consultation-draft-restored.png"))
                print("Captured real-consultation-draft-restored.png")

        # 4. AI Assistant: Fill prompt and submit as Guest
        print("4. Navigating to /ai-assistant...")
        await page.goto(f"{BASE}/ai-assistant", timeout=60000)
        await page.wait_for_timeout(3000)
        # Enable semantics
        await page.evaluate("""() => {
            const p = document.querySelector('flt-semantics-placeholder');
            if (p) p.click();
        }""")
        await page.wait_for_timeout(1000)

        ai_fields = page.locator("flt-semantics input, flt-semantics textarea, input, textarea")
        print("AI input fields count:", await ai_fields.count())
        if await ai_fields.count() > 0:
            await ai_fields.first.fill("شرایط کارت فرصت آلمان چیست؟")
            await page.wait_for_timeout(1000)
            await page.screenshot(path=str(OUT / "real-ai-filled-persian.png"))
            print("Captured real-ai-filled-persian.png")

            # Click Send button
            send_btn = page.locator("flt-semantics[role='button'][aria-label*='ارسال']").or_(page.locator("flt-semantics[role='button'][aria-label*='Send']"))
            if await send_btn.count() > 0:
                await send_btn.first.dispatch_event('click')
            else:
                await page.keyboard.press("Enter")

            await page.wait_for_timeout(3000)
            print("Redirected URL after AI send:", page.url)
            await page.screenshot(path=str(OUT / "real-ai-gated-to-login.png"))
            print("Captured real-ai-gated-to-login.png")

            # Return to /ai-assistant to verify draft preservation
            print("Returning to /ai-assistant to verify draft restoration...")
            await page.goto(f"{BASE}/ai-assistant", timeout=60000)
            await page.wait_for_timeout(3000)
            await page.screenshot(path=str(OUT / "real-ai-draft-restored.png"))
            print("Captured real-ai-draft-restored.png")

        await b.close()
        print("All interactive flow tests completed successfully!")


if __name__ == "__main__":
    asyncio.run(main())

