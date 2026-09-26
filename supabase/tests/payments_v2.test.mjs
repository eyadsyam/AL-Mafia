// node --experimental-strip-types supabase/tests/payments_v2.test.mjs
// Payments v2 edge validation and the owner's Telegram notice. No network:
// the builder returns a request; nothing here calls fetch.
import assert from 'node:assert/strict';
import {
  decodeProofImage, parseFilter, parsePlatform, parseReject, parseSender, parseSubmit,
  proofPath, PROOF_MAX_BYTES, REFUSALS, sha256Hex, telegramRequest, telegramText,
} from '../functions/_shared/coin_payments.ts';

globalThis.fetch = () => { throw new Error('network used in a unit test'); };
const b64 = (bytes) => Buffer.from(Uint8Array.from(bytes)).toString('base64');
const jpeg = b64([0xff, 0xd8, 0xff, 0xe0, ...Array(40).fill(7)]);
const png = b64([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...Array(40).fill(1)]);
const webp = b64([...Buffer.from('RIFF'), 0, 0, 0, 0, ...Buffer.from('WEBPVP8 '), ...Array(30).fill(2)]);
const order = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

// Platform: only the two builds that sell.
assert.equal(parsePlatform('android'), 'android');
assert.equal(parsePlatform('web'), 'web');
assert.equal(parsePlatform('ios'), null);

// Image: required, judged by its bytes, bounded.
assert.equal(decodeProofImage(undefined).ok, false);
assert.equal(decodeProofImage('').ok, false);
assert.equal(decodeProofImage(jpeg).value.mime, 'image/jpeg');
assert.equal(decodeProofImage(`data:image/jpeg;base64,${jpeg}`).value.ext, 'jpg');
assert.equal(decodeProofImage(png).value.mime, 'image/png');
assert.equal(decodeProofImage(webp).value.mime, 'image/webp');
assert.equal(decodeProofImage(b64([...Buffer.from('%PDF-1.7 fake document body')])).ok, false, 'pdf refused');
assert.equal(decodeProofImage(b64([...Buffer.from('<svg onload=alert(1)></svg> ....')])).ok, false, 'svg refused');
assert.equal(decodeProofImage('!!!!not base64!!!!').ok, false);
const huge = Buffer.alloc(PROOF_MAX_BYTES + 10, 0); huge[0] = 0xff; huge[1] = 0xd8; huge[2] = 0xff;
assert.equal(decodeProofImage(huge.toString('base64')).error, 'image too large');

// Sender name: required, as the payment app shows it (any script, digits ok).
assert.equal(parseSender('  إياد   عبد الرحمن '), 'إياد عبد الرحمن');
assert.equal(parseSender('01012345678'), '01012345678', 'Vodafone Cash may show a number');
assert.equal(parseSender('E'), null);
assert.equal(parseSender(''), null);
assert.equal(parseSender('<script>x</script>'), null);
assert.equal(parseSender('a'.repeat(81)), null);

// Submit: order, platform, sender and image are all required; prices never read.
const good = { order, platform: 'android', senderName: 'Eyad S', image: jpeg, amount: 1, coins: 99999 };
const parsed = parseSubmit(good);
assert.equal(parsed.ok, true);
assert.deepEqual(Object.keys(parsed.value).sort(), ['image', 'order', 'platform', 'sender']);
assert.equal(parseSubmit({ ...good, image: undefined }).ok, false, 'upload required');
assert.equal(parseSubmit({ ...good, senderName: ' ' }).ok, false, 'sender required');
assert.equal(parseSubmit({ ...good, order: 'x' }).ok, false);
assert.equal(parseSubmit({ ...good, platform: 'ios' }).ok, false);

// Hash is of the bytes: the same image is the same hash, whatever its wrapper.
const h1 = await sha256Hex(decodeProofImage(jpeg).value.bytes);
const h2 = await sha256Hex(decodeProofImage(`data:image/jpeg;base64,${jpeg}`).value.bytes);
assert.match(h1, /^[0-9a-f]{64}$/);
assert.equal(h1, h2);
assert.notEqual(h1, await sha256Hex(decodeProofImage(png).value.bytes));
assert.equal(proofPath('u1', order, 'n1', 'jpg'), `u1/${order}/n1.jpg`);

// Admin inputs.
assert.equal(parseReject({ order, reason: 'no' }).ok, false, 'a reason is required');
assert.equal(parseReject({ order, reason: 'Amount not received' }).value.reason, 'Amount not received');
assert.equal(parseFilter('approved'), 'approved');
assert.equal(parseFilter('drop table'), 'pending');
for (const code of ['TOO_MANY_PENDING', 'DUPLICATE_PROOF', 'PROOF_REQUIRED', 'SENDER_REQUIRED', 'SALES_DISABLED']) {
  assert.ok(REFUSALS[code], code);
}

// Telegram: product, price, sender, short id, deep link; plain text.
const notice = {
  id: order, reference: 'MM-1A2B3C4D', pack: 'coins_500', coins: 500, amountPiastres: 4999,
  method: 'instapay', senderName: 'Eyad <b>S</b>',
};
const text = telegramText(notice);
assert.match(text, /Order: MM-1A2B3C4D \(#7c9e6679\)/);
assert.match(text, /Product: 500 coins/);
assert.match(text, /Price: 49\.99 EGP/);
assert.match(text, /Method: InstaPay/);
assert.match(text, /Sender: Eyad <b>S<\/b>/);
assert.ok(text.includes(`https://almafia.vercel.app/admin?order=${order}`));
assert.match(telegramText({ ...notice, pack: 'quiet_pass', coins: 0, entitlement: 'remove_interruptions', amountPiastres: 19999 }), /Quiet Pass[^\n]*\nPrice: 199\.99 EGP/);
assert.match(telegramText({ ...notice, pack: 'starter_bundle', coins: 600, item: 'frame_council_seal', amountPiastres: 2999 }), /Starter Bundle \(600 coins \+ frame_council_seal\)/);

// Secrets absent or malformed: skip silently.
const env = (v) => (n) => v[n];
assert.equal(telegramRequest(env({}), notice), null);
assert.equal(telegramRequest(env({ TELEGRAM_BOT_TOKEN: '123:abcdefghijklmnopqrstuvwxyz' }), notice), null);
assert.equal(telegramRequest(env({ TELEGRAM_BOT_TOKEN: 'bad', TELEGRAM_ADMIN_CHAT_ID: '12345' }), notice), null);
const token = '123456:ABCdefGHIjklMNOpqrSTUvwxYZ_0123';
const req = telegramRequest(env({ TELEGRAM_BOT_TOKEN: token, TELEGRAM_ADMIN_CHAT_ID: '-100123456' }), notice);
assert.equal(req.url, `https://api.telegram.org/bot${token}/sendMessage`);
const sent = JSON.parse(req.body);
assert.equal(sent.chat_id, '-100123456');
assert.equal(sent.parse_mode, undefined, 'no markup parsing');
assert.equal(sent.text, text);
assert.ok(!req.body.includes(token), 'the token is never in the message body');
console.log('PASS payments v2: platform, image bytes/size, sender, submit, hash, admin inputs, Telegram builder');
