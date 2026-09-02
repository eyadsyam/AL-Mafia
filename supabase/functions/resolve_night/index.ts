/**
 * `resolve_night` — kill minus protect, then the trace (doc 10 §5).
 *
 * ## W8: the win check runs after every death is applied
 *
 * Not during resolution. A doctor save and a kill are decided together, and a
 * win check that ran between them would see a roster that never existed.
 *
 * ## What the caller gets back
 *
 * The public morning payload and nothing else. `savedSeat` is computed here
 * because `C11` needs it and the post-game autopsy is entitled to it, but it is
 * written to the archive rather than broadcast: `T2` announces that a save
 * happened and may never name who (doc 09 §1.4).
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { buildHistory } from "../_shared/history.ts";
import { selectTrace } from "../_shared/trace.ts";
import { deriveSeed, SeedSalt, tieBreakIndex } from "../_shared/seed.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "the host resolves", 403);
  if (me.phase !== "night") return fail("PHASE_CLOSED", "not the night");

  const night = me.phaseNumber;

  const { data: players } = await db
    .from("room_players")
    .select("user_id, seat, alive, role")
    .eq("room_id", roomId)
    .order("seat");
  const roster = players ?? [];
  const seatOf = new Map(roster.map((p) => [p.user_id, p.seat]));

  const { data: actions } = await db
    .from("night_actions")
    .select("actor_id, action, target_id")
    .eq("room_id", roomId)
    .eq("night", night);

  // Mafia votes, tallied. A tie is broken on the seed, with no extra pass —
  // doc 05 §5 rejects an extra passing round because it "instantly leaks the
  // Mafia count".
  const tally = new Map<string, number>();
  for (const a of actions ?? []) {
    if (a.action !== "kill" || !a.target_id) continue;
    tally.set(a.target_id, (tally.get(a.target_id) ?? 0) + 1);
  }
  let victimId: string | null = null;
  if (tally.size > 0) {
    const top = Math.max(...tally.values());
    const tied = [...tally.entries()]
      .filter(([, v]) => v === top)
      .map(([k]) => k)
      // Sorted by seat, so the set handed to the tie-break is ordered before
      // the seed is drawn.
      .sort((a, b) => (seatOf.get(a) ?? 0) - (seatOf.get(b) ?? 0));
    victimId = tied[
      tieBreakIndex(deriveSeed(me.matchSeed, SeedSalt.nightTieBreak, night), tied.length)
    ];
  }

  const protectedIds = new Set(
    (actions ?? []).filter((a) => a.action === "protect" && a.target_id)
      .map((a) => a.target_id as string),
  );

  let savedId: string | null = null;
  if (victimId && protectedIds.has(victimId)) {
    savedId = victimId;
    victimId = null;
  }

  if (victimId) {
    await db.from("room_players").update({ alive: false })
      .eq("room_id", roomId).eq("user_id", victimId);
    // When each player went out, for the result screen. Written as it happens
    // rather than reconstructed at the end: the roster only records *whether*
    // somebody is alive, and "died on night 2" is not recoverable from that.
    await db.rpc("set_public_path", {
      p_room: roomId,
      p_path: ["eliminations", String(seatOf.get(victimId) ?? -1)],
      p_value: { phase: "night", number: night },
    });
    // Doc 09 §3.4 — anything still in flight to the dead is voided.
    await db.from("whisper_meta").update({ voided: true })
      .eq("room_id", roomId).eq("to_id", victimId).eq("voided", false);
  }

  const history = await buildHistory(db, roomId);
  const record = history.nights.find((n) => n.nightNumber === night);
  const trace = record
    ? selectTrace({
      night: {
        ...record,
        victim: victimId ? seatOf.get(victimId) ?? null : null,
        saveOccurred: savedId !== null,
        savedSeat: savedId ? seatOf.get(savedId) ?? null : null,
        resolved: true,
      },
      history: history.nights.filter((n) => n.resolved && n.nightNumber < night),
      alive: history.alive.filter((s) => s !== (victimId ? seatOf.get(victimId) : -1)),
      nightNumber: night,
      matchSeed: me.matchSeed,
    })
    : null;

  // The night's record, written at its own key so the nights before it
  // survive. `buildHistory` reads every one of them on every later night, and
  // a handler that replaced `public_data` wholesale would quietly empty the
  // Information Engine's memory (`T4`, `T5`, `C6` and `C7` all read backwards).
  await db.rpc("set_public_path", {
    p_room: roomId,
    p_path: ["resolvedNights", String(night)],
    p_value: {
      victimSeat: victimId ? seatOf.get(victimId) ?? null : null,
      // Archived, not broadcast. `T2` may never name the saved player.
      savedSeat: savedId ? seatOf.get(savedId) ?? null : null,
      trace: trace?.type ?? null,
    },
  });

  // W8 — the win check runs after the death is applied and before anything
  // else happens. A night that reaches parity is a finished match, and the
  // room must not be able to open a day on it (the offline engine refuses the
  // same move in `beginDay`).
  const living = roster.filter((p) => p.alive && p.user_id !== victimId);
  const mafiaAlive = living.filter((p) => p.role === "mafia").length;
  const townAlive = living.length - mafiaAlive;
  const outcome = mafiaAlive === 0
    ? "town"
    : mafiaAlive >= townAlive
    ? "mafia"
    : null;

  const morning = {
    victimSeat: victimId ? seatOf.get(victimId) ?? null : null,
    someoneSavedUnnamed: savedId !== null,
    trace,
  };

  await db.rpc("merge_public_data", {
    p_room: roomId,
    p_patch: { morning, outcome },
  });

  // The morning is shown either way: a match decided overnight still gets its
  // "who died" screen before the result, exactly as it does offline. Ending
  // the room is `open_phase('result')`'s job, and it refuses unless this wrote
  // an outcome.
  await db.from("room_state").update({
    phase: "morning",
    phase_ends_at: null,
    active_speaker: null,
    updated_at: new Date().toISOString(),
  }).eq("room_id", roomId);

  return ok({ ...morning, outcome });
}));
