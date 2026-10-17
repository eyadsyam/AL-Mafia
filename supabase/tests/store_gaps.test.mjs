import test from 'node:test';
import assert from 'node:assert/strict';
import {
  appealCounts, appealUpheld, appealed, detectiveSees, graveVoters, halfDoorSeats, lastWordOf,
  lockedSeats, revoteRequested, toolVoteWeight, unsilenceable, whisperAnswer,
} from '../functions/_shared/tools.ts';
import { resolveNightCore } from '../functions/_shared/night_core.ts';
import { ballotVerdict } from '../functions/_shared/vote_rules.ts';
import { ROLE_UNLOCKS, ensureCosmeticAccess, ensureRoleAccess } from '../functions/_shared/purchase_access.ts';
import { COMMIT_RPC, routeReward } from '../functions/_shared/ad_rewards.ts';
import { ECONOMY_REFUSALS, refusalOf } from '../functions/_shared/economy_actions.ts';

// Pure-helper proofs for the GAP rows of docs/plans/audit/M4-store.md. Every
// helper here is the one the edge functions call, composed the way they compose
// it (`resolve_night`, `resolve_vote`, `submit_night_action`), so a change in
// either place breaks the row.

const use = (seat, tool_code, phase_number, extra = {}) => ({
  user_id: `u${seat}`, seat, tool_code, phase: 'discuss', phase_number,
  target_seats: [], note: null, ...extra,
});
const roster = [
  { user_id: 'm', seat: 0, role: 'mafia', alive: true },
  { user_id: 's', seat: 1, role: 'silencer', alive: true },
  { user_id: 'd', seat: 2, role: 'doctor', alive: true },
  { user_id: 'n', seat: 3, role: 'sniper', alive: true },
  { user_id: 'a', seat: 4, role: 'citizen', alive: true },
  { user_id: 'b', seat: 5, role: 'citizen', alive: true },
  { user_id: 'e', seat: 6, role: 'detective', alive: true },
];
const withDead = (...ids) => roster.map(p => ({ ...p, alive: !ids.includes(p.user_id) }));
const move = (actor_id, action, target_id, used_bullet = false) => ({ actor_id, action, target_id, used_bullet });
// The wiring of `resolve_night`: a lock is out of reach of everything; the silence
// is also stopped by a half door and by a vote shield.
const night = (uses, n, actions, people = roster, settings = {}) => resolveNightCore({
  roster: people, actions, matchSeed: 31415, night: n, settings,
  lockedSeatSet: lockedSeats(uses, n),
  noSilenceSeatSet: new Set([...halfDoorSeats(uses, n), ...unsilenceable(uses, n)]),
});

// ── M4-3 Silencer ──────────────────────────────────────────────────────────
test('M4-3: a silence lands on the chosen living seat; the kill is independent of it', () => {
  assert.equal(night([], 1, [move('s', 'silence', 'a')]).silencedId, 'a');
  const both = night([], 1, [move('m', 'kill', 'b'), move('s', 'silence', 'a')]);
  assert.deepEqual(both.deathIds, ['b']);
  assert.equal(both.silencedId, 'a');
  // The Doctor cannot undo a silence.
  assert.equal(night([], 1, [move('d', 'protect', 'a'), move('s', 'silence', 'a')]).silencedId, 'a');
  // A silencer may silence himself.
  assert.equal(night([], 1, [move('s', 'silence', 's')]).silencedId, 's');
});

test('M4-3: a seat that dies the same night is not announced as silenced', () => {
  const r = night([], 1, [move('m', 'kill', 'a'), move('s', 'silence', 'a')]);
  assert.deepEqual(r.deathIds, ['a']);
  assert.equal(r.silencedId, null, 'a false silence announcement');
  // The Sniper's shot is a death too.
  const shot = night([], 1, [move('n', 'suspect', 'a', true), move('s', 'silence', 'a')]);
  assert.equal(shot.silencedId, null);
});

