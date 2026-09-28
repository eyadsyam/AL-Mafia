import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const roomId = body.roomId;
  if (!roomId || typeof body.ready !== "boolean" || !Number.isInteger(body.revision)) {
    return fail("BAD_REQUEST", "roomId, ready and revision required");
  }

  const member = await loadMembership(db, roomId, userId);
  if (!member) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  const { data, error } = await db.rpc("set_lobby_ready", {
    p_room: roomId,
    p_user: userId,
    p_ready: body.ready,
    p_revision: body.revision,
  });
  if (error) {
    const message = String(error.message ?? "");
    if (message.includes("STALE_REVISION")) return fail("STALE_REVISION", "the lobby changed", 409);
    if (message.includes("PHASE_CLOSED")) return fail("PHASE_CLOSED", "the match has started", 409);
    if (message.includes("NOT_A_MEMBER")) return fail("NOT_A_MEMBER", "you are not in that room", 403);
    if (message.includes("FEATURE_OFF")) return fail("FEATURE_OFF", "lobby ready is disabled", 404);
    if (message.includes("BAD_REQUEST")) return fail("BAD_REQUEST", "the seat is away");
    if (message.includes("ROOM_NOT_FOUND")) return fail("ROOM_NOT_FOUND", "no such room", 404);
    throw error;
  }
  return ok(data);
}));
