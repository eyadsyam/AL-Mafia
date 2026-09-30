// Production read/write smoke for the closed-test launch. Stores short-lived
// anonymous sessions under ignored build/ so reruns do not exhaust sign-ups.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import assert from 'node:assert/strict';

const defines = JSON.parse(await readFile('dart_defines.json', 'utf8'));
const origin = defines.SUPABASE_URL?.replace(/\/$/, '');
const key = defines.SUPABASE_KEY;
assert(origin && key, 'Supabase client configuration is missing');
const cachePath = 'build/prod_launch_smoke_sessions.json';
let sessions = await readFile(cachePath, 'utf8').then(JSON.parse).catch(() => []);
const results = [];

async function request(path, body, session, method = 'POST') {
  const response = await fetch(`${origin}${path}`, {
    method,
    headers: { apikey: key, Authorization: `Bearer ${session?.access_token ?? key}`,
      'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const raw = await response.text();
  let data; try { data = JSON.parse(raw); } catch { data = raw; }
  return { status: response.status, data };
}

async function session(index) {
  if (sessions[index]?.access_token) {
    const check = await request('/auth/v1/user', undefined, sessions[index], 'GET');
    if (check.status === 200) return sessions[index];
  }
  const signed = await request('/auth/v1/signup', {});
  if (signed.status !== 200 || !signed.data.access_token) {
    throw Error(`anonymous sign-in unavailable (${signed.status})`);
  }
  sessions[index] = signed.data;
  await mkdir('build', { recursive: true });
  await writeFile(cachePath, JSON.stringify(sessions));
  return sessions[index];
}

async function check(label, run) {
  try { const detail = await run(); results.push({ label, pass: true, detail }); }
  catch (error) { results.push({ label, pass: false, detail: String(error.message ?? error) }); }
}

const host = await session(0);
const guest = await session(1);
const invitee = await session(2);
let room;
await check('create room', async () => {
  const r = await request('/functions/v1/create_room', { name: 'LaunchHost' }, host);
  assert.equal(r.status, 200); assert.match(r.data.code, /^[A-HJ-NP-Z2-9]{6}$/);
  room = r.data;
  return `code ${room.code}`;
});
await check('join by code', async () => {
  assert(room);
  const r = await request('/functions/v1/join_room', { code: room.code, name: 'LaunchGuest' }, guest);
  assert.equal(r.status, 200); return 'joined';
});
await check('join by link', async () => {
  assert(room);
  const link = new URL(`/join/${room.code}`, 'https://saidalmafia.com');
  const r = await request('/functions/v1/join_room', { code: link.pathname.split('/').at(-1), name: 'LaunchGuest' }, guest);
  assert.equal(r.status, 200); return 'same seat restored';
});
await check('username invite creates inbox row', async () => {
  assert(room);
  const handle = `launch${Date.now().toString(36).slice(-9)}`;
  await request('/functions/v1/friends', { action: 'hello', name: 'LaunchInvitee', gender: 'unspecified', tz: 'Africa/Cairo', locale: 'ar' }, invitee);
  const set = await request('/functions/v1/friends', { action: 'setHandle', handle }, invitee);
  assert.equal(set.status, 200);
  const sent = await request('/functions/v1/friends', { action: 'invite', handle, roomId: room.roomId }, host);
  assert.equal(sent.status, 200);
  const inbox = await request('/functions/v1/friends', { action: 'inbox' }, invitee);
  assert.equal(inbox.status, 200);
  assert(inbox.data.invites?.some(i => i.id === sent.data.inviteId));
  return 'invite delivered';
});
for (const platform of ['android', 'web']) {
  await check(`${platform} transfer methods`, async () => {
    const r = await request('/functions/v1/coin_orders', { action: 'shop', platform }, host);
    assert.equal(r.status, 200);
    const methods = (r.data.methods ?? []).filter(m => m.available).map(m => m.code);
    assert(methods.includes('instapay') && methods.includes('vodafone_cash'));
    return methods.join(',');
  });
}
await check('unverified reward refused', async () => {
  const r = await request('/functions/v1/admob_ssv?signature=unverified', undefined, undefined, 'GET');
  assert.equal(r.status, 400); return 'HTTP 400';
});
for (const r of results) console.log(`${r.pass ? 'PASS' : 'FAIL'} ${r.label}: ${r.detail}`);
if (results.some(r => !r.pass)) process.exitCode = 1;
