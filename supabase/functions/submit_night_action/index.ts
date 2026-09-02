/**
 * `submit_night_action` — O18's answer.
 *
 * *"Malicious client submits a night action for a role it does not have →
 * Edge Function validates role → rejected."* Four checks, in this order:
 *
 *   1. the caller is a member of the room  (from the JWT, never the body)
 *   2. the caller is alive
 *   3. the phase is `night`
 *   4. the action is the one the caller's role performs
 *
 * The actor is `auth.uid()`. There is no field in the request that names one,
 * so submitting *as* somebody else is not a thing that can be attempted.
 */
import { actionForRole, fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, action, targetSeat, note, actionId } = await req.json();
  if (!roomId || !action) return fail("BAD_REQUEST", "roomId and action required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead take no part in the night", 403);
  if (me.phase !== "night") return fail("PHASE_CLOSED", "the night is closed");

  // Skipping is legal for every role — doc 05 rules 5 and 6 make the control
  // universal, and doc 10 §8.2 needs it for three of the four expiry defaults.
  const permitted = actionForRole(me.role);
  if (action !== "skip" && action !== permitted) {
    return fail("WRONG_ROLE", "that is not your action", 403);
  }
  if (note != null && String(note).length > 40) {
    return fail("BAD_REQUEST", "a note is at most 40 characters");
  }

  let targetId: string | null = null;
  if (action !== "skip") {
    if (targetSeat == null) return fail("BAD_REQUEST", "a target is required");
    const { data: target } = await db
      .from("room_players")
      .select("user_id, alive")
      .eq("room_id", roomId)
      .eq("seat", targetSeat)
      .maybeSingle();
    if (!target) return fail("BAD_REQUEST", "no such seat");
    if (!target.alive) return fail("BAD_REQUEST", "that player is dead");
    if (target.user_id === userId) return fail("BAD_REQUEST", "not yourself");
    targetId = target.user_id;
  }

  // N15/O19 — idempotent. The primary key is (room, night, actor), so a retried
  // request overwrites its own row and can never double-act.
  const { error } = await db.from("night_actions").upsert({
    room_id: roomId,
    night: me.phaseNumber,
    actor_id: userId,
    action,
    target_id: targetId,
    note: note ?? null,
    action_id: actionId ?? null,
  });
  if (error) throw error;

  // The Detective's answer goes back in the response to their own request and
  // nowhere else: not into `public_data`, not into a row any other client can
  // read, and not into the night's record (doc 05 rule 10 — the one fact in
  // the game that is never written down). The offline engine hands it back
  // from the same call for the same reason, so both modes tell the Detective
  // the same thing in the same breath.
  //
  // It is the *exact* role, matching `InvestigateResult.revealedRole`. A
  // narrower "mafia / not mafia" here would make the online Detective weaker
  // than the offline one, which is a rules change wearing a privacy costume.
  if (action === "investigate" && targetId) {
    const { data: target } = await db
      .from("room_players")
      .select("role")
      .eq("room_id", roomId)
      .eq("user_id", targetId)
      .maybeSingle();
    return ok({ revealedRole: target?.role ?? null });
  }

  // Ack only. Nothing about anybody else's night reaches the caller.
  return ok();
}));
