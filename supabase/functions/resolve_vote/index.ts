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
import { voteFingerprint } from "../_shared/vote_fingerprint.ts";
import { resolveBallotCore } from "../_shared/ballot_core.ts";
import { isMafiaTeam } from "../_shared/teams.ts";
import {
  lastWordOf,
  loadToolUses,
} from "../_shared/tools.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  // See resolve_night: an archived room's commit is refused anyway.
  if (me.status !== "playing") return fail("PHASE_CLOSED", "no match is running");
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
  const refundUnusedRevote = async () => {
    try {
      const { error } = await db.rpc("refund_unused_table_tool", {
        p_room: roomId, p_tool: "revote", p_phase_number: day,
      });
      if (error) throw error;
    } catch (error) {
      console.error("revote refund failed after resolution commit", error);
    }
  };

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

    // The round is the room's (`revote.round`), never inferred from the ballots
    // cast: a revote nobody has voted in yet is still round two, and resolving
    // it as round one would count the ballot that tied a second time.
    const { data: state, error: stateError } = await db.from("room_state")
      .select("public_data").eq("room_id", roomId).maybeSingle();
    if (stateError) throw stateError;
    const revoteState = (state?.public_data as Record<string, unknown> | null)
      ?.revote as Record<string, unknown> | null | undefined;
    const decidedOutcome = (state?.public_data as Record<string, unknown> | null)?.outcome;
    const revealedElderSeats = ((state?.public_data as Record<string, unknown> | null)
      ?.elderRevealedSeats as number[] | undefined) ?? [];
    const round = Number(revoteState?.round ?? 1);
    // «أدوات القعدة»: one read per request.
    const toolUses = await loadToolUses(db, roomId);

    const { data: cast, error: castError } = await db
      .from("votes")
      .select("voter_id, target_id, round")
      .eq("room_id", roomId)
      .eq("day", day)
      .eq("round", round);
    if (castError) throw castError;

    // See `resolve_night`: the ballots this outcome counts, for the commit to
    // check against the ballots the room holds when it locks the row.
    const fingerprint = voteFingerprint(cast ?? [], roster, toolUses, day);
    const { eliminatedId, eliminatedSeat, eliminatedRole, tiedSeats, revote,
      publicTally, boughtRevoteWorked, outcome, revoteBought } = resolveBallotCore({
      roster, cast: cast ?? [], round,
      revoteState: revoteState as { round?: number; tiedSeats?: unknown } | null,
      toolUses, day, revealedElderSeats, decidedOutcome, settings: me.settings,
    });

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
      if (committed) {
        if (revoteBought && !boughtRevoteWorked) await refundUnusedRevote();
        return ok({ tie: true, tiedSeats, round: round + 1 });
      }
      if (!(await stillOpen(round))) return fail("PHASE_CLOSED", "ballot already resolved");
      continue;
    }

    // RL15 — the eliminated player's last word, if he bought one: the table is
    // told (`lastVote.lastWord`) even when this ballot ends the match. A floor
    // grant exists only if another day can follow.
    const lastWord = lastWordOf(toolUses, day, eliminatedSeat);

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
          ...(lastWord ? { lastWord } : {}),
        },
        ...(lastWord && !outcome ? { lastWordFloor: { ...lastWord, day } } : {}),
        // The confrontation's public archive of day eliminations (C12, C14):
        // who went out and whether the card shown was the Mafia's.
        ...(eliminatedSeat !== null
          ? {
            dayResults: {
              ...(((state?.public_data as Record<string, unknown> | null)
                ?.dayResults as Record<string, unknown> | undefined) ?? {}),
              [String(day)]: {
                seat: eliminatedSeat,
                mafia: isMafiaTeam(eliminatedRole),
              },
            },
          }
          : {}),
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
      if (revoteBought && !boughtRevoteWorked) await refundUnusedRevote();
      return ok({
        eliminatedSeat,
        eliminatedRole,
        tally: publicTally,
        outcome,
        ...(lastWord ? { lastWord } : {}),
      });
    }
    if (!(await stillOpen(round))) return fail("PHASE_CLOSED", "ballot already resolved");
  }
  return fail("PHASE_CLOSED", "the ballot is still being resolved");
}));
