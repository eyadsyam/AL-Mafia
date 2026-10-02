/**
 * `ready_to_vote` — «جاهزين للتصويت». A living player says the discussion is
 * done for them (or takes it back); once every living player has, the ballot
 * opens for everybody (owner, 2026-09-24: nobody drives the match, the host
 * included, so a finished discussion needed a way to end that belongs to the
 * table).
 *
 * The readiness itself is recorded by `mark_ready_to_vote`, under the
 * room_state row lock — two players tapping at once cannot erase each other.
 * The ballot is then opened through the same compare-and-set every other
 * transition uses (`commit_phase_open`), so a clock expiring in the same
 * instant and this call cannot both move the room.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { clearedFor, deadlineFor } from "../_shared/phases.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, ready } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "only the living end the talk", 403);
  if (me.phase !== "discuss") {
    return fail("PHASE_CLOSED", "there is no discussion to end");
  }

  const { data: tally, error } = await db.rpc("mark_ready_to_vote", {
    p_room: roomId,
    p_user: userId,
    p_ready: ready !== false,
  });
  if (error) {
    const code = String(error.message ?? "");
    if (code.includes("PHASE_CLOSED")) {
      return fail("PHASE_CLOSED", "the discussion has already ended");
    }
    if (code.includes("NOT_ALIVE")) {
      return fail("NOT_ALIVE", "only the living end the talk", 403);
    }
    if (code.includes("NOT_A_MEMBER")) {
      return fail("NOT_A_MEMBER", "you are not in that room", 403);
    }
    throw error;
  }

  const result = tally as {
    seats: number[];
    living: number;
    everyone: boolean;
    number: number;
    deadline: string | null;
  };

  let opened = false;
  if (result.everyone) {
    const endsAt = deadlineFor("vote", me.settings);
    const { data: moved, error: moveError } = await db.rpc(
      "commit_phase_open",
      {
        p_room: roomId,
        p_expected: "discuss",
        p_number: result.number,
        p_expected_deadline: result.deadline,
        p_next: "vote",
        p_next_number: result.number,
        p_deadline: endsAt,
        p_patch: clearedFor("vote"),
        p_require_all_seen: false,
      },
    );
    if (moveError) throw moveError;
    // False only when the clock or another last tap got there first — the
    // ballot is open either way.
    opened = moved === true;
  }

  return ok({
    readySeats: result.seats,
    living: result.living,
    ballotOpened: opened,
  });
}));
