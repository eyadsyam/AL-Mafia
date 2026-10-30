/**
 * `public_suspicion` — «أنا شاكك في»: the caller names one living other during
 * the discussion, or clears their pick (targetSeat null). Public by design;
 * the rules (phase, alive, not silenced, one per day, changeable) are kept in
 * `set_public_suspicion`, under the room's row lock.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, targetSeat } = await req.json();
  if (typeof roomId !== "string" ||
      (targetSeat !== null && !(Number.isInteger(targetSeat) && targetSeat >= 0))) {
    return fail("BAD_REQUEST", "roomId and targetSeat (or null) required");
  }
  // Who is asking, before anything else; the RPC checks it again under lock.
  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.phase !== "discuss") return fail("PHASE_CLOSED", "only during the discussion");
  const { data, error } = await db.rpc("set_public_suspicion", {
    p_room: roomId, p_user: userId, p_target_seat: targetSeat,
  });
  if (error) {
    const message = String(error.message ?? "");
    if (message === "ROOM_NOT_FOUND") return fail("ROOM_NOT_FOUND", "suspicion refused");
    if (message === "PHASE_CLOSED") return fail("PHASE_CLOSED", "suspicion refused");
    if (message === "NOT_A_MEMBER") return fail("NOT_A_MEMBER", "suspicion refused", 403);
    if (message === "NOT_ALIVE") return fail("NOT_ALIVE", "suspicion refused");
    if (message === "SILENCED") return fail("SILENCED", "suspicion refused");
    if (message === "BAD_REQUEST") return fail("BAD_REQUEST", "suspicion refused");
    throw error;
  }
  return ok(data ?? {});
}));
