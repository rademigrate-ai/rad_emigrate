"""Production real-app verification script for RAD Emigrate PR #54.

Captures high-fidelity before/after verification evidence for:
1. Centered bottom navigation dock with Persian «دستیار هوشمند»
2. 5-state AI assistant bird with articulated poses and visual cues
3. Transparent sidebar logo with NO white background box
4. Natural wing-flapping loading system across public routes
5. World clock with verified IANA timezones
6. Animated recording of the natural bird wing-flapping motion
"""

import asyncio
import json
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright

BASE_URL = "http://127.0.0.1:8794"
OUT_DIR = Path("docs/qa/pr54/verification")
VIDEOS_DIR = OUT_DIR / "videos"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


async def setup_page_prefs(context, locale_code: str, theme_mode: str):
    """Seed SharedPreferences in localStorage so Flutter Web boots in desired config."""
    script = f"""
    try {{
        localStorage.setItem('flutter.rad_locale', JSON.stringify('{locale_code}'));
        localStorage.setItem('flutter.rad_theme_mode', JSON.stringify('{theme_mode}'));
    }} catch(e) {{
        console.error('Failed to set localStorage', e);
    }}
    """
    await context.add_init_script(script)


async def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
    report = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=CHROME,
            headless=True,
            args=["--disable-gpu-sandbox"],
        )

        # ----------------------------------------------------------------------
        # TEST 1: Mobile RTL (Persian) - Dark Theme - 390x844
        # ----------------------------------------------------------------------
        print("\n--- TEST 1: Mobile RTL (Persian) Dark Mode (390x844) ---")
        context_mobile_fa_dark = await browser.new_context(
            viewport={"width": 390, "height": 844},
            locale="fa-IR",
            record_video_dir=str(VIDEOS_DIR),
            record_video_size={"width": 390, "height": 844},
        )
        await setup_page_prefs(context_mobile_fa_dark, "fa", "dark")
        page_m_fa = await context_mobile_fa_dark.new_page()

        print("[1/8] Loading Mobile Persian Dark Dashboard...")
        await page_m_fa.goto(f"{BASE_URL}/", wait_until="commit", timeout=45000)
        await page_m_fa.wait_for_timeout(6000)
        p1 = OUT_DIR / "final-mobile-fa-dark-dashboard.png"
        await page_m_fa.screenshot(path=str(p1))
        print(f"Captured: {p1}")
        report.append({"test": "Mobile Persian Dark Dashboard", "file": str(p1)})

        # Crop bottom navigation bar to verify «دستیار هوشمند» baseline alignment
        try:
            im = Image.open(p1)
            # Navigation bar is at bottom: bottom 88px of 844px height
            nav_crop = im.crop((0, 750, 390, 844))
            p_nav = OUT_DIR / "final-mobile-fa-nav-dock-crop.png"
            nav_crop.save(p_nav)
            print(f"Captured nav dock crop: {p_nav}")
            report.append({"test": "Mobile Persian Nav Dock Crop", "file": str(p_nav)})
        except Exception as e:
            print(f"Error cropping nav dock: {e}")

        # Capture multiple frames of the bird flapping to build an animated GIF
        print("Capturing 16 frames of the animated nav bird...")
        frames = []
        for i in range(16):
            await page_m_fa.wait_for_timeout(80)
            frame_bytes = await page_m_fa.screenshot()
            import io
            fim = Image.open(io.BytesIO(frame_bytes))
            # Crop around the center bird button (width 390: center is ~195, bottom ~750-840)
            bird_crop = fim.crop((145, 750, 245, 835))
            frames.append(bird_crop)

        gif_path = OUT_DIR / "final-bird-wing-flapping.gif"
        if frames:
            frames[0].save(
                gif_path,
                save_all=True,
                append_images=frames[1:],
                optimize=True,
                duration=80,
                loop=0,
            )
            print(f"Captured animated bird GIF: {gif_path}")
            report.append({"test": "Animated Bird Wing Flapping GIF", "file": str(gif_path)})

        print("[2/8] Loading Mobile Persian Dark AI Assistant...")
        await page_m_fa.goto(f"{BASE_URL}/ai-assistant", wait_until="commit", timeout=30000)
        await page_m_fa.wait_for_timeout(4500)
        p2 = OUT_DIR / "final-mobile-fa-dark-ai-assistant.png"
        await page_m_fa.screenshot(path=str(p2))
        print(f"Captured: {p2}")
        report.append({"test": "Mobile Persian Dark AI Assistant", "file": str(p2)})

        print("[3/8] Loading Mobile Persian Dark Visa Discovery...")
        await page_m_fa.goto(f"{BASE_URL}/visa", wait_until="commit", timeout=30000)
        await page_m_fa.wait_for_timeout(4500)
        p3 = OUT_DIR / "final-mobile-fa-dark-visa.png"
        await page_m_fa.screenshot(path=str(p3))
        print(f"Captured: {p3}")
        report.append({"test": "Mobile Persian Dark Visa", "file": str(p3)})

        print("[4/8] Loading Mobile Persian Dark World Time...")
        await page_m_fa.goto(f"{BASE_URL}/world-clock", wait_until="commit", timeout=30000)
        await page_m_fa.wait_for_timeout(4500)
        p4 = OUT_DIR / "final-mobile-fa-dark-world-clock.png"
        await page_m_fa.screenshot(path=str(p4))
        print(f"Captured: {p4}")
        report.append({"test": "Mobile Persian Dark World Time", "file": str(p4)})

        print("[5/8] Loading Mobile Persian Dark Profile...")
        await page_m_fa.goto(f"{BASE_URL}/profile", wait_until="commit", timeout=30000)
        await page_m_fa.wait_for_timeout(4500)
        p5 = OUT_DIR / "final-mobile-fa-dark-profile.png"
        await page_m_fa.screenshot(path=str(p5))
        print(f"Captured: {p5}")
        report.append({"test": "Mobile Persian Dark Profile", "file": str(p5)})

        await context_mobile_fa_dark.close()

        # ----------------------------------------------------------------------
        # TEST 2: Mobile LTR (English) - Light Theme - 390x844
        # ----------------------------------------------------------------------
        print("\n--- TEST 2: Mobile LTR (English) Light Mode (390x844) ---")
        context_mobile_en_light = await browser.new_context(
            viewport={"width": 390, "height": 844},
            locale="en-US",
        )
        await setup_page_prefs(context_mobile_en_light, "en", "light")
        page_m_en = await context_mobile_en_light.new_page()

        print("[6/8] Loading Mobile English Light Dashboard...")
        await page_m_en.goto(f"{BASE_URL}/", wait_until="commit", timeout=45000)
        await page_m_en.wait_for_timeout(6000)
        p6 = OUT_DIR / "final-mobile-en-light-dashboard.png"
        await page_m_en.screenshot(path=str(p6))
        print(f"Captured: {p6}")
        report.append({"test": "Mobile English Light Dashboard", "file": str(p6)})

        await context_mobile_en_light.close()

        # ----------------------------------------------------------------------
        # TEST 3: Desktop LTR (English) - Dark Theme - 1440x900
        # ----------------------------------------------------------------------
        print("\n--- TEST 3: Desktop LTR (English) Dark Mode (1440x900) ---")
        context_desk_en_dark = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            locale="en-US",
        )
        await setup_page_prefs(context_desk_en_dark, "en", "dark")
        page_d_en = await context_desk_en_dark.new_page()

        print("[7/8] Loading Desktop English Dark Dashboard with Sidebar...")
        await page_d_en.goto(f"{BASE_URL}/dashboard", wait_until="commit", timeout=45000)
        await page_d_en.wait_for_timeout(6000)
        p7 = OUT_DIR / "final-desktop-en-dark-dashboard.png"
        await page_d_en.screenshot(path=str(p7))
        print(f"Captured: {p7}")
        report.append({"test": "Desktop English Dark Sidebar Dashboard", "file": str(p7)})

        # Crop sidebar logo to verify NO white background box
        try:
            im_desk = Image.open(p7)
            # Sidebar header is at top left: (0, 0, 260, 100)
            logo_crop = im_desk.crop((0, 0, 260, 100))
            p_logo = OUT_DIR / "final-desktop-en-sidebar-logo-crop.png"
            logo_crop.save(p_logo)
            print(f"Captured sidebar logo crop: {p_logo}")
            report.append({"test": "Desktop English Sidebar Logo Crop", "file": str(p_logo)})
        except Exception as e:
            print(f"Error cropping sidebar logo: {e}")

        await context_desk_en_dark.close()

        # ----------------------------------------------------------------------
        # TEST 4: Desktop RTL (Persian) - Light Theme - 1440x900
        # ----------------------------------------------------------------------
        print("\n--- TEST 4: Desktop RTL (Persian) Light Mode (1440x900) ---")
        context_desk_fa_light = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            locale="fa-IR",
        )
        await setup_page_prefs(context_desk_fa_light, "fa", "light")
        page_d_fa = await context_desk_fa_light.new_page()

        print("[8/8] Loading Desktop Persian Light Dashboard...")
        await page_d_fa.goto(f"{BASE_URL}/dashboard", wait_until="commit", timeout=45000)
        await page_d_fa.wait_for_timeout(6000)
        p8 = OUT_DIR / "final-desktop-fa-light-dashboard.png"
        await page_d_fa.screenshot(path=str(p8))
        print(f"Captured: {p8}")
        report.append({"test": "Desktop Persian Light Dashboard", "file": str(p8)})

        await context_desk_fa_light.close()
        await browser.close()

    summary_file = OUT_DIR / "verification_summary.json"
    summary_file.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nVerification complete. Summary written to {summary_file}")


if __name__ == "__main__":
    asyncio.run(main())
