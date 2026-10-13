"""Real JWT + Chrome acceptance using synthetic, non-immigration local evidence.

Only the named disposable 47+5 stack is permitted. No external research or AI
provider is contacted. Feed fixtures are removed with the human guard intact.
"""
import argparse
import asyncio
import hashlib
import json
import re
import time
import uuid
from pathlib import Path

from playwright.async_api import async_playwright
from verify_stage2_browser_e2e import (
    BrowserAcceptance, LocalSupabaseFixtures, load_local_environment, require, serve_web,
)
from verify_prepilot_consultation import access_token
from verify_prod_equiv_rpc_acceptance import psql


async def browser_workflow(fixtures, admin, user, draft, title, web_root, artifacts, result):
    result.update({"rpc_responses": [], "cold_start": []})
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(channel="chrome", headless=True)
        try:
            with serve_web(web_root, 3311) as base:
                acceptance = BrowserAcceptance(browser, base, artifacts, fixtures,
                                               user, user, admin, admin)
                for width, height in ((1280, 800), (390, 844)):
                    context, page, problems = await acceptance.new_context(width, height)
                    try:
                        started = time.monotonic()
                        await acceptance.goto(page, "/")
                        await page.get_by_label("Email", exact=True).wait_for(state="attached", timeout=30000)
                        elapsed = round((time.monotonic() - started) * 1000)
                        await page.screenshot(path=artifacts / f"cold-start-{width}.png")
                        require(not problems, "cold-start console errors: " + str(problems))
                        result["cold_start"].append({"viewport": [width, height], "interactive_ms": elapsed,
                                                     "terminal_route": page.url.split(base)[-1]})
                    finally:
                        await context.close()
                context, page, problems = await acceptance.new_context(1280, 800)
                try:
                    page.on("response", lambda response: result["rpc_responses"].append({
                        "rpc": response.url.split('/rpc/')[-1].split('?')[0], "status": response.status,
                    }) if '/rest/v1/rpc/' in response.url else None)
                    await acceptance.sign_in(page, admin)
                    async def open_draft():
                        await acceptance.goto(page, "/admin/operations")
                        await acceptance.click(page.get_by_text("Under review", exact=True).first)
                        # Flutter merges a ListTile's title, subtitle and status
                        # into one semantics node; exact text is not its label.
                        await page.screenshot(path=artifacts / "review-queue.png", full_page=True)
                        result['review_semantics'] = await page.locator('flt-semantics').evaluate_all(
                            "nodes => nodes.map(n => n.getAttribute('aria-label') || n.textContent || '').filter(Boolean)"
                        )
                        # ListTile exposes merged copy in aria-label, not a DOM
                        # text child. Use its actual accessible name.
                        await acceptance.click(page.get_by_label(re.compile(re.escape(title))).last)
                        await page.get_by_label("Title", exact=True).wait_for(state="attached")
                    await open_draft()
                    await page.screenshot(path=artifacts / "review-unapproved.png", full_page=True)
                    await acceptance.click(page.get_by_role("button", name="Approve", exact=True))
                    await page.get_by_label("Title", exact=True).wait_for(state="detached")
                    row = fixtures.expect_json("GET", f"/rest/v1/content_drafts?select=status&id=eq.{draft}")[0]
                    require(row['status'] == 'approved', "Chrome approval did not persist")
                    require(psql("select count(*) from public.feed_items") == '0', "approval auto-published")
                    await open_draft()
                    await page.screenshot(path=artifacts / "approved-before-publish.png", full_page=True)
                    await acceptance.click(page.get_by_role("button", name="Publish", exact=True))
                    await page.get_by_label("Title", exact=True).wait_for(state="detached")
                    row = fixtures.expect_json("GET", f"/rest/v1/content_drafts?select=status,feed_item_id&id=eq.{draft}")[0]
                    require(row['status'] == 'published' and row['feed_item_id'], "Chrome publication did not persist")
                    result['published_feed_id'] = row['feed_item_id']
                    await acceptance.goto(page, "/feed")
                    # The editorial card exposes its title as the button's
                    # accessible label rather than a separate text node.
                    await page.get_by_label(re.compile(re.escape(title))).last.wait_for(state='attached')
                    await page.screenshot(path=artifacts / "feed-explicit-publication.png", full_page=True)
                    require(not problems, "Admin workflow browser errors: " + str(problems))
                    result['console_errors'] = problems
                    result['chrome_approve_publish_feed'] = 'PASS'
                finally:
                    await context.close()
        finally:
            await browser.close()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--web-root', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    args = parser.parse_args()
    env = load_local_environment()
    require(env['API_URL'] == 'http://127.0.0.1:56321', 'refusing any other stack')
    build = (args.web_root / 'main.dart.js').read_text(encoding='utf-8')
    require(env['API_URL'] in build and 'inshddthftkhcdosoqcn' not in build,
            'web artifact must be compiled exclusively for this local stack')
    args.artifacts.mkdir(parents=True, exist_ok=False)
    fixtures = LocalSupabaseFixtures(env)
    doc, job = str(uuid.uuid4()), str(uuid.uuid4())
    title = 'Synthetic engineering fixture ' + uuid.uuid4().hex[:8]
    result = {'result': 'FAIL', 'synthetic_only': True, 'checks': {}}
    admin = user = None
    try:
        require(psql('select count(*) from public.feed_items') == '0', 'expected empty disposable Feed')
        user, admin = fixtures.create_identity('user'), fixtures.create_identity('admin')
        user_token, admin_token = access_token(fixtures, user), access_token(fixtures, admin)
        fixtures.expect_json('POST', '/rest/v1/source_documents', payload=[{
            'id': doc, 'canonical_url': f'https://example.test/synthetic/{doc}',
            'source_authority': 'other', 'title': title, 'language_code': 'en',
        }], prefer='return=representation')
        fixtures.expect_json('POST', '/rest/v1/research_jobs', payload=[{
            'id': job, 'job_type': 'targeted_research', 'trigger_type': 'manual',
            'idempotency_key': job, 'requested_by': admin.user_id,
        }], prefer='return=representation')
        evidence = 'SYNTHETIC ENGINEERING TEST ONLY. Contains no immigration advice or factual claims.'
        payload = {'p_job_id': job, 'p_document_id': doc,
                   'p_content_hash': hashlib.sha256(evidence.encode()).hexdigest(),
                   'p_normalized_text': evidence, 'p_http_status': 200, 'p_metadata': {'synthetic': True}}
        for token, label in ((fixtures.anon_key, 'anon_ingest'), (user_token, 'user_ingest')):
            status, _, _ = fixtures.request('POST', '/rest/v1/rpc/ingest_research_snapshot', token=token, payload=payload)
            require(status in (401,403), label + ' was not denied')
            result['checks'][label] = status
        finding = fixtures.expect_json('POST', '/rest/v1/rpc/ingest_research_snapshot', payload=payload)
        duplicate = fixtures.expect_json('POST', '/rest/v1/rpc/ingest_research_snapshot', payload=payload)
        require(duplicate is None, 'duplicate research was not idempotent')
        draft = fixtures.expect_json('GET', f'/rest/v1/content_drafts?select=id,title,status&research_finding_id=eq.{finding}')
        require(len(draft) == 1 and draft[0]['status'] == 'review', 'atomic review candidate absent')
        draft, title = draft[0]['id'], draft[0]['title']
        require(psql('select count(*) from public.feed_items') == '0', 'research auto-published')
        for token, label, rpc, body in (
            (user_token, 'user_approval', 'set_content_draft_status', {'p_draft_id': draft, 'p_status': 'approved'}),
            (user_token, 'user_publish', 'publish_content_draft', {'p_draft_id': draft}),
            (fixtures.service_key, 'service_publish', 'publish_content_draft', {'p_draft_id': draft}),
            (admin_token, 'unapproved_publish', 'publish_content_draft', {'p_draft_id': draft}),
        ):
            status, _, _ = fixtures.request('POST', '/rest/v1/rpc/' + rpc, token=token, payload=body)
            require(status in (400,401,403), label + ' was not denied')
            result['checks'][label] = status
        result['research_atomic_review_no_publication'] = 'PASS'
        result['browser'] = {}
        asyncio.run(browser_workflow(fixtures, admin, user, draft, title, args.web_root.resolve(), args.artifacts, result['browser']))
        again = fixtures.expect_json('POST', '/rest/v1/rpc/publish_content_draft', token=admin_token,
                                     payload={'p_draft_id': draft})
        require(again == result['browser']['published_feed_id'], 'publication was not idempotent')
        result['result'] = 'PASS'
    finally:
        if admin:
            # Local fixture-only cleanup with original human trigger predicates;
            # never disable RLS/triggers or relax grants for test cleanup.
            psql(f"begin; select set_config('request.jwt.claim.sub','{admin.user_id}',true); "
                 f"select set_config('rad.human_publish_actor','{admin.user_id}',true); "
                 f"delete from public.feed_items where id in (select feed_item_id from public.content_drafts where research_job_id='{job}'); "
                 f"delete from public.content_drafts where research_job_id='{job}'; "
                 f"delete from public.research_jobs where id='{job}'; "
                 f"delete from public.source_documents where id='{doc}'; commit;")
        fixtures.cleanup()
        result['fixtures_cleaned'] = True
        (args.artifacts / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
