/**
 * `saw_role` — one player says they have looked at their own card.
 *
 * The whole of the deal's gate is this boolean. A client that dismisses the
 * card tells the server so; `open_phase` will not leave `reveal` until every
 * seat has. Nothing about *what* was on the card crosses — the function never
 * reads `role` and never returns it.
 *
 * Idempotent by construction: setting a boolean that is already true is the
 * same write, so a retry on a flaky network is a no-op rather than a second
 * anything.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // Only during the deal. A client that posts this from the night is either
  // confused or probing, and neither deserves a write.
  if (me.phase !== "reveal") {
    return fail("PHASE_CLOSED", "the deal is not open");
  }

  const { error } = await db
    .from("room_players")
    .update({ saw_role: true })
    .eq("room_id", roomId)
    .eq("user_id", userId);
  if (error) throw error;

  return ok({ sawRole: true });
}));