test('M4-3: with no living Mafioso the Silencer\'s stored kill is the night\'s kill', () => {
  // `submit_night_action` stores a silencer move as `kill` when no living `mafia` remains.
  const people = withDead('m');
  const r = night([], 2, [move('s', 'kill', 'a')], people);
  assert.deepEqual(r.deathIds, ['a']);
  assert.equal(r.silencedId, null, 'no silence is cast once the kill is inherited');
  // The inherited kill never lands on the Mafia team.
  assert.deepEqual(night([], 2, [move('s', 'kill', 'm')], people).deathIds, []);
  assert.deepEqual(night([], 2, [move('s', 'kill', 's')], people).deathIds, []);
  // While a Mafioso lives the silencer's move stays a silence and kills nobody.
  assert.deepEqual(night([], 2, [move('s', 'silence', 'a')]).deathIds, []);
});

test('M4-3: a vote shield, a half door and a lock each stop the silence silently', () => {
  for (const tool of ['vote_shield', 'half_door', 'lock_door']) {
    const r = night([use(4, tool, 1)], 2, [move('s', 'silence', 'a')]);
    assert.equal(r.silencedId, null, tool);
    assert.deepEqual(r.deathIds, [], tool);
  }
  // Only on the night after the day it was bought.
  assert.equal(night([use(4, 'half_door', 1)], 3, [move('s', 'silence', 'a')]).silencedId, 'a');
});

// ── M4-8 and M4-9 Sniper ────────────────────────────────────────────────────
test('M4-8: a shot at a Mafia seat kills only that seat, and the Doctor cannot stop it', () => {
  const r = night([], 1, [move('n', 'suspect', 'm', true), move('d', 'protect', 'm')]);
  assert.deepEqual(r.deathIds, ['m']);
  const silencer = night([], 1, [move('n', 'suspect', 's', true)]);
  assert.deepEqual(silencer.deathIds, ['s'], 'the Silencer is on the Mafia team');
});

test('M4-8: a miss at a town seat kills the target and the Sniper', () => {
  const r = night([], 1, [move('n', 'suspect', 'a', true)]);
  assert.deepEqual(r.deathIds, ['n', 'a']);
  // A protected citizen is still shot: protection answers only the Mafia kill.
  assert.deepEqual(night([], 1, [move('n', 'suspect', 'a', true), move('d', 'protect', 'a')]).deathIds, ['n', 'a']);
});

test('M4-8 and M4-9: no bullet, no shot; a dead Sniper or dead target fires nothing; deaths are not doubled', () => {
  assert.deepEqual(night([], 1, [move('n', 'suspect', 'a', false)]).deathIds, [], 'a plain suspicion kills nobody');
  assert.deepEqual(night([], 1, [move('n', 'suspect', 'a', true)], withDead('n')).deathIds, []);
  assert.deepEqual(night([], 1, [move('n', 'suspect', 'a', true)], withDead('a')).deathIds, []);
  // A shot and a Mafia kill on the same seat is one death.
  assert.deepEqual(night([], 1, [move('m', 'kill', 'a'), move('n', 'suspect', 'a', true)]).deathIds, ['n', 'a']);
  // Only a Sniper shoots: the same move from another role is nothing.
  assert.deepEqual(night([], 1, [move('d', 'suspect', 'a', true)]).deathIds, []);
});

// ── M4-25 half door and M4-33 lock door ────────────────────────────────────
test('M4-25: a half door stops the silence and the investigation, never the kill', () => {
  const uses = [use(4, 'half_door', 1)];
  const r = night(uses, 2, [move('m', 'kill', 'a'), move('s', 'silence', 'a')]);
  assert.deepEqual(r.deathIds, ['a'], 'the kill reaches a half door');
  assert.equal(r.silencedId, null);
  assert.equal(detectiveSees(uses, 2, 4, 'citizen'), 'unreachable');
  assert.equal(detectiveSees(uses, 2, 5, 'citizen'), 'citizen', 'only the owner\'s seat is behind the door');
  // The Sniper's shot also reaches a half door.
  assert.deepEqual(night(uses, 2, [move('n', 'suspect', 'a', true)]).deathIds, ['n', 'a']);
});

