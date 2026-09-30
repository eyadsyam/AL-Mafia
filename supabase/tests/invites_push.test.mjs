// node supabase/tests/invites_push.test.mjs
// `friends` routing for search/discover/invite/registerPush/hello, the
// country bucket (time zone + locale only), and the FCM step: skipped without
// the secret, dead tokens dropped, and a payload that names nothing but the
// room code, the sender's name/handle and the invite id (Doc 05).
import assert from 'node:assert/strict';
import { friendsCall, countryFrom, languageFrom } from '../functions/_shared/friends_actions.ts';
import { inviteMessage, sendInvitePush, messageFor } from '../functions/_shared/push.ts';

const me = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
const room = '00000000-0000-4000-8000-0000000000CD';
const invite = '00000000-0000-4000-8000-0000000000EF';

// ── Routing: the caller is always the session ──────────────────────────────
assert.deepEqual(friendsCall({ action: 'search', query: 'نور', p_user: other }, me),
  { fn: 'directory_search', args: { p_user: me, p_query: 'نور', p_page: 0 } });
assert.deepEqual(friendsCall({ action: 'search', query: 'x', page: 2 }, me).args.p_page, 2);
assert.equal(friendsCall({ action: 'search', query: 'x', page: -1 }, me), null);
assert.equal(friendsCall({ action: 'search', query: 'x', page: 1.5 }, me), null);
assert.equal(friendsCall({ action: 'search', query: 'x'.repeat(41) }, me), null);

assert.deepEqual(friendsCall({ action: 'discover' }, me),
  { fn: 'directory_discover', args: { p_user: me, p_filter: null, p_page: 0 } });
for (const filter of ['near', 'online', 'played', 'level']) {
  assert.equal(friendsCall({ action: 'discover', filter }, me).args.p_filter, filter);
}
assert.equal(friendsCall({ action: 'discover', filter: 'gps' }, me), null);

// Invite: a friend by id or anyone by handle — exactly one of them.
assert.deepEqual(friendsCall({ action: 'invite', handle: 'اياد_2', roomId: room }, me),
  { fn: 'room_invite_send', args: { p_user: me, p_handle: 'اياد_2', p_target: null, p_room: room.toLowerCase() } });
assert.deepEqual(friendsCall({ action: 'invite', userId: other, roomId: room }, me).args,
  { p_user: me, p_handle: null, p_target: other, p_room: room.toLowerCase() });
assert.equal(friendsCall({ action: 'invite', userId: other, handle: 'x', roomId: room }, me), null);
assert.equal(friendsCall({ action: 'invite', roomId: room }, me), null);
assert.equal(friendsCall({ action: 'invite', handle: 'a b', roomId: room }, me), null);
assert.equal(friendsCall({ action: 'invite', handle: 'x', roomId: 'nope' }, me), null);
assert.equal(friendsCall({ action: 'invite', userId: 'nope', roomId: room }, me), null);

assert.deepEqual(friendsCall({ action: 'respondInvite', inviteId: invite, accept: true }, me),
  { fn: 'invite_respond', args: { p_user: me, p_invite: invite.toLowerCase(), p_accept: true } });
assert.equal(friendsCall({ action: 'respondInvite', inviteId: invite }, me), null);

assert.deepEqual(friendsCall({ action: 'registerPush', token: 't'.repeat(40), platform: 'web' }, me),
  { fn: 'push_token_register', args: { p_user: me, p_token: 't'.repeat(40), p_platform: 'web' } });
assert.equal(friendsCall({ action: 'registerPush', token: 'short', platform: 'web' }, me), null);
assert.equal(friendsCall({ action: 'registerPush', token: 't'.repeat(40), platform: 'ios' }, me), null);

assert.deepEqual(friendsCall({ action: 'hello', name: 'إياد', gender: 'male', tz: 'Africa/Cairo', locale: 'ar' }, me),
  { fn: 'directory_hello', args: { p_user: me, p_name: 'إياد', p_gender: 'male', p_country: 'EG', p_lang: 'ar' } });
assert.equal(friendsCall({ action: 'hello', name: '' }, me), null);
// Nothing but tz and locale reaches the server: coordinates are ignored.
assert.deepEqual(Object.keys(friendsCall({ action: 'hello', name: 'A', lat: 30, lng: 31 }, me).args).sort(),
  ['p_country', 'p_gender', 'p_lang', 'p_name', 'p_user']);

assert.deepEqual(friendsCall({ action: 'setHandle', handle: 'salma_ali' }, me).args,
  { p_user: me, p_handle: 'salma_ali' });
assert.equal(friendsCall({ action: 'setHandle', handle: 'ab' }, me), null);
assert.deepEqual(friendsCall({ action: 'prefs', searchable: false }, me).args,
  { p_user: me, p_searchable: false, p_stranger_invites: null });
assert.equal(friendsCall({ action: 'prefs' }, me), null);
assert.equal(friendsCall({ action: 'prefs', searchable: 'no' }, me), null);
assert.equal(friendsCall({ action: 'teleport' }, me), null);
assert.equal(friendsCall({ action: 'status' }, me).fn, 'friends_status');

// ── Country bucket ─────────────────────────────────────────────────────────
assert.equal(countryFrom('Africa/Cairo', 'en'), 'EG');
assert.equal(countryFrom('Asia/Riyadh', 'ar-EG'), 'SA', 'the zone wins over the locale');
assert.equal(countryFrom('Etc/GMT-3', 'ar_KW'), 'KW', 'unknown zone: the locale region');
assert.equal(countryFrom('', 'ar'), null);
assert.equal(languageFrom('ar-EG'), 'ar');
assert.equal(languageFrom(''), null);

