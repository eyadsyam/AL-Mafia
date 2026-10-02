/**
 * `witness_view` — the whole table, to the dead and to nobody else.
 *
 * ## The owner's decision (2026-09-23)
 *
 * Doc 12 §4.1 originally kept living players' roles from Witness mode. The
 * owner reversed that for online play: a player who is out should watch the
 * match they were part of *knowing* it — every role, and every night choice as
 * it is made. The wall that keeps this fair is unchanged and is the reason the
 * reversal is safe inside the app: nothing a dead player sees or says can reach
 * a living one (`ghost_say`, `ghost_messages_dead_read`, and the voice mesh,
 * which stops sending a dead device's audio to living peers).
 *
 * ## Who is refused
 *
 * Everyone alive, and every seat that was removed (`loadMembership` returns
 * null for a kicked row). The refusal is the same `NOT_ALIVE` (as `ghost_say` uses) whatever the
 * caller's role, so the answer tells a living player nothing.
 *
 * ## What it answers
 *
 * `roles`   — every dealt seat and its role.
 * `actions` — every night action of the match so far, including the night in
 *             progress, as seats. `skip` rows are left out: "chose nobody" is
 *             a non-event to watch, and it is what an unanswered seat defaults
 *             to anyway.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.alive || me.status !== "playing") {
    return fail("NOT_ALIVE", "only an eliminated player watches the whole table", 403);
  }

  const [players, actions] = await Promise.all([
    db
      .from("room_players")
      .select("user_id, seat, role")
      .eq("room_id", roomId)
      .eq("kicked", false)
      .not("role", "is", null)
      .order("seat"),
    db
      .from("night_actions")
      .select("night, actor_id, action, target_id")
      .eq("room_id", roomId)
      .neq("action", "skip")
      .order("night")
      .order("created_at"),
  ]);
  if (players.error) throw players.error;
  if (actions.error) throw actions.error;

  const seatOf = new Map<string, number>(
    (players.data ?? []).map((p) => [p.user_id as string, p.seat as number]),
  );

  return ok({
    roles: (players.data ?? []).map((p) => ({ seat: p.seat, role: p.role })),
    actions: (actions.data ?? [])
      .filter((a) => seatOf.has(a.actor_id) && seatOf.has(a.target_id))
      .map((a) => ({
        night: a.night,
        seat: seatOf.get(a.actor_id),
        action: a.action,
        targetSeat: seatOf.get(a.target_id),
      })),
  });
}));
