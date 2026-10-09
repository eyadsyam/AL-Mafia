// Loads the live site in WebKit (iPhone) and Chromium (Android phone, desktop)
// and reports: time to the first Flutter frame, console errors, and frame
// pacing over a few seconds of the home screen (rAF intervals: p50, p95, and
// frames slower than 50 ms). Writes a small screenshot per device.
//
//   node tool/web_perf_probe.mjs [url] [outDir]
import { webkit, chromium, devices } from 'playwright';

const url = process.argv[2] ?? 'https://saidalmafia.com/';
const out = process.argv[3] ?? 'build';
const runs = [
  ['iphone', webkit, devices['iPhone 14']],
  ['android', chromium, devices['Pixel 7']],
  ['desktop', chromium, { viewport: { width: 1366, height: 820 } }],
];

for (const [name, engine, device] of runs) {
  const browser = await engine.launch();
  const page = await (await browser.newContext({ ...device, locale: 'ar-EG' })).newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 160)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 160)); });
  const start = Date.now();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 90000 });
  let firstFrame = null;
  try {
    await page.waitForFunction(() => {
      const v = document.querySelector('flutter-view');
      return !!document.querySelector('flutter-view canvas, flt-glass-pane, flutter-view flt-scene-host') || (v && v.shadowRoot && v.shadowRoot.querySelector('canvas'));
    }, null, { timeout: 60000 });
    firstFrame = Date.now() - start;
  } catch { /* reported as null */ }
  await page.waitForTimeout(3000);
  const pacing = await page.evaluate(() => new Promise((done) => {
    const gaps = []; let last = performance.now(); const end = last + 4000;
    function tick(t) { gaps.push(t - last); last = t; if (t < end) requestAnimationFrame(tick); else done(gaps); }
    requestAnimationFrame(tick);
  }));
  const sorted = [...pacing].sort((a, b) => a - b);
  const pct = (p) => Math.round(sorted[Math.floor(sorted.length * p)] ?? 0);
  await page.screenshot({ path: `${out}/perf_${name}.png` });
  console.log(JSON.stringify({
    device: name, firstFrameMs: firstFrame, frames: pacing.length,
    p50: pct(0.5), p95: pct(0.95), slowOver50: pacing.filter((g) => g > 50).length,
    errors: errors.slice(0, 5),
  }));
  await browser.close();
}
