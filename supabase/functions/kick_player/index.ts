/**
 * `kick_player` — the host removing somebody, for good.
 *
 * Host-only, checked here against `rooms.host_id` and not against anything the
 * caller said. A kick does two things that a disconnection does not: it adds
 * the player's id to `rooms.banned_user_ids`, so the rejoin path in `join_room`
 * refuses them however many times they type the code, and it sets `kicked` on
 * their own row, which is how their device learns to say so and go home.
 *
 * The seat is *not* re-packed and the row is *not* deleted, mid-match or in a
 * lobby. A deleted row is a player who could be dealt a fresh seat by a
 * rejoining stranger, and re-packing seats mid-match would move everybody
 * else's identity claim (O5).
 *
 * A host cannot kick themselves. That is not a rule about manners: the room
 * would be left with a host who is banned from it.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, seat } = await req.json();
  if (!roomId || seat === undefined || seat === null) {
    return fail("BAD_REQUEST", "roomId and seat required");
  }

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "only the host removes", 403);
  if (me.seat === seat) return fail("BAD_REQUEST", "a host cannot remove itself");

  // One statement under the room lock (`kick_member`): the ban is appended
  // to the list the room holds *now*, and the seat is marked in the same
  // transaction. The host check runs again inside it against the row.
  const { data: removed, error } = await db.rpc("kick_member", {
    p_room: roomId,
    p_host: userId,
    p_seat: seat,
  });
  if (error) {
    if (error.message?.includes("NOT_HOST")) {
      return fail("NOT_HOST", "only the host removes", 403);
    }
    if (error.message?.includes("BAD_REQUEST")) {
      return fail("BAD_REQUEST", "no such seat");
    }
    throw error;
  }
  if (!removed) return fail("BAD_REQUEST", "no such seat");

  return ok({ kicked: seat });
}));
