// node supabase/tests/request_envelope.test.mjs
//
// S4 + observability, at runtime. error_envelope.test.mjs proves every
// `fail(...)` is written as literals; this runs the real `_shared/api.ts` and
// proves what those literals become on the wire:
//
// * every refusal body is exactly {error, message, requestId};
// * no refusal carries role/team/target/seed/action/note keys (at any depth),
//   a UUID other than its own request id, or a player name;
// * the body is the same for every caller role (only the request id differs);
// * `x-request-id` matches the body, a database error is a generic 500 that
//   echoes nothing, and the one log line names no person, room or role.
//
// No network and no Deno: the Supabase import is stubbed and TypeScript is
// loaded with Node's type stripping.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { importTs } from './support/ts_loader.mjs';

const api = await importTs('supabase/functions/_shared/api.ts');
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;
const FORBIDDEN_KEYS = new Set(['role', 'team', 'target', 'seed', 'action', 'note',
  'roles', 'targetSeat', 'matchSeed', 'teammates', 'userId', 'name']);
const NAMES = ['Amira', 'Karim', 'Mona', 'Tarek', 'Salma', 'أميرة', 'كريم'];

/** Recursively rejects private keys, stray UUIDs and names. */
function assertClean(value, where, allowId) {
  if (Array.isArray(value)) return value.forEach((v, i) => assertClean(v, `${where}[${i}]`, allowId));
  if (value && typeof value === 'object') {
    for (const [k, v] of Object.entries(value)) {
      assert.ok(!FORBIDDEN_KEYS.has(k), `${where}.${k} is a private key`);
      if (k === 'requestId' && v === allowId) continue;
      assertClean(v, `${where}.${k}`, allowId);
    }
    return;
  }
  if (typeof value === 'string') {
    assert.ok(!UUID.test(value), `${where} carries a UUID: ${value}`);
    for (const n of NAMES) assert.ok(!value.includes(n), `${where} carries a name`);
  }
}

async function envelope(res) {
  const body = await res.json();
  const id = res.headers.get('x-request-id');
  assert.match(id ?? '', new RegExp(`^${UUID.source}$`, 'i'), 'x-request-id missing');
  return { body, id };
}

// 1. Every literal refusal every function can send ------------------------------
const pairs = new Map();
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (path.endsWith('.ts')) {
      const src = readFileSync(path, 'utf8');
      const re = /(?<![\w.])fail\(\s*"([A-Z_]+)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*(?:,\s*(\d{3}))?\s*\)/g;
      let m;
      while ((m = re.exec(src))) pairs.set(`${m[1]}|${m[2]}|${m[3] ?? 400}`, [m[1], m[2], Number(m[3] ?? 400)]);
    }
  }
})('supabase/functions');
assert.ok(pairs.size > 150, `only ${pairs.size} literal refusals found`);

const callers = ['mafia', 'doctor', 'detective', 'citizen', 'host', 'spectator', 'kicked', 'dead'];
let checked = 0;
for (const [code, message, status] of pairs.values()) {
  let first;
  for (const caller of callers) {
    // The caller's seat is not an input to fail(); running it under each role
    // proves nothing about the seat can reach the body.
    const res = api.fail(code, message, status);
    const { body, id } = await envelope(res);
    assert.equal(res.status, status);
    assert.deepEqual(Object.keys(body).sort(), ['error', 'message', 'requestId'],
      `${code}: unexpected keys ${Object.keys(body)}`);
    assert.equal(body.requestId, id, 'body and header ids differ');
    assert.equal(body.error, code);
    assertClean(body, `${code}(${caller})`, id);
    const shape = { error: body.error, message: body.message };
    if (first) assert.deepEqual(shape, first, `${code} differs by caller`);
    first = shape;
    checked++;
  }
}

// 2. ok() is additive and never overrides a replayed request id ------------------
{
  const { body, id } = await envelope(api.ok({ ok: true, state: {} }));
  assert.equal(body.requestId, id);
  const replay = await envelope(api.ok({ ok: true, requestId: 'kept' }));
  assert.equal(replay.body.requestId, 'kept', 'a replayed mutation keeps its own id');
  const list = await (api.ok([1, 2])).json();
  assert.deepEqual(list, [1, 2], 'non-object bodies are untouched');
}

// 3. handler(): unauthenticated, exception → generic 500, one clean log line -----
{
  const logs = [];
  const original = console.log;
  console.log = (line) => logs.push(String(line));
  try {
    const secret = 'role=mafia target=22222222-2222-4222-8222-222222222222 name=Amira';
    const serve = api.handler(async () => { throw new Error(secret); });
    const unauth = await serve(new Request('http://x/functions/v1/submit_night_action',
      { method: 'POST', headers: { Authorization: 'Bearer bad' } }));
    const u = await envelope(unauth);
    assert.equal(unauth.status, 401);
    assert.deepEqual(Object.keys(u.body).sort(), ['error', 'message', 'requestId']);

    const boom = await serve(new Request('http://x/functions/v1/submit_night_action',
      { method: 'POST', headers: { Authorization: 'Bearer good' } }));
    const b = await envelope(boom);
    assert.equal(boom.status, 500, 'a database error is a generic 500');
    assert.deepEqual(b.body, { error: 'BAD_REQUEST', message: 'request could not be completed', requestId: b.id });
    assertClean(b.body, 'exception', b.id);
    assert.notEqual(u.id, b.id, 'request ids are per request');

    const okServe = api.handler(async () => api.ok({ ok: true }));
    const good = await okServe(new Request('http://x/functions/v1/heartbeat',
      { method: 'POST', headers: { Authorization: 'Bearer good' } }));
    const g = await envelope(good);
    assert.equal(g.body.requestId, g.id);

    assert.equal(logs.length, 3, `one log line per request, got ${logs.length}`);
    const parsed = logs.map((l) => JSON.parse(l));
    for (const [i, line] of parsed.entries()) {
      assert.deepEqual(Object.keys(line).sort(), ['fn', 'latency', 'requestId', 'result']);
      assertClean(line, `log${i}`, line.requestId);
      assert.ok(!logs[i].includes('mafia') && !logs[i].includes('Amira'), 'log leaks the exception');
    }
    assert.deepEqual(parsed.map((l) => [l.fn, l.result]), [
      ['submit_night_action', 'refused_401'], ['submit_night_action', 'exception'], ['heartbeat', 'ok']]);
    assert.equal(parsed[1].requestId, b.id, 'log and response share the request id');
  } finally {
    console.log = original;
  }
  assert.equal(api.latencyBucket(50), '<100ms');
  assert.equal(api.latencyBucket(5000), '>=3s');
}

console.log(`PASS request envelope: ${pairs.size} literal refusals × ${callers.length} caller roles (${checked} bodies), ok/handler/log shape`);
