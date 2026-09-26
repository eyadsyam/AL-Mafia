/**
 * `resolve_vote` — tally, ties, elimination, win check (doc 10 §5).
 *
 * D3's bound is the important part: **at most one revote**. A revote narrows
 * the ballot to exactly the seats that tied, so a table that split once tends
 * to split again, and an unbounded loop is a real hang for a real table. The
 * second tie stands and nobody is eliminated.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { deadlineFor } from "../_shared/phases.ts";
import { rosterFingerprint } from "../_shared/roster_fingerprint.ts";
import { ballotTargetAllowed } from "../_shared/ballot_candidates.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.phase !== "vote") return fail("PHASE_CLOSED", "not the ballot");
  // The host resolves, and so does anybody else once the server's own clock has
  // run out. Doc 10 §8.2 — no phase may stall — is not a promise the room can
  // keep while the only device allowed to end a phase is one particular phone
  // that may be face-down on a table. The deadline is still the server's and it
  // is still read here, so a client with a fast clock can ask early and be
  // refused; it cannot end a ballot people are still voting in.
  const expired = !!me.phaseEndsAt && new Date(me.phaseEndsAt) <= new Date();
  if (me.hostId !== userId && !expired) {
    return fail("NOT_HOST", "the host resolves", 403);
  }

  const day = me.phaseNumber;

  // A refused commit is one of two things: the ballot already closed (or a
  // revote opened a new round, which is the same thing for this caller), or a
  // ballot landed after the tally and the fingerprint no longer matches. This
  // tells them apart so the second case is counted again, not abandoned — and
  // only the second: a driver that tallied round one never gets to close
  // round two by "retrying".
  const stillOpen = async (round: number) => {
    const { data: again, error } = await db.from("room_state")
      .select("phase, phase_number, public_data").eq("room_id", roomId).maybeSingle();
    if (error) throw error;
    const revoteNow = (again?.public_data as Record<string, unknown> | null)
      ?.revote as Record<string, unknown> | null | undefined;
    return !!again && again.phase === "vote" && again.phase_number === day &&
      Number(revoteNow?.round ?? 1) === round;
  };

  // Bounded: a driver must not sit on a request forever, and a table where a
  // ballot lands between every tally and its commit settles within a round or two.
  for (let attempt = 0; attempt < 3; attempt++) {
    const { data: players, error: playersError } = await db
      .from("room_players")
      .select("user_id, seat, alive, role")
      .eq("room_id", roomId)
      .order("seat");
    if (playersError) throw playersError;
    const roster = players ?? [];
    const seatOf = new Map(roster.map((p) => [p.user_id, p.seat]));

    // The round is the room's (`revote.round`), never inferred from the ballots
    // cast: a revote nobody has voted in yet is still round two, and resolving
    // it as round one would count the ballot that tied a second time.
    const { data: state, error: stateError } = await db.from("room_state")
      .select("public_data").eq("room_id", roomId).maybeSingle();
    if (stateError) throw stateError;
    const revoteState = (state?.public_data as Record<string, unknown> | null)
      ?.revote as Record<string, unknown> | null | undefined;
    const round = Number(revoteState?.round ?? 1);

    const { data: cast, error: castError } = await db
      .from("votes")
      .select("voter_id, target_id, round")
      .eq("room_id", roomId)
      .eq("day", day)
      .eq("round", round);
    if (castError) throw castError;

    // See `resolve_night`: the ballots this outcome counts, for the commit to
    // check against the ballots the room holds when it locks the row.
    const fingerprint = [...(cast ?? [])]
      .sort((a, b) => a.voter_id < b.voter_id ? -1 : a.voter_id > b.voter_id ? 1 : 0)
      .map((v) => `${v.voter_id}|${v.target_id ?? "-"}`)
      .join(";") + "#roster:" + rosterFingerprint(roster);
    // A ballot counts only between two living seats: a voter the host removed
    // after casting it is out of the match, and a seat put out does not go on
    // deciding the town's verdict from outside it (see `resolve_night`).
    const alive = new Set(roster.filter((p) => p.alive).map((p) => p.user_id));
    const tally = new Map<string, number>();
    for (const v of cast ?? []) {
      if (v.round !== round || !v.target_id || !alive.has(v.target_id) || !alive.has(v.voter_id)) continue;
      if (!ballotTargetAllowed(round, revoteState?.tiedSeats, seatOf.get(v.target_id))) continue;
      tally.set(v.target_id, (tally.get(v.target_id) ?? 0) + 1);
    }

    const publicTally: Record<number, number> = {};
    for (const [id, n] of tally) publicTally[seatOf.get(id) ?? -1] = n;

    let eliminatedId: string | null = null;
    let tiedSeats: number[] = [];
    let revote = false;

    if (tally.size > 0) {
      const top = Math.max(...tally.values());
      const tied = [...tally.entries()].filter(([, v]) => v === top).map(([k]) => k)
        .filter((id) => roster.find((p) => p.user_id === id)?.alive);
      if (tied.length === 1) {
        eliminatedId = tied[0];
      } else if (tied.length > 1) {
        tiedSeats = tied.map((id) => seatOf.get(id) ?? -1).sort((a, b) => a - b);
        const rule = me.settings.dayTieRule ?? "noElimination";
        // Round 1 is the opening ballot; anything above it has already had its
        // second chance.
        revote = rule === "revote" && round === 1;
      }
    }

    if (revote) {
      // A revote narrows the ballot to exactly the tied seats and opens another
      // round. Merged, never replaced: the day's archives outlive the ballot.
      const { data: committed, error } = await db.rpc("commit_resolution", {
        p_room: roomId, p_phase: "vote", p_number: day, p_round: round,
        p_victim: null, p_saved_seat: null, p_archive: {},
        p_patch: {
          lastVote: { tally: publicTally, tiedSeats, eliminatedSeat: null },
          revote: { round: round + 1, tiedSeats },
        },
        p_next: "vote", p_deadline: deadlineFor("vote", me.settings),
        p_fingerprint: fingerprint,
      });
      if (error) throw error;
      if (committed) return ok({ tie: true, tiedSeats, round: round + 1 });
      if (!(await stillOpen(round))) return fail("PHASE_CLOSED", "ballot already resolved");
      continue;
    }

    let eliminatedSeat: number | null = null;
    let eliminatedRole: string | null = null;
    if (eliminatedId) {
      eliminatedSeat = seatOf.get(eliminatedId) ?? null;
      // D11 — the reveal is never skipped. A day elimination is public by design
      // (FR-019); this is the one place a role legitimately reaches the table.
      eliminatedRole =
        roster.find((p) => p.user_id === eliminatedId)?.role ?? null;
    }

    // W8 — the check runs after every death is applied, never mid-resolution.
    const living = roster.filter(
      (p) => p.alive && p.user_id !== eliminatedId,
    );
    const mafia = living.filter((p) => p.role === "mafia").length;
    const town = living.length - mafia;
    let outcome: string | null = null;
    if (mafia === 0) outcome = "town";
    else if (mafia >= town) outcome = "mafia";

    const { data: committed, error } = await db.rpc("commit_resolution", {
      p_room: roomId, p_phase: "vote", p_number: day, p_round: round,
      p_victim: eliminatedId, p_saved_seat: null, p_archive: {},
      p_next: "verdict", p_deadline: deadlineFor("verdict", me.settings),
      p_fingerprint: fingerprint,
      p_patch: {
        lastVote: {
          tally: publicTally,
          eliminatedSeat,
          // D11 — a day elimination is public by design (FR-019). This is the
          // one place in the schema where a role legitimately reaches the table,
          // and it is why the reveal is never skipped.
          eliminatedRole,
          tiedSeats,
        },
        outcome,
        // The next night starts clean; the archives are not in this list and so
        // survive (see `clearedFor`).
        ...(outcome
          ? {}
          : {
            morning: null,
            confrontation: null,
            confrontationSilent: null,
            revote: null,
          }),
      },
    });

    if (error) throw error;
    if (committed) {
      return ok({ eliminatedSeat, eliminatedRole, tally: publicTally, outcome });
    }
    if (!(await stillOpen(round))) return fail("PHASE_CLOSED", "ballot already resolved");
  }
  return fail("PHASE_CLOSED", "the ballot is still being resolved");
}));
