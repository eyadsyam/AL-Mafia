import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");
  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead cannot reveal", 403);
  if (me.role !== "elder") return fail("WRONG_ROLE", "only the Elder reveals", 403);
  const { data, error } = await db.rpc("reveal_elder_role", {
    p_room: roomId,
    p_user: userId,
  });
  if (error) throw error;
  if (data !== true) return fail("PHASE_CLOSED", "not a day phase");
  return ok({ revealed: true, seat: me.seat });
}));
