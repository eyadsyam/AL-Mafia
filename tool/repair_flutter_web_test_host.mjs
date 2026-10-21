// Windows-only Flutter test-host workaround, not application code.
// Usage: node tool/repair_flutter_web_test_host.mjs <Chrome debug port> <flutter SDK>
// Supplies the SDK's own CanvasKit bytes and normalizes the generated selector.
// No assertions, compiled application modules or production SDK files are changed.
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const port = Number(process.argv[2]);
const sdk = process.argv[3];
if (!Number.isInteger(port) || port < 1 || port > 65535 || !sdk) {
  throw new Error('Expected Chrome debug port and Flutter SDK directory');
}
const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const tab = tabs.find(t => t.type === 'page' && t.title === 'Flutter Test Browser Host');
if (!tab || new URL(tab.url).hostname !== 'localhost') {
  throw new Error('Only a local Flutter Test Browser Host may be repaired');
}
const origin = new URL(tab.url).origin;
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  ws.addEventListener('open', resolve, { once: true });
  ws.addEventListener('error', reject, { once: true });
});
let nextId = 1;
const pending = new Map();
const failures = [];
let assets = 0;
let selectors = 0;
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}
ws.addEventListener('message', async event => {
  const message = JSON.parse(event.data);
  const response = pending.get(message.id);
  if (response) {
    pending.delete(message.id);
    if (message.error) response.reject(new Error(message.error.message));
    else response.resolve(message.result);
    return;
  }
  if (message.method !== 'Fetch.requestPaused') return;
  const { requestId, request } = message.params;
  try {
    const url = new URL(request.url);
    let body;
    let contentType;
    if (url.origin !== origin) throw new Error('Unexpected request origin');
    if (url.pathname.startsWith('/canvaskit/')) {
      const relative = url.pathname.slice('/canvaskit/'.length);
      if (!['canvaskit.js', 'canvaskit.wasm', 'chromium/canvaskit.js', 'chromium/canvaskit.wasm'].includes(relative)) {
        await send('Fetch.continueRequest', { requestId });
        return;
      }
      body = await readFile(join(sdk, 'bin/cache/flutter_web_sdk/canvaskit', relative));
      contentType = relative.endsWith('.wasm') ? 'application/wasm' : 'text/javascript';
      assets++;
    } else {
      const original = await fetch(request.url);
      if (!original.ok) throw new Error('Test HTML unavailable');
      const html = await original.text();
      const fixed = html.replace(/window\.testSelector = "([^"\n]+)";/g,
        (_, selector) => `window.testSelector = ${JSON.stringify(selector.replaceAll('\\', '/'))};`);
      if (fixed !== html) selectors++;
      body = Buffer.from(fixed);
      contentType = 'text/html';
    }
    await send('Fetch.fulfillRequest', {
      requestId, responseCode: 200,
      responseHeaders: [{ name: 'Content-Type', value: contentType }],
      body: body.toString('base64'),
    });
  } catch (error) {
    failures.push(error.message);
    await send('Fetch.failRequest', { requestId, errorReason: 'Failed' });
  }
});
try {
  await send('Fetch.enable', { patterns: [
    { urlPattern: `${origin}/canvaskit/*`, requestStage: 'Request' },
    { urlPattern: `${origin}/*_test.html*`, requestStage: 'Request' },
  ] });
  await send('Runtime.evaluate', {
    expression: 'document.querySelector("iframe").contentWindow.location.reload()',
  });
  await new Promise(resolve => setTimeout(resolve, 15000));
  if (failures.length) throw new Error(failures.join('; '));
  if (!selectors || !assets) throw new Error('Expected test-host repairs were not observed');
  console.log(`Test host repaired: ${selectors} selector(s), ${assets} local SDK asset(s). Test results remain authoritative.`);
} finally {
  if (ws.readyState === WebSocket.OPEN) {
    await send('Fetch.disable');
    ws.close();
  }
}
