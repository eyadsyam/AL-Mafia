/**
 * `leave_room` — what "I'm out" means, which depends entirely on when it is
 * said (doc 10 §8.1).
 *
 * **In the lobby** it is a departure: the row goes and the seats re-pack.
 * Seat order is the night pass and the «اسم واحد» order, so a hole in it would
 * put an empty chair in both.
 *
 * **Mid-match** it is only a disconnection, however deliberate. The seat is the
 * identity claim (O5) and the role was dealt against it, so the row stays and
 * the player can come back to it (O4). A match does not lose a player because
 * their phone rang.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  const { data, error } = await db.rpc("leave_room", {
    p_room: roomId,
    p_user: userId,
  });
  if (error) throw error;

  return ok({ result: data });
}));
