// node supabase/tests/whisper_replay.test.mjs
//
// M6 — the whisper retry rule, against the real `_shared/whisper_replay.ts`.
// A 23505 returns the original id only for today's whisper from the same
// sender, to the same seat's player, with the exact stored body.
import assert from 'node:assert/strict';
import { importTs } from './support/ts_loader.mjs';

const { sameWhisper } = await importTs('supabase/functions/_shared/whisper_replay.ts');

/** A read-only PostgREST double over in-memory rows. */
function fakeDb(tables) {
  return {
    from(table) {
      const filters = [];
      const q = {
        select() { return q; },
        eq(column, value) { filters.push([column, value]); return q; },
        async maybeSingle() {
          const rows = (tables[table] ?? []).filter((r) => filters.every(([c, v]) => r[c] === v));
          if (rows.length > 1) return { data: null, error: { code: 'PGRST116' } };
          return { data: rows[0] ?? null, error: null };
        },
      };
      return q;
    },
  };
}

const room = 'r1', sender = 'u-sender', recipient = 'u-recipient', other = 'u-other';
const db = fakeDb({
  whisper_meta: [{ id: 'w-original', room_id: room, day: 2, from_id: sender, to_id: recipient }],
  room_players: [
    { room_id: room, seat: 3, user_id: recipient },
    { room_id: room, seat: 4, user_id: other },
  ],
  whisper_content: [{ whisper_id: 'w-original', body: 'الدكتور شكله مريب' }],
});

// Lost response, identical retry → the original id.
assert.equal(await sameWhisper(db, room, sender, 2, 3, 'الدكتور شكله مريب'), 'w-original');
// Concurrent identical retries both resolve to the one original.
const both = await Promise.all([
  sameWhisper(db, room, sender, 2, 3, 'الدكتور شكله مريب'),
  sameWhisper(db, room, sender, 2, 3, 'الدكتور شكله مريب'),
]);
assert.deepEqual(both, ['w-original', 'w-original']);
// A different recipient is a second whisper: refused.
assert.equal(await sameWhisper(db, room, sender, 2, 4, 'الدكتور شكله مريب'), null);
// Different words (even whitespace) are a second whisper: refused.
assert.equal(await sameWhisper(db, room, sender, 2, 3, 'الدكتور شكله مريب '), null);
assert.equal(await sameWhisper(db, room, sender, 2, 3, 'حاجة تانية'), null);
// Another day, another sender, an empty seat: refused.
assert.equal(await sameWhisper(db, room, sender, 3, 3, 'الدكتور شكله مريب'), null);
assert.equal(await sameWhisper(db, room, other, 2, 3, 'الدكتور شكله مريب'), null);
assert.equal(await sameWhisper(db, room, sender, 2, 9, 'الدكتور شكله مريب'), null);
// A read error never turns into a false "already sent".
const broken = { from() { const q = { select: () => q, eq: () => q,
  maybeSingle: async () => ({ data: null, error: { message: 'down' } }) }; return q; } };
assert.equal(await sameWhisper(broken, room, sender, 2, 3, 'الدكتور شكله مريب'), null);

console.log('PASS whisper replay: identical/concurrent → original id; recipient/body/day/sender mismatch → refusal');