test('M4-25 and M4-33: a lock beats a half door on the same seat; both cover one night only', () => {
  const both = [use(4, 'half_door', 1), use(4, 'lock_door', 1)];
  const r = night(both, 2, [move('m', 'kill', 'a'), move('s', 'silence', 'a')]);
  assert.deepEqual(r.deathIds, [], 'the lock cancels the kill');
  assert.equal(r.victimId, null);
  assert.equal(r.silencedId, null);
  assert.equal(detectiveSees(both, 2, 4, 'citizen'), 'unreachable');
  for (const uncovered of [1, 3]) {
    const back = night(both, uncovered, [move('m', 'kill', 'a')]);
    assert.deepEqual(back.deathIds, ['a'], `a lock bought in day 1 covers night 2 only, not night ${uncovered}`);
  }
  assert.equal(lockedSeats(both, 2).has(4), true);
  assert.equal(halfDoorSeats(both, 2).has(4), true, 'a lock includes the half door');
  assert.equal(lockedSeats([use(4, 'half_door', 1)], 2).size, 0, 'a half door is not a lock');
});

test('M4-33: a lock cancels the kill, the shot with its recoil, the silence and the investigation', () => {
  const uses = [use(4, 'lock_door', 1)];
  const killed = night(uses, 2, [move('m', 'kill', 'a')]);
  assert.deepEqual(killed.deathIds, []);
  const shot = night(uses, 2, [move('n', 'suspect', 'a', true)]);
  assert.deepEqual(shot.deathIds, [], 'neither the target nor the Sniper dies');
  assert.equal(night(uses, 2, [move('s', 'silence', 'a')]).silencedId, null);
  assert.equal(detectiveSees(uses, 2, 4, 'citizen'), 'unreachable');
  // Its neighbour on the same night is not protected.
  assert.deepEqual(night(uses, 2, [move('m', 'kill', 'b')]).deathIds, ['b']);
  // A lock does not move a narrator answer.
  const roleOf = seat => roster.find(p => p.seat === seat)?.role ?? null;
  assert.equal(whisperAnswer(use(2, 'narrator_whisper', 2, { target_seats: [0, 4] }), roleOf), true);
});

test('M4-33: what a lock covers is a function of the stored rows only, so a reconnect reads the same', () => {
  const uses = [use(4, 'lock_door', 1)];
  const first = [...lockedSeats(uses, 2)], again = [...lockedSeats(uses.map(u => ({ ...u })), 2)];
  assert.deepEqual(first, again);
  assert.deepEqual([...lockedSeats(uses, 3)], [], 'nothing left to replay on the night after');
  // A tool bought during a night itself belongs to no later night.
  assert.equal(lockedSeats([use(4, 'lock_door', 1, { phase: 'night' })], 2).size, 0);
});

// ── M4-26 double vote, M4-29 grave vote ────────────────────────────────────
test('M4-26: the doubled ballot belongs to its seat and its day only', () => {
  const uses = [use(4, 'double_vote', 3)];
  assert.equal(toolVoteWeight(uses, 3, 4), 2);
  assert.equal(toolVoteWeight(uses, 3, 5), 1);
  assert.equal(toolVoteWeight(uses, 4, 4), 1);
  assert.equal(toolVoteWeight([], 3, 4), 1);
});

test('M4-29: a grave vote is for the day it was bought, once, and for that seat only', () => {
  const uses = [use(2, 'grave_vote', 3)];
  assert.deepEqual([...graveVoters(uses, 3)], [2]);
  assert.deepEqual([...graveVoters(uses, 4)], [], 'it does not carry to the next ballot');
  assert.deepEqual([...graveVoters(uses, 2)], []);
  assert.deepEqual([...graveVoters([], 3)], []);
});

