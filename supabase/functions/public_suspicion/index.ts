/**
 * `public_suspicion` — «أنا شاكك في»: the caller names one living other during
 * the discussion, or clears their pick (targetSeat null). Public by design;
 * the rules (phase, alive, not silenced, one per day, changeable) are kept in
 * `set_public_suspicion`, under the room's row lock.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

const CODES = new Set([
  "ROOM_NOT_FOUND", "PHASE_CLOSED", "NOT_A_MEMBER", "NOT_ALIVE", "SILENCED", "BAD_REQUEST",
]);

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
    const code = CODES.has(error.message) ? error.message : null;
    if (code) return fail(code, "suspicion refused", code === "NOT_A_MEMBER" ? 403 : 400);
    throw error;
  }
  return ok(data ?? {});
}));
