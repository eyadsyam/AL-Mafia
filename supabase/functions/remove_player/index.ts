/**
 * `remove_player` — doc 10 §8.1's last row: *"player gone > 3 minutes → host
 * may mark them «خرج» — treated as a neutral elimination, then a win check."*
 *
 * ## Neutral, and why that word is doing work
 *
 * Nobody voted for this. So no role is announced, nothing is attributed to the
 * table, and the Information Engine is told nothing: a removal is not a
 * suspicion, not an accusation and not a lynch, and a generator that treated it
 * as one would be inventing a fact about a player who was not even there
 * (prime directive 4).
 *
 * ## The three-minute check is the server's
 *
 * A host who could remove anybody at any moment would be holding a delete
 * button over the other players, and "they were disconnected, honestly" is not
 * a thing the other four can check. So the server checks: the target must
 * actually have been silent for three minutes. A host with a grudge and a fast
 * finger gets a refusal.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, seat } = await req.json();
  if (!roomId || seat == null) return fail("BAD_REQUEST", "roomId and seat required");
  const target = Number(seat);
  if (!Number.isInteger(target) || target < 0) return fail("BAD_REQUEST", "no such seat");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "only the host may remove", 403);
  if (me.status !== "playing") return fail("PHASE_CLOSED", "no match is running");

  // The silence test, the elimination, the voided whispers, the record and
  // the win check are one statement under the room lock
  // (`strike_absent_member`). They used to be five requests with no error
  // checked: a roster read that failed came back empty, and an empty roster
  // has no Mafia in it, so the town was declared the winner of a match the
  // server had not actually looked at.
  const { data, error } = await db.rpc("strike_absent_member", {
    p_room: roomId, p_host: userId, p_seat: target,
  });
  if (error) {
    const message = String(error.message ?? "");
    if (message.includes("ROOM_NOT_FOUND")) return fail("ROOM_NOT_FOUND", "no such room", 404);
    if (message.includes("NOT_HOST")) return fail("NOT_HOST", "only the host may remove", 403);
    if (message.includes("PHASE_CLOSED")) return fail("PHASE_CLOSED", "no match is running");
    if (message.includes("ALREADY_OUT")) return fail("BAD_REQUEST", "that player is already out");
    if (message.includes("STILL_HERE")) return fail("BAD_REQUEST", "that player is still here");
    if (message.includes("BAD_REQUEST")) return fail("BAD_REQUEST", "no such seat");
    throw error;
  }
  const answer = (data ?? {}) as { removed?: number; outcome?: string | null };
  return ok({ removed: answer.removed ?? target, outcome: answer.outcome ?? null });
}));
