/**
 * `submit_prediction` — the eliminated player's stake in the ending
 * (doc 12 §4.1).
 *
 * *"Prediction panel — privately predict the winner and name the remaining
 * Mafia. Locked once submitted, scored in post-game."*
 *
 * ## Why the lock is here and not a trigger
 *
 * A trigger can refuse a second write; it cannot explain itself. The screen has
 * to say *"you already called it"* and show what was called, and that is one
 * response rather than an error plus a follow-up read. So the uniqueness is the
 * primary key's, and the refusal is this function's.
 *
 * ## Why a dead player, and only a dead player
 *
 * A living player who could lodge a prediction would have a private, durable,
 * server-held note of who they suspect — which is a notebook the offline game
 * does not have and doc 09 deliberately did not build. The panel exists because
 * an eliminated player has nothing else to do; it is not a feature of playing.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, winner, mafiaSeats } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");
  if (winner !== "mafia" && winner !== "town") {
    return fail("BAD_REQUEST", "winner must be mafia or town");
  }

  const seats = Array.isArray(mafiaSeats)
    ? [...new Set(mafiaSeats.map(Number).filter(Number.isInteger))].sort(
      (a, b) => a - b,
    )
    : [];

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.alive) {
    return fail("NOT_ALIVE", "the living play; they do not predict", 403);
  }
  if (me.status === "finished") {
    return fail("ROOM_FINISHED", "the match is over", 403);
  }

  // Every named seat has to be a seat in this room. A prediction naming seat 40
  // would score as wrong forever and read as a bug at the end of the evening.
  const { data: roster } = await db
    .from("room_players")
    .select("seat")
    .eq("room_id", roomId);
  const known = new Set((roster ?? []).map((row) => row.seat as number));
  if (seats.some((seat) => !known.has(seat))) {
    return fail("BAD_REQUEST", "no such seat");
  }

  const { error } = await db
    .from("predictions")
    .insert({
      room_id: roomId,
      user_id: userId,
      winner,
      mafia_seats: seats,
    });

  if (error) {
    // 23505 — the primary key. They have already called it.
    if (error.code === "23505") {
      return fail("RATE_LIMITED", "you have already called it");
    }
    throw error;
  }

  return ok();
}));
