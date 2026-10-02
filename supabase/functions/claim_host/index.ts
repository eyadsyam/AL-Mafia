/**
 * `claim_host` — O1 and O2: the match never ends because the host left.
 *
 * ## Who asks
 *
 * The lowest-seat connected player, and only when the host has stopped
 * answering. Every client can work that out for itself from the roster it
 * already has, which is what makes the migration automatic rather than a menu
 * item somebody has to find.
 *
 * ## Who decides
 *
 * This does not. `migrate_host` does, inside one statement holding a lock on
 * the room, because several clients can decide to ask at the same moment and
 * "the lowest connected seat" evaluated twice against a moving roster is two
 * different answers. The function returns whoever the host now is; a claimant
 * that was beaten to it gets the winner's id back and no error, because
 * "somebody is host" is the whole of what it wanted.
 *
 * ## What it deliberately does not do
 *
 * Nothing to the phase. A host migration is not a state change in the game —
 * the room is exactly where it was, and the new host inherits the same
 * «التالي» the old one was about to tap.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.status === "finished") {
    return fail("ROOM_FINISHED", "that match has already finished");
  }

  // The claimant is alive on the network whatever else is true of them: they
  // just made a request. Recording it first stops a room where everybody is
  // marked stale from concluding that nobody may take over (O2's tail).
  const { error: beatError } = await db.from("room_players")
    .update({ connected: true, last_seen: new Date().toISOString() })
    .eq("room_id", roomId)
    .eq("user_id", userId);
  if (beatError) throw beatError;

  const { data, error } = await db.rpc("migrate_host", {
    p_room: roomId,
    p_claimant: userId,
  });
  if (error) throw error;

  const host = data as string | null;
  return ok({ hostId: host, claimed: host === userId });
}));
