/** Seat assignment and start share the room-row lock; retries restore the same seat. */
import { fail, handler, ok, type ErrorCode } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const code = String(body.code ?? "").trim().toUpperCase();
  const name = String(body.name ?? "").trim();
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/.test(code) || !name || name.length > 20) {
    return fail("BAD_REQUEST", "valid code and display name are required");
  }
  const { data, error } = await db.rpc("join_room_atomic", {
    p_code: code, p_user: userId, p_name: name,
    p_gender: ["male", "female"].includes(body.gender) ? body.gender : "unspecified",
  });
  if (error) {
    const expected: ErrorCode[] = ["ROOM_NOT_FOUND", "ROOM_FINISHED", "ROOM_FULL", "NOT_A_MEMBER", "PHASE_CLOSED",
      "ROOM_UNAVAILABLE", "NAME_NOT_ALLOWED", "ACCOUNT_RESTRICTED", "BAD_REQUEST"];
    const refusal = expected.find((code) => code === error.message);
    if (refusal) {
      return fail(refusal, "room entry refused", refusal === "ROOM_NOT_FOUND" ? 404 : 400);
    }
    throw error;
  }
  return ok(data);
}));