// ── Payload: Doc 05 ────────────────────────────────────────────────────────
const target = {
  enabled: true, kind: 'invite', inviteId: invite, code: 'K7M2QP', fromName: 'إياد', fromHandle: 'eyad',
  tokens: [{ token: 'a'.repeat(40), platform: 'android' }, { token: 'w'.repeat(40), platform: 'web' }],
};
const android = inviteMessage(target, 'a'.repeat(40), 'android').message;
assert.deepEqual(Object.keys(android.data).sort(), ['code', 'fromHandle', 'fromName', 'inviteId', 'kind']);
assert.equal(android.android.notification.channel_id, 'mafia_invites');
assert.equal(android.android.notification.sound, 'invite_knock');
assert.equal(android.android.priority, 'HIGH');
const web = inviteMessage(target, 'w'.repeat(40), 'web').message;
assert.equal(web.webpush.notification.requireInteraction, true);
assert.equal(web.webpush.fcm_options.link, 'https://saidalmafia.com/join/K7M2QP');
assert.ok(Array.isArray(web.webpush.notification.vibrate));
const words = JSON.stringify([android, web]).toLowerCase();
// (The brand word appears in channel and icon names; the data itself is checked below.)
assert.ok(!JSON.stringify(android.data).toLowerCase().includes('mafia'));
for (const banned of ['role', 'doctor', 'detective', 'seat', 'phase', 'night', 'vote']) {
  assert.ok(!words.includes(banned), `payload mentions ${banned}`);
}
assert.throws(() => inviteMessage({ ...target, code: '../x' }, 't', 'web'));

// ── Push step ──────────────────────────────────────────────────────────────
const logs = [];
const calls = [];
const dropped = [];
const deps = (over = {}) => ({
  secret: undefined,
  accessToken: async () => 'access',
  fetch: async (url, init) => { calls.push({ url, init }); return new Response('{}', { status: 200 }); },
  dropToken: async (t) => { dropped.push(t); },
  log: (line) => logs.push(line),
  ...over,
});

assert.deepEqual(await sendInvitePush(target, deps()), { result: 'skipped', reason: 'no_secret' });
assert.equal(calls.length, 0, 'no secret: nothing is sent');
assert.ok(logs.some((l) => l.includes('not set')));
assert.deepEqual(await sendInvitePush({ enabled: false }, deps({ secret: 'x' })), { result: 'skipped', reason: 'off' });
assert.deepEqual(await sendInvitePush({ ...target, tokens: [] }, deps({ secret: 'x' })), { result: 'skipped', reason: 'no_tokens' });
assert.deepEqual(await sendInvitePush(target, deps({ secret: 'not json' })), { result: 'skipped', reason: 'bad_secret' });

const secret = Buffer.from(JSON.stringify({ project_id: 'almafia-test', client_email: 'x@y', private_key: 'k' })).toString('base64');
const sent = await sendInvitePush(target, deps({
  secret,
  fetch: async (url, init) => {
    calls.push({ url, init });
    return JSON.parse(init.body).message.token.startsWith('w')
      ? new Response('{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}', { status: 404 })
      : new Response('{}', { status: 200 });
  },
}));
assert.deepEqual(sent, { result: 'sent', sent: 1, dead: 1, failed: 0 });
assert.deepEqual(dropped, ['w'.repeat(40)], 'the dead token is deleted');
assert.ok(calls.every((c) => c.url === 'https://fcm.googleapis.com/v1/projects/almafia-test/messages:send'));
assert.ok(calls.every((c) => c.init.headers.authorization === 'Bearer access'));
// Logs never carry a token, a name or a code.
assert.ok(logs.every((l) => !l.includes('a'.repeat(20)) && !l.includes('إياد') && !l.includes('K7M2QP')));
// A throwing transport never throws out.
assert.equal((await sendInvitePush(target, deps({ secret, fetch: async () => { throw new Error('net'); } }))).failed, 2);

// ── D: friend events on the quiet channel ──────────────────────────────────
const social = { enabled: true, kind: 'friend_request', fromName: 'إياد', tokens: [] };
const sa = messageFor(social, 't'.repeat(40), 'android').message;
assert.equal(sa.android.notification.channel_id, 'mafia_social');
assert.equal(sa.android.notification.default_sound, true);
assert.deepEqual(Object.keys(sa.data).sort(), ['fromName', 'kind']);
assert.equal(messageFor({ ...social, kind: 'friend_accepted' }, 't', 'web').message.data.kind, 'friend_accepted');
assert.equal(messageFor(target, 't', 'android').message.android.notification.channel_id, 'mafia_invites');

for (const kind of ['order_paid', 'order_rejected']) {
  const android = messageFor({ enabled: true, kind }, 't', 'android').message;
  const web = messageFor({ enabled: true, kind }, 't', 'web').message;
  assert.equal(android.data.kind, kind);
  assert.equal(android.android.notification.icon, 'ic_stat_mafia');
  assert.equal(web.webpush.notification.badge, '/icons/badge-72.png');
  assert.ok(web.webpush.notification.title.length > 0);
  assert.ok(!JSON.stringify(android).includes('balance'));
}

console.log('invites/push routing and FCM step: PASS');
