import { spawn } from 'node:child_process';
import { readFile, writeFile, mkdtemp } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';

const profile = await mkdtemp(resolve('build/web-ads-profile-'));
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
  '--headless=new', `--user-data-dir=${profile}`, '--remote-debugging-port=0',
  '--no-first-run', '--no-default-browser-check', '--ignore-certificate-errors',
  'about:blank',
], { windowsHide: true, stdio: 'ignore' });
let ws;
try {
  let port;
  for (let i = 0; i < 80 && !port; i++) {
    try { port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; }
    catch { await delay(250); }
  }
  assert(port, 'Chrome did not start');
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  ws = new WebSocket(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
  await new Promise((ok, fail) => { ws.onopen = ok; ws.onerror = fail; });
  let id = 0;
  const calls = new Map();
  const failures = [];
  const requests = new Map();
  const exceptions = [];
  ws.onmessage = event => {
    const response = JSON.parse(event.data);
    if (response.method === 'Network.loadingFailed') {
      failures.push(`${requests.get(response.params.requestId) ?? 'unknown'}: ${response.params.errorText}`);
    }
    if (response.method === 'Network.requestWillBeSent') {
      requests.set(response.params.requestId, new URL(response.params.request.url).hostname);
    }
    if (response.method === 'Runtime.exceptionThrown') {
      exceptions.push(response.params.exceptionDetails.text);
    }
    if (calls.has(response.id)) {
      calls.get(response.id)(response);
      calls.delete(response.id);
    }
  };
  async function cmd(method, params = {}) {
    const seq = ++id;
    const result = await Promise.race([
      new Promise(ok => { calls.set(seq, ok); ws.send(JSON.stringify({ id: seq, method, params })); }),
      delay(20000).then(() => { throw Error(`CDP timeout: ${method}`); }),
    ]);
    if (result.error) throw Error(result.error.message);
    return result.result;
  }
  async function evaluate(expression) {
    return (await cmd('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result.value;
  }
  await cmd('Page.enable');
  await cmd('Network.enable');
  await cmd('Runtime.enable');
  await cmd('Emulation.setDeviceMetricsOverride', {
    width: 390, height: 760, deviceScaleFactor: 1, mobile: true,
  });
  // Returning-player state exposes Home directly. This uses the same persisted
  // shared_preferences key the app writes after its first-launch deck.
  await cmd('Page.addScriptToEvaluateOnNewDocument', {
    source: "try { localStorage.setItem('flutter.mafia.introSeen.v1', 'true'); localStorage.setItem('flutter.mm.store.onboardingSeen.v1', 'true'); localStorage.setItem('flutter.mafia.playerProfile.v1', JSON.stringify(JSON.stringify({name:'Browser Check',gender:'male'}))); } catch (_) {}",
  });
  await cmd('Page.navigate', { url: 'https://saidalmafia.com/' });
  await delay(65000);
  const page = await evaluate('({url:location.href,flutter:!!document.querySelector("flt-glass-pane"),ready:document.readyState,onboarding:localStorage.getItem("flutter.mm.store.onboardingSeen.v1"),text:document.body.innerText.slice(0,500)})');
  const clip = { x: 0, y: 0, width: 390, height: 760, scale: 420 / 760 };
  const breakShot = await cmd('Page.captureScreenshot', {
    format: 'png', clip,
  });
  await writeFile('build/web_ads_interstitial_check.png', Buffer.from(breakShot.data, 'base64'));
  // The app-open house break unlocks its close control after five seconds.
  for (const type of ['mousePressed', 'mouseReleased']) {
    await cmd('Input.dispatchMouseEvent', {
      type, x: 195, y: 480, button: 'left', clickCount: 1,
    });
  }
  await delay(3000);
  const shot = await cmd('Page.captureScreenshot', {
    format: 'png', clip,
  });
  await writeFile('build/web_ads_check.png', Buffer.from(shot.data, 'base64'));
  assert(page.url.startsWith('https://saidalmafia.com/'), page.url);
  assert(page.flutter, 'Flutter canvas missing');
  console.log('Chrome loaded production Flutter; screenshot build/web_ads_check.png (216×420)');
  console.log('Visible DOM text:', JSON.stringify(page.text));
  console.log('Page state:', JSON.stringify({ url: page.url, ready: page.ready, onboarding: page.onboarding }));
  console.log('Network failures:', failures.slice(0, 5));
  console.log('Browser exceptions:', exceptions.slice(0, 5));
} finally {
  ws?.close();
  chrome.kill();
}
