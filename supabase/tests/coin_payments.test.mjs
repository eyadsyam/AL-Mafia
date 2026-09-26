// node --experimental-strip-types supabase/tests/coin_payments.test.mjs
import assert from 'node:assert/strict';
import {
  parseClaim, parseCreate, parseReview, paymentMethods,
} from '../functions/_shared/coin_payments.ts';

const env = (values) => (name) => values[name];

// Only a configured https destination is offered; http is refused, not upgraded.
let methods = paymentMethods(env({}));
assert.deepEqual(methods.map((m) => [m.code, m.available, m.reason]), [
  ['instapay', false, 'not_configured'], ['vodafone_cash', false, 'not_configured'],
]);
methods = paymentMethods(env({
  COIN_PAY_INSTAPAY_URL: 'https://pay.example/instapay/abc',
  COIN_PAY_VODAFONE_CASH_URL: 'http://pay.example/vf?id=1',
}));
assert.equal(methods[0].available, true);
assert.equal(methods[0].url, 'https://pay.example/instapay/abc');
assert.equal(methods[1].available, false);
assert.equal(methods[1].reason, 'not_https');
assert.equal(methods[1].url, undefined, 'an unavailable method exposes no link');
assert.equal(paymentMethods(env({ COIN_PAY_INSTAPAY_URL: 'https://u:p@x.example/' }))[0].available, false);
assert.equal(paymentMethods(env({ COIN_PAY_INSTAPAY_URL: 'not a url' }))[0].available, false);


// Price tampering: the client cannot send amounts; unknown fields are dropped.
const created = parseCreate({ pack: 'coins_500', method: 'instapay', coins: 99999, amount: 1 });
assert.deepEqual(created, { ok: true, value: { pack: 'coins_500', method: 'instapay' } });
assert.equal(parseCreate({ pack: 'coins_500', method: 'paypal' }).ok, false);
assert.equal(parseCreate({ pack: "x'; drop", method: 'instapay' }).ok, false);

const order = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
assert.equal(parseClaim({ order, reference: 'TXN 123/45' }).ok, true);
assert.equal(parseClaim({ order, reference: '12' }).ok, false, 'reference too short');
assert.equal(parseClaim({ order: 'nope', reference: 'TXN12345' }).ok, false);
assert.equal(parseClaim({ order, reference: 'TXN12345', payerHint: 'PIN 12345678' }).ok, false,
  'long digit runs (PIN/OTP/account) are not stored');
assert.equal(parseClaim({ order, reference: 'TXN12345', payerHint: 'Eyad S.' }).value.payerHint, 'Eyad S.');

assert.equal(parseReview({ order, decision: 'approve', transaction: 'T-1', receivedPiastres: 5000 }).ok, true);
assert.equal(parseReview({ order, decision: 'credit' }).ok, false);
assert.equal(parseReview({ order, decision: 'approve', receivedPiastres: -5 }).ok, false);
assert.equal(parseReview({ order, decision: 'approve', receivedPiastres: 1.5 }).ok, false);
console.log('PASS coin payments: https-only methods, no client prices, claim/review validation');
