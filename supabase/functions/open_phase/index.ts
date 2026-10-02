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

  // Three cases where the transition is not the host's private property.
  //
  //  * the deal → the night, by anyone, once every seat has dismissed its card
  //  * a confrontation → the discussion, by the player being confronted
  //  * any phase at all, by anyone, once the server's own clock has run out
  //
  // The second used to be host-only, which meant «خلصت» did nothing unless the
  // accused happened to be holding the room, and the table waited out the whole
  // forty-five seconds instead. The window belongs to the person in it.
  //
  // The third is doc 10 §8.2 taken seriously: *no phase may stall*. A rule that
  // lets only the host end a phase makes that promise conditional on one
  // particular phone staying awake, and a host whose screen has locked is
  // indistinguishable, from every other seat, from a match that has broken.
  // Nothing is loosened by it: the deadline is the server's, it is read here
  // from `phase_ends_at`, and the transition table below still governs where
  // the room may go. A client with a fast clock can ask early and be refused.
  const dealDone = me.phase === "reveal" && phase === "night";
  const ownConfrontation = me.phase === "confront" &&
    phase === "discuss" &&
    (await confrontationTarget(db, roomId)) === me.seat;
  const expired = !!me.phaseEndsAt && new Date(me.phaseEndsAt) <= new Date();
  const communal = dealDone || ownConfrontation || expired;
  if (!communal && me.hostId !== userId) {
    return fail("NOT_HOST", "only the host advances", 403);
  }

  const allowed = TRANSITIONS[me.phase] ?? [];
  if (!allowed.includes(phase)) {
    return fail("PHASE_CLOSED", `cannot go from ${me.phase} to ${phase}`);
  }

  // The deal's gate. Never the client's word for it: `saw_role` is written by
  // one Edge Function, per seat, and read here.
  //
  // `!expired` is the escape doc 10 s8.2 requires. While the deal's own clock
  // is running the gate is absolute — no client may skip another player's
  // card. Once it has run out, the room is no longer waiting on a decision;
  // it is stuck behind one, and the night opens. Nothing is written about the
  // seats that never answered: `saw_role` stays false, which is the honest
  // record of what happened, and the night names their role to them anyway.
  //
  // Checked twice: here, so the caller gets a message that says what is
  // missing; and again inside `commit_phase_open`, under the lock that opens
  // the night, so that the answer cannot change between the check and the
  // move. A read that fails is a refusal, never a pass — an empty answer from
  // a query that errored used to look exactly like "everybody has seen it".
  const requireAllSeen = dealDone && !expired;
  if (requireAllSeen) {
    const { data: unseen, error: unseenError } = await db
      .from("room_players")
      .select("seat")
      .eq("room_id", roomId)
      .eq("kicked", false)
      .eq("saw_role", false);
    if (unseenError) throw unseenError;
    if ((unseen ?? []).length > 0) {
      return fail(
        "PHASE_CLOSED",
        "not everybody has seen their card",
      );
    }
  }

  // `result` is only reachable from a morning that already decided the match.
  // Anything else would be a client ending a game that is still being played.
  let finalStandings: Record<string, unknown>[] | null = null;
  if (phase === "result") {
    const { data: state, error: stateError } = await db.from("room_state")
      .select("public_data").eq("room_id", roomId).maybeSingle();
    if (stateError) throw stateError;
    const archive = (state?.public_data ?? {}) as Record<string, unknown>;
    if (!archive.outcome) return fail("PHASE_CLOSED", "nobody has won yet");

    // The one moment every role becomes public (FR-019, doc 05: the secrecy
    // ends when the match does). Written here and nowhere earlier: a payload
    // that carried roles a phase too soon would be the whole game, and this is
    // the only handler that can reach `result`.
    const { data: roster, error: rosterError } = await db
      .from("room_players")
      .select("seat, role")
      .eq("room_id", roomId)
      .not("role", "is", null)
      .order("seat");
    if (rosterError) throw rosterError;
    const eliminations = (archive.eliminations ?? {}) as Record<
      string,
      { phase: string; number: number }
    >;
    finalStandings = (roster ?? []).map((p) => ({
      seat: p.seat,
      role: p.role,
      eliminatedPhase: eliminations[String(p.seat)]?.phase ?? null,
      eliminatedNumber: eliminations[String(p.seat)]?.number ?? null,
    }));
  }

  // The opening round points at one seat at a time, and the first one is the
  // lowest living seat — the same order the night pass uses.
  let openingSeat: number | null = null;
  if (phase === "opening") {
    const { data: living, error: livingError } = await db
      .from("room_players")
      .select("seat")
      .eq("room_id", roomId)
      .eq("alive", true)
      .order("seat")
      .limit(1);
    if (livingError) throw livingError;
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

  if (finalStandings !== null) patch.standings = finalStandings;

  const endsAt = deadlineFor(phase, me.settings);

  // The day number moves here, and only here: a new night *is* the new day.
  // `resolve_vote` used to move it, which put the room on day N+1 before it had
  // shown anybody the verdict of day N.
  const opensNewDay = phase === "night" && me.phase === "verdict";

  // Compare-and-set on the phase this caller actually read. Now that an expired
  // phase may be advanced by any of five clients at once, two of them can ask
  // for the same transition in the same instant; the first one moves the room
  // and the second matches no row. Both asked for the same thing, so there is
  // nothing to reconcile — but without the guard the second would re-open a
  // phase the room had already left, and reset its clock while doing it.
  const { data: moved, error } = await db.rpc("commit_phase_open", {
    p_room: roomId, p_expected: me.phase, p_number: me.phaseNumber,
    p_expected_deadline: me.phaseEndsAt,
    p_next: phase, p_next_number: me.phaseNumber + (opensNewDay ? 1 : 0),
    p_deadline: endsAt, p_patch: patch, p_require_all_seen: requireAllSeen,
  });
  if (error) throw error;
  if (!moved) {
    // Somebody else got there first. Not an error, and not a lie either: the
    // client resyncs on `PHASE_CLOSED` and finds the room already where it was
    // trying to send it.
    return fail("PHASE_CLOSED", "the room has already moved on");
  }

  return ok({ phase, phaseEndsAt: endsAt });
}));

/**
 * The seat currently being confronted, as the *server* holds it.
 *
 * Read from `public_data`, never from the request: the caller says which phase
 * they want opened and nothing about who they are, and "am I the one being
 * confronted" has to be answered from the room's own record or it is not an
 * answer at all. Null when there is no confrontation running, which makes a
 * caller who is not the host simply the host-check they always were.
 */
async function confrontationTarget(
  // deno-lint-ignore no-explicit-any
  db: any,
  roomId: string,
): Promise<number | null> {
  const { data, error } = await db.from("room_state")
    .select("public_data").eq("room_id", roomId).maybeSingle();
  if (error) throw error;
  const confrontation =
    (data?.public_data as Record<string, unknown> | null)?.confrontation;
  if (!confrontation || typeof confrontation !== "object") return null;
  const seat = (confrontation as Record<string, unknown>).targetSeat;
  return typeof seat === "number" ? seat : null;
}
