/**
 * `send_whisper` — the abuse controls that cannot be client-side (doc 09 §3.5).
 *
 * *"Rate limit — 1/day, enforced **server-side** in online mode — never trust
 * the client."* The unique index on `(room_id, day, from_id)` is what enforces
 * it; this function turns the resulting 23505 into a clear refusal rather than
 * a 500.
 *
 * The body is written to `whisper_content`, which only the two parties can
 * select. The graph goes to `whisper_meta`, which the whole room can read —
 * that asymmetry is the layer's entire design (doc 09 §3.1).
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

const MAX_LENGTH = 120;

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, toSeat, body } = await req.json();
  if (!roomId || toSeat == null) return fail("BAD_REQUEST", "roomId and toSeat required");

  const text = String(body ?? "").trim();
  // H-E10 and H-E6. Never truncated: a whisper that arrives half-said is worse
  // than one that was refused, and the sender cannot tell which happened.
  if (text.length === 0) return fail("BAD_REQUEST", "an empty whisper is not a whisper");
  if (text.length > MAX_LENGTH) return fail("BAD_REQUEST", `at most ${MAX_LENGTH} characters`);

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead do not whisper", 403);
  if (me.seat === toSeat) return fail("BAD_REQUEST", "not yourself");
  if (me.settings.whisperEnabled === false) {
    return fail("PHASE_CLOSED", "whispers are off for this match");
  }

  const { data: target } = await db
    .from("room_players")
    .select("user_id, alive")
    .eq("room_id", roomId)
    .eq("seat", toSeat)
    .maybeSingle();
  if (!target) return fail("BAD_REQUEST", "no such seat");
  if (!target.alive) return fail("BAD_REQUEST", "that player is dead");

  const { data: meta, error } = await db
    .from("whisper_meta")
    .insert({
      room_id: roomId,
      day: me.phaseNumber,
      from_id: userId,
      to_id: target.user_id,
    })
    .select("id")
    .single();

  if (error) {
    if (error.code === "23505") {
      return fail("RATE_LIMITED", "you have already whispered today");
    }
    throw error;
  }

  const { error: bodyError } = await db
    .from("whisper_content")
    .insert({ whisper_id: meta.id, body: text });
  if (bodyError) {
    // The edge is public and the body is not there — a whisper the table can
    // see and the recipient cannot read. Undo it rather than leave that.
    await db.from("whisper_meta").delete().eq("id", meta.id);
    throw bodyError;
  }

  // H-E9 — a blocked sender's whisper is dropped for the recipient, and the
  // sender is told nothing at all. The row exists, the graph shows it, and the
  // recipient's client simply never fetches the body. Building the drop here,
  // as a deletion, would be observable to the sender.
  return ok({ id: meta.id });
}));
