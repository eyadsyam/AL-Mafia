/**
 * `submit_vote` — O17's answer.
 *
 * *"Malicious client posts a vote for someone else → Edge Function rejects —
 * `voter_id` is taken from the auth token, never from the body."* Which is
 * exactly what happens below: the request carries a *target*, never a voter.
 */
import { asUuid, fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { ballotTargetAllowed } from "../_shared/ballot_candidates.ts";

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
    const { data: target, error: targetError } = await db
      .from("room_players")
      .select("user_id, alive")
      .eq("room_id", roomId)
      .eq("seat", targetSeat)
      .maybeSingle();
    if (targetError) throw targetError;
    if (!target) return fail("BAD_REQUEST", "no such seat");
    if (!target.alive) return fail("BAD_REQUEST", "that player is dead");
    targetId = target.user_id;
  }

  // D10 — last write per (day, voter, round) wins, which the primary key makes
  // true without a read-modify-write.
  // The round is the room's. A client may say which round it thinks it is
  // voting in, and a ballot for any other round is refused rather than filed
  // under a round nobody is counting: a revote is a new ballot, not a second
  // column of the first one.
  const { data: state, error: stateError } = await db.from("room_state")
    .select("public_data").eq("room_id", roomId).maybeSingle();
  if (stateError) throw stateError;
  const revote = (state?.public_data as Record<string, unknown> | null)
    ?.revote as Record<string, unknown> | null | undefined;
  const thisRound = Number(revote?.round ?? 1);
  if (round != null && Number(round) !== thisRound) {
    return fail("PHASE_CLOSED", "that ballot round is over");
  }
  if (!ballotTargetAllowed(thisRound, revote?.tiedSeats, targetSeat ?? null)) {
    return fail("BAD_REQUEST", "choose one of the tied players");
  }
  const { error } = await db.from("votes").upsert({
    room_id: roomId,
    day: me.phaseNumber,
    voter_id: userId,
    target_id: targetId,
    round: thisRound,
    action_id: asUuid(actionId),
  });
  if (error) {
    if (error.message?.includes("INVALID_REVOTE_TARGET")) {
      return fail("BAD_REQUEST", "choose one of the tied players");
    }
    // The phase guard on the table (migration `action_epoch`): the ballot was
    // resolved between this caller's read and its write.
    if (error.message?.includes("PHASE_CLOSED")) {
      return fail("PHASE_CLOSED", "the ballot is closed");
    }
    // The membership guard on the same trigger (migration `kicked_moves`):
    // the seat was removed between this caller's read and its write.
    if (error.message?.includes("NOT_A_MEMBER")) {
      return fail("NOT_A_MEMBER", "you are no longer in that room", 403);
    }
    throw error;
  }

  await closeBallotIfEveryoneVoted(db, roomId, me.phaseNumber, thisRound);
  return ok();
}));

/**
 * Brings the ballot's clock to now once every living player has voted.
 *
 * The same argument as the night's, and the same mechanism: sixty seconds
 * exists so that somebody still deciding is not defaulted to an abstention,
 * and the moment nobody is still deciding it is only making the room wait.
 * The phase is not changed here — the host's client still asks for the tally,
 * so there is exactly one route into a resolution and this only stops it being
 * late.
 *
 * An abstention is a vote for this purpose, which is the point: the row is
 * what says the player answered.
 */
async function closeBallotIfEveryoneVoted(
  // deno-lint-ignore no-explicit-any
  db: any,
  roomId: string,
  day: number,
  round: number,
): Promise<void> {
  const [living, cast] = await Promise.all([
    db.from("room_players").select("user_id").eq("room_id", roomId).eq(
      "alive",
      true,
    ),
    db.from("votes").select("voter_id").eq("room_id", roomId).eq("day", day).eq(
      "round",
      round,
    ),
  ]);
  if (living.error || cast.error) return;
  const alive = new Set(
    (living.data ?? []).map((p: { user_id: string }) => p.user_id),
  );
  if (alive.size === 0) return;
  const voted = new Set(
    (cast.data ?? []).map((v: { voter_id: string }) => v.voter_id),
  );
  for (const id of alive) {
    if (!voted.has(id)) return;
  }
  await db.from("room_state")
    .update({ phase_ends_at: new Date().toISOString() })
    .eq("room_id", roomId)
    .eq("phase", "vote")
    .eq("phase_number", day);
}
