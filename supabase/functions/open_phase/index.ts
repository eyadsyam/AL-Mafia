/**
 * `open_phase` — the only way a room changes phase without resolving anything.
 *
 * ## Why one function and not five
 *
 * The resolving functions (`resolve_night`, `resolve_vote`,
 * `generate_confrontation`) each end by setting the phase, because each of them
 * *computed* which phase comes next. Everything else — the host tapping
 * «التالي» — is the same operation with a different argument, and splitting it
 * into `begin_night`, `begin_vote`, `end_confrontation` would be five copies of
 * the same four checks.
 *
 * ## What it guards
 *
 * 1. **The host, and only the host.** Every device runs the same screens; one
 *    of them drives (doc 10 §7).
 * 2. **The transition.** Never the client's claim about where the room is:
 *    `loadMembership` reads the real phase, and a transition that is not in the
 *    table below is refused. This is doc 10 §10's "validate phase on every
 *    call" — a client that thinks it is on the discussion cannot open a ballot
 *    on a room that is still in the night.
 * 3. **The payload.** Each phase clears the keys that belonged to the last one,
 *    and merges rather than replaces, so the archives `buildHistory` reads
 *    survive the whole match (see `merge_public_data`).
 *
 * ## The clock
 *
 * `phase_ends_at` is set here, from `now()` on the **server**. Doc 10 §8.2: the
 * timer is server-side, never the client's, and a client with a wrong clock
 * must never be able to act early or block a phase. A client renders the
 * countdown against this timestamp with skew correction, and when it expires
 * `advance_phase` applies the default — after re-checking the same deadline
 * against the same clock.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { clearedFor, deadlineFor, TRANSITIONS } from "../_shared/phases.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, phase, silent } = await req.json();
  if (!roomId || !phase) return fail("BAD_REQUEST", "roomId and phase required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // The one transition any member may make. The deal ends when the last card
  // is dismissed, and the person who dismissed it is whoever it is — making
  // the room wait for the host to notice would strand it on the one screen
  // where every player is looking at their own phone anyway. The gate below
  // is what actually decides, and it is the same gate for everybody.
  const communal = me.phase === "reveal" && phase === "night";
  if (!communal && me.hostId !== userId) {
    return fail("NOT_HOST", "only the host advances", 403);
  }

  const allowed = TRANSITIONS[me.phase] ?? [];
  if (!allowed.includes(phase)) {
    return fail("PHASE_CLOSED", `cannot go from ${me.phase} to ${phase}`);
  }

  // The deal's gate. Never the client's word for it: `saw_role` is written by
  // one Edge Function, per seat, and read here.
  if (communal) {
    const { data: unseen } = await db
      .from("room_players")
      .select("seat")
      .eq("room_id", roomId)
      .eq("saw_role", false);
    if ((unseen ?? []).length > 0) {
      return fail(
        "PHASE_CLOSED",
        "not everybody has seen their card",
      );
    }
  }

  // `result` is only reachable from a morning that already decided the match.
  // Anything else would be a client ending a game that is still being played.
  if (phase === "result") {
    const { data: state } = await db.from("room_state")
      .select("public_data").eq("room_id", roomId).maybeSingle();
    const archive = (state?.public_data ?? {}) as Record<string, unknown>;
    if (!archive.outcome) return fail("PHASE_CLOSED", "nobody has won yet");

    // The one moment every role becomes public (FR-019, doc 05: the secrecy
    // ends when the match does). Written here and nowhere earlier: a payload
    // that carried roles a phase too soon would be the whole game, and this is
    // the only handler that can reach `result`.
    const { data: roster } = await db
      .from("room_players")
      .select("seat, role")
      .eq("room_id", roomId)
      .order("seat");
    const eliminations = (archive.eliminations ?? {}) as Record<
      string,
      { phase: string; number: number }
    >;
    const standings = (roster ?? []).map((p) => ({
      seat: p.seat,
      role: p.role,
      eliminatedPhase: eliminations[String(p.seat)]?.phase ?? null,
      eliminatedNumber: eliminations[String(p.seat)]?.number ?? null,
    }));
    await db.rpc("merge_public_data", {
      p_room: roomId,
      p_patch: { standings },
    });

    await db.from("rooms")
      .update({ status: "finished", ended_at: new Date().toISOString() })
      .eq("id", roomId);
  }

  // The opening round points at one seat at a time, and the first one is the
  // lowest living seat — the same order the night pass uses.
  let openingSeat: number | null = null;
  if (phase === "opening") {
    const { data: living } = await db
      .from("room_players")
      .select("seat")
      .eq("room_id", roomId)
      .eq("alive", true)
      .order("seat")
      .limit(1);
    openingSeat = living?.[0]?.seat ?? null;
    if (openingSeat === null) return fail("BAD_REQUEST", "nobody is alive");
  }

  const patch: Record<string, unknown> = { ...clearedFor(phase) };
  if (openingSeat !== null) patch.openingSeat = openingSeat;
  // C-E5 — a confrontation that ended in silence says so, because the silence
  // is information the table is entitled to and `C9` reads it later.
  if (phase === "discuss" && me.phase === "confront") {
    patch.confrontationSilent = silent === true;
  }

  await db.rpc("merge_public_data", { p_room: roomId, p_patch: patch });

  const endsAt = deadlineFor(phase, me.settings);

  const { error } = await db.from("room_state").update({
    phase,
    phase_ends_at: endsAt,
    // Nobody's microphone is live across a phase change until the next phase
    // grants one (doc 10 §6.3). Leaving a stale speaker set is how a mic stays
    // open into the night.
    active_speaker: null,
    updated_at: new Date().toISOString(),
  }).eq("room_id", roomId);
  if (error) throw error;

  return ok({ phase, phaseEndsAt: endsAt });
}));
