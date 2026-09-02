/**
 * `submit_vote` — O17's answer.
 *
 * *"Malicious client posts a vote for someone else → Edge Function rejects —
 * `voter_id` is taken from the auth token, never from the body."* Which is
 * exactly what happens below: the request carries a *target*, never a voter.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, targetSeat, round, actionId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead do not vote", 403);
  if (me.phase !== "vote") return fail("PHASE_CLOSED", "the ballot is closed");

  let targetId: string | null = null;
  if (targetSeat != null) {
    if (targetSeat === me.seat) return fail("BAD_REQUEST", "not yourself");
    const { data: target } = await db
      .from("room_players")
      .select("user_id, alive")
      .eq("room_id", roomId)
      .eq("seat", targetSeat)
      .maybeSingle();
    if (!target) return fail("BAD_REQUEST", "no such seat");
    if (!target.alive) return fail("BAD_REQUEST", "that player is dead");
    targetId = target.user_id;
  }

  // D10 — last write per (day, voter, round) wins, which the primary key makes
  // true without a read-modify-write.
  const { error } = await db.from("votes").upsert({
    room_id: roomId,
    day: me.phaseNumber,
    voter_id: userId,
    target_id: targetId,
    round: round ?? 1,
    action_id: actionId ?? null,
  });
  if (error) throw error;

  return ok();
}));
