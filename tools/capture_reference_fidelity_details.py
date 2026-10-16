"""Real Flutter detail, scroll and accessibility evidence using fixture data."""
import asyncio
import json
import os
import re
from pathlib import Path
from playwright.async_api import async_playwright

BASE = os.environ.get('RAD_QA_BASE_URL', 'http://127.0.0.1:8826/')
OUT = Path('docs/qa/pr54/fidelity/details')


async def enable_semantics(page):
    placeholder = page.locator('flt-semantics-placeholder')
    if await placeholder.count():
        await placeholder.evaluate('(element) => element.click()')
    await page.wait_for_timeout(500)


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel='chrome', headless=True)
        for locale in ['en', 'fa']:
            for theme in ['light', 'dark']:
                page = await browser.new_page(viewport={'width': 390, 'height': 844}, reduced_motion='reduce')
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.on('console', lambda msg: errors.append(msg.text) if msg.type == 'error' else None)

                async def open_screen(screen, scale=1):
                    await page.goto(f'{BASE}?screen={screen}&locale={locale}&theme={theme}&capture=1&dock=1&scale={scale}', wait_until='networkidle')
                    await enable_semantics(page)

                async def save(name):
                    filename = f'{locale}-{theme}-{name}.png'
                    await page.wait_for_load_state('networkidle')
                    await page.wait_for_timeout(1600)
                    await page.screenshot(path=str(OUT / filename))
                    records.append({'file': filename, 'viewport': page.viewport_size, 'errors': list(errors)})

                for screen, label, name in [
                    ('cases', 'Sample study pathway' if locale == 'en' else 'پرونده آزمایشی تحصیل', 'case-detail'),
                    ('documents', 'Sample passport' if locale == 'en' else 'گذرنامه آزمایشی', 'document-actions'),
                    ('world-time', 'Tehran' if locale == 'en' else 'تهران', 'city-detail'),
                    ('profile', 'Edit profile' if locale == 'en' else 'ویرایش پروفایل', 'profile-edit'),
                ]:
                    await open_screen(screen)
                    await page.get_by_role('button', name=re.compile(re.escape(label))).first.dispatch_event('click')
                    await save(name)

                await open_screen('dashboard')
                await page.mouse.move(190, 400)
                await page.mouse.wheel(0, 450)
                await save('dashboard-image-cards')

                await open_screen('profile')
                await page.mouse.move(190, 400)
                await page.mouse.wheel(0, 450)
                await save('settings-more')

                await page.set_viewport_size({'width': 320, 'height': 844})
                for screen in ['dashboard', 'visa', 'ai-empty', 'cases', 'documents', 'profile', 'world-time', 'splash']:
                    # Splash must remain pending in its dedicated fixture, not
                    # wrapped in a shell with an invented onboarding route.
                    suffix = '' if screen == 'splash' else '&dock=1'
                    await page.goto(f'{BASE}?screen={screen}&locale={locale}&theme={theme}&capture=1&scale=2{suffix}', wait_until='networkidle')
                    await save(f'narrow-200pct-{screen}')

                await open_screen('ai-empty')
                await page.locator('input, textarea').first.fill('Visual QA focus / آزمایش تمرکز')
                await page.set_viewport_size({'width': 320, 'height': 500})
                await save('focused-composer-reduced-viewport')
                await page.close()
        await browser.close()
    (OUT / 'manifest.json').write_text(json.dumps({'evidence': 'Actual Flutter fixture rendering. Focused composer uses a reduced browser viewport; this is not native keyboard testing.', 'captures': records}, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'captures': len(records), 'with_errors': sum(bool(r['errors']) for r in records)}))
    assert not any(r['errors'] for r in records)


if __name__ == '__main__':
    asyncio.run(main())
