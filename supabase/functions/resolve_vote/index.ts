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

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "the host resolves", 403);
  if (me.phase !== "vote") return fail("PHASE_CLOSED", "not the ballot");

  const day = me.phaseNumber;
  const { data: players } = await db
    .from("room_players")
    .select("user_id, seat, alive, role")
    .eq("room_id", roomId)
    .order("seat");
  const roster = players ?? [];
  const seatOf = new Map(roster.map((p) => [p.user_id, p.seat]));

  const { data: cast } = await db
    .from("votes")
    .select("voter_id, target_id, round")
    .eq("room_id", roomId)
    .eq("day", day);

  const round = Math.max(1, ...(cast ?? []).map((v) => v.round));
  const tally = new Map<string, number>();
  for (const v of cast ?? []) {
    if (v.round !== round || !v.target_id) continue;
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
    await db.rpc("merge_public_data", {
      p_room: roomId,
      p_patch: {
        lastVote: { tally: publicTally, tiedSeats, eliminatedSeat: null },
        revote: { round: round + 1, tiedSeats },
      },
    });
    await db.from("room_state").update({
      phase: "vote",
      phase_ends_at: deadlineFor("vote", me.settings),
      updated_at: new Date().toISOString(),
    }).eq("room_id", roomId);
    return ok({ tie: true, tiedSeats, round: round + 1 });
  }

  let eliminatedSeat: number | null = null;
  let eliminatedRole: string | null = null;
  if (eliminatedId) {
    eliminatedSeat = seatOf.get(eliminatedId) ?? null;
    // D11 — the reveal is never skipped. A day elimination is public by design
    // (FR-019); this is the one place a role legitimately reaches the table.
    eliminatedRole =
      roster.find((p) => p.user_id === eliminatedId)?.role ?? null;
    await db.from("room_players").update({ alive: false })
      .eq("room_id", roomId).eq("user_id", eliminatedId);
    await db.rpc("set_public_path", {
      p_room: roomId,
      p_path: ["eliminations", String(eliminatedSeat)],
      p_value: { phase: "day", number: day },
    });
    await db.from("whisper_meta").update({ voided: true })
      .eq("room_id", roomId).eq("to_id", eliminatedId).eq("voided", false);
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

  if (outcome) {
    await db.from("rooms").update({
      status: "finished",
      ended_at: new Date().toISOString(),
    }).eq("id", roomId);
  }

  await db.rpc("merge_public_data", {
    p_room: roomId,
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

  await db.from("room_state").update({
    phase: outcome ? "result" : "night",
    phase_number: outcome ? day : day + 1,
    phase_ends_at: outcome ? null : deadlineFor("night", me.settings),
    active_speaker: null,
    updated_at: new Date().toISOString(),
  }).eq("room_id", roomId);

  return ok({ eliminatedSeat, eliminatedRole, tally: publicTally, outcome });
}));
