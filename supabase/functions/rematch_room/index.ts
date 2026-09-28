/**
 * `rematch_room` — «ماتش كمان بنفس الترابيزة». The host of a finished room
 * opens the next one with the same settings; the old room's public data then
 * carries its code, so every player still on the result screen joins with one
 * tap. A second call returns the same new room.
 *
 * Like `create_room`, the seed is minted here and never returned.
 */
import { fail, generateCode, handler, newMatchSeed, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const roomId = String(body.roomId ?? "");
  const name = String(body.name ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(roomId)) return fail("BAD_REQUEST", "roomId is required");
  if (!name || name.length > 20) return fail("BAD_REQUEST", "a display name is required");
  const gender = ["male", "female"].includes(body.gender) ? body.gender : "unspecified";

  for (let attempt = 0; attempt < 8; attempt++) {
    const { data, error } = await db.rpc("rematch_room_atomic", {
      p_old: roomId, p_host: userId, p_name: name, p_gender: gender,
      p_code: generateCode(), p_seed: newMatchSeed(),
    });
    if (error) {
      if (error.code === "23505") continue;
      for (const code of ["ROOM_NOT_FOUND", "PHASE_CLOSED", "NOT_HOST", "NEW_ROOMS_PAUSED"] as const) {
        if (error.message?.includes(code)) {
          return fail(code, "rematch refused",
            code === "ROOM_NOT_FOUND" ? 404 : code === "NEW_ROOMS_PAUSED" ? 503 : 400);
        }
      }
      throw error;
    }
    return ok(data);
  }
  return fail("BAD_REQUEST", "could not allocate a room code");
}));
