"""Capture actual Flutter fixture screens; never production/customer records."""
import asyncio
import json
import os
from pathlib import Path
from playwright.async_api import async_playwright

OUT = Path(os.environ.get('RAD_QA_OUTPUT', 'docs/qa/pr54/redesign'))
BASE = os.environ.get('RAD_QA_BASE_URL', 'http://127.0.0.1:8824/')
SCREENS = ['shell', 'dashboard', 'visa', 'ai', 'cases', 'documents', 'profile',
           'world-time', 'ai-empty', 'splash', 'loading', 'bird-states', 'login', 'register', 'otp', 'forgot-password',
           'reset-password', 'profile-completion', 'consultation', 'feed',
           'notifications', 'admin', 'not-found']
if os.environ.get('RAD_QA_SCREENS'):
    SCREENS = os.environ['RAD_QA_SCREENS'].split(',')
SIZES = {'mobile': (390, 844), 'tablet': (834, 1112), 'desktop': (1440, 900)}


if os.environ.get('RAD_QA_SIZES'):
    SIZES = {key: SIZES[key] for key in os.environ['RAD_QA_SIZES'].split(',')}


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    captures = []
    # Isolate GPU processes: sharing one Chromium instance across many
    # CanvasKit pages can leave decoded assets waiting indefinitely on Windows.
    semaphore = asyncio.Semaphore(2)
    async with async_playwright() as p:
        # Restart Chromium between locale/theme/viewport batches so hundreds
        # of CanvasKit pages cannot exhaust a shared GPU process.
        for size, dimensions in SIZES.items():
            for locale in ['en', 'fa']:
                for theme in ['light', 'dark']:
                    async def capture(screen):
                        async with semaphore:
                            attempts = []
                            for attempt in range(4):
                                browser = await p.chromium.launch(channel='chrome', headless=True)
                                page = await browser.new_page(viewport=dict(zip(('width', 'height'), dimensions)), reduced_motion='reduce')
                                await page.add_init_script(f"localStorage.setItem('flutter.rad_locale', JSON.stringify('{locale}')); localStorage.setItem('flutter.rad_theme_mode', JSON.stringify('{theme}'));")
                                errors = []
                                page.on('pageerror', lambda error: errors.append(str(error)))
                                page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
                                url = f'{BASE}?screen={screen}&locale={locale}&theme={theme}&capture=1'
                                if os.environ.get('RAD_QA_DOCK') == '1' and screen in ['shell', 'dashboard', 'visa', 'ai', 'ai-empty', 'cases', 'documents', 'profile', 'world-time', 'feed']:
                                    url += '&dock=1'
                                try:
                                    response = await page.goto(url, wait_until='networkidle', timeout=90000)
                                    await page.wait_for_selector('flt-glass-pane', state='attached', timeout=60000)
                                    placeholder = page.locator('flt-semantics-placeholder')
                                    if await placeholder.count():
                                        await placeholder.evaluate('(element) => element.click()')
                                    await page.wait_for_function('window.radQaAssetsReady === true', timeout=30000)
                                    await page.wait_for_timeout(1400)
                                    if errors:
                                        raise RuntimeError('; '.join(errors))
                                    filename = f'{size}-{locale}-{theme}-{screen}.png'
                                    await page.screenshot(path=str(OUT / filename))
                                    captures.append(dict(file=filename, screen=screen, locale=locale, theme=theme,
                                                         viewport=list(dimensions), status=response.status, errors=errors, retries=attempts))
                                    (OUT / 'capture-progress.json').write_text(json.dumps(captures, indent=2), encoding='utf-8')
                                    return
                                except Exception as error:
                                    attempts.append(str(error))
                                    if attempt == 3:
                                        raise
                                finally:
                                    await browser.close()

                    await asyncio.gather(*(capture(screen) for screen in SCREENS))
                    print(f'{size} {locale} {theme}: {len(SCREENS)} captured', flush=True)
    if os.environ.get('RAD_QA_MERGE') == '1' and (OUT / 'capture-manifest.json').exists():
        previous = json.loads((OUT / 'capture-manifest.json').read_text(encoding='utf-8'))['captures']
        merged = {capture['file']: capture for capture in previous}
        merged.update({capture['file']: capture for capture in captures})
        captures = list(merged.values())
    captures.sort(key=lambda item: item['file'])
    (OUT / 'capture-manifest.json').write_text(json.dumps(dict(
        evidence='Actual Flutter Web pages with synthetic fixture repositories; not authenticated production testing.',
        limitations=['Notifications captures show the unavailable-service state.',
                     'Reset-password captures show the invalid/missing recovery-session state; valid recovery requires a real session.',
                     'No physical Android or iOS device execution.'], captures=captures), indent=2), encoding='utf-8')
    print(json.dumps(dict(captures=len(captures), with_errors=sum(bool(c['errors']) for c in captures))))


if __name__ == '__main__':
    asyncio.run(main())
