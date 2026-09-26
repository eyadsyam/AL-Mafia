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

  if (!Number.isInteger(toSeat) || toSeat < 0) return fail("BAD_REQUEST", "no such seat");
  // The room lock serializes sends with phase changes and removals. Both
  // tables commit together, before Realtime can notify the recipient.
  const { data: id, error } = await db.rpc("commit_whisper", {
    p_room: roomId, p_sender: userId, p_seat: toSeat,
    p_day: me.phaseNumber, p_body: text,
  });

  if (error) {
    if (error.code === "23505") {
      return fail("RATE_LIMITED", "you have already whispered today");
    }
    const message = String(error.message ?? "");
    if (message === "PHASE_CLOSED") return fail("PHASE_CLOSED", "whispers are closed");
    if (message === "NOT_A_MEMBER") return fail("NOT_A_MEMBER", "you are not in that room", 403);
    if (message === "NOT_ALIVE") return fail("NOT_ALIVE", "the dead do not whisper", 403);
    if (message === "ROOM_NOT_FOUND") return fail("ROOM_NOT_FOUND", "no such room", 404);
    if (message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid whisper");
    throw error;
  }

  // H-E9 — a blocked sender's whisper is dropped for the recipient, and the
  // sender is told nothing at all. The row exists, the graph shows it, and the
  // recipient's client simply never fetches the body. Building the drop here,
  // as a deletion, would be observable to the sender.
  return ok({ id });
}));