// ── M4-27 camouflage and M4-31 impersonate ────────────────────────────────
test('M4-27: camouflage makes the next investigation unclear; impersonate and doors outrank it', () => {
  const camo = [use(1, 'camouflage', 1)];
  assert.equal(detectiveSees(camo, 2, 1, 'mafia'), 'unclear');
  assert.equal(detectiveSees(camo, 2, 2, 'mafia'), 'mafia', 'another seat is read as it is');
  assert.equal(detectiveSees(camo, 3, 1, 'mafia'), 'mafia', 'one night only');
  assert.equal(detectiveSees(camo, 1, 1, 'mafia'), 'mafia', 'not the night it was bought in');
  assert.equal(detectiveSees([...camo, use(1, 'impersonate', 1, { note: 'citizen' })], 2, 1, 'mafia'), 'citizen');
  assert.equal(detectiveSees([...camo, use(1, 'half_door', 1)], 2, 1, 'mafia'), 'unreachable');
  assert.equal(detectiveSees([...camo, use(1, 'lock_door', 1)], 2, 1, 'mafia'), 'unreachable');
});

test('M4-31: impersonate shows exactly the chosen face of the two; any other face is ignored', () => {
  assert.equal(detectiveSees([use(1, 'impersonate', 1, { note: 'citizen' })], 2, 1, 'mafia'), 'citizen');
  assert.equal(detectiveSees([use(1, 'impersonate', 1, { note: 'mafia' })], 2, 1, 'citizen'), 'mafia');
  assert.equal(detectiveSees([use(1, 'impersonate', 1, { note: 'doctor' })], 2, 1, 'mafia'), 'mafia');
  assert.equal(detectiveSees([use(1, 'impersonate', 1, { note: null })], 2, 1, 'citizen'), 'citizen');
  assert.equal(detectiveSees([use(1, 'impersonate', 1, { note: 'citizen' })], 3, 1, 'mafia'), 'mafia');
});

// ── M4-28 revote, M4-34 appeal, M4-23 last word ────────────────────────────
test('M4-28: a ballot goes to a second round at most; a third is never opened', () => {
  for (const topSeats of [1, 2, 3]) {
    for (const dayTieRule of ['revote', 'noElimination', undefined]) {
      for (const revoteBought of [true, false]) {
        const v = ballotVerdict({ round: 2, topSeats, dayTieRule, revoteBought });
        assert.notEqual(v, 'revote', `round 2, ${topSeats} top seats, ${dayTieRule}, bought ${revoteBought}`);
        assert.equal(v, topSeats === 1 ? 'eliminate' : 'stand');
      }
    }
  }
  assert.equal(ballotVerdict({ round: 1, topSeats: 1, dayTieRule: 'noElimination', revoteBought: true }), 'revote');
  assert.equal(ballotVerdict({ round: 1, topSeats: 2, dayTieRule: 'noElimination', revoteBought: true }), 'revote');
  assert.equal(ballotVerdict({ round: 1, topSeats: 2, dayTieRule: 'noElimination', revoteBought: false }), 'stand');
  assert.equal(ballotVerdict({ round: 1, topSeats: 1, dayTieRule: 'revote', revoteBought: false }), 'eliminate');
  assert.equal(revoteRequested([use(1, 'revote', 3)], 3), true);
  assert.equal(revoteRequested([use(1, 'revote', 3)], 4), false, 'bought for another day');
});

