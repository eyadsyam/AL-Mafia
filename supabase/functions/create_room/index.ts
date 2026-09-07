/**
 * `create_room` — mints a room, a code and the match seed (doc 10 §5).
 *
 * The seed is generated here and **never returned**. Doc 10 §10: with it a
 * client could predict every tie-break in the match, including tonight's Mafia
 * target resolution and tomorrow's trace.
 */
import { fail, generateCode, handler, newMatchSeed, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const name = String(body.name ?? "").trim();
  if (!name) return fail("BAD_REQUEST", "a display name is required");

  // O13 — a duplicate code must be impossible, not merely unlikely. The unique
  // index decides; this loop just retries the collision. Checking first and
  // then inserting would be a race with exactly the outcome the check was for.
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateCode();
    const { data, error } = await db
      .from("rooms")
      .insert({ code, host_id: userId, match_seed: newMatchSeed() })
      .select("id, code")
      .single();

    if (error) {
      if (error.code === "23505") continue;
      throw error;
    }

    await db.from("room_players").insert({
      room_id: data.id,
      user_id: userId,
      name,
      gender: ["male", "female"].includes(body.gender) ? body.gender : "unspecified",
      seat: 0,
    });
    await db.from("room_state").insert({ room_id: data.id, phase: "lobby" });

    return ok({ roomId: data.id, code: data.code, seat: 0 });
  }
  return fail("BAD_REQUEST", "could not allocate a room code");
}));
