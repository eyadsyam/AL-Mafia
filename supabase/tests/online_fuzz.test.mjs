// node --test supabase/tests/online_fuzz.test.mjs        (FUZZ_MATCHES=200 for a longer run)
//
// The online twin of test/engine/fuzz_harness_test.dart (doc 11 §9): whole random
// matches played through the real edge functions on the local harness (PGlite,
// every migration). Each step is a random member doing a random thing — legal or
// not — and after every step:
//   * no call answers 5xx (a refusal is a 4xx with a code, never a crash),
//   * the phase is a known one and its number never goes back,
//   * a living seat's role is never in the public state (doc 05; a revealed
//     Elder is public by rule),
//   * a dead or struck seat's vote or night move is refused,
//   * the match ends: «result» with an outcome inside the step guard,
//   * the outcome agrees with who is alive.
// Rooms are fresh per match on one database, so a run boots the migrations once.
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from '../../tool/edge_harness/index.mjs';

const MATCHES = Number(process.env.FUZZ_MATCHES ?? 40);
const STEP_GUARD = 400;
const PHASES = new Set(['reveal', 'night', 'morning', 'opening', 'discuss', 'confront', 'vote', 'verdict', 'result']);
const MAFIA_TEAM = new Set(['mafia', 'silencer']);
// What the run reached, so a quiet pass cannot hide a branch it never took.
const seen = new Map();
const saw = (k) => seen.set(k, (seen.get(k) ?? 0) + 1);

// Small, seeded, so a failing match replays from its number.
function rng(seed) {
  let s = (seed * 2654435761) >>> 0 || 1;
  const next = () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
  return { next, int: (n) => Math.floor(next() * n), pick: (xs) => xs[Math.floor(next() * xs.length)], chance: (p) => next() < p };
}

function deal(r, n) {
  const mafiaTotal = n >= 9 ? 3 : n >= 7 ? 2 : 1;
  const roles = { doctor: 1, detective: 1 };
  const settings = { openingRoundEnabled: r.chance(0.5), dayTieRule: r.pick(['revote', 'noElimination']),
    abstainAllowed: r.chance(0.3), confrontationEnabled: r.chance(0.5), whisperEnabled: r.chance(0.5),
    traceEnabled: r.chance(0.7), bulletsEnabled: r.chance(0.8), discussionMode: r.pick(['free', 'structured']),
    openVoting: r.chance(0.3) };
  let mafia = mafiaTotal;
  if (mafiaTotal >= 2 && r.chance(0.5)) { roles.silencer = 1; mafia--; settings.silencerEnabled = true; }
  roles.mafia = mafia;
  if (n >= 6 && r.chance(0.5)) { roles.elder = 1; settings.elderEnabled = true; }
  if (n >= 7 && r.chance(0.5)) { roles.sniper = 1; settings.sniperEnabled = true; }
  const used = Object.values(roles).reduce((a, b) => a + b, 0);
  roles.citizen = n - used;
  return { roles, settings };
}

// Every object in the public state that names a seat and a role.
function leaks(publicData, roster, revealedElders) {
  const alive = new Map(roster.filter((p) => p.alive).map((p) => [p.seat, p.role]));
  const found = [];
  const walk = (v, path) => {
    if (Array.isArray(v)) return v.forEach((x, i) => walk(x, `${path}[${i}]`));
    if (!v || typeof v !== 'object') return;
    const seat = typeof v.seat === 'number' ? v.seat : null;
    if (seat !== null && alive.has(seat)) {
      for (const [k, x] of Object.entries(v)) {
        if (!/role/i.test(k) || typeof x !== 'string') continue;
        if (x === 'elder' && revealedElders.has(seat)) continue;
        found.push(`${path}.${k}=${x} for living seat ${seat}`);
      }
    }
    for (const [k, x] of Object.entries(v)) walk(x, `${path}.${k}`);
  };
  walk(publicData, 'public_data');
  return found;
}

