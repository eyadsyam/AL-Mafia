import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const origin = 'https://saidalmafia.com';
const md5 = bytes => createHash('md5').update(bytes).digest('hex');
const local = md5(await readFile('build/web/main.dart.js'));
const expected = [
  ['/', 'text/html'], ['/privacy/', 'text/html'],
  ['/delete-data/', 'text/html'], ['/room/ABCD', 'text/html'],
  ['/.well-known/assetlinks.json', 'application/json'],
  ['/ads.txt', 'text/plain'], ['/main.dart.js', 'javascript'],
];
let failed = false;
for (const [path, mime] of expected) {
  const response = await fetch(origin + path, { redirect: 'follow' });
  const type = response.headers.get('content-type') ?? '';
  const bytes = Buffer.from(await response.arrayBuffer());
  const hash = path === '/main.dart.js' ? md5(bytes) : '';
  const pass = response.status === 200 && type.includes(mime) &&
    (path !== '/main.dart.js' || hash === local);
  failed ||= !pass;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${path}: ${response.status} ${type}` +
    (hash ? ` md5=${hash} local=${local}` : ''));
}
if (failed) process.exitCode = 1;
