/**
 * `submit_accusation` — one name in the «اسم واحد» round (doc 09 §2.2).
 *
 * ## Why this is not just another vote
 *
 * It is public, it is forced, and it is *ordered*. Ten seconds per player in
 * seating order, one name, no explanation and no "I don't know". The order is
 * what makes it worth having: the fifth player answers knowing what four
 * people said, and the room ends the round with a full suspicion map instead
 * of a silence somebody has to break.
 *
 * So the phase points at one seat — `openingSeat` in the public payload — and
 * this refuses anybody else. That is the same rule the offline engine keeps
 * with `currentActorSeat`, and refusing it here is what keeps a fast client
 * from answering out of turn on somebody else's ten seconds.
 *
 * ## What it never trusts
 *
 * The caller's seat. It comes from the JWT through `loadMembership`, the same
 * way a vote's does (O17): there is no field in the request that names an
 * accuser.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { deadlineFor } from "../_shared/phases.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, targetSeat } = await req.json();
  if (!roomId || targetSeat == null) {
    return fail("BAD_REQUEST", "roomId and targetSeat required");
  }

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead do not accuse", 403);
  if (me.phase !== "opening") return fail("PHASE_CLOSED", "not the opening round");
  if (targetSeat === me.seat) return fail("BAD_REQUEST", "not yourself");

  const { data: state, error: stateError } = await db.from("room_state")
    .select("public_data").eq("room_id", roomId).maybeSingle();
  if (stateError) throw stateError;
  const data = (state?.public_data ?? {}) as Record<string, unknown>;
  if (Number(data.openingSeat) !== me.seat) {
    return fail("PHASE_CLOSED", "it is not your turn to name somebody");
  }

  const { data: roster, error: rosterError } = await db
    .from("room_players")
    .select("seat, alive")
    .eq("room_id", roomId)
    .order("seat");
  if (rosterError) throw rosterError;
  const living = (roster ?? []).filter((p) => p.alive).map((p) => p.seat);
  if (!living.includes(targetSeat)) {
    return fail("BAD_REQUEST", "that player is not alive");
  }

  const next = living.find((seat) => seat > me.seat) ?? null;

  // The name, the hand-over of the floor (or the close of the round) and the
  // clock land in one statement, and only while the floor is still this
  // seat's. A double tap, or a retry that arrives after the floor has moved,
  // matches nothing: the first answer stands and nothing is reset.
  const { data: recorded, error } = await db.rpc("commit_accusation", {
    p_room: roomId,
    p_number: me.phaseNumber,
    p_seat: me.seat,
    p_target: targetSeat,
    p_next_seat: next,
    p_next_deadline: new Date(Date.now() + 10_000).toISOString(),
    p_discuss_deadline: deadlineFor("discuss", me.settings),
  });
  if (error) throw error;
  if (!recorded) {
    return fail("PHASE_CLOSED", "it is not your turn to name somebody");
  }

  if (next !== null) return ok({ next });
  return ok({ next: null, phase: "discuss" });
}));