async function playOne(h, seed) {
  const r = rng(seed);
  const n = 5 + r.int(8);                         // 5..12 seats
  const { roles, settings } = deal(r, n);
  const tag = `m${seed}_`;
  const ids = [];
  for (let i = 0; i < n; i++) ids.push(await h.user(`${tag}${i}`));
  const who = (seat) => `${tag}${seat}`;
  const trail = [];
  const calls = [];
  const call = async (name, seat, body) => {
    const res = await h.call(name, who(seat), body);
    calls.push(`${name} by ${seat} ${JSON.stringify(body)} -> ${res.status} ${JSON.stringify(res.json).slice(0, 160)}`);
    if (res.status >= 500) throw new Error(`5xx from ${name}: ${JSON.stringify(res.json)}`);
    return res;
  };
  const fail = (msg) => { throw new Error(`match ${seed} (${n} seats, ${JSON.stringify(roles)}): ${msg}\n  last calls:\n    ${calls.slice(-12).join('\n    ')}`); };

  await h.sql("insert into all_access_grants(user_id,reason,granted_by) values($1,'fuzz','service_role') on conflict do nothing", [ids[0]]);
  const created = await call('create_room', 0, { name: 'Host', settings: { maxPlayers: 15, ...settings } });
  if (created.status !== 200) fail(`create_room ${JSON.stringify(created.json)}`);
  const { roomId, code } = created.json;
  for (let i = 1; i < n; i++) {
    const j = await call('join_room', i, { code, name: `P${i}` });
    if (j.status !== 200) fail(`join_room ${JSON.stringify(j.json)}`);
  }
  const started = await call('start_match', 0, { roomId, roles });
  if (started.status !== 200) fail(`start_match ${JSON.stringify(started.json)}`);

  const roster = async () => (await h.sql('select seat,role,alive,user_id from room_players where room_id=$1 order by seat', [roomId])).rows;
  const state = async () => (await h.sql('select phase,phase_number,public_data from room_state where room_id=$1', [roomId])).rows[0];
  const expire = () => h.sql("update room_state set phase_ends_at=now()-interval '1 second' where room_id=$1", [roomId]);
  const fresh = () => h.sql("update room_players set last_seen=now(),connected=true,status='connected' where room_id=$1 and status<>'left'", [roomId]);

  let lastNumber = 0; let lastPhase = null;
  // Chaos, chosen per match so matches differ in what goes wrong, not only in who is dealt what:
  //   a guest whose phone dies (struck by age_presence past 90 s), the host
  //   leaving for good (the room closes for everybody, owner 2026-10-30), and
  //   two members asking the same phase to end at the same moment.
  const strikeAt = r.chance(0.35) ? 2 + r.int(12) : -1;
  const hostLeavesAt = r.chance(0.06) ? 3 + r.int(15) : -1;
  const doubleTap = r.chance(0.5);
  for (let step = 0; step < STEP_GUARD; step++) {
    await fresh();
    const s = await state();
    const players = await roster();
    const living = players.filter((p) => p.alive);
    const dead = players.filter((p) => !p.alive);
    const revealed = new Set((s.public_data?.elderRevealedSeats ?? []).map(Number));

    // Invariants after every step.
    if (!PHASES.has(s.phase)) fail(`unknown phase ${s.phase}`);
    if (s.phase === lastPhase && s.phase_number < lastNumber) fail(`phase number went back ${lastNumber} -> ${s.phase_number}`);
    lastNumber = Math.max(lastNumber, s.phase_number ?? 0); lastPhase = s.phase;
    // At «result» every role is told (the match is over); never before.
    const leaked = s.phase === 'result' ? [] : leaks(s.public_data ?? {}, players, revealed);
    if (leaked.length) fail(`role in public state: ${leaked.join('; ')}`);
    const outcome = s.public_data?.outcome ?? null;
    if (outcome) {
      const mafiaAlive = living.filter((p) => MAFIA_TEAM.has(p.role)).length;
      const townAlive = living.length - mafiaAlive;
      if (outcome === 'town' && mafiaAlive > 0) fail(`town won with ${mafiaAlive} Mafia alive`);
      if (outcome === 'mafia' && mafiaAlive < townAlive) fail(`Mafia won outnumbered ${mafiaAlive} vs ${townAlive}`);
    }
    if (s.phase === 'result') {
      if (!outcome) fail('result with no outcome');
      for (const k of Object.keys(roles)) saw(`role:${k}`);
      return { seed, n, steps: step, outcome, trail };
    }
    trail.push(`${s.phase}#${s.phase_number}`);
    saw(`phase:${s.phase}`);
    if (revealed.size) saw('elder revealed');
    if (s.public_data?.revote) saw('revote');
    if (s.public_data?.silencedSeat != null || s.public_data?.morning?.silencedSeat != null) saw('silenced');

    if (step === hostLeavesAt && s.phase !== 'result') {
      const left = await call('leave_room', 0, { roomId });
      if (left.status !== 200) fail(`host could not leave: ${JSON.stringify(left.json)}`);
      const room = (await h.sql('select status from rooms where id=$1', [roomId])).rows[0];
      if (room.status !== 'finished') fail(`host left, room still ${room.status}`);
      const after = await call('submit_vote', r.pick(living.filter((p) => p.seat !== 0)).seat, { roomId, targetSeat: 0 });
      if (after.status === 200) fail('a closed room took a vote');
      saw('chaos:host left');
      return { seed, n, steps: step, outcome: 'closed', trail };
    }
    // Only while the match is undecided: once it is won nobody is struck (age_presence).
    if (step === strikeAt && s.phase !== 'reveal' && !outcome) {
      const guests = living.filter((p) => p.seat !== 0);
      if (guests.length > 2) {
        const gone = r.pick(guests);
        await h.sql("update room_players set status='left',connected=false,last_seen=now()-interval '2 minutes' where room_id=$1 and seat=$2", [roomId, gone.seat]);
        await h.sql("insert into room_presence(room_id,user_id,heard_at) values($1,$2,now()-interval '2 minutes') on conflict (room_id,user_id) do update set heard_at=excluded.heard_at", [roomId, gone.user_id]).catch(() => {});
        await h.sql('select public.age_presence()');
        const row = (await h.sql('select alive from room_players where room_id=$1 and seat=$2', [roomId, gone.seat])).rows[0];
        if (row.alive) fail(`seat ${gone.seat} silent past 90 s in ${s.phase} was not struck`);
        saw('chaos:guest struck');
        continue;
      }
    }

    // The dead never act.
    if (dead.length && r.chance(0.3)) {
      const d = r.pick(dead); const t = r.pick(living);
      const res = s.phase === 'vote'
        ? await call('submit_vote', d.seat, { roomId, targetSeat: t.seat })
        : s.phase === 'night' ? await call('submit_night_action', d.seat, { roomId, action: 'kill', targetSeat: t.seat }) : null;
      if (res && res.status === 200 && !(res.json?.ignored)) fail(`dead seat ${d.seat} acted in ${s.phase}: ${JSON.stringify(res.json)}`);
    }

    if (s.phase === 'reveal') {
      for (const p of players) await call('saw_role', p.seat, { roomId });
      await expire();
      await call('open_phase', r.pick(living).seat, { roomId, phase: 'night' });
      continue;
    }

    if (s.phase === 'night') {
      for (const p of living) {
        if (r.chance(0.15)) continue;                       // some never act: the clock decides
        const others = living.filter((x) => x.seat !== p.seat);
        const target = r.pick(others).seat;
        const useBullet = r.chance(0.1);
        let body;
        switch (p.role) {
          case 'mafia': body = { action: r.chance(0.1) ? 'skip' : 'kill', targetSeat: target, useBullet }; break;
          case 'silencer': body = { action: 'silence', targetSeat: target }; break;
          case 'doctor': body = { action: 'protect', targetSeat: r.chance(0.2) ? p.seat : target, useBullet }; break;
          case 'detective': body = { action: r.chance(0.1) ? 'skip' : 'investigate', targetSeat: target, useBullet }; break;
          case 'elder': body = r.chance(0.4) ? { action: r.chance(0.8) ? 'reveal' : 'unreveal', targetSeat: null } : { action: 'suspect', targetSeat: target }; break;
          default: body = { action: 'suspect', targetSeat: target, useBullet: p.role === 'sniper' && useBullet };
        }
        // A wrong action for the role now and then: must be a refusal or an ignored ok, never a 5xx.
        if (r.chance(0.05)) body = { action: r.pick(['kill', 'protect', 'investigate', 'silence']), targetSeat: target };
        await call('submit_night_action', p.seat, { roomId, ...body });
      }
      if (r.chance(0.2)) await call('advance_phase', r.pick(living).seat, { roomId });
      if (doubleTap) {
        await Promise.all([call('resolve_night', r.pick(living).seat, { roomId }), call('resolve_night', r.pick(living).seat, { roomId })]);
        saw('chaos:double resolve');
      } else await call('resolve_night', r.pick(living).seat, { roomId });
      continue;
    }

    if (s.phase === 'vote') {
      for (const p of living) {
        if (r.chance(0.1)) continue;
        const choices = living.filter((x) => x.seat !== p.seat).map((x) => x.seat);
        const target = r.chance(0.1) ? null : r.pick(choices);
        await call('submit_vote', p.seat, { roomId, targetSeat: target, round: s.public_data?.revote?.round ?? 1 });
        if (r.chance(0.05)) await call('submit_vote', p.seat, { roomId, targetSeat: target });   // a double tap
      }
      const before = (await roster()).filter((p) => p.alive).length;
      if (doubleTap) {
        await Promise.all([call('resolve_vote', r.pick(living).seat, { roomId }), call('resolve_vote', r.pick(living).seat, { roomId })]);
        const gone = before - (await roster()).filter((p) => p.alive).length;
        if (gone > 1) fail(`one ballot removed ${gone} seats`);
      } else await call('resolve_vote', r.pick(living).seat, { roomId });
      continue;
    }

    if (s.phase === 'discuss') {
      // A whisper or two, to anybody, including the dead and oneself (refused, never a crash).
      for (let i = 0; i < r.int(3); i++) {
        const from = r.pick(living); const to = r.pick(players);
        const w = await call('send_whisper', from.seat, { roomId, toSeat: to.seat, body: 'w' + r.int(1000) });
        if (w.status === 200) saw('whisper sent');
      }
    }

    // The morning opens the day the way the app opens it: the host asks for
    // the day's confrontation (a confrontation only when there is a real fact
    // to confront, else the discussion). Sometimes two ask at once.
    if (s.phase === 'morning' && !outcome && r.chance(0.6)) {
      const asks = doubleTap ? [0, r.pick(living).seat] : [0];
      const res = await Promise.all(asks.map((seat) => call('generate_confrontation', seat, { roomId })));
      const opened = res.filter((x) => x.status === 200);
      if (opened.length > 1) fail('the day opened twice');
      const next = await state();
      if (next.phase === 'confront') saw('phase:confront');
      if (next.phase === s.phase && next.phase_number === s.phase_number && !opened.length && !players.find((p) => p.seat === 0)?.alive) {
        await expire();
        await call('generate_confrontation', r.pick(living).seat, { roomId });
      }
      continue;
    }

    // Every other phase: its clock runs out, and somebody asks it to move on.
    await expire();
    const mover = r.pick(living).seat;
    const moved = await call('advance_phase', mover, { roomId });
    if ((await state()).phase !== s.phase || (await state()).phase_number !== s.phase_number) continue;
    // advance_phase had nothing to apply here: try the legal next phases.
    const candidates = s.phase === 'morning' ? (outcome ? ['result'] : ['opening', 'discuss'])
      : s.phase === 'verdict' ? (outcome ? ['result'] : ['night'])
      : s.phase === 'opening' || s.phase === 'confront' ? ['discuss']
      : s.phase === 'discuss' ? ['vote'] : [];
    let ok = moved.status === 200 && moved.json?.applied;
    for (const next of candidates) {
      const opened = await call('open_phase', mover, { roomId, phase: next });
      if (opened.status === 200) { ok = true; break; }
    }
    const after = await state();
    if (after.phase === s.phase && after.phase_number === s.phase_number && !ok) {
      fail(`stuck in ${s.phase}#${s.phase_number}: nothing moved it`);
    }
  }
  fail(`no result within ${STEP_GUARD} steps; trail ${trail.slice(-20).join(' ')}`);
}

