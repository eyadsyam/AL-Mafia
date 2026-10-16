import test from 'node:test';
import assert from 'node:assert/strict';
import {
  investigationVerdict,
  previousProtectTarget,
  protectsSameTwice,
  defaultProtectTargets,
} from '../functions/_shared/night_rules.ts';
import {
  bulletEnabled,
  bulletFor,
  loadTeamBulletSpent,
  mafiaWentQuiet,
  quietNightAvailable,
  saveIsTold,
  survivingSave,
  teamBulletSpent,
} from '../functions/_shared/bullets.ts';

// ── RL5: one investigation a night ─────────────────────────────────────────
test('investigation: the first question is open', () => {
  assert.equal(investigationVerdict(null, { action: 'investigate', targetId: 'm' }), 'open');
  assert.equal(investigationVerdict(undefined, { action: 'investigate', targetId: 'm' }), 'open');
});

test('investigation: a skipped night may still be used to look', () => {
  const skipped = { action: 'skip', target_id: null };
  assert.equal(investigationVerdict(skipped, { action: 'investigate', targetId: 'm' }), 'open');
});

test('investigation: the same target again is the same request, a different one is refused', () => {
  const looked = { action: 'investigate', target_id: 'm' };
  assert.equal(investigationVerdict(looked, { action: 'investigate', targetId: 'm' }), 'same');
  assert.equal(investigationVerdict(looked, { action: 'investigate', targetId: 'c' }), 'refused');
});

test('investigation: giving the night up after looking is refused', () => {
  const looked = { action: 'investigate', target_id: 'm' };
  assert.equal(investigationVerdict(looked, { action: 'skip', targetId: null }), 'refused');
});

// ── RL3: the Doctor may not repeat last night's target ────────────────────
const rows = [
  { night: 1, actor_id: 'doc', action: 'protect', target_id: 'a' },
  { night: 1, actor_id: 'mafia', action: 'kill', target_id: 'a' },
  { night: 2, actor_id: 'doc', action: 'protect', target_id: 'b' },
  { night: 2, actor_id: 'doc2', action: 'protect', target_id: 'c' },
];

test('protect no-repeat: last night\'s target is the previous night\'s protect row of this actor', () => {
  assert.equal(previousProtectTarget(rows, 'doc', 2), 'a');
  assert.equal(previousProtectTarget(rows, 'doc', 3), 'b');
  assert.equal(previousProtectTarget(rows, 'doc2', 3), 'c');
});

test('protect no-repeat: nothing before the first night, another actor\'s rows or other actions', () => {
  assert.equal(previousProtectTarget(rows, 'doc', 1), null);
  assert.equal(previousProtectTarget(rows, 'mafia', 2), null);
  assert.equal(previousProtectTarget(rows, 'doc', 5), null);
  assert.equal(previousProtectTarget([], 'doc', 2), null);
});

test('protect no-repeat: the same player twice is refused, self-protection is exempt', () => {
  assert.equal(protectsSameTwice('a', 'a', false), true);
  assert.equal(protectsSameTwice('a', 'b', false), false);
  assert.equal(protectsSameTwice(null, 'a', false), false);
  assert.equal(protectsSameTwice('a', 'a', true), false);
});

test('protect default: skips himself and last night\'s target, ordered by seat', () => {
  const living = [
    { user_id: 'c', seat: 3 },
    { user_id: 'doc', seat: 0 },
    { user_id: 'a', seat: 1 },
    { user_id: 'b', seat: 2 },
  ];
  assert.deepEqual(defaultProtectTargets(living, 'doc', 'b').map(p => p.user_id), ['a', 'c']);
  assert.deepEqual(defaultProtectTargets(living, 'doc', null).map(p => p.user_id), ['a', 'b', 'c']);
  // a stale id (the target is dead) filters nothing else out
  assert.deepEqual(defaultProtectTargets(living, 'doc', 'gone').map(p => p.user_id), ['a', 'b', 'c']);
});

test('protect default: nothing legal left is an empty list, not last night\'s target', () => {
  const living = [{ user_id: 'doc', seat: 0 }, { user_id: 'a', seat: 1 }];
  assert.deepEqual(defaultProtectTargets(living, 'doc', 'a'), []);
});

// ── RL1: the quiet night is the team's one bullet ─────────────────────────
const mafiosi = new Set(['m1', 'm2']);

test('team bullet: spent once any Mafioso other than the asker has spent it', () => {
  const spent = [{ actor_id: 'm1', used_bullet: true }];
  assert.equal(teamBulletSpent(spent, mafiosi, 'm2'), true);
  assert.equal(teamBulletSpent(spent, mafiosi, 'm1'), false, 'his own bullet is the per-player rule');
  assert.equal(teamBulletSpent(spent, mafiosi), true);
});

test('team bullet: only role mafia holds it; nothing spent means nothing gone', () => {
  assert.equal(teamBulletSpent([{ actor_id: 'doc', used_bullet: true }], mafiosi, 'm2'), false);
  assert.equal(teamBulletSpent([{ actor_id: 'm1', used_bullet: false }], mafiosi, 'm2'), false);
  assert.equal(teamBulletSpent([{ actor_id: 'm1' }], ['m1'], 'm2'), false);
  assert.equal(teamBulletSpent([], mafiosi, 'm2'), false);
  assert.equal(teamBulletSpent([{ actor_id: 'm1', used_bullet: true }], ['m1', 'm2'], 'm2'), true, 'arrays work too');
});

