import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const origin = 'https://saidalmafia.com';
const md5 = bytes => createHash('md5').update(bytes).digest('hex');
const local = md5(await readFile('build/web/main.dart.js'));
const expected = [
  ['/', 'text/html'], ['/privacy/', 'text/html'],
  ['/beta/', 'text/html'], ['/beta/join/', 'text/html'],
  ['/delete-data/', 'text/html'], ['/room/ABCD', 'text/html'],
  ['/.well-known/assetlinks.json', 'application/json'],
  ['/ads.txt', 'text/plain'], ['/main.dart.js', 'javascript'],
  // Safari and iOS load this CanvasKit, not the chromium/ one.
  ['/canvaskit/canvaskit.wasm', 'application/wasm'],
];
// Without it Safari draws the whole game one screen to the right of the
// display (web/index.html, "Where the film went").
const SAFARI_GUARD = 'flutter-view { direction: ltr; }';
const JOIN_GUARD = 'id="group"';
let failed = false;
for (const [path, mime] of expected) {
  const response = await fetch(origin + path, { redirect: 'follow' });
  const type = response.headers.get('content-type') ?? '';
  const bytes = Buffer.from(await response.arrayBuffer());
  const hash = path === '/main.dart.js' ? md5(bytes) : '';
  const pass = response.status === 200 && type.includes(mime) &&
    (path !== '/main.dart.js' || hash === local) &&
    (path !== '/' || bytes.toString('utf8').includes(SAFARI_GUARD)) &&
    (path !== '/beta/join/' || bytes.toString('utf8').includes(JOIN_GUARD));
  failed ||= !pass;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${path}: ${response.status} ${type}` +
    (hash ? ` md5=${hash} local=${local}` : ''));
}
if (failed) process.exitCode = 1;
