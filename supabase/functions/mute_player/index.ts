/**
 * `mute_player` — the host silencing one microphone for the whole room.
 *
 * ## Why the server holds this and not the speakers
 *
 * A mesh has no server in the media path, so nothing can drop a stream on the
 * way through. What the server can do is state the fact — `room_players.muted`
 * — and every client then refuses to render that peer, exactly as they already
 * refuse to render anybody who does not hold the floor (doc 10 §6.1's V4). The
 * muted device also stops publishing, which is the polite half; the half that
 * matters is that fifteen listeners independently do not play it, because a
 * modified client can skip the first and cannot skip the others.
 *
 * Host-only, checked here. A toggle rather than two functions: the state is a
 * boolean and the caller passes the value it wants, so a double-tap on a slow
 * network cannot leave the room disagreeing about whether somebody is muted.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, seat, muted } = await req.json();
  if (!roomId || seat === undefined || seat === null) {
    return fail("BAD_REQUEST", "roomId and seat required");
  }

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "only the host mutes", 403);

  const { error } = await db
    .from("room_players")
    .update({ muted: muted === true })
    .eq("room_id", roomId)
    .eq("seat", seat);
  if (error) throw error;

  return ok({ seat, muted: muted === true });
}));
