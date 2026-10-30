/* Read-only real Flutter browser acceptance against a marked QA runtime.
 * Default: exact local V4 stack. Explicit staging mode: epolbumcfbohtmgvomki
 * only; private hosted automation is blocked without credential extraction.
 * Uses installed Chrome and Playwright, as tools/test_real_app_smoke.py does.
 * Route/title receipts do not replace the independent structural corpus audit.
 */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {chromium} = require('playwright');

const argv = process.argv.slice(2);
const arg = (name, fallback) => { const i = argv.indexOf('--' + name); return i < 0 ? fallback : argv[i + 1]; };
const environmentMode=arg('environment','local');
if(!['local','staging'].includes(environmentMode)) throw Error('only_local_or_explicit_staging_environment_supported');
const staging=environmentMode==='staging';
const runtime = path.resolve(arg('runtime', ''));
const output = path.resolve(arg('output', 'build/content-v4-browser'));
const base = arg('base-url', staging?'http://127.0.0.1:64333':'http://127.0.0.1:64332');
const limit = Number(arg('limit', '0'));
const headsFile = arg('heads-file', null);
const read = name => JSON.parse(fs.readFileSync(path.join(runtime, name), 'utf8'));
const marker = read(staging?'RAD_STAGING_BROWSER_READ_ONLY.json':'RAD_DISPOSABLE_LOCAL_ONLY.json');
const config = read('flutter-public.json');
if(staging) {
  if(runtime!==path.resolve('_scratch/v4-staging-runtime')||marker.project!=='epolbumcfbohtmgvomki'||marker.environment!=='staging:epolbumcfbohtmgvomki'||marker.read_only!==true||config.SUPABASE_URL!=='https://epolbumcfbohtmgvomki.supabase.co'||base!=='http://127.0.0.1:64333') throw Error('exact_marked_read_only_staging_targets_required');
} else if (marker.project !== 'rad_full_content_v4_20261028' || marker.port !== 64522 || config.SUPABASE_URL !== 'http://127.0.0.1:64521' || base !== 'http://127.0.0.1:64332') throw Error('exact_marked_loopback_QA_targets_required');
const authKey='sb-'+new URL(config.SUPABASE_URL).hostname.split('.')[0]+'-auth-token';
const readRpcs=new Set(['get_editorial_article','get_editorial_reference_links','get_visa_article','get_visa_catalog','list_editorial_library','list_country_visa_content','list_visa_content_countries']);
function permittedStageRequest(method,url) {
  if(['GET','HEAD','OPTIONS'].includes(method)) return true;
  const parsed=new URL(url);
  return method==='POST'&&(parsed.pathname.startsWith('/rest/v1/rpc/')&&readRpcs.has(parsed.pathname.split('/').pop())||parsed.pathname==='/auth/v1/token'&&['password','refresh_token'].includes(parsed.searchParams.get('grant_type')));
}
// Hosted verification must use the owner's existing native browser session.
// Never read/export its passwords, cookies or auth tokens into this harness.
const accounts = staging?[]:read('qa-accounts.private.json').accounts;
const key = config.SUPABASE_PUBLISHABLE_KEY || config.SUPABASE_ANON_KEY;
fs.mkdirSync(output, {recursive:true});
const report = {
  head:execFileSync('git', ['-c','safe.directory=*','rev-parse','HEAD'], {encoding:'utf8'}).trim(),
  environment:(staging?'staging:':'local:')+marker.project, project:marker.project, api_url:config.SUPABASE_URL,
  frontend_url:base,
  scope:'explicit environment only; real Flutter route, title and first/final retained-block rendering plus complete RPC-body comparison; separate source-preservation auditor required',
  publication_operations:0, account_changes:0, hosted_operations:0,
  auth_session_operations:0, hosted_browser_requests:0, blocked_write_requests:[],
  discovery:[], countries:[], mobile_readers:[], security:[], readers:[],
};
const save = () => fs.writeFileSync(path.join(output,'report.json'), JSON.stringify(report,null,2));
const canonical = value => Array.isArray(value)?'['+value.map(canonical).join(',')+']':value&&typeof value==='object'?'{'+Object.keys(value).sort().map(key=>JSON.stringify(key)+':'+canonical(value[key])).join(',')+'}':JSON.stringify(value);
const hash = value => crypto.createHash('sha256').update(canonical(value)).digest('hex');
async function api(url, payload, token) {
  if(staging&&!permittedStageRequest(payload===undefined?'GET':'POST',config.SUPABASE_URL+url)) throw Error('non_readonly_staging_request_blocked');
  if(staging) report.hosted_operations++;
  const response = await fetch(config.SUPABASE_URL + url, {
    method:payload === undefined ? 'GET' : 'POST',
    headers:{apikey:key, Authorization:'Bearer ' + (token || key), 'Content-Type':'application/json'},
    body:payload === undefined ? undefined : JSON.stringify(payload),
    redirect:'error', signal:AbortSignal.timeout(45000),
  });
  if (!response.ok) throw Error('local_API_status_' + response.status);
  return response.json();
}
const rpc = (name, params, token) => api('/rest/v1/rpc/' + name, params, token);
async function login(role) {
  if(staging) throw Error('hosted_credential_automation_forbidden_existing_native_session_required');
  const account = accounts.find(account => account.role === role);
  if (!account) throw Error('existing_local_fixture_account_required');
  if(account.session) return account.session;
  report.auth_session_operations++;
  return api('/auth/v1/token?grant_type=password', {email:account.email,password:account.password});
}
async function contextFor(browser, viewport, locale, session) {
  const context = await browser.newContext({viewport, locale:locale === 'fa' ? 'fa-IR' : 'en-US'});
  if(staging) {
    context.on('request',request=>{if(request.url().startsWith(config.SUPABASE_URL+'/')) report.hosted_browser_requests++;});
    await context.route(config.SUPABASE_URL+'/**',async route=>{
      const request=route.request();
      if(permittedStageRequest(request.method(),request.url())) await route.continue();
      else {report.blocked_write_requests.push({method:request.method(),path:new URL(request.url()).pathname});await route.abort('blockedbyclient');}
    });
  }
  await context.addInitScript(state => {
    localStorage.setItem('flutter.rad_locale', JSON.stringify(state.locale));
    localStorage.setItem('flutter.rad_theme_mode', JSON.stringify('light'));
    // Preserve real GoTrue refreshes during long exhaustive runs.
    if (state.session && !localStorage.getItem(state.authKey)) localStorage.setItem(state.authKey, JSON.stringify(state.session));
  }, {locale,session,authKey});
  return context;
}
async function semantics(page) {
  await page.waitForSelector('flutter-view', {timeout:90000});
  for (let i=0;i<40;i++) {
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.first().evaluate(element=>element.click());
    if (await page.locator('flt-semantics').count()) return;
    await page.waitForTimeout(300);
  }
  throw Error('Flutter_semantics_unavailable');
}
function renderLeaf(block) {
  const original=block.current_structure || block.original_structure || block;
  if(original.type==='table') {
    for(const row of original.rows||[]) for(const cell of row) if(typeof cell.text==='string'&&cell.text.trim()) return cell.text;
  }
  if(original.type==='bullet_list'||original.type==='numbered_list') {
    for(const item of original.items||[]) {
      const text=typeof item==='string'?item:item.text;
      if(typeof text==='string'&&text.trim()) return text;
    }
  }
  return original.text || original.caption || original.alt || original.url || '';
}
async function probeBlock(page,route,block) {
  await page.goto(base+route+'#'+encodeURIComponent(block.id),{waitUntil:'domcontentloaded'});
  await semantics(page);
  await page.getByText(renderLeaf(block).slice(0,160),{exact:false}).first().waitFor({state:'visible',timeout:60000});
}
async function main() {
  if(staging) {
    report.all_passed=false;
    report.blocker='Hosted private QA requires the existing signed-in native browser session; password, cookie and token extraction is forbidden.';
    save();
    console.error(report.blocker);
    process.exitCode=2;
    return;
  }
  let session = await login('super_admin');
  let token = session.access_token;
  let heads = headsFile ? JSON.parse(fs.readFileSync(headsFile,'utf8')) : [];
  if(headsFile&&heads.some(head=>head.environment&&head.environment!==report.environment)) throw Error('expected_head_manifest_environment_mismatch');
  while (!headsFile) {
    const page = await api('/rest/v1/visa_article_heads?select=article_id,locale&order=article_id,locale&limit=500&offset=' + heads.length, undefined, token);
    heads.push(...page);
    if (page.length < 500) break;
  }
  report.reader_rows_total = heads.length;
  report.reader_selection_source=headsFile?'expected_active_destination_manifest':'all_admin_visible_heads';
  if (!heads.length) throw Error('admin_visible_article_heads_required');
  if (limit) heads = heads.slice(0,limit);
  report.reader_rows_selected = heads.length;
  report.exhaustive_reader_selection = heads.length === report.reader_rows_total;
  const browser = await chromium.launch({executablePath:arg('chrome','C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'),headless:true,args:['--disable-gpu-sandbox']});
  try {
    for (const viewport of [{width:1280,height:900},{width:390,height:844}]) {
      for (const locale of ['fa','en']) {
        for (const preview of [false,true]) {
          const context = await contextFor(browser,viewport,locale,preview?session:null);
          const page = await context.newPage();
          const errors=[];
          page.on('pageerror',error=>errors.push(String(error)));
          const route = '/visa/other-titles' + (preview?'?preview=true':'');
          await page.goto(base+route,{waitUntil:'domcontentloaded'});
          await semantics(page);
          await page.getByText(locale==='fa'?'دیگر عناوین':'Other Titles',{exact:true}).first().waitFor({state:'visible',timeout:60000});
          const expected = (await rpc('list_editorial_library',{p_locale:locale,p_preview:preview,p_offset:0,p_limit:20},preview?token:null)).data;
          if (expected.items.length) await page.getByText(expected.items[0].title,{exact:true}).first().waitFor({state:'visible',timeout:60000});
          else {
            const empty = preview ? (locale==='fa'?'در این صفحه از فهرست بازبینی، عنوان مستقلی وجود ندارد.':'No independent articles on this review page.') : (locale==='fa'?'مقاله منتشرشده‌ای در این صفحه موجود نیست.':'No published articles on this page.');
            await page.getByText(empty,{exact:true}).waitFor({state:'visible',timeout:60000});
          }
          const screenshot=`library-${locale}-${viewport.width}-${preview?'preview':'public'}.png`;
          await page.screenshot({path:path.join(output,screenshot)});
          report.discovery.push({route,locale,width:viewport.width,preview,passed:errors.length===0,errors,screenshot,returned_cards:expected.items.length});
          save();
          await context.close();
        }
      }
    }
    for (const role of [null,'user_a']) {
      if(role&&!accounts.some(account=>account.role===role)) {report.security.push({role,passed:false,blocker:'ordinary_authenticated_fixture_not_provided'});save();continue;}
      const context=await contextFor(browser,{width:390,height:844},'en',role?await login(role):null);
      const page=await context.newPage();
      await page.goto(base+'/visa/other-titles?preview=true',{waitUntil:'domcontentloaded'});
      await semantics(page);
      await page.getByText('Articles unavailable; retry',{exact:true}).waitFor({state:'visible',timeout:60000});
      const draft=heads[0];
      for(const preview of [true,false]) {
        await page.goto(base+`/visa/content/${draft.article_id}?locale=${draft.locale}${preview?'&preview=true':''}`,{waitUntil:'domcontentloaded'});
        await semantics(page);
        await page.getByText(draft.locale==='fa'?'محتوا یا ترجمه در دسترس نیست.':'Content or translation is unavailable.',{exact:true}).waitFor({state:'visible',timeout:60000});
      }
      report.security.push({role:role||'anonymous',library_preview_denied:true,private_reader_preview_denied:true,private_reader_public_route_denied:true,passed:true});
      save();
      await context.close();
    }
    for(const locale of ['fa','en']) {
      const countryContext=await contextFor(browser,{width:1280,height:900},locale,session);
      const countryPage=await countryContext.newPage();
      const countries=(await rpc('list_visa_content_countries',{p_locale:locale,p_preview:true},token)).data.items;
      for(const country of countries) {
        const code=country.country_code;
        const expected=(await rpc('list_country_visa_content',{p_country_code:code,p_locale:locale,p_preview:true},token)).data;
        const categories=expected.categories||[], titles=expected.other_titles||[];
        const first=categories[0]||titles[0];
        if(!first) throw Error('listed_country_has_no_article_destination');
        const route=`/visa/content-countries/${code}?preview=true`;
        await countryPage.goto(base+route,{waitUntil:'domcontentloaded'});
        await semantics(countryPage);
        await countryPage.getByText(first.title,{exact:true}).first().waitFor({state:'visible',timeout:60000});
        await countryPage.getByText(first.title,{exact:true}).first().click();
        await countryPage.waitForURL(url=>url.pathname===`/visa/content/${first.id}`&&url.searchParams.get('preview')==='true',{timeout:30000});
        await countryPage.getByText(first.title,{exact:true}).first().waitFor({state:'visible',timeout:60000});
        report.countries.push({country_code:code,locale,route,category_ids:categories.map(card=>card.id),other_titles_ids:titles.map(card=>card.id),actual_card_navigation_id:first.id,passed:true});
        save();
      }
      await countryContext.close();
    }
    const context=await contextFor(browser,{width:1280,height:900},'fa',session);
    const page=await context.newPage();
    const mobileSamples=new Set();
    let consoleErrors=[];
    page.on('pageerror',error=>consoleErrors.push(String(error)));
    page.on('console',message=>{if(message.type()==='error') consoleErrors.push(message.text());});
    fs.writeFileSync(path.join(output,'reader-receipts.jsonl'),'');
    for (let index=0;index<heads.length;index++) {
      const expires=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString('utf8')).exp;
      if(expires<Date.now()/1000+300) {
        const stored=await page.evaluate(key=>localStorage.getItem(key),authKey).catch(()=>null);
        const current=stored?JSON.parse(stored):null;
        if(current?.access_token&&JSON.parse(Buffer.from(current.access_token.split('.')[1],'base64url').toString('utf8')).exp>expires) session=current;
        else session=await login('super_admin');
        token=session.access_token;
      }
      const head=heads[index], started=Date.now();
      consoleErrors=[];
      const row={article_id:head.article_id,locale:head.locale,environment:report.environment,project:report.project,api_url:report.api_url,passed:false,route_opened:false,body_render_verified:false,render_probe:'first_and_final_retained_block',checked_block_ids:[],console_errors:[],full_api_structure_verified:false};
      try {
        const data=(await rpc('get_editorial_article',{p_article_id:head.article_id,p_locale:head.locale,p_preview:true},token)).data;
        const route=`/visa/content/${head.article_id}?locale=${head.locale}&preview=true`;
        row.route=route;
        row.revision_id=data.revision_id;
        const responsePromise=page.waitForResponse(response=>{
          if(!response.url().endsWith('/rest/v1/rpc/get_editorial_article')) return false;
          const input=response.request().postDataJSON();
          return input?.p_article_id===head.article_id&&input?.p_locale===head.locale&&input?.p_preview===true;
        },{timeout:90000}).catch(()=>null);
        await page.goto(base+route,{waitUntil:'domcontentloaded'});
        await semantics(page);
        await page.getByText(data.title,{exact:true}).first().waitFor({state:'visible',timeout:60000});
        row.route_opened=true;
        const browserResponse=await responsePromise;
        if(!browserResponse) throw Error('article_RPC_response_not_observed');
        const actual=(await browserResponse.json()).data;
        const sections=data.rich_sections||data.sections||[];
        const blocks=sections.flatMap(section=>section.blocks||[]);
        const firstBlock=blocks.find(block=>typeof block.id==='string'&&renderLeaf(block).trim());
        const finalBlock=blocks.findLast(block=>typeof block.id==='string'&&renderLeaf(block).trim());
        if(!firstBlock||!finalBlock) throw Error('retained_body_block_required');
        row.browser_rpc_rich_sections_sha256=hash(actual.rich_sections||actual.sections||[]);
        row.direct_rpc_rich_sections_sha256=hash(sections);
        const actualBody={rich_sections:actual.rich_sections||actual.sections||[],source_assets:actual.source_assets||[],source_links:actual.source_links||[]};
        row.browser_rpc_body_sha256=hash(actualBody);
        if(actual.revision_id!==data.revision_id||row.browser_rpc_rich_sections_sha256!==row.direct_rpc_rich_sections_sha256) throw Error('browser_API_revision_or_body_mismatch');
        const expectedHash=head.expected_rich_sections_sha256||head.rich_sections_sha256;
        const expectedBodyHash=head.expected_body_sha256||head.body_sha256;
        if(head.revision_id&&head.revision_id!==data.revision_id) throw Error('expected_revision_mismatch');
        if(expectedHash&&expectedHash!==row.browser_rpc_rich_sections_sha256) throw Error('canonical_payload_body_mismatch');
        if(expectedBodyHash&&expectedBodyHash!==row.browser_rpc_body_sha256) throw Error('canonical_payload_body_and_media_mismatch');
        row.full_api_structure_verified=Boolean(expectedBodyHash);
        row.expected_rich_sections_sha256=expectedHash||null;
        row.expected_body_sha256=expectedBodyHash||null;
        row.api_structure_check=expectedBodyHash?'all_rich_sections_and_media_and_links_compared_to_canonical_payload':expectedHash?'rich_sections_compared_to_canonical_payload; expected_media_and_links_hash_not_supplied':'browser_RPC_matches_direct_RPC_only; expected_payload_hash_not_supplied';
        for(const block of [...new Map([firstBlock,finalBlock].map(block=>[block.id,block])).values()]) {
          await probeBlock(page,route,block);
          row.checked_block_ids.push(block.id);
        }
        Object.assign(row,{passed:consoleErrors.length===0,body_render_verified:consoleErrors.length===0,title_sha256:crypto.createHash('sha256').update(data.title).digest('hex'),rich_sections:sections.length,body_blocks:blocks.length,body_render_check:'first_and_final_retained_block_leaves_visible; not_every_intermediate_widget_probed'});
        const publishers=data.source_publishers||[];
        const sampleTags=publishers.filter(publisher=>!mobileSamples.has('publisher:'+publisher)).map(publisher=>'publisher:'+publisher);
        const table=blocks.find(block=>(block.current_structure||block.original_structure||block).type==='table');
        if(table&&!mobileSamples.has('rich-table:'+head.locale)) sampleTags.push('rich-table:'+head.locale);
        if(head.locale==='en'&&!mobileSamples.has('original-English')) sampleTags.push('original-English');
        if(sampleTags.length) {
          const mobileContext=await contextFor(browser,{width:390,height:844},head.locale,session);
          const mobilePage=await mobileContext.newPage();
          const errors=[];
          mobilePage.on('pageerror',error=>errors.push(String(error)));
          const probes=[...new Map([firstBlock,table||finalBlock].map(block=>[block.id,block])).values()];
          for(const block of probes) await probeBlock(mobilePage,route,block);
          const screenshot=`mobile-reader-${index}.png`;
          await mobilePage.screenshot({path:path.join(output,screenshot)});
          report.mobile_readers.push({article_id:head.article_id,locale:head.locale,viewport:{width:390,height:844},sample_tags:sampleTags,checked_block_ids:probes.map(block=>block.id),console_errors:errors,passed:errors.length===0,screenshot});
          for(const tag of sampleTags) mobileSamples.add(tag);
          await mobileContext.close();
        }
      } catch(error) {
        row.error_type=error.name;
        row.error=error.message.includes('mismatch')?error.message:'route_or_reader_body_probe_unavailable';
        await page.screenshot({path:path.join(output,`failure-${index}.png`)}).catch(()=>{});
      }
      row.console_errors=[...consoleErrors];
      row.seconds=(Date.now()-started)/1000;
      report.readers.push(row);
      fs.appendFileSync(path.join(output,'reader-receipts.jsonl'),JSON.stringify(row)+'\n');
      save();
      if(index%20===0) console.log(JSON.stringify({checked:index+1,selected:heads.length,failed:report.readers.filter(row=>!row.passed).length}));
    }
    await context.close();
  } finally { await browser.close(); }
  report.all_render_probes_passed=[...report.discovery,...report.countries,...report.mobile_readers,...report.security,...report.readers].every(row=>row.passed);
  report.canonical_payload_body_verification_complete=report.exhaustive_reader_selection&&report.readers.every(row=>row.full_api_structure_verified);
  report.all_passed=report.all_render_probes_passed&&report.canonical_payload_body_verification_complete&&report.blocked_write_requests.length===0;
  save();
  console.log(JSON.stringify({all_passed:report.all_passed,all_render_probes_passed:report.all_render_probes_passed,exhaustive_reader_selection:report.exhaustive_reader_selection,readers:report.readers.length,discovery:report.discovery.length}));
  if(!report.all_render_probes_passed||(headsFile&&report.readers.some(row=>!row.full_api_structure_verified))) process.exitCode=1;
}
main().catch(error=>{report.all_passed=false;report.blocker=error.name+': '+error.message;save();console.error(report.blocker);process.exitCode=1;});
