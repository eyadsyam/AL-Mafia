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
import { deriveSeed, SeedSalt, tieBreakIndex } from "../_shared/seed.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.phase !== "night") return fail("PHASE_CLOSED", "not the night");
  // The host resolves, and so does anybody else once the server's own clock has
  // run out — the same rule as the ballot's, for the same reason: a match must
  // not stop because one phone went to sleep. Read from `phase_ends_at`, never
  // from the caller, and `submit_night_action` brings that timestamp forward to
  // now the moment every living player has acted, so the ordinary case is not
  // "the timer expired" but "the room is finished".
  const expired = !!me.phaseEndsAt && new Date(me.phaseEndsAt) <= new Date();
  if (me.hostId !== userId && !expired) {
    return fail("NOT_HOST", "the host resolves", 403);
  }

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
    const isLocked = (id: string | null | undefined) => !!id && locked.has(seatOf.get(id) ?? -1);
    const isUnsilenceable = (id: string | null | undefined) =>
      !!id && noSilence.has(seatOf.get(id) ?? -1);

    const { data: actions, error: actionsError } = await db
      .from("night_actions")
      .select("actor_id, action, target_id, used_bullet")
      .eq("room_id", roomId)
      .eq("night", night);
    if (actionsError) throw actionsError;

    // The moves this outcome is computed from, as `commit_resolution` will
    // recompute them under the room lock (`night_fingerprint`). A move that
    // lands between this read and the commit changes the string, the commit
    // refuses, and the driver tallies again — nothing anybody did is left out
    // of the count, and nothing is counted twice.
    const fingerprint = [...(actions ?? [])]
      .sort((a, b) => a.actor_id < b.actor_id ? -1 : a.actor_id > b.actor_id ? 1 : 0)
      .map((a) => `${a.actor_id}|${a.action}|${a.target_id ?? "-"}|${a.used_bullet ? "1" : "0"}`)
      .join(";") + "#roster:" + rosterFingerprint(roster);

    // Mafia votes, tallied. A tie is broken on the seed, with no extra pass —
    // doc 05 §5 rejects an extra passing round because it "instantly leaks the
    // Mafia count".
    // A target that is no longer alive when the night resolves — removed by
    // the host, or gone for three minutes and struck — is not a kill: the
    // seat is already out, and `commit_resolution` refuses to eliminate a
    // dead seat, which used to leave a night nobody could resolve.
    // And a seat that is no longer alive when the night resolves has no move:
    // a ballot or a night action it cast before the host removed it is void,
    // exactly as its whispers are (doc 09 §3.4) — a player put out of the match
    // does not go on killing or protecting from outside it.
    const alive = new Set(roster.filter((p) => p.alive).map((p) => p.user_id));
    const mafiaIds = new Set(roster.filter((p) => isMafiaTeam(p.role)).map((p) => p.user_id));
    const tally = new Map<string, number>();
    for (const a of actions ?? []) {
      if (a.action !== "kill" || !a.target_id || !alive.has(a.target_id) || !alive.has(a.actor_id)) continue;
      // The Mafia never kill one of their own (owner, 2026-10-01).
      if (mafiaIds.has(a.target_id)) continue;
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

    // One protected seat, never the union of every Doctor's (owner,
    // 2026-10-01): the seat most of them chose, and on an even split one of
    // their choices drawn on the seed, which is the Mafia's rule on a stream
    // of its own. Mirrors `NightResolver.resolveNight`.
    const protectTally = new Map<string, number>();
    for (const a of actions ?? []) {
      if (a.action !== "protect" || !a.target_id || !alive.has(a.actor_id)) continue;
      protectTally.set(a.target_id, (protectTally.get(a.target_id) ?? 0) + 1);
    }
    const protectedIds = new Set<string>();
    if (protectTally.size > 0) {
      const top = Math.max(...protectTally.values());
      const tied = [...protectTally.entries()]
        .filter(([, v]) => v === top)
        .map(([k]) => k)
        .sort((a, b) => (seatOf.get(a) ?? 0) - (seatOf.get(b) ?? 0));
      protectedIds.add(tied[
        tieBreakIndex(deriveSeed(me.matchSeed, SeedSalt.doctorTieBreak, night), tied.length)
      ]);
    }

    if (isLocked(victimId)) victimId = null;

    let savedId: string | null = null;
    if (victimId && protectedIds.has(victimId)) {
      savedId = victimId;
      victimId = null;
    }

    const deaths = new Set<string>();
    if (victimId) deaths.add(victimId);
    for (const a of actions ?? []) {
      const actor = roster.find((p) => p.user_id === a.actor_id);
      const target = roster.find((p) => p.user_id === a.target_id);
      if (!a.used_bullet || a.action !== "suspect" || actor?.role !== "sniper" ||
          !target || !alive.has(actor.user_id) || !alive.has(target.user_id) ||
          isLocked(target.user_id)) continue;
      deaths.add(target.user_id);
      if (!isMafiaTeam(target.role)) deaths.add(actor.user_id);
    }
    const deathIds = [...deaths].sort(
      (a, b) => (seatOf.get(a) ?? 0) - (seatOf.get(b) ?? 0),
    );
    const silencedId = (actions ?? []).find((a) =>
      a.action === "silence" && !!a.target_id && alive.has(a.actor_id) && alive.has(a.target_id) &&
      !isLocked(a.target_id) && !isUnsilenceable(a.target_id) && !deaths.has(a.target_id)
    )?.target_id ?? null;

    const history = await buildHistory(db, roomId);
    const record = history.nights.find((n) => n.nightNumber === night);
    const trace = record
      ? selectTrace({
        night: {
          ...record,
          victim: deathIds[0] ? seatOf.get(deathIds[0]) ?? null : null,
          saveOccurred: savedId !== null,
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
    const outcome = mafiaAlive === 0
      ? "town"
      : mafiaAlive >= townAlive
      ? "mafia"
      : null;

    const morning = {
      victimSeat: deathIds[0] ? seatOf.get(deathIds[0]) ?? null : null,
      victimSeats: deathIds.map((id) => seatOf.get(id) ?? -1).filter((seat) => seat >= 0),
      silencedSeat: silencedId ? seatOf.get(silencedId) ?? null : null,
      someoneSavedUnnamed: savedId !== null,
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
