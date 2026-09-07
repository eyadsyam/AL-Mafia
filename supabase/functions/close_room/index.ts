/**
 * `close_room` — the host ending it for everybody, on purpose.
 *
 * Task 5 draws a hard line between two things that used to be confused. A host
 * who *leaves* does not end the match: the room migrates and carries on, and
 * that is not negotiable, because a dropped phone must never cost four other
 * people their game. A host who taps «اقفل الأوضة» does end it, because that is
 * what the words say and there is a confirmation in front of them.
 *
 * So this is the only path from a live room to a dead one that is not a
 * victory, and it is host-only, checked here.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "only the host closes", 403);
  if (me.status === "finished") return ok({ closed: true });

  // No standings and no outcome. A room that was closed is not a room that was
  // won, and writing a result here would put a fabricated ending into the
  // archive every client reads.
  const { error } = await db
    .from("rooms")
    .update({ status: "finished", ended_at: new Date().toISOString() })
    .eq("id", roomId);
  if (error) throw error;

  return ok({ closed: true });
}));
