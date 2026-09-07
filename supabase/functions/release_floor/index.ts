/**
 * `release_floor` — giving the microphone back early.
 *
 * The polite path, not the mechanism. Every grant made by `claim_floor` also
 * carries `speaker_until`, so the floor comes back on its own from a player
 * whose battery died mid-sentence (V5). This is what happens when they simply
 * finished talking, and it is worth having because the alternative is a table
 * waiting out a timer for no reason.
 *
 * Scoped to the holder inside `release_speaking_floor`: a client whose grant
 * already lapsed cannot clear the next speaker's.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  const { error } = await db.rpc("release_speaking_floor", {
    p_room: roomId,
    p_user: userId,
  });
  if (error) throw error;

  // You have finished speaking. Leaving your own hand up afterwards would put
  // you back in the set of people asking for a turn you just took.
  await db.rpc("lower_hand", { p_room: roomId, p_user: userId });

  return ok();
}));