test('M4-34: an appeal stands only above two thirds of the weighted counted ballots, the appellant excluded', () => {
  const ballot = (voter, target, weight = 1) => ({ voter, target, weight });
  // 4 of 6 is exactly two thirds: not enough. 5 of 6 is enough.
  const four = [ballot('v1', 'x'), ballot('v2', 'x'), ballot('v3', 'x'), ballot('v4', 'x'), ballot('v5', 'y'), ballot('v6', null)];
  assert.deepEqual(appealCounts(four, 'x'), { confirm: 4, voters: 6 });
  assert.equal(appealUpheld(4, 6), false);
  const five = [...four.slice(0, 4), ballot('v5', 'x'), ballot('v6', null)];
  assert.deepEqual(appealCounts(five, 'x'), { confirm: 5, voters: 6 });
  assert.equal(appealUpheld(5, 6), true);
  // The appellant's own ballot is on neither side.
  const own = [...five, ballot('x', 'v1', 3)];
  assert.deepEqual(appealCounts(own, 'x'), { confirm: 5, voters: 6 });
  // A doubled ballot weighs two on both sides: 4 confirmations + a doubled dissent is 4 of 6.
  const doubled = [ballot('v1', 'x'), ballot('v2', 'x'), ballot('v3', 'x'), ballot('v4', 'x'), ballot('v5', 'y', 2)];
  assert.deepEqual(appealCounts(doubled, 'x'), { confirm: 4, voters: 6 });
  assert.equal(appealUpheld(4, 6), false);
  // A tripled Elder among the confirmers carries the appeal alone: 3 of 4.
  const elder = [ballot('e', 'x', 3), ballot('v1', 'y')];
  const elderSides = appealCounts(elder, 'x');
  assert.deepEqual(elderSides, { confirm: 3, voters: 4 });
  assert.equal(appealUpheld(elderSides.confirm, elderSides.voters), true);
  // No other ballot, nothing stands.
  assert.equal(appealUpheld(0, 0), false);
  assert.deepEqual([...appealed([use(2, 'appeal', 3)], 3)], [2]);
  assert.deepEqual([...appealed([use(2, 'appeal', 3)], 4)], []);
});

test('M4-23: a last word is announced only for the seat voted out on that day, and names its choice', () => {
  const uses = [use(2, 'last_word', 3, { phase: 'vote', target_seats: [5] })];
  assert.deepEqual(lastWordOf(uses, 3, 2), { seat: 2, target: 5 });
  assert.equal(lastWordOf(uses, 3, 4), null, 'a different seat went out');
  assert.equal(lastWordOf(uses, 3, null), null, 'nobody went out');
  assert.equal(lastWordOf(uses, 4, 2), null, 'bought on another day');
  assert.equal(lastWordOf([use(2, 'last_word', 3, { target_seats: [] })], 3, 2), null, 'no chosen player, nothing invented');
  assert.deepEqual(lastWordOf([use(2, 'last_word', 3, { target_seats: [0] })], 3, 2), { seat: 2, target: 0 }, 'seat zero is a seat');
});

// ── M4-2 who may switch a sold role on ─────────────────────────────────────
const dbOwning = owned => ({
  rpc: async (name, args) => {
    assert.equal(name, 'user_owns_item');
    return { data: owned.has(args.p_item), error: null };
  },
});

test('M4-2: the host flag of a sold role is refused unless the host owns that role', async () => {
  assert.deepEqual(ROLE_UNLOCKS, { silencerEnabled: 'role_silencer', elderEnabled: 'role_elder', sniperEnabled: 'role_sniper' });
  for (const [flag, item] of Object.entries(ROLE_UNLOCKS)) {
    assert.equal(await ensureRoleAccess(dbOwning(new Set()), 'u', { [flag]: true }), false, `${flag} unowned`);
    assert.equal(await ensureRoleAccess(dbOwning(new Set([item])), 'u', { [flag]: true }), true, `${flag} owned`);
    assert.equal(await ensureRoleAccess(dbOwning(new Set([item])), 'u', { [flag]: false }), true, `${flag} off needs nothing`);
    // Refunded: the item is gone from the inventory, the flag is refused again.
    const owned = new Set([item]);
    assert.equal(await ensureRoleAccess(dbOwning(owned), 'u', { [flag]: true }), true);
    owned.delete(item);
    assert.equal(await ensureRoleAccess(dbOwning(owned), 'u', { [flag]: true }), false, `${flag} after refund`);
  }
  // Each role needs its own purchase: owning one does not unlock another.
  assert.equal(await ensureRoleAccess(dbOwning(new Set(['role_elder'])), 'u', { sniperEnabled: true }), false);
  assert.equal(await ensureRoleAccess(dbOwning(new Set(['role_elder'])), 'u', { elderEnabled: true, sniperEnabled: true }), false);
  assert.equal(await ensureRoleAccess(dbOwning(new Set(['role_elder', 'role_sniper'])), 'u', { elderEnabled: true, sniperEnabled: true }), true);
  assert.equal(await ensureRoleAccess(dbOwning(new Set()), 'u', undefined), true);
  assert.equal(await ensureRoleAccess(dbOwning(new Set()), 'u', { silencerEnabled: 'true' }), true, 'only a real true is a switch');
  await assert.rejects(ensureRoleAccess({ rpc: async () => ({ data: null, error: new Error('db') }) }, 'u', { elderEnabled: true }));
});

