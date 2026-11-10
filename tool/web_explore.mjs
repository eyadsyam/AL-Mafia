// Interactive explorer: one Chromium context on the local build, real hosted
// server. Reads commands from a file so each step can be chosen after looking.
//   node explore.mjs <cmdFile> <outDir>
// cmd lines: "dump", "click <label substring>", "type <text>", "shot <name>", "wait <s>", "goto <path>", "quit"
import { chromium } from 'playwright';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const cmdFile = process.argv[2];
const out = process.argv[3];
await mkdir(out, { recursive: true });
const browser = await chromium.launch({
  headless: true,
  args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream', '--autoplay-policy=no-user-gesture-required'],
});
const context = await browser.newContext({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 1, locale: 'ar-EG',
  permissions: ['microphone', 'notifications'] });
const page = await context.newPage();
const log = [];
page.on('console', (m) => { if (m.type() === 'error') log.push('console: ' + m.text().slice(0, 300)); });
page.on('pageerror', (e) => log.push('pageerror: ' + String(e).slice(0, 300)));
await page.goto('http://127.0.0.1:5182/', { waitUntil: 'load' });

async function semantics() {
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.click();
  });
  await page.waitForTimeout(400);
}
async function dump() {
  await semantics();
  return page.evaluate(() => {
    const rows = [];
    for (const el of document.querySelectorAll('flt-semantics, [role], input, textarea')) {
      const label = (el.getAttribute('aria-label') || '').trim();
      const text = el.children.length === 0 ? (el.textContent || '').trim() : '';
      const role = el.getAttribute('role') || el.tagName.toLowerCase();
      const r = el.getBoundingClientRect();
      if (!label && !text) continue;
      if (r.width === 0) continue;
      rows.push(`${role} [${Math.round(r.x)},${Math.round(r.y)} ${Math.round(r.width)}x${Math.round(r.height)}] ${label || text}`);
    }
    return [...new Set(rows)].join('\n');
  });
}
async function clickLabel(sub) {
  await semantics();
  const box = await page.evaluate((s) => {
    const els = [...document.querySelectorAll('flt-semantics, [role]')].filter((el) => {
      const l = (el.getAttribute('aria-label') || el.textContent || '').trim();
      const r = el.getBoundingClientRect();
      return l.includes(s) && r.width > 0 && r.height > 0;
    });
    const el = els.find((e) => e.getAttribute('role') === 'button') || els[els.length - 1];
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, sub);
  if (!box) return 'NOT FOUND: ' + sub;
  await page.mouse.click(box.x, box.y);
  return 'clicked ' + sub + ' at ' + JSON.stringify(box);
}

let done = 0;
for (;;) {
  if (!existsSync(cmdFile)) { await page.waitForTimeout(500); continue; }
  const lines = (await readFile(cmdFile, 'utf8')).split('\n').map((l) => l.trim()).filter(Boolean);
  if (lines.length <= done) { await page.waitForTimeout(500); continue; }
  const cmd = lines[done++];
  const [verb, ...rest] = cmd.split(' ');
  const arg = rest.join(' ');
  let result = '';
  try {
    if (verb === 'dump') result = await dump();
    else if (verb === 'click') result = await clickLabel(arg);
    else if (verb === 'tap') { const [x, y] = arg.split(',').map(Number); await page.mouse.click(x, y); result = 'tapped'; }
    else if (verb === 'type') { await page.keyboard.type(arg, { delay: 40 }); result = 'typed'; }
    else if (verb === 'key') { await page.keyboard.press(arg); result = 'key'; }
    else if (verb === 'shot') { await page.screenshot({ path: `${out}/${arg}.png` }); result = 'shot ' + arg; }
    else if (verb === 'wait') { await page.waitForTimeout(Number(arg) * 1000); result = 'waited'; }
    else if (verb === 'goto') { await page.goto('http://127.0.0.1:5182' + arg); result = 'went'; }
    else if (verb === 'eval') { result = JSON.stringify(await page.evaluate(arg)); }
    else if (verb === 'quit') break;
  } catch (e) { result = 'ERROR ' + String(e).slice(0, 300); }
  await writeFile(`${out}/step_${String(done).padStart(3, '0')}.txt`, `> ${cmd}\n${result}\n--- errors\n${log.splice(0).join('\n')}\n`);
}
await browser.close();
