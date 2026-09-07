/**
 * `advance_phase` — the expiry defaults (doc 10 §8.2).
 *
 * *"When [the timer] expires the server applies a deterministic default so the
 * match can **never** stall."* One default per phase, and every one of them is
 * a real recorded choice rather than a skipped turn:
 *
 * | Phase                | Default                                        |
 * |----------------------|------------------------------------------------|
 * | Night — Mafia        | a random living non-Mafia, seeded from the seed |
 * | Night — Doctor       | no protection                                   |
 * | Night — Detective    | no investigation                               |
 * | Night — Citizen      | recorded as skipped (feeds `T6` / `C10`)       |
 * | Confrontation        | silence — and silence is itself information     |
 * | Vote                 | abstain                                        |
 * | Whisper              | not sent                                       |
 *
 * Anyone in the room may call it, and that is deliberate: if only the host
 * could, a host who dropped at the same instant the timer expired would strand
 * the room. The deadline is server-side, so a client with a fast clock calling
 * early is simply refused.
 */
import { actionForRole, fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { deadlineFor } from "../_shared/phases.ts";
import { deriveSeed, SeedSalt, tieBreakIndex } from "../_shared/seed.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // O8 — the client's clock is never trusted. If the deadline has not passed on
  // the *server*, nothing happens, however sure the caller is.
  if (me.phaseEndsAt && new Date(me.phaseEndsAt) > new Date()) {
    return fail("PHASE_CLOSED", "the phase has not expired yet");
  }

  const { data: players } = await db
    .from("room_players")
    .select("user_id, seat, alive, role")
    .eq("room_id", roomId)
    .order("seat");
  const roster = (players ?? []).filter((p) => p.alive);

  if (me.phase === "night") {
    const { data: acted } = await db
      .from("night_actions")
      .select("actor_id")
      .eq("room_id", roomId)
      .eq("night", me.phaseNumber);
    const done = new Set((acted ?? []).map((a) => a.actor_id));

    for (const player of roster) {
      if (done.has(player.user_id)) continue;
      const action = actionForRole(player.role);
      if (action === "kill" || action === "protect") {
        // The one default that picks a target: a Mafia who does nothing would
        // otherwise make "the Mafia are all disconnected" strictly better for
        // them than playing (N9).
        const targets = roster
          .filter((p) => action === "kill" ? p.role !== "mafia" : p.user_id !== player.user_id)
          .sort((a, b) => a.seat - b.seat);
        if (targets.length === 0) continue;
        const pick = targets[
          tieBreakIndex(
            deriveSeed(me.matchSeed, SeedSalt.timerDefault, me.phaseNumber * 100 + player.seat),
            targets.length,
          )
        ];
        await db.from("night_actions").upsert({
          room_id: roomId,
          night: me.phaseNumber,
          actor_id: player.user_id,
          action,
          target_id: pick.user_id,
        });
      } else {
        await db.from("night_actions").upsert({
          room_id: roomId,
          night: me.phaseNumber,
          actor_id: player.user_id,
          action: "skip",
          target_id: null,
        });
      }
    }
    return ok({ applied: "night-defaults" });
  }

  if (me.phase === "vote") {
    const { data: cast } = await db
      .from("votes")
      .select("voter_id, round")
      .eq("room_id", roomId)
      .eq("day", me.phaseNumber);
    const round = Math.max(1, ...(cast ?? []).map((v) => v.round));
    const voted = new Set(
      (cast ?? []).filter((v) => v.round === round).map((v) => v.voter_id),
    );
    for (const player of roster) {
      if (voted.has(player.user_id)) continue;
      await db.from("votes").upsert({
        room_id: roomId,
        day: me.phaseNumber,
        voter_id: player.user_id,
        target_id: null,
        round,
      });
    }
    return ok({ applied: "abstentions" });
  }

  if (me.phase === "confront") {
    // C-E5 — the window closes and the day proceeds. The silence is recorded
    // because it is information, not because something failed.
    await db.rpc("merge_public_data", {
      p_room: roomId,
      p_patch: { confrontationSilent: true },
    });
    await db.from("room_state").update({
      phase: "discuss",
      phase_ends_at: deadlineFor("discuss", me.settings),
      active_speaker: null,
      updated_at: new Date().toISOString(),
    }).eq("room_id", roomId);
    return ok({ applied: "silence" });
  }

  if (me.phase === "opening") {
    // Doc 10 §8.2 has no row for the «اسم واحد» round, because doc 09 §2.2
    // describes it as a *forced* choice — no explanation, no "I don't know".
    // A forced choice is enforceable at a table and not over a network: the
    // player whose ten seconds ran out may simply not be there.
    //
    // So the default is the one this app already uses everywhere else it must
    // not invent a fact: nothing is recorded and the round moves on. The seat
    // has no entry in `openingAccusations`, which is exactly what a seat that
    // said nothing looks like, and `C10` reads that silence honestly later.
    // Recording a name nobody said would put a fabricated accusation into the
    // generators' input, which is the one thing rule 4 forbids outright.
    const { data: state } = await db.from("room_state")
      .select("public_data").eq("room_id", roomId).maybeSingle();
    const current = Number(
      (state?.public_data as Record<string, unknown> | null)?.openingSeat ?? -1,
    );
    const next = roster.map((p) => p.seat).sort((a, b) => a - b)
      .find((seat) => seat > current) ?? null;

    if (next !== null) {
      await db.rpc("merge_public_data", {
        p_room: roomId,
        p_patch: { openingSeat: next },
      });
      await db.from("room_state").update({
        phase_ends_at: deadlineFor("opening", me.settings),
        updated_at: new Date().toISOString(),
      }).eq("room_id", roomId);
      return ok({ applied: "opening-skip", next });
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
    return ok({ applied: "opening-closed" });
  }

  if (me.phase === "discuss") {
    // The discussion is the one phase whose expiry is not a default for a
    // missing action — nobody owes it anything. It is simply over, and the
    // ballot opens, which is what "no phase may stall" means here.
    await db.from("room_state").update({
      phase: "vote",
      phase_ends_at: deadlineFor("vote", me.settings),
      active_speaker: null,
      updated_at: new Date().toISOString(),
    }).eq("room_id", roomId);
    return ok({ applied: "ballot-opened" });
  }

  // Nothing to default. A phase with no expiry action is one the room advances
  // itself, and saying so is better than pretending something happened.
  return ok({ applied: null });
}));
