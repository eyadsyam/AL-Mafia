// Plays the Stories V2 pilot («قهوة المعلم») end to end on a local web build,
// in WebKit (iPhone), Chromium with touch (Android) and Chromium (desktop):
// the first-entry explainer, the hub, the narrator (does the browser really
// play it, and does +5 move it), five names typed, the how-to, the whole
// pass with a real press-and-hold on every private page, three searches, the
// decision and the result. Reports frame pacing for each stretch (rAF gaps:
// p50, p95, frames over 50 ms), console errors, and writes a 420 px shot per
// step. Talks to no server: build without dart_defines. NOWARM=1 starts
// before the app's audio warm-up finishes (after it, headless Chromium's
// audio device gives out and media stops advancing); STOP=narrator ends
// after the narrator. Console noise from a raw build: sw.js is stamped at
// deploy, so its request falls back to index.html; the ad script times out
// offline.
//
//   flutter build web --release --base-href / --output build/web_stories_check
//   node tool/web_stories_probe.mjs [buildDir] [outDir] [only=iphone|android|desktop]
import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { mkdir, readFile, stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';
import { chromium, devices, webkit } from 'playwright';

const root = resolve(process.argv[2] ?? 'build/web_stories_check');
const out = resolve(process.argv[3] ?? 'build/web_stories_probe');
const only = process.argv[4];
await mkdir(out, { recursive: true });

const types = {
  '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.html': 'text/html', '.json': 'application/json', '.webp': 'image/webp',
  '.png': 'image/png', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.woff2': 'font/woff2', '.mp4': 'video/mp4', '.css': 'text/css',
};
const server = createServer(async (req, res) => {
  let path = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (path !== root && !path.startsWith(root + sep)) return res.writeHead(403).end();
  try { if ((await stat(path)).isDirectory()) path = join(path, 'index.html'); }
  catch { path = join(root, 'index.html'); }
  const size = (await stat(path)).size;
  const headers = { 'Content-Type': types[extname(path)] ?? 'application/octet-stream', 'Accept-Ranges': 'bytes' };
  const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
  if (range) {
    const start = +range[1]; const end = range[2] ? Math.min(+range[2], size - 1) : size - 1;
    res.writeHead(206, { ...headers, 'Content-Range': `bytes ${start}-${end}/${size}`, 'Content-Length': end - start + 1 });
    createReadStream(path, { start, end }).pipe(res);
  } else {
    res.writeHead(200, { ...headers, 'Content-Length': size });
    createReadStream(path).pipe(res);
  }
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const base = `http://127.0.0.1:${server.address().port}`;

// A set-up player (name, terms, intro), so /stories opens straight away.
const seed = () => {
  try { if (localStorage.getItem('flutter.mafia.playerProfile.v1')) return; } catch { return; }
  const set = (k, v) => localStorage.setItem(`flutter.${k}`, JSON.stringify(v));
  set('mafia.playerProfile.v1', JSON.stringify({ name: 'تجربة', gender: 'male' }));
  set('mafia.introSeen.v1', true);
  set('mafia.terms.version', '2026-09-27');
  set('mafia.terms.acceptedAt', new Date().toISOString());
  set('mafia.terms.adult', true);
  set('mafia.terms.synced', true);
  set('mafia.permissions.onboarding.v1', true);
};
// Every media play(): its source, whether the browser allowed it, the element.
const audioSpy = () => {
  window.__plays = [];
  window.__loads = [];
  const load = HTMLMediaElement.prototype.load;
  HTMLMediaElement.prototype.load = function (...args) {
    window.__loads.push(this);
    return load.apply(this, args);
  };
  const play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) {
    const rec = { src: this.currentSrc || this.src, ok: null, el: this };
    window.__plays.push(rec);
    const p = play.apply(this, args);
    if (p && p.then) p.then(() => { rec.ok = true; }, (e) => { rec.ok = String(e && e.name); });
    return p;
  };
};

const runs = [
  ['iphone', webkit, devices['iPhone 14'], 'mouse'],
  ['android', chromium, devices['Pixel 7'], 'touch'],
  ['desktop', chromium, { viewport: { width: 1366, height: 820 } }, 'mouse'],
].filter(([name]) => !only || only === name);

const names = ['أحمد', 'مريم', 'كريم', 'ياسمين', 'عمر'];
const world = JSON.parse(await readFile(resolve('assets/stories_v2/qahwet_el_moallem.json'), 'utf8'));
const suspects = world.suspects.map((s) => s.name);
const report = [];

for (const [device, engine, profile, pointer] of runs) {
  const browser = await engine.launch();
  const context = await browser.newContext({ ...profile, locale: 'ar-EG' });
  await context.addInitScript(seed);
  await context.addInitScript(audioSpy);
  const page = await context.newPage();
  const cdp = pointer === 'touch' ? await context.newCDPSession(page) : null;
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 200)); });
  const steps = [];
  let shot = 0;
  const log = (step, extra = {}) => { steps.push({ step, ...extra }); console.log(device, step, JSON.stringify(extra)); };
  const snap = async (name) => page.screenshot({ path: `${out}/${device}_${String(++shot).padStart(2, '0')}_${name}.png` });

  const pacingStart = () => page.evaluate(() => {
    window.__gaps = []; let last = performance.now(); window.__pacing = true;
    const tick = (t) => { window.__gaps.push(t - last); last = t; if (window.__pacing) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  });
  const pacingStop = async () => {
    const gaps = await page.evaluate(() => { window.__pacing = false; return window.__gaps.slice(1); });
    const s = [...gaps].sort((a, b) => a - b);
    const pct = (p) => Math.round(s[Math.min(s.length - 1, Math.floor(s.length * p))] ?? 0);
    return { frames: gaps.length, p50: pct(0.5), p95: pct(0.95), over50: gaps.filter((g) => g > 50).length, worst: Math.round(s.at(-1) ?? 0) };
  };
  const button = (name) => page.getByRole('button', { name }).first();
  const text = (t) => page.getByText(t, { exact: false }).first();
  const tap = async (locator, label) => {
    await locator.waitFor({ state: 'visible', timeout: 15000 });
    if (profile.hasTouch) await locator.tap(); else await locator.click();
    await page.waitForTimeout(450);
    if (label) log(`tap ${label}`);
  };
  const hold = async (locator, ms) => {
    await locator.waitFor({ state: 'visible', timeout: 15000 });
    const b = await locator.boundingBox();
    const x = b.x + b.width / 2; const y = b.y + b.height / 2;
    // A real player has no semantics tree on top: let the press reach the
    // app's own gesture handling, as it would on their phone.
    await page.evaluate(() => document.querySelectorAll('flt-semantics, flt-semantics-container')
      .forEach((n) => { n.style.pointerEvents = 'none'; }));
    if (cdp) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
      await page.waitForTimeout(ms);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    } else {
      await page.mouse.move(x, y); await page.mouse.down();
      await page.waitForTimeout(ms);
      await page.mouse.up();
    }
    await page.waitForTimeout(450);
    await page.evaluate(() => document.querySelectorAll('flt-semantics, flt-semantics-container')
      .forEach((n) => { n.style.pointerEvents = ''; }));
  };

  try {
    const t0 = Date.now();
    await page.goto(`${base}/stories`, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder'), null, { timeout: 90000 });
    // Phones turn the semantics tree on only for a real touch on the
    // full-screen placeholder; desktops for a click on it.
    if (profile.hasTouch) {
      const size = page.viewportSize();
      for (let i = 0; i < 5; i++) {
        await page.touchscreen.tap(size.width / 2, size.height / 2);
        await page.waitForTimeout(800);
        if (await page.evaluate(() => document.querySelectorAll('flt-semantics').length > 3)) break;
      }
    } else {
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
    }
    await button('يلا نشوف القضايا').waitFor({ timeout: 90000 });
    log('first stories screen', { ms: Date.now() - t0 });
    // A fresh browser reads the whole bundle once behind «بنجهّز الترابيزة»
    // (the app's first-launch warm-up). Measure after it, not during it.
    const w0 = Date.now();
    if (!process.env.NOWARM) await page.waitForFunction(
      () => localStorage.getItem('flutter.mafia.warmup.signature.v1'),
      null, { timeout: 240000, polling: 500 },
    );
    await page.getByText('بنجهّز الترابيزة').first().waitFor({ state: 'hidden', timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(1500);
    log('first-launch warm-up done', { ms: Date.now() - w0 });
    await snap('about');

    await pacingStart();
    await tap(button('يلا نشوف القضايا'), 'about → hub');
    await page.waitForTimeout(800);
    log('pacing hub enter', await pacingStop());
    await snap('hub');

    await pacingStart();
    await tap(text('قهوة المعلم'), 'open the pilot');
    await page.waitForTimeout(800);
    log('pacing file enter', await pacingStop());
    await snap('file');

    // The narrator: the browser must really play it, and +5 must move it.
    await tap(button('شغّل'), 'narrator play');
    await page.waitForTimeout(2500);
    const before = await page.evaluate(() => {
      const r = window.__plays.filter((p) => /stories_v2/.test(p.src)).at(-1);
      return r ? { src: r.src.split('/').slice(-1)[0], ok: r.ok, at: r.el.currentTime, paused: r.el.paused } : null;
    });
    log('narrator playing', before ?? {
      missing: true,
      loads: await page.evaluate(() => window.__loads.map((e) => [
        (e.currentSrc || e.src).split('/').slice(-1)[0], e.readyState, e.networkState,
        e.error && e.error.code, e.paused])),
      plays: await page.evaluate(() => window.__plays.map((p) => [p.src.split('/').slice(-2).join('/'), p.ok])),
    });
    await tap(button('+٥'), 'narrator +5');
    await page.waitForTimeout(300);
    const after = await page.evaluate(() => {
      const r = window.__plays.filter((p) => /stories_v2/.test(p.src)).at(-1);
      return r ? { at: r.el.currentTime, paused: r.el.paused } : null;
    });
    log('narrator after +5', after ?? { missing: true });
    await snap('narrator');
    if (process.env.STOP === 'narrator') throw new Error('stopped after the narrator');

    await tap(button('العب مع صحابك'), 'play with friends');
    await snap('names');
    // Like a phone keyboard: type, then «next» moves to the following field.
    await tap(page.getByRole('textbox').first());
    for (let i = 0; i < names.length; i++) {
      await page.keyboard.type(names[i]);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(150);
    }
    await page.waitForTimeout(300);
    log('typed names');
    await snap('names_typed');
    await tap(button('كمّل'), 'names → how-to');
    for (let i = 0; i < 4; i++) await tap(button('اللي بعده'));
    await snap('howto_last');
    await tap(button(/^يلا$/), 'deal');
    await page.waitForTimeout(800);
    await snap('cast');

    await pacingStart();
    await tap(button('يلا نلف بالموبايل'), 'begin the pass');
    for (let seat = 0; seat < names.length; seat++) {
      await tap(button(/أنا .*، افتح/));
      if (seat === 0) await snap('card');
      await hold(button(/مطوّل/), 1300);
      const opened = await button(/خبّي/).isVisible().catch(() => false);
      log(`seat ${seat + 1} hold opened the secret`, { opened });
      if (seat === 0) await snap('secret');
      await tap(button(/خبّي/));
    }
    log('pacing the whole pass', await pacingStop());
    await snap('desk');

    // A stray back or reload mid-table asks the browser's «Leave site?».
    let prompted = null;
    page.once('dialog', async (d) => { prompted = d.type(); await d.dismiss(); });
    await page.goBack({ timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(1000);
    log('browser back at the desk', {
      prompted, stillAtTheDesk: await button('قراري').isVisible().catch(() => false),
    });

    await pacingStart();
    if (cdp) {
      // A finger flick up the desk and back, as touch events.
      for (const [from, to] of [[600, 200], [600, 200], [200, 600], [200, 600]]) {
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 200, y: from }] });
        for (let k = 1; k <= 8; k++) {
          await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 200, y: from + ((to - from) * k) / 8 }] });
          await page.waitForTimeout(16);
        }
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        await page.waitForTimeout(400);
      }
      log('pacing desk scroll', await pacingStop());
    } else if (device !== 'iphone') {
      await page.mouse.move(200, 400);
      for (let i = 0; i < 6; i++) { await page.mouse.wheel(0, 250); await page.waitForTimeout(120); }
      for (let i = 0; i < 6; i++) { await page.mouse.wheel(0, -250); await page.waitForTimeout(120); }
      log('pacing desk scroll', await pacingStop());
    } else {
      await pacingStop();
      log('desk scroll skipped (mobile WebKit has no wheel or touch drag here)');
    }

    await pacingStart();
    for (const place of ['صالة القهوة', 'ركن الشيش', 'حوش الفحم']) {
      await tap(button(new RegExp(place)), `search ${place}`);
      await snap('found');
      await tap(button('رجوع'));
    }
    log('pacing three searches', await pacingStop());

    await tap(button('قراري'), 'decide');
    await snap('decision');
    let picked = null;
    for (const name of suspects) {
      const face = page.getByText(name, { exact: true }).first();
      if (await face.isVisible().catch(() => false)) { await tap(face, `pick ${name}`); picked = name; break; }
    }
    if (!picked) throw new Error('no suspect face on the decision page');
    await tap(button(/ثبّت القرار/), 'confirm');
    await snap('reveal');
    await tap(button('شوف النتيجة'), 'result');
    await snap('result');
    log('done');
  } catch (error) {
    log('FAILED', { error: String(error).split('\n')[0].slice(0, 300) });
    await snap('failure').catch(() => {});
  }
  report.push({ device, errors: [...new Set(errors)].slice(0, 8), steps });
  await browser.close();
}
server.close();
console.log('REPORT ' + JSON.stringify(report));
