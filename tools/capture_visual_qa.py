import asyncio
from pathlib import Path

from playwright.async_api import async_playwright

OUT = Path('docs/visual_qa')
OUT.mkdir(parents=True, exist_ok=True)

TARGETS = [
    ('login_after_desktop.png', 'http://127.0.0.1:8083/#/login', {'width': 1280, 'height': 800}),
    ('login_after_mobile.png', 'http://127.0.0.1:8083/#/login', {'width': 390, 'height': 844}),
    ('dashboard_after_desktop.png', 'http://127.0.0.1:8084/?screen=dashboard&capture=1', {'width': 1280, 'height': 800}),
    ('dashboard_after_mobile.png', 'http://127.0.0.1:8084/?screen=dashboard&capture=1', {'width': 390, 'height': 844}),
    ('visa_after_desktop.png', 'http://127.0.0.1:8084/?screen=visa&capture=1', {'width': 1280, 'height': 800}),
    ('visa_after_mobile.png', 'http://127.0.0.1:8084/?screen=visa&capture=1', {'width': 390, 'height': 844}),
    ('ai_after_desktop.png', 'http://127.0.0.1:8084/?screen=ai&capture=1', {'width': 1280, 'height': 800}),
    ('feed_after_desktop.png', 'http://127.0.0.1:8084/?screen=feed&capture=1', {'width': 1280, 'height': 800}),
    ('admin_after_desktop.png', 'http://127.0.0.1:8084/?screen=admin&capture=1', {'width': 1280, 'height': 800}),
]

async def main():
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path='/usr/bin/chromium',
            headless=True,
            args=['--no-sandbox'],
        )
        for filename, url, viewport in TARGETS:
            page = await browser.new_page(viewport=viewport, device_scale_factor=1)
            await page.goto(url, wait_until='networkidle', timeout=60000)
            await page.wait_for_timeout(4500)
            await page.screenshot(path=str(OUT / filename), full_page=False)
            await page.close()
        await browser.close()

if __name__ == '__main__':
    asyncio.run(main())
