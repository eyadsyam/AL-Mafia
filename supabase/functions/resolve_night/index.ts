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
import { deadlineFor } from "../_shared/phases.ts";
import { buildHistory } from "../_shared/history.ts";
import { rosterFingerprint } from "../_shared/roster_fingerprint.ts";
import { selectTrace } from "../_shared/trace.ts";
import { isMafiaTeam } from "../_shared/teams.ts";
import { halfDoorSeats, loadToolUses, lockedSeats, unsilenceable } from "../_shared/tools.ts";
import { resolveNightCore } from "../_shared/night_core.ts";
import { nightComplete } from "../_shared/phase_guards.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  // An archived room (everybody silent for five minutes) keeps its last phase
  // row, but the commit refuses it: answer once instead of retrying.
  if (me.status !== "playing") return fail("PHASE_CLOSED", "no match is running");
  if (me.phase !== "night") return fail("PHASE_CLOSED", "not the night");
  // Any member may request resolution, but nobody may end another player's
  // turn. The server clock or a complete set of owed actions is the gate.
  const expired = !!me.phaseEndsAt && new Date(me.phaseEndsAt) <= new Date();

  const night = me.phaseNumber;

  // Bounded, because a room where a move lands between every tally and its
  // commit is a room that will settle within a couple of rounds; and bounded
  // rather than unbounded because a driver must not sit on a request forever.
  for (let attempt = 0; attempt < 3; attempt++) {
    const { data: players, error: playersError } = await db
      .from("room_players")
      .select("user_id, seat, alive, role")
      .eq("room_id", roomId)
      .order("seat");
    if (playersError) throw playersError;
    const roster = players ?? [];
    const seatOf = new Map(roster.map((p) => [p.user_id, p.seat]));
    // «أدوات القعدة»: a locked door is out of reach of the kill, the shot and
    // the silence; a half door only of the silence.
    const toolUses = await loadToolUses(db, roomId);
    const locked = lockedSeats(toolUses, night);
    const noSilence = new Set([...halfDoorSeats(toolUses, night), ...unsilenceable(toolUses, night)]);

    const { data: actions, error: actionsError } = await db
      .from("night_actions")
      .select("actor_id, action, target_id, used_bullet")
      .eq("room_id", roomId)
      .eq("night", night);
    if (actionsError) throw actionsError;
    // The host has no right to close another player's unfinished turn.
    // Citizens and Elders have no online night action, as in submit_night_action.
    if (!expired) {
      if (!nightComplete(roster, actions ?? [])) {
        return fail("PHASE_CLOSED", "the night is still running");
      }
    }

    const { data: state, error: stateError } = await db.from("room_state")
      .select("public_data").eq("room_id", roomId).maybeSingle();
    if (stateError) throw stateError;
    const heldOutcome = (state?.public_data as Record<string, unknown> | null)?.outcome;
    const decidedOutcome = heldOutcome === "mafia" || heldOutcome === "town"
      ? heldOutcome : null;

    // The moves this outcome is computed from, as `commit_resolution` will
    // recompute them under the room lock (`night_fingerprint`). A move that
    // lands between this read and the commit changes the string, the commit
    // refuses, and the driver tallies again — nothing anybody did is left out
    // of the count, and nothing is counted twice.
    const fingerprint = [...(actions ?? [])]
      .sort((a, b) => a.actor_id < b.actor_id ? -1 : a.actor_id > b.actor_id ? 1 : 0)
      .map((a) => `${a.actor_id}|${a.action}|${a.target_id ?? "-"}|${a.used_bullet ? "1" : "0"}`)
      .join(";") + "#roster:" + rosterFingerprint(roster);

    const { deathIds, savedId, saveTold, silencedId } = decidedOutcome
      ? { deathIds: [] as string[], savedId: null, saveTold: false, silencedId: null }
      : resolveNightCore({
      roster, actions: actions ?? [], matchSeed: me.matchSeed, night, settings: me.settings,
      lockedSeatSet: locked, noSilenceSeatSet: noSilence,
    });
    const deaths = new Set(deathIds);

    const history = await buildHistory(db, roomId);
    const record = history.nights.find((n) => n.nightNumber === night);
    const trace = !decidedOutcome && record
      ? selectTrace({
        night: {
          ...record,
          victim: deathIds[0] ? seatOf.get(deathIds[0]) ?? null : null,
          saveOccurred: saveTold,
          savedSeat: savedId ? seatOf.get(savedId) ?? null : null,
          resolved: true,
        },
        history: history.nights.filter((n) => n.resolved && n.nightNumber < night),
        alive: history.alive.filter((s) =>
          !deathIds.some((id) => seatOf.get(id) === s)
        ),
        nightNumber: night,
        matchSeed: me.matchSeed,
      })
      : null;

    // W8 — the win check runs after the death is applied and before anything
    // else happens. A night that reaches parity is a finished match, and the
    // room must not be able to open a day on it (the offline engine refuses the
    // same move in `beginDay`).
    const living = roster.filter((p) => p.alive && !deaths.has(p.user_id));
    const mafiaAlive = living.filter((p) => isMafiaTeam(p.role)).length;
    const townAlive = living.length - mafiaAlive;
    const outcome = decidedOutcome ?? (mafiaAlive === 0
      ? "town"
      : mafiaAlive >= townAlive
      ? "mafia"
      : null);

    const morning = {
      victimSeat: deathIds[0] ? seatOf.get(deathIds[0]) ?? null : null,
      victimSeats: deathIds.map((id) => seatOf.get(id) ?? -1).filter((seat) => seat >= 0),
      silencedSeat: silencedId ? seatOf.get(silencedId) ?? null : null,
      someoneSavedUnnamed: saveTold,
      trace,
    };

    const { data: committed, error } = await db.rpc("commit_night_roles_resolution", {
      p_room: roomId, p_number: night,
      p_victims: deathIds, p_saved_seat: savedId ? seatOf.get(savedId) ?? null : null,
      p_archive: { victimSeat: morning.victimSeat, trace: trace?.type ?? null },
      p_patch: { morning, outcome }, p_next: "morning",
      p_deadline: deadlineFor("morning", me.settings),
      p_fingerprint: fingerprint,
    });
    if (error) throw error;
    if (committed) return ok({ ...morning, outcome });
    // Refused: either the room already left the night, or a move landed
    // after the tally above (the fingerprint no longer matches). Look again;
    // if the night is still open, count again with the move included.
    const again = await loadMembership(db, roomId, userId);
    if (!again || again.phase !== "night" || again.phaseNumber !== night) {
      return fail("PHASE_CLOSED", "night already resolved");
    }
  }
  return fail("PHASE_CLOSED", "the night is still being resolved");
}));
