// Runs the isolated build from voice_runtime_probe.dart.
//
//   node tool/run_voice_runtime_probe.mjs            local media path only
//   node tool/run_voice_runtime_probe.mjs --hosted   two players, two browsers
//
// Hosted mode starts two Chrome instances with two disposable user-data-dirs.
// That is the whole point: an earlier version ran both players in one page and
// the Supabase SDK synchronised their auth sessions through a BroadcastChannel,
// so the two "players" became one identity. Separate profiles share no storage
// and no broadcast channel, so the isolation is real rather than patched.
//
// The room code passes from the host page to the guest page through this
// script and is never printed. Neither is anything else the probe holds: the
// page publishes booleans, counts and redacted traces only.
//
// Synthetic microphones. Not a human-hearing test.
import { createServer } from 'node:http';
import { spawn, execFileSync } from 'node:child_process';
import { createReadStream } from 'node:fs';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { resolve, join, sep, extname } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const hosted = process.argv.includes('--hosted');
const strictAutoplay = process.argv.includes('--strict-autoplay');
const relayOnly = process.argv.includes('--relay-only');
const root = resolve('build/voice-probe');
const chromePath = process.env.CHROME_EXECUTABLE
  ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const deadline = Date.now() + (hosted ? 300000 : 120000);

const server = createServer(async (req, res) => {
  const path = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
  if (path !== root && !path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try {
    const file = (await stat(path)).isDirectory() ? join(path, 'index.html') : path;
    const type = { '.js': 'text/javascript', '.wasm': 'application/wasm', '.html': 'text/html', '.json': 'application/json' }[extname(file)];
    res.writeHead(200, { 'Content-Type': type ?? 'application/octet-stream' });
    createReadStream(file).pipe(res);
  } catch { res.writeHead(404).end(); }
});

const browsers = [];

/// One disposable browser: its own profile, its own storage, its own session.
async function openBrowser(label) {
  const profile = await mkdtemp(resolve('build/voice-probe-profile-'));
  const process_ = spawn(chromePath, [
    '--headless=new', `--user-data-dir=${profile}`, '--remote-debugging-port=0',
    '--no-first-run', '--no-default-browser-check', '--use-fake-device-for-media-stream',
    '--use-fake-ui-for-media-stream',
    strictAutoplay ? '--autoplay-policy=document-user-activation-required' : '--autoplay-policy=no-user-gesture-required',
    'about:blank',
  ], { windowsHide: true, stdio: 'ignore' });
  const browser = { label, profile, process: process_ };
  browsers.push(browser);

  let debugPort;
  while (!debugPort && Date.now() < deadline) {
    try { debugPort = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; }
    catch { await delay(250); }
  }
  if (!debugPort) throw Error(`${label}: browser startup timed out`);

  const tabs = await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json();
  const socket = new WebSocket(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
  await new Promise((ok, fail) => { socket.onopen = ok; socket.onerror = fail; });
  browser.socket = socket;

  let nextId = 0;
  const pending = new Map();
  socket.onmessage = event => {
    const message = JSON.parse(event.data);
    if (pending.has(message.id)) { pending.get(message.id)(message); pending.delete(message.id); }
  };
  browser.command = (method, params) => new Promise(ok => {
    const id = ++nextId;
    pending.set(id, ok);
    socket.send(JSON.stringify({ id, method, params }));
  });
  browser.read = async id => {
    const response = await Promise.race([
      browser.command('Runtime.evaluate', {
        expression: `document.getElementById(${JSON.stringify(id)})?.textContent`,
        returnByValue: true,
      }),
      delay(5000).then(() => null),
    ]);
    return response?.result?.result?.value ?? null;
  };
  // Test-only network constraint: disallow direct candidates without changing
  // production defaults or credentials. The report must confirm relay use.
  if (relayOnly) {
    await browser.command('Page.enable', {});
    await browser.command('Page.addScriptToEvaluateOnNewDocument', {
      source: `(() => {
        const Native = window.RTCPeerConnection;
        window.__relayProbeTypes = [];
        window.RTCPeerConnection = class extends Native {
          constructor(config, constraints) {
            super({...config, iceTransportPolicy: 'relay'}, constraints);
          }
          async getStats(selector) {
            const reports = await super.getStats(selector);
            reports.forEach(report => {
              if (report.type === 'candidate-pair' && report.state === 'succeeded' && report.nominated) {
                const candidate = reports.get(report.localCandidateId);
                if (candidate?.candidateType) window.__relayProbeTypes.push(candidate.candidateType);
              }
            });
            return reports;
          }
        };
      })();`,
    });
  }
  return browser;
}

/// Polls one element until it holds something other than the running marker.
async function waitFor(browser, id, { json = true, abortOn } = {}) {
  while (Date.now() < deadline) {
    const value = await browser.read(id);
    if (strictAutoplay && await browser.read('playout-retry-needed')) {
      await browser.command('Input.dispatchMouseEvent', {type:'mousePressed',x:10,y:10,button:'left',clickCount:1});
      await browser.command('Input.dispatchMouseEvent', {type:'mouseReleased',x:10,y:10,button:'left',clickCount:1});
    }
    if (value && value !== 'RUNNING') {
      if (!json) return value;
      if (value.startsWith('{')) return JSON.parse(value);
    }
    // A page that has already published its report is never going to publish
    // the thing being waited for; show its failure instead of a timeout.
    if (abortOn) {
      const report = await browser.read(abortOn);
      if (report?.startsWith('{')) {
        const parsed = JSON.parse(report);
        throw Error(`${browser.label} stopped at ${parsed.failedStage ?? 'unknown'}: `
          + JSON.stringify(parsed.checks));
      }
    }
    await delay(500);
  }
  throw Error(`${browser.label}: ${id} did not arrive before the deadline`);
}

try {
  await new Promise(ok => server.listen(0, '127.0.0.1', ok));
  const port = server.address().port;
  const url = path => `http://127.0.0.1:${port}/${path}`;

  if (!hosted) {
    const only = await openBrowser('local');
    await only.command('Page.navigate', { url: url('') });
    const report = await waitFor(only, 'voice-runtime-result');
    console.log(JSON.stringify(report, null, 2));
    process.exitCode = report.status === 'PASS' ? 0 : 1;
  } else {
    const host = await openBrowser('A');
    await host.command('Page.navigate', { url: url('?role=A') });
    // Held in a variable and passed on. Never logged, never in the report.
    const code = (await waitFor(host, 'voice-probe-code',
      { json: false, abortOn: 'voice-runtime-result' })).trim();
    const guest = await openBrowser('B');
    await guest.command('Page.navigate', {
      url: url(`?role=B&code=${encodeURIComponent(code)}`),
    });
    const [a, b] = await Promise.all([
      waitFor(host, 'voice-runtime-result'),
      waitFor(guest, 'voice-runtime-result'),
    ]);
    // Cross-check that the two browsers really were two people: each side's
    // peer must be the other side's self.
    const paired = a.evidence?.self && b.evidence?.self
      && a.evidence.self !== b.evidence.self
      && a.evidence.self === b.evidence.peer
      && b.evidence.self === a.evidence.peer;
    // The engine samples its connection diagnostic once at the connected
    // event, when selected-pair stats can still be absent. Read the actual
    // nominated pairs captured by subsequent RTP-stat samples as well.
    const relayTypes = relayOnly ? await Promise.all([host, guest].map(async browser => {
      const reply = await browser.command('Runtime.evaluate', {
        expression: 'Array.from(new Set(window.__relayProbeTypes ?? []))', returnByValue: true,
      });
      return reply.result?.result?.value ?? [];
    })) : [];
    const relayVerified = !relayOnly || relayTypes.every(types =>
      types.length > 0 && types.every(type => type === 'relay'));
    console.log(JSON.stringify({
      status: a.status === 'PASS' && b.status === 'PASS' && paired && relayVerified ? 'PASS' : 'FAIL',
      twoDistinctPlayers: Boolean(paired),
      relayOnly, relayVerified, relayTypes,
      A: a, B: b,
    }, null, 2));
    process.exitCode = a.status === 'PASS' && b.status === 'PASS' && paired && relayVerified ? 0 : 1;
  }
} catch (error) {
  console.error('Probe runner failed:', error.message);
  process.exitCode = 1;
} finally {
  for (const browser of browsers) {
    browser.socket?.close();
    if (browser.process?.pid) {
      try {
        execFileSync('taskkill', ['/PID', String(browser.process.pid), '/T', '/F'],
          { windowsHide: true, stdio: 'ignore' });
      } catch {}
    }
    // Only profiles this invocation generated, and only inside the project.
    if (!browser.profile.startsWith(resolve('build') + sep)) throw Error('Invalid cleanup path');
    await rm(browser.profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 300 });
  }
  server.closeAllConnections();
  server.close();
}
