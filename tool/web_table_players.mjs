// Several real players, each in its own browser, play one online match of the
// real web build against the hosted server — through the screen only: the
// onboarding, the room, the card, the night, the opening round, the talk, the
// ballot and the result. Optional API bots fill the rest of the table.
//
// Every screen each player saw is logged (headline lines, buttons), with
// console errors, failed requests and a 420 px shot per phase, so what a real
// table meets is on record.
//
//   node tool/serve_build.mjs build/web 5182        (another terminal)
//   node tool/web_table_players.mjs [players=3] [outDir=build/web_table] [bots=2]
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { mkdir, writeFile, appendFile } from 'node:fs/promises';

const count = Number(process.argv[2] ?? 3);
const out = process.argv[3] ?? 'build/web_table';
const bots = Number(process.argv[4] ?? 2);
const base = process.env.BASE ?? 'http://127.0.0.1:5182';
const names = ['سمير', 'هالة', 'ماجد', 'نادية', 'رامي', 'سلمى'];
await mkdir(out, { recursive: true });
const logFile = `${out}/log.txt`;
await writeFile(logFile, '');
const log = async (who, line) => {
  const row = `${new Date().toISOString().slice(11, 19)} [${who}] ${line}`;
  console.log(row);
  await appendFile(logFile, row + '\n');
};

const browser = await chromium.launch({
  headless: true,
  args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream', '--autoplay-policy=no-user-gesture-required'],
});

async function nodes(page) {
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  return page.evaluate(() => {
    const rows = [];
    for (const el of document.querySelectorAll('flt-semantics, [role], input')) {
      const label = (el.getAttribute('aria-label') || (el.children.length === 0 ? el.textContent : '') || '').trim();
      const r = el.getBoundingClientRect();
      if (!label || r.width === 0 || r.height === 0) continue;
      rows.push({ role: el.getAttribute('role') || el.tagName.toLowerCase(), label, x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width, h: r.height,
        disabled: el.getAttribute('aria-disabled') === 'true' });
    }
    return rows;
  });
}
const find = (rows, sub, role) => rows.filter((r) => r.label.includes(sub) && (!role || r.role === role));
const pointer = (page, js) => page.evaluate(js);
async function hold(page, x, y, ms = 2800) {
  await pointer(page, `(async()=>{const v=document.querySelector('flutter-view');const o={bubbles:true,cancelable:true,pointerId:11,pointerType:'mouse',isPrimary:true,clientX:${x},clientY:${y},button:0,buttons:1};v.dispatchEvent(new PointerEvent('pointerdown',o));await new Promise(r=>setTimeout(r,${ms}));v.dispatchEvent(new PointerEvent('pointerup',{...o,buttons:0}));})()`);
}
async function swipe(page, x, y) {
  await pointer(page, `(async()=>{const v=document.querySelector('flutter-view');const b={bubbles:true,cancelable:true,pointerId:12,pointerType:'mouse',isPrimary:true,button:0,buttons:1};v.dispatchEvent(new PointerEvent('pointerdown',{...b,clientX:${x},clientY:${y}}));for(let i=1;i<=12;i++){await new Promise(r=>setTimeout(r,16));v.dispatchEvent(new PointerEvent('pointermove',{...b,button:-1,clientX:${x}+i*18,clientY:${y}}));}v.dispatchEvent(new PointerEvent('pointerup',{...b,buttons:0,clientX:${x}+216,clientY:${y}}));})()`);
}

const seatNames = new Set(['Bassem', 'Camelia', 'Dawoud', 'Enas', ...names]);
function seats(rows, me) {
  // A seat's label repeats the name on two lines («ماجد\nماجد»).
  const name = (r) => r.label.split('\n')[0].trim();
  const seen = new Set();
  return rows.filter((r) => r.role === 'button' && r.w < 120 && seatNames.has(name(r)) && name(r) !== me)
    .filter((r) => !seen.has(name(r)) && seen.add(name(r)))
    .map((r) => ({ ...r, label: name(r) }));
}

let roomCode = null;
const done = new Set();

