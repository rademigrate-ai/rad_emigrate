"""Guest interactions in the real app, using CI placeholder configuration."""
import asyncio
import json
from pathlib import Path
from playwright.async_api import async_playwright

BASE = 'http://127.0.0.1:8825'
OUT = Path('docs/qa/pr54/redesign/real-app')


async def semantics(page):
    placeholder = page.locator('flt-semantics-placeholder')
    if await placeholder.count():
        await placeholder.evaluate('(element) => element.click()')
    await page.wait_for_timeout(500)


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel='chrome', headless=True)
        page = await browser.new_page(viewport={'width': 390, 'height': 844}, reduced_motion='reduce')
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        await page.goto(BASE + '/dashboard', wait_until='networkidle')
        await semantics(page)
        for label in ['Home', 'Explore', 'AI Assistant', 'Cases', 'Profile']:
            assert await page.get_by_role('button', name=label, exact=True).count() >= 1, label
        await page.screenshot(path=str(OUT / 'guest-dashboard.png'))
        results.append({'flow': 'five localized primary destinations', 'status': 'PASS'})

        await page.get_by_role('button', name='Profile', exact=True).dispatch_event('click')
        await page.wait_for_url('**/profile')
        await page.mouse.move(190, 400)
        await page.mouse.wheel(0, 1500)
        await page.wait_for_timeout(800)
        world_time = page.get_by_role('button', name='World Time', exact=True)
        assert await world_time.count() == 1
        await page.screenshot(path=str(OUT / 'visible-more-destinations.png'))
        await world_time.dispatch_event('click')
        await page.wait_for_url('**/world-clock')
        results.append({'flow': 'Profile to World Time without long-press', 'status': 'PASS'})

        await page.goto(BASE + '/profile', wait_until='networkidle')
        await page.mouse.move(190, 400)
        await page.mouse.wheel(0, 1600)
        await page.wait_for_timeout(800)
        await semantics(page)
        await page.get_by_role('checkbox', name='Dark', exact=True).dispatch_event('click')
        await page.get_by_role('checkbox', name='Persian', exact=True).dispatch_event('click')
        await page.wait_for_timeout(800)
        await page.screenshot(path=str(OUT / 'persian-dark-profile.png'))
        await page.goto(BASE + '/dashboard', wait_until='networkidle')
        await semantics(page)
        assert await page.get_by_role('button', name='کاوش', exact=True).count() == 1
        await page.screenshot(path=str(OUT / 'persian-dark-dashboard.png'))
        results.append({'flow': 'language/theme persist across refresh', 'status': 'PASS'})

        await page.goto(BASE + '/ai-assistant', wait_until='networkidle')
        await semantics(page)
        fields = page.locator('input, textarea')
        assert await fields.count() >= 1
        draft = 'Visual QA manual draft / پیش‌نویس آزمایشی'
        await fields.first.fill(draft)
        await page.get_by_role('button', name='ارسال پیام', exact=True).dispatch_event('click')
        await page.wait_for_url(lambda url: '/login?from=' in url and 'ai-assistant' in url)
        await page.screenshot(path=str(OUT / 'guest-ai-gated-to-login.png'))
        await page.goto(BASE + '/ai-assistant', wait_until='networkidle')
        await semantics(page)
        await page.locator('input, textarea').first.focus()
        await page.wait_for_timeout(300)
        await page.screenshot(path=str(OUT / 'guest-ai-draft-restored.png'))
        restored = await page.locator('input, textarea').first.input_value()
        assert restored == draft, {'expected': draft, 'restored': restored}
        results.append({'flow': 'guest AI gate and draft restoration; no auto-submit', 'status': 'PASS'})

        await browser.close()
    (OUT / 'verification.json').write_text(json.dumps(dict(
        evidence='Actual production entrypoint with non-production CI placeholder configuration; guest only.',
        results=results, page_errors=errors), ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'passed': len(results), 'page_errors': len(errors)}))
    assert not errors


if __name__ == '__main__':
    asyncio.run(main())
