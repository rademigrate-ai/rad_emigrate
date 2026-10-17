// Capture the actual navigation fixture in all four locale/theme combinations.
// Set NODE_PATH when using an existing external Playwright installation.
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');

async function main() {
  const baseUrl = process.env.RAD_QA_BASE_URL || 'http://127.0.0.1:8795/';
  const output = path.resolve('docs/qa/pr54/navigation');
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const captures = [];
  try {
    for (const locale of ['en', 'fa']) {
      for (const theme of ['light', 'dark']) {
        const page = await browser.newPage({
          viewport: { width: 390, height: 844 },
          deviceScaleFactor: 1,
          reducedMotion: 'reduce',
        });
        const errors = [];
        page.on('pageerror', error => errors.push(error.message));
        page.on('console', message => {
          if (message.type() === 'error') errors.push(message.text());
        });
        const url = new URL(baseUrl);
        url.search = new URLSearchParams({
          screen: 'shell', theme, locale, capture: '1',
        }).toString();
        await page.goto(url.toString(), { waitUntil: 'networkidle' });
        await page.waitForSelector('flt-glass-pane', { state: 'attached' });
        await page.waitForTimeout(1500);
        const filename = `mobile-${locale}-${theme}.png`;
        await page.screenshot({ path: path.join(output, filename) });
        await page.screenshot({
          path: path.join(output, `navigation-${locale}-${theme}.png`),
          clip: { x: 0, y: 744, width: 390, height: 100 },
        });
        captures.push({ filename, locale, theme, errors });
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }
  await fs.writeFile(
    path.join(output, 'capture-manifest.json'),
    JSON.stringify({ evidence: 'Flutter shell fixture, synthetic dashboard', captures }, null, 2),
  );
  console.log(JSON.stringify(captures, null, 2));
  if (captures.some(capture => capture.errors.length)) process.exitCode = 1;
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
