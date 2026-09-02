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

  const { data: state } = await db.from("room_state")
    .select("public_data").eq("room_id", roomId).maybeSingle();
  const data = (state?.public_data ?? {}) as Record<string, unknown>;
  if (Number(data.openingSeat) !== me.seat) {
    return fail("PHASE_CLOSED", "it is not your turn to name somebody");
  }

  const { data: roster } = await db
    .from("room_players")
    .select("seat, alive")
    .eq("room_id", roomId)
    .order("seat");
  const living = (roster ?? []).filter((p) => p.alive).map((p) => p.seat);
  if (!living.includes(targetSeat)) {
    return fail("BAD_REQUEST", "that player is not alive");
  }

  await db.rpc("set_public_path", {
    p_room: roomId,
    p_path: ["openingAccusations", String(me.seat)],
    p_value: targetSeat,
  });

  // Pass the round on, or close it. Day 1 has no confrontation — the
  // generators need a day of history before they have anything true to say —
  // so the round runs straight into the discussion (mirrors
  // `MatchEngine._openConfrontationOrDiscussion`, which takes the same branch
  // on `dayNumber > 1`).
  const next = living.find((seat) => seat > me.seat) ?? null;

  if (next !== null) {
    await db.rpc("merge_public_data", {
      p_room: roomId,
      p_patch: { openingSeat: next },
    });
    await db.from("room_state").update({
      phase_ends_at: new Date(Date.now() + 10_000).toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("room_id", roomId);
    return ok({ next });
  }

  await db.rpc("merge_public_data", {
    p_room: roomId,
    p_patch: { openingSeat: null },
  });
  await db.from("room_state").update({
    phase: "discuss",
    phase_ends_at: deadlineFor("discuss", me.settings),
    updated_at: new Date().toISOString(),
  }).eq("room_id", roomId);

  return ok({ next: null, phase: "discuss" });
}));
