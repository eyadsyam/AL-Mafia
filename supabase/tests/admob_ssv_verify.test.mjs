// node supabase/tests/admob_ssv_verify.test.mjs
import assert from 'node:assert/strict';
import {
  cachedKeyLoader, KeysUnavailable, verifySsv,
} from '../functions/admob_ssv/verify.ts';

const subtle = globalThis.crypto.subtle;

function toDer(raw) {
  const part = (bytes) => {
    let i = 0;
    while (i < bytes.length - 1 && bytes[i] === 0) i++;
    let v = bytes.slice(i);
    if (v[0] & 0x80) v = Uint8Array.from([0, ...v]);
    return [0x02, v.length, ...v];
  };
  const body = [...part(raw.slice(0, 32)), ...part(raw.slice(32))];
  return Uint8Array.from([0x30, body.length, ...body]);
}
const b64url = (bytes) => Buffer.from(bytes).toString('base64')
  .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function keyPair() {
  const pair = await subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const spki = Buffer.from(await subtle.exportKey('spki', pair.publicKey)).toString('base64');
  return { pair, spki };
}
async function callback(privateKey, keyId, query) {
  const signed = new TextEncoder().encode(query);
  const raw = new Uint8Array(await subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, privateKey, signed));
  return new URL(`https://x.test/admob_ssv?${query}&signature=${b64url(toDer(raw))}&key_id=${keyId}`);
}

const query = 'ad_network=5450213213286189855&ad_unit=5224354917&custom_data=claim-1'
  + '&reward_amount=1&reward_item=coins&timestamp=1700000000000&transaction_id=t-1&user_id=u-1';
const current = await keyPair();
const rotated = await keyPair();
const keys = (entries) => new Map(entries);

// A correct signature is valid.
{
  const url = await callback(current.pair.privateKey, 11, query);
  assert.equal(await verifySsv(url, async () => keys([[11, current.spki]])), 'valid');
}

// A wrong signature, a tampered query and garbage are invalid (400), not errors.
{
  const other = await keyPair();
  const wrong = await callback(other.pair.privateKey, 11, query);
  assert.equal(await verifySsv(wrong, async () => keys([[11, current.spki]])), 'invalid');
  const good = await callback(current.pair.privateKey, 11, query);
  const tampered = new URL(good.href.replace('reward_amount=1', 'reward_amount=9'));
  assert.equal(await verifySsv(tampered, async () => keys([[11, current.spki]])), 'invalid');
  const garbage = new URL(`https://x.test/?${query}&signature=AAAA&key_id=11`);
  assert.equal(await verifySsv(garbage, async () => keys([[11, current.spki]])), 'invalid');
  assert.equal(await verifySsv(new URL('https://x.test/?a=1'), async () => keys([])), 'invalid');
}

// Rotation: a key id missing from the cached list triggers one fresh fetch.
{
  const url = await callback(rotated.pair.privateKey, 12, query);
  const asked = [];
  const verdict = await verifySsv(url, async (fresh) => {
    asked.push(fresh);
    return fresh ? keys([[11, current.spki], [12, rotated.spki]]) : keys([[11, current.spki]]);
  });
  assert.equal(verdict, 'valid');
  assert.deepEqual(asked, [false, true]);
}

// Unknown key id even after a fresh fetch: invalid.
{
  const url = await callback(rotated.pair.privateKey, 99, query);
  assert.equal(await verifySsv(url, async () => keys([[11, current.spki]])), 'invalid');
}

// Network failure fetching Google's keys: KeysUnavailable (503, retried), never "invalid".
{
  const url = await callback(current.pair.privateKey, 11, query);
  const load = cachedKeyLoader(async () => { throw new TypeError('fetch failed'); });
  await assert.rejects(verifySsv(url, load), KeysUnavailable);
  const empty = cachedKeyLoader(async () => new Map());
  await assert.rejects(verifySsv(url, empty), KeysUnavailable);
}

// The cache: reused within the hour; a forced refresh at most once a minute.
{
  let t = 0; let fetches = 0;
  const load = cachedKeyLoader(async () => { fetches++; return keys([[11, current.spki]]); }, () => t);
  await load(false); await load(false); assert.equal(fetches, 1);
  await load(true); assert.equal(fetches, 1, 'forced refresh is rate limited');
  t = 61 * 1000; await load(true); assert.equal(fetches, 2);
  t = 2 * 60 * 60 * 1000; await load(false); assert.equal(fetches, 3, 'expires after an hour');
  // A failed refresh does not poison a later one.
  let fail = true;
  const flaky = cachedKeyLoader(async () => { if (fail) throw new Error('down'); return keys([[1, 'x']]); }, () => 0);
  await assert.rejects(flaky(false), KeysUnavailable);
  fail = false; assert.equal((await flaky(false)).size, 1);
}

console.log('admob_ssv verify: all assertions passed');