async function player(i) {
  const me = names[i];
  const context = await browser.newContext({ viewport: { width: 412, height: 915 }, locale: 'ar-EG', permissions: ['microphone', 'notifications'] });
  const page = await context.newPage();
  page.on('console', (m) => { if (m.type() === 'error') log(me, 'console: ' + m.text().slice(0, 160)); });
  page.on('pageerror', (e) => log(me, 'PAGEERROR ' + String(e).slice(0, 200)));
  page.on('response', (r) => { if (r.status() >= 500) log(me, `HTTP ${r.status()} ${r.url().split('?')[0]}`); });
  await page.goto(base + '/', { waitUntil: 'load' });
  await page.waitForTimeout(9000);
  let last = '';
  let phaseShots = new Set();
  let acted = new Set();
  const deadline = Date.now() + 25 * 60 * 1000;
  while (Date.now() < deadline) {
    const rows = await nodes(page);
    const labels = rows.map((r) => r.label);
    const head = labels.slice(0, 6).join(' | ').slice(0, 220);
    if (head !== last) { last = head; await log(me, 'SCREEN ' + head); }
    const has = (s, role) => find(rows, s, role).length > 0;
    const click = async (s, role, pick = 0) => {
      const m = find(rows, s, role);
      const r = pick === -1 ? m[m.length - 1] : m[pick];
      if (!r) return false;
      await page.mouse.click(r.x, r.y);
      await log(me, 'tap ' + s);
      await page.waitForTimeout(900);
      return true;
    };
    const shot = async (tag) => {
      if (phaseShots.has(tag)) return;
      phaseShots.add(tag);
      await page.screenshot({ path: `${out}/${i}_${tag}.png` });
    };
    // ── onboarding
    if (has('العب كضيف')) { await click('العب كضيف'); continue; }
    if (has('عندي 18')) {
      if (!acted.has('agree')) { await click('عندي 18'); acted.add('agree'); }
      await click(i % 2 ? 'بنت' : 'ولد', 'button'); await page.waitForTimeout(2500); continue;
    }
    if (has('اكتب اسمك')) {
      const f = find(rows, 'اكتب اسمك')[0];
      await page.mouse.click(f.x, f.y);
      await page.keyboard.type(me, { delay: 40 });
      await page.waitForTimeout(400);
      await click('كمل', 'button', -1);
      continue;
    }
    // ── to the room
    if (has('ابدأ اللعبة')) {
      if (i === 0) { await click('ابدأ اللعبة'); continue; }
      if (roomCode) { await page.goto(`${base}/join/${roomCode}`); await page.waitForTimeout(6000); continue; }
      await page.waitForTimeout(1500); continue;
    }
    if (has('هتلعب إيه')) { await click('المافيا', 'button'); continue; }
    if (has('هتلعبوها إزاي')) { await click('أونلاين', 'button'); continue; }
    if (i === 0 && has('اعمل أوضة') && !roomCode) {
      const make = find(rows, 'اعمل أوضة', 'button');
      if (make.length > 1) { await page.mouse.click(make[make.length - 1].x, make[make.length - 1].y); await page.waitForTimeout(5000); continue; }
      await click('اعمل أوضة'); await page.waitForTimeout(1500); continue;
    }
    const codeRow = rows.find((r) => /^الأوضة [A-Z0-9]{6}$/.test(r.label));
    if (codeRow && !roomCode) {
      roomCode = codeRow.label.split(' ')[1];
      await log(me, 'ROOM ' + roomCode);
      await shot('lobby');
      if (bots > 0) {
        const p = spawn('python', ['supabase/tests/bots_for_app.py', roomCode], { env: { ...process.env, PYTHONIOENCODING: 'utf-8', PYTHONUNBUFFERED: '1', BOT_COUNT: String(bots) } });
        p.stdout.on('data', (d) => String(d).split('\n').filter(Boolean).forEach((l) => log('bots', l)));
        p.stderr.on('data', (d) => log('bots', 'ERR ' + String(d).slice(0, 200)));
      }
      continue;
    }
    if (has('ادخل أوضة', 'button') && !codeRow) {
      const field = find(rows, 'كود الأوضة')[0];
      await log(me, 'JOIN SHEET ' + rows.filter((r) => r.y > 0).map((r) => r.role + ':' + r.label).join(' | ').slice(0, 200));
      if (field && roomCode && !acted.has('typed')) { await page.mouse.click(field.x, field.y); await page.keyboard.type(roomCode, { delay: 50 }); acted.add('typed'); }
      await click('ادخل أوضة', 'button', -1); await page.waitForTimeout(4000); continue;
    }
    if (i === 0 && has('يلا نبدأ')) {
      const ready = new Set(rows.filter((r) => seatNames.has(r.label.split('\n')[0].trim())).map((r) => r.label.split('\n')[0].trim())).size;
      if (!acted.has('lobbyAt')) acted.add('lobbyAt'), (player.lobbyAt = Date.now());
      if (ready >= count + bots || Date.now() - player.lobbyAt > 60000) {
        await log(me, 'starting with ' + ready + ' seats seen'); await click('يلا نبدأ'); await page.waitForTimeout(3000); }
      else await page.waitForTimeout(2000);
      continue;
    }
    // ── the card
    if (has('دوس ثانيتين عشان تشوف كارتك')) { await hold(page, 206, 480); await page.waitForTimeout(800); continue; }
    if (has('اسحب الكارت')) { await swipe(page, 206, 350); await page.waitForTimeout(1200); await shot('card'); continue; }
    // ── night
    const night = labels.find((l) => l.startsWith('الليلة'));
    if (night && !acted.has(night)) {
      await shot('night');
      const options = seats(rows, me);
      if (has('دوس ثانيتين عشان تأكد')) {
        if (options.length && !has('مفيش اختيار')) { const t = options[Math.floor(Math.random() * options.length)]; await page.mouse.click(t.x, t.y); await page.waitForTimeout(700); await log(me, 'night pick ' + t.label); }
        const c = find(await nodes(page), 'دوس ثانيتين عشان تأكد')[0];
        if (c) { await hold(page, c.x, c.y); acted.add(night); await log(me, 'night confirmed'); }
      }
      await page.waitForTimeout(1500); continue;
    }
    // ── opening round: my turn to name somebody
    if (has('سمّي') || has('دورك تسمي') || has('مين شاكك فيه')) {
      const options = seats(rows, me);
      if (options.length) { const t = options[0]; await page.mouse.click(t.x, t.y); await page.waitForTimeout(600); }
      const confirm = find(await nodes(page), 'أكد', 'button')[0] || find(await nodes(page), 'سمّي', 'button')[0];
      if (confirm) { await page.mouse.click(confirm.x, confirm.y); await log(me, 'named somebody'); }
      await page.waitForTimeout(1500); continue;
    }
    // ── discussion
    if (has('جاهز للتصويت', 'button') && !acted.has('ready' + labels.find((l) => l.startsWith('اليوم')))) {
      await shot('discuss');
      await click('جاهز للتصويت', 'button');
      acted.add('ready' + labels.find((l) => l.startsWith('اليوم')));
      continue;
    }
    // ── ballot
    if (has('مين يخرج') && !acted.has('vote' + labels.find((l) => l.startsWith('اليوم')))) {
      await shot('vote');
      const options = seats(rows, me);
      if (options.length) {
        const t = options[Math.floor(Math.random() * options.length)];
        await page.mouse.click(t.x, t.y); await page.waitForTimeout(700);
        const v = find(await nodes(page), 'صوّت', 'button')[0] || find(await nodes(page), 'أكد صوتك', 'button')[0];
        if (v) { await page.mouse.click(v.x, v.y); await log(me, 'voted ' + t.label); acted.add('vote' + labels.find((l) => l.startsWith('اليوم'))); }
        else await log(me, 'NO VOTE BUTTON after picking ' + t.label);
      }
      await page.waitForTimeout(1500); continue;
    }
    // ── result
    if (has('المباراة خلصت')) {
      await page.waitForTimeout(2500);
      await shot('result');
      const winner = labels.find((l) => l.includes('كسب') || l.includes('كسبت'));
      await log(me, 'RESULT ' + (winner ?? '?'));
      done.add(i);
      break;
    }
    // Nothing above matched: a lone «كمل» moves most screens on.
    if (find(rows, 'كمل', 'button').length && !has('جاهز للتصويت')) { await click('كمل', 'button', -1); continue; }
    await page.waitForTimeout(1500);
  }
  await context.close();
}

await Promise.all(Array.from({ length: count }, (_, i) => new Promise((r) => setTimeout(r, i * 4000)).then(() => player(i)).catch((e) => log(names[i], 'CRASH ' + e))));
await log('table', `finished: ${done.size}/${count} players reached the result`);
await browser.close();
process.exit(0);
