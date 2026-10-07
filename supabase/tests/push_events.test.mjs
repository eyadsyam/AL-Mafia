// node supabase/tests/push_events.test.mjs
// The outbox kinds (20261002000100_push_outbox.sql): wording, payload and
// Doc 05. A notification carries only its kind, and no line says anything a
// single seat alone knows (role, target, night result).
import assert from 'node:assert/strict';
import { EVENT_TEXT, messageFor, sendPush } from '../functions/_shared/push.ts';

const forbidden = ['دكتور', 'محقق', 'مواطن', 'قتل', 'اتقتل', 'مات', 'اتنقذ', 'حماية', 'دورك', 'ضحية', 'مشتبه'];

for (const [kind, spec] of Object.entries(EVENT_TEXT)) {
  assert.ok(spec.lines.length >= 2, `${kind}: more than one wording`);
  for (const line of spec.lines) {
    for (const word of forbidden) {
      assert.ok(!line.title.includes(word) && !line.body.includes(word), `${kind} leaks "${word}"`);
    }
  }
  for (const platform of ['android', 'web']) {
    for (let variant = 0; variant < 4; variant++) {
      const { message } = messageFor({ enabled: true, kind, variant }, 'tok'.repeat(10), platform);
      assert.deepEqual(message.data, { kind }, `${kind}/${platform}: data is the kind and nothing else`);
      const n = platform === 'android' ? message.notification : message.webpush.notification;
      assert.ok(n.title && n.body);
    }
  }
}

// The same row id always picks the same wording; different ids vary.
const bodies = new Set([0, 1, 2].map((variant) =>
  messageFor({ enabled: true, kind: 'daily', variant }, 'x'.repeat(20), 'android').message.notification.body));
assert.equal(bodies.size, 3);

// «الليل نزل» is identical for everyone: nothing in the message depends on the recipient.
const a = messageFor({ enabled: true, kind: 'night', variant: 7 }, 'a'.repeat(20), 'android');
const b = messageFor({ enabled: true, kind: 'night', variant: 7 }, 'b'.repeat(20), 'android');
delete a.message.token; delete b.message.token;
assert.deepEqual(a, b);
const night0 = messageFor({ enabled: true, kind: 'night', variant: 0 }, 'a'.repeat(20), 'android');
const night1 = messageFor({ enabled: true, kind: 'night', variant: 1 }, 'b'.repeat(20), 'android');
delete night0.message.token; delete night1.message.token;
assert.deepEqual(night0, night1, 'every seat gets identical room-event wording');

// Events with a big picture carry one; turn-like notices do not.
assert.ok(messageFor({ enabled: true, kind: 'thursday' }, 'x'.repeat(20), 'android').message.notification.image);
assert.ok(messageFor({ enabled: true, kind: 'thursday' }, 'x'.repeat(20), 'web').message.webpush.notification.image);
assert.equal(messageFor({ enabled: true, kind: 'night' }, 'x'.repeat(20), 'android').message.notification.image, undefined);

// No secret, no push — and no throw.
const logs = [];
const out = await sendPush(
  { enabled: true, kind: 'night', tokens: [{ token: 'x'.repeat(20), platform: 'android' }] },
  { secret: undefined, accessToken: async () => '', fetch: async () => { throw new Error('no'); }, dropToken: async () => {}, log: (l) => logs.push(l) });
assert.deepEqual(out, { result: 'skipped', reason: 'no_secret' });
console.log('push_events: ok');
