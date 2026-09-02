/**
 * `record_speaking` — how long a seat held the floor today.
 *
 * The one input to the Information Engine that nothing else produces. `C3`
 * («لسه ماتكلمش النهارده») is the confrontation that asks the quiet player to
 * explain themselves, and a player is only quiet if somebody measured it. The
 * discussion screen measures; this is where the measurement lands.
 *
 * Seconds accumulate rather than replace: a player who takes the floor three
 * times has spoken for the sum. The addition happens inside one SQL statement
 * (`add_speaking_seconds`), because two clients reporting at once against a
 * read-modify-write would lose one of them.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

const MAX_SECONDS = 600;

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, seconds } = await req.json();
  if (!roomId || seconds == null) {
    return fail("BAD_REQUEST", "roomId and seconds required");
  }

  const value = Math.floor(Number(seconds));
  // A client reporting an implausible number is not attacked, it is clamped:
  // the field feeds a "who has been quiet" comparison, and one player claiming
  // an hour of floor time would poison it for everybody.
  if (!Number.isFinite(value) || value < 0 || value > MAX_SECONDS) {
    return fail("BAD_REQUEST", "implausible speaking time");
  }

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead hold no floor", 403);

  await db.rpc("add_speaking_seconds", {
    p_room: roomId,
    p_day: me.phaseNumber,
    p_seat: me.seat,
    p_seconds: value,
  });

  return ok();
}));