test('M4-2: a presentation or narrator pack on the room needs ownership; the classic one needs none', async () => {
  assert.equal(await ensureCosmeticAccess(dbOwning(new Set()), 'u', {}), true);
  assert.equal(await ensureCosmeticAccess(dbOwning(new Set()), 'u', { presentationPack: 'classic', narratorPack: 'classic' }), true);
  assert.equal(await ensureCosmeticAccess(dbOwning(new Set()), 'u', { narratorPack: 'narrator_noir' }), false);
  assert.equal(await ensureCosmeticAccess(dbOwning(new Set(['narrator_noir'])), 'u', { narratorPack: 'narrator_noir' }), true);
  assert.equal(await ensureCosmeticAccess(dbOwning(new Set(['narrator_noir'])), 'u', { narratorPack: 'narrator_noir', presentationPack: 'pack_old_town' }), false);
});

// ── M4-44 and M4-45 where a rewarded-ad callback can land ──────────────────
const env = values => name => values[name];
const claim = '4b0c1e5a-1111-4222-8333-444455556666';

test('M4-45: a callback pays only through a claim it names, on an accepted unit, in a configured deployment', () => {
  const live = env({ ADMOB_REWARDED_ANDROID_ID: 'ca-app-pub-0000000000000000/1234567890' });
  assert.deepEqual(routeReward(`d1:${claim}`, '1234567890', live), { ok: true, scheme: 'daily', claimId: claim });
  assert.equal(COMMIT_RPC.daily, 'commit_daily_ad');
  assert.deepEqual(routeReward(claim, '1234567890', live), { ok: true, scheme: 'v1', claimId: claim });
  assert.deepEqual(routeReward(`d1:${claim}`, '9999999999', live), { ok: false, reason: 'unit_not_accepted' });
  assert.deepEqual(routeReward(`d1:${claim}`, null, live), { ok: false, reason: 'unit_not_accepted' });
  assert.deepEqual(routeReward('d1:not-a-claim', '1234567890', live), { ok: false, reason: 'bad_claim' });
  assert.deepEqual(routeReward(null, '1234567890', live), { ok: false, reason: 'bad_claim' });
  assert.deepEqual(routeReward('', '1234567890', live), { ok: false, reason: 'bad_claim' });
  assert.deepEqual(routeReward(`d1:${claim}`, '1234567890', env({})), { ok: false, reason: 'not_configured' });
  // The claim is the lower-cased id, so a shouted callback cannot name a second claim.
  assert.equal(routeReward(`d1:${claim.toUpperCase()}`, '1234567890', live).claimId, claim);
});

// ── M4-39 the client can act on every refusal code the tool function raises ──
test('M4-39: every refusal use_table_tool and buy_table_tool raise is a code the economy function reports', () => {
  const codes = [
    'ITEM_NOT_FOUND', 'NOT_PLAYING', 'NOT_A_MEMBER', 'NOT_ALIVE', 'ALIVE', 'WRONG_PHASE', 'SILENCED',
    'BAD_TARGETS', 'BAD_NOTE', 'LIMIT_MATCH', 'LIMIT_HEAVY', 'LIMIT_TOOL', 'LIMIT_PHASE', 'NO_CHARGES',
    'NOT_THIS_ROOM', 'BAD_PACK', 'INSUFFICIENT_COINS',
  ];
  for (const code of codes) {
    assert.ok(ECONOMY_REFUSALS.includes(code), `${code} is not a reported refusal`);
    assert.equal(refusalOf(`ERROR: ${code}`), code);
  }
  assert.equal(refusalOf('something unexpected'), null);
  assert.equal(refusalOf(undefined), null);
});
