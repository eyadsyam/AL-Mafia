// node supabase/tests/story_v2_sessions.test.mjs
// «قصص» V2 story sessions: the economy edge contract. No network, keys or database.
import assert from 'node:assert/strict';
import { economyCall, refusalOf } from '../functions/_shared/economy_actions.ts';

const user = '00000000-0000-4000-8000-000000000001';
const session = '0F0E0D0C-0B0A-4908-8706-050403020100';

// storyStart: the story, the table size and the phone's recent culprits.
assert.deepEqual(
  economyCall({ action: 'storyStart', story: 'qahwet_el_moallem', players: 5, avoid: ['n03'] }, user),
  { rpc: 'start_story_session', args: {
    p_user: user, p_story: 'qahwet_el_moallem', p_players: 5, p_avoid: ['n03'] } },
);
assert.deepEqual(
  economyCall({ action: 'storyStart', story: 'qahwet_el_moallem', players: 1 }, user).args.p_avoid,
  [],
);
for (const bad of [
  { story: 'Qahwa!', players: 5 },
  { story: 'qahwet_el_moallem', players: 0 },
  { story: 'qahwet_el_moallem', players: 11 },
  { story: 'qahwet_el_moallem', players: 2.5 },
  { story: 'qahwet_el_moallem', players: '5' },
  { story: 'qahwet_el_moallem', players: 5, avoid: 'n03' },
  { story: 'qahwet_el_moallem', players: 5, avoid: ['n03', 'DROP TABLE'] },
  { story: 'qahwet_el_moallem', players: 5, avoid: Array.from({ length: 11 }, (_, i) => `n${i}0`) },
]) {
  assert.equal(economyCall({ action: 'storyStart', ...bad }, user), null, JSON.stringify(bad));
}

// storyClaim: groups send who only; solo adds why and how.
assert.deepEqual(
  economyCall({ action: 'storyClaim', sessionId: session, who: 'n02' }, user),
  { rpc: 'claim_story_session', args: {
    p_user: user, p_session: session.toLowerCase(), p_who: 'n02', p_why: null, p_how: null } },
);
assert.deepEqual(
  economyCall({ action: 'storyClaim', sessionId: session, who: 'n02',
    why: 'cafe_will', how: 'powder_under_tobacco' }, user).args,
  { p_user: user, p_session: session.toLowerCase(), p_who: 'n02',
    p_why: 'cafe_will', p_how: 'powder_under_tobacco' },
);
for (const bad of [
  { sessionId: 'not-a-uuid', who: 'n02' },
  { sessionId: session },
  { sessionId: session, who: 'N 02' },
  { sessionId: session, who: 'n02', why: 7 },
  { sessionId: session, who: 'n02', how: 'x' },
]) {
  assert.equal(economyCall({ action: 'storyClaim', ...bad }, user), null, JSON.stringify(bad));
}

// The hourly limit is a refusal the client can read (it deals offline then).
assert.equal(refusalOf('STORY_LIMIT'), 'STORY_LIMIT');
console.log('story_v2_sessions.test.mjs: all assertions passed');
