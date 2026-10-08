import asyncio
from pathlib import Path

from playwright.async_api import async_playwright

OUT = Path('docs/visual_qa/motion_frames')
OUT.mkdir(parents=True, exist_ok=True)

async def main():
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path='/usr/bin/chromium',
            headless=True,
            args=['--no-sandbox'],
        )
        page = await browser.new_page(viewport={'width': 1280, 'height': 800}, device_scale_factor=1)
        await page.goto('http://127.0.0.1:8083/#/login?motion_capture=1', wait_until='networkidle', timeout=60000)
        await page.wait_for_timeout(1200)
        for index in range(12):
            await page.screenshot(path=str(OUT / f'frame_{index:03d}.png'))
            await page.wait_for_timeout(125)
        # Real focus interaction: tap the visible email field.
        await page.mouse.click(680, 350)
        for index in range(12, 25):
            await page.screenshot(path=str(OUT / f'frame_{index:03d}.png'))
            await page.wait_for_timeout(125)
        await browser.close()

if __name__ == '__main__':
    asyncio.run(main())
