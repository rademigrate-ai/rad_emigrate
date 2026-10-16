"""Capture actual Flutter fixture screens; never production/customer records."""
import asyncio
import json
import os
from pathlib import Path
from playwright.async_api import async_playwright

OUT = Path('docs/qa/pr54/redesign')
BASE = os.environ.get('RAD_QA_BASE_URL', 'http://127.0.0.1:8824/')
SCREENS = ['shell', 'dashboard', 'visa', 'ai', 'cases', 'documents', 'profile',
           'world-time', 'login', 'register', 'otp', 'forgot-password',
           'reset-password', 'profile-completion', 'consultation', 'feed',
           'notifications', 'admin', 'not-found']
SIZES = {'mobile': (390, 844), 'tablet': (834, 1112), 'desktop': (1440, 900)}


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    captures = []
    semaphore = asyncio.Semaphore(3)
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel='chrome', headless=True)

        async def capture(screen, locale, theme, size, dimensions):
            async with semaphore:
                page = await browser.new_page(viewport=dict(zip(('width', 'height'), dimensions)), reduced_motion='reduce')
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
                url = f'{BASE}?screen={screen}&locale={locale}&theme={theme}&capture=1'
                response = await page.goto(url, wait_until='networkidle', timeout=90000)
                await page.wait_for_selector('flt-glass-pane', state='attached')
                await page.wait_for_timeout(1000)
                filename = f'{size}-{locale}-{theme}-{screen}.png'
                await page.screenshot(path=str(OUT / filename))
                captures.append(dict(file=filename, screen=screen, locale=locale, theme=theme,
                                     viewport=list(dimensions), status=response.status, errors=errors))
                await page.close()

        await asyncio.gather(*(capture(screen, locale, theme, size, dimensions)
                               for size, dimensions in SIZES.items()
                               for locale in ['en', 'fa'] for theme in ['light', 'dark']
                               for screen in SCREENS))
        await browser.close()
    captures.sort(key=lambda item: item['file'])
    (OUT / 'capture-manifest.json').write_text(json.dumps(dict(
        evidence='Actual Flutter Web pages with synthetic fixture repositories; not authenticated production testing.',
        limitations=['Notifications captures show the unavailable-service state.',
                     'Reset-password captures show the invalid/missing recovery-session state; valid recovery requires a real session.',
                     'No physical Android or iOS device execution.'], captures=captures), indent=2), encoding='utf-8')
    print(json.dumps(dict(captures=len(captures), with_errors=sum(bool(c['errors']) for c in captures))))


if __name__ == '__main__':
    asyncio.run(main())