test('quiet night: a living Mafioso\'s spent bullet tonight silences the kill', () => {
  const alive = new Set(['m1', 'm2', 'c']);
  assert.equal(mafiaWentQuiet([{ actor_id: 'm1', used_bullet: true }], mafiosi, alive), true);
  assert.equal(mafiaWentQuiet([{ actor_id: 'm1', used_bullet: false }], mafiosi, alive), false);
  assert.equal(mafiaWentQuiet([], mafiosi, alive), false);
});

test('quiet night: a removed Mafioso, a Doctor\'s or a Silencer\'s bullet is not the quiet night', () => {
  assert.equal(mafiaWentQuiet([{ actor_id: 'm1', used_bullet: true }], mafiosi, new Set(['m2'])), false);
  assert.equal(mafiaWentQuiet([{ actor_id: 'doc', used_bullet: true }], mafiosi, new Set(['doc'])), false);
  assert.equal(mafiaWentQuiet([{ actor_id: 'sil', used_bullet: true }], mafiosi, new Set(['sil'])), false);
});

test('bullets: only a Mafioso holds the quiet night; the settings read as MatchSettings does', () => {
  assert.equal(bulletFor('mafia'), 'quietNight');
  assert.equal(bulletFor('silencer'), null);
  assert.equal(bulletFor('doctor'), 'selfProtect');
  assert.equal(bulletFor('sniper'), 'sniperShot');
  assert.equal(bulletEnabled({}, 'quietNight'), true, 'absent means on');
  assert.equal(bulletEnabled({ bulletsEnabled: false }, 'quietNight'), false);
  assert.equal(bulletEnabled({ quietNightEnabled: false }, 'quietNight'), false);
  assert.equal(bulletEnabled({ bulletsEnabled: false }, 'selfProtect'), true, 'selfProtect is always on');
  assert.equal(bulletEnabled({}, 'sniperShot'), false);
  assert.equal(bulletEnabled({ sniperEnabled: true }, 'sniperShot'), true);
});

test('team bullet loader: two reads, the same answer as the pure rule', async () => {
  const tables = {
    room_players: { data: [{ user_id: 'm1' }, { user_id: 'm2' }], error: null },
    night_actions: { data: [{ actor_id: 'm1', used_bullet: true }], error: null },
  };
  const db = {
    from(table) {
      const q = {
        select: () => q, eq: () => q,
        then: (resolve) => resolve(tables[table]),
      };
      return q;
    },
  };
  assert.equal(await loadTeamBulletSpent(db, 'room', 'm2'), true);
  assert.equal(await loadTeamBulletSpent(db, 'room', 'm1'), false);
  assert.equal(await loadTeamBulletSpent(db, 'room'), true);
  tables.night_actions = { data: [], error: null };
  assert.equal(await loadTeamBulletSpent(db, 'room', 'm2'), false);
  tables.night_actions = { data: null, error: new Error('boom') };
  await assert.rejects(() => loadTeamBulletSpent(db, 'room', 'm2'), /boom/);
});

// ── RL2 and RL17: when a save is told ─────────────────────────────────────
const bulletsOn = {};
const noBullets = { bulletsEnabled: false };
const noQuietNight = { quietNightEnabled: false };

test('quiet night available: bullets and the quiet night both on (absent = on)', () => {
  assert.equal(quietNightAvailable({}), true);
  assert.equal(quietNightAvailable(noBullets), false);
  assert.equal(quietNightAvailable(noQuietNight), false);
  assert.equal(quietNightAvailable({ bulletsEnabled: true, quietNightEnabled: true }), true);
});

test('save told: never behind a quiet night', () => {
  assert.equal(saveIsTold({ savedSeat: 2, deaths: [], settings: bulletsOn }), false);
});

test('save told: told when the room has no quiet night (fast preset, or the quiet night off)', () => {
  assert.equal(saveIsTold({ savedSeat: 2, deaths: [], settings: noBullets }), true);
  assert.equal(saveIsTold({ savedSeat: 2, deaths: [], settings: noQuietNight }), true);
  assert.equal(saveIsTold({ savedSeat: 0, deaths: [], settings: noBullets }), true, 'seat 0 is a seat');
});

test('save told: nothing to tell without a save', () => {
  assert.equal(saveIsTold({ savedSeat: null, deaths: [], settings: noBullets }), false);
  assert.equal(saveIsTold({ savedSeat: undefined, deaths: [], settings: noBullets }), false);
});

test('save told: a covered seat the Sniper took is no save (sets, arrays and ids)', () => {
  assert.equal(saveIsTold({ savedSeat: 2, deaths: [2, 4], settings: noBullets }), false);
  assert.equal(saveIsTold({ savedSeat: 2, deaths: new Set([2]), settings: noBullets }), false);
  assert.equal(saveIsTold({ savedSeat: 2, deaths: [4], settings: noBullets }), true);
  assert.equal(saveIsTold({ savedSeat: 'u2', deaths: new Set(['u2']), settings: noBullets }), false);
  assert.equal(saveIsTold({ savedSeat: 'u2', deaths: new Set(['u3']), settings: noBullets }), true);
  assert.equal(saveIsTold({ savedSeat: 0, deaths: [0], settings: noBullets }), false);
});

test('surviving save: the record keeps the save unless the covered seat dies', () => {
  assert.equal(survivingSave('u2', new Set(['u3'])), 'u2');
  assert.equal(survivingSave('u2', new Set(['u2'])), null);
  assert.equal(survivingSave(0, [1]), 0);
  assert.equal(survivingSave(0, [0]), null);
  assert.equal(survivingSave(null, [1]), null);
  assert.equal(survivingSave(undefined, []), null);
});
