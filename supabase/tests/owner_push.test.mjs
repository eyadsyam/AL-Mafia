// node supabase/tests/owner_push.test.mjs
// The owner's notices (20261030000200_owner_push.sql): each opens its admin
// page on the website and carries its kind and that link only — no amount,
// name, reference or payment method.
import assert from 'node:assert/strict';
import { OWNER_TEXT, WEB_ORIGIN, isOwnerKind, messageFor } from '../functions/_shared/push.ts';

const forbidden = ['جنيه', 'EGP', 'instapay', 'vodafone', 'فودافون', 'انستاباي', '@'];

assert.deepEqual(Object.keys(OWNER_TEXT).sort(), [
  'owner_claimed', 'owner_feedback', 'owner_order', 'owner_play', 'owner_report', 'owner_tester',
]);
assert.equal(OWNER_TEXT.owner_feedback.path, '/admin/review');
for (const [kind, spec] of Object.entries(OWNER_TEXT)) {
  assert.ok(isOwnerKind(kind));
  assert.ok(spec.path.startsWith('/admin'), `${kind} opens an admin page`);
  for (const word of forbidden) {
    assert.ok(!spec.title.includes(word) && !spec.body.includes(word), `${kind} carries "${word}"`);
  }
  for (const platform of ['android', 'web']) {
    const { message } = messageFor({ enabled: true, kind }, 'tok'.repeat(10), platform);
    const link = `${WEB_ORIGIN}${spec.path}`;
    assert.deepEqual(message.data, { kind, link }, `${kind}/${platform}: kind and link only`);
    if (platform === 'web') {
      assert.equal(message.webpush.fcm_options.link, link);
      assert.equal(message.webpush.notification.title, spec.title);
    } else {
      assert.equal(message.notification.title, spec.title);
      assert.equal(message.android.priority, 'HIGH');
    }
  }
}

// Every other kind keeps its own message.
assert.ok(!isOwnerKind('order_paid'));
assert.ok(!isOwnerKind('night'));
assert.equal(messageFor({ enabled: true, kind: 'night' }, 'x'.repeat(20), 'android').message.data.kind, 'night');

console.log('owner_push: ok');