test(`${MATCHES} random online matches keep every invariant and finish`, { timeout: 60 * 60 * 1000 }, async () => {
  const h = await harness();
  try {
    await h.sql('update operations_control set new_rooms_enabled=true where singleton=true');
    const outcomes = { town: 0, mafia: 0, closed: 0 };
    const start = Number(process.env.FUZZ_FROM ?? 0);
    for (let seed = start; seed < start + MATCHES; seed++) {
      const result = await playOne(h, seed);
      outcomes[result.outcome] = (outcomes[result.outcome] ?? 0) + 1;
    }
    console.log(`online fuzz: ${MATCHES} matches, outcomes ${JSON.stringify(outcomes)}`);
    console.log(`reached: ${JSON.stringify(Object.fromEntries([...seen].sort()))}`);
    for (const k of ['phase:opening', 'phase:verdict', 'elder revealed', 'revote', 'role:sniper', 'role:silencer', 'chaos:guest struck', 'chaos:double resolve', 'whisper sent', 'phase:confront', 'silenced']) {
      if (MATCHES >= 50) assert.ok(seen.get(k) > 0, `the run never reached ${k}`);
    }
    assert.ok(outcomes.town > 0 && outcomes.mafia > 0, `one side never wins: ${JSON.stringify(outcomes)}`);
  } finally { await h.close(); }
});
