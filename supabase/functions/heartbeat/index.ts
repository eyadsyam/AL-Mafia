/**
 * `heartbeat` — a short presence beat while the client is foregrounded.
 *
 * The client uses a three-second beat. The beat itself is private to the
 * server (M3); the room hears only the transitions, which the server owns.
 *
 * **The night freeze (doc 10 §6.3) is not implemented here** and must not be:
 * `connected` keeps updating, and it is the *client* that stops rendering
 * per-player status for the whole night phase. Freezing the data would lose the
 * disconnect detection that §8.1 depends on; freezing the display loses
 * nothing, because there is nothing a player may act on during the night
 * anyway.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // A beat that did not land is not a beat: the client treats a failed
  // heartbeat as weather and degrades, and a 200 for a write that failed
  // would have it believe the room still hears it.
  //
  // M3 — the beat lands in the unpublished `room_presence`. `room_players`
  // (and so the room's Realtime stream) only changes when this seat's state
  // does: coming back from away, or from a stale disconnect.
  const { data: seated, error } = await db.rpc("presence_beat", {
    p_room: roomId,
    p_user: userId,
  });
  if (error) throw error;
  if (seated !== true) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  return ok();
}));
