/**
 * `remove_player` — doc 10 §8.1's last row: *"player gone > 3 minutes → host
 * may mark them «خرج» — treated as a neutral elimination, then a win check."*
 *
 * ## Neutral, and why that word is doing work
 *
 * Nobody voted for this. So no role is announced, nothing is attributed to the
 * table, and the Information Engine is told nothing: a removal is not a
 * suspicion, not an accusation and not a lynch, and a generator that treated it
 * as one would be inventing a fact about a player who was not even there
 * (prime directive 4).
 *
 * ## The three-minute check is the server's
 *
 * A host who could remove anybody at any moment would be holding a delete
 * button over the other players, and "they were disconnected, honestly" is not
 * a thing the other four can check. So the server checks: the target must
 * actually have been silent for three minutes. A host with a grudge and a fast
 * finger gets a refusal.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

const GONE_AFTER_MS = 3 * 60 * 1000;

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, seat } = await req.json();
  if (!roomId || seat == null) return fail("BAD_REQUEST", "roomId and seat required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) return fail("NOT_HOST", "only the host may remove", 403);
  if (me.status !== "playing") return fail("PHASE_CLOSED", "no match is running");

  const { data: target } = await db
    .from("room_players")
    .select("user_id, alive, connected, last_seen")
    .eq("room_id", roomId)
    .eq("seat", seat)
    .maybeSingle();
  if (!target) return fail("BAD_REQUEST", "no such seat");
  if (!target.alive) return fail("BAD_REQUEST", "that player is already out");

  const silentFor = Date.now() - new Date(target.last_seen).getTime();
  if (target.connected && silentFor < GONE_AFTER_MS) {
    return fail("BAD_REQUEST", "that player is still here");
  }

  await db.from("room_players")
    .update({ alive: false })
    .eq("room_id", roomId)
    .eq("user_id", target.user_id);

  // Doc 09 §3.4 — anything still in flight to somebody who has left is voided,
  // exactly as it is for a player who died.
  await db.from("whisper_meta")
    .update({ voided: true })
    .eq("room_id", roomId)
    .eq("to_id", target.user_id)
    .eq("voided", false);

  await db.rpc("set_public_path", {
    p_room: roomId,
    p_path: ["eliminations", String(seat)],
    p_value: { phase: "day", number: me.phaseNumber },
  });

  // W8 — the check runs after the removal is applied, never mid-resolution.
  const { data: players } = await db
    .from("room_players")
    .select("user_id, role, alive")
    .eq("room_id", roomId);
  const living = (players ?? []).filter((p) => p.alive);
  const mafia = living.filter((p) => p.role === "mafia").length;
  const town = living.length - mafia;
  const outcome = mafia === 0 ? "town" : mafia >= town ? "mafia" : null;

  if (outcome) {
    await db.rpc("merge_public_data", {
      p_room: roomId,
      p_patch: { outcome },
    });
  }

  return ok({ removed: seat, outcome });
}));
