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

  const { data: target } = await db
    .from("room_players")
    .select("user_id")
    .eq("room_id", roomId)
    .eq("seat", seat)
    .maybeSingle();
  if (!target) return fail("BAD_REQUEST", "no such seat");

  const { data: room } = await db
    .from("rooms")
    .select("banned_user_ids")
    .eq("id", roomId)
    .maybeSingle();
  const banned = new Set<string>((room?.banned_user_ids ?? []) as string[]);
  banned.add(target.user_id);

  await db
    .from("rooms")
    .update({ banned_user_ids: [...banned] })
    .eq("id", roomId);

  const { error } = await db
    .from("room_players")
    .update({ status: "left", connected: false, kicked: true })
    .eq("room_id", roomId)
    .eq("user_id", target.user_id);
  if (error) throw error;

  return ok({ kicked: seat });
}));
