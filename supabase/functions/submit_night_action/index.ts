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
 *
 * ## The fifth check: the bullet
 *
 * Two roles hold one irreversible move each for the whole match (doc 13 §2, as
 * doc 14 §4 left it): the Mafia's «الليلة الهادية» and the Doctor's
 * self-protection. Both arrive here as an ordinary action with `useBullet`
 * set, and both are validated the same way everything else is — against the
 * caller's role as the server knows it, the room's settings as the *room*
 * holds them, and `night_actions.used_bullet` for whether it is already gone.
 *
 * Nothing about a bullet is taken from the client except the intention to use
 * one. A client that asked to spend a bullet it does not hold is refused, and a
 * client that quietly omitted the flag simply does not spend one — which is
 * also what a player declining to use it looks like, so the two are the same
 * request and neither is a special case.
 */
import {
  actionForRole,
  asUuid,
  fail,
  handler,
  loadMembership,
  ok,
} from "../_shared/api.ts";

/** The once-per-match move each role holds, or null for the two that hold none. */
function bulletFor(role: string | null): "quietNight" | "selfProtect" | null {
  switch (role) {
    case "mafia":
      return "quietNight";
    case "doctor":
      return "selfProtect";
    default:
      return null;
  }
}

/**
 * Whether the room turned this bullet on.
 *
 * Read from `rooms.settings`, never from the request — a client that lied about
 * its own settings would be spending a move the rest of the table is not
 * playing with. Absent means on, matching `MatchSettings`' defaults, because a
 * room created by an older client is playing the same game as this one.
 */
function bulletEnabled(
  settings: Record<string, unknown>,
  kind: "quietNight" | "selfProtect",
): boolean {
  if (kind === "selfProtect") return true;
  if (settings.bulletsEnabled === false) return false;
  const key = kind === "quietNight" ? "quietNightEnabled" : "selfProtectEnabled";
  return settings[key] !== false;
}

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, action, targetSeat, note, actionId, useBullet } = await req
    .json();
  if (!roomId || !action) return fail("BAD_REQUEST", "roomId and action required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead take no part in the night", 403);
  if (me.phase !== "night") return fail("PHASE_CLOSED", "the night is closed");

  // Skipping is legal for every role — doc 05 rules 5 and 6 make the control
  // universal, and doc 10 §8.2 needs it for three of the four expiry defaults.
  const permitted = actionForRole(me.role);
  if (me.role === "doctor" && action === "skip") {
    return fail("BAD_REQUEST", "a doctor must protect a living player");
  }
  if (action !== "skip" && action !== permitted) {
    return fail("WRONG_ROLE", "that is not your action", 403);
  }
  if (note != null && String(note).length > 40) {
    return fail("BAD_REQUEST", "a note is at most 40 characters");
  }

  // ── the bullet ──────────────────────────────────────────────────────────
  const wants = useBullet === true;
  const bullet = bulletFor(me.role);
  const available = bullet !== null && bulletEnabled(me.settings, bullet);

  // Already spent? One query, and it is the same one the unique index enforces
  // — the index is what makes two simultaneous requests impossible to both win,
  // and this is what gives the loser a sentence instead of a constraint error.
  //
  // Only an *earlier* night counts (M5). This night's own row is the same move
  // arriving again: a request that committed and lost its response on a weak
  // network is retried with a fresh action id, and it must land on its own row
  // like every other retry, not be told the bullet is gone and leave the
  // player believing a move that stands was refused.
  let alreadySpent = false;
  if (wants && available) {
    const { data: prior, error: priorError } = await db
      .from("night_actions")
      .select("night")
      .eq("room_id", roomId)
      .eq("actor_id", userId)
      .eq("used_bullet", true)
      .lt("night", me.phaseNumber)
      .limit(1);
    if (priorError) throw priorError;
    alreadySpent = (prior ?? []).length > 0;
  }
  const spending = wants && available && !alreadySpent;

  // The self-protection is the *only* reason a night action may name its own
  // actor, and it is narrow on purpose: the Doctor, protecting, with the
  // bullet, having not yet used it. Everything else naming itself is still the
  // mistake it always was.
  const selfProtect = spending &&
    bullet === "selfProtect" &&
    action === "protect" &&
    targetSeat === me.seat;

  if (wants && !available) {
    return fail("WRONG_ROLE", "you hold no such move", 403);
  }
  if (wants && alreadySpent) {
    return fail("RATE_LIMITED", "you have already used it");
  }

  let targetId: string | null = null;
  if (action !== "skip") {
    if (targetSeat == null) return fail("BAD_REQUEST", "a target is required");
    const { data: target, error: targetError } = await db
      .from("room_players")
      .select("user_id, alive")
      .eq("room_id", roomId)
      .eq("seat", targetSeat)
      .maybeSingle();
    if (targetError) throw targetError;
    if (!target) return fail("BAD_REQUEST", "no such seat");
    if (!target.alive) return fail("BAD_REQUEST", "that player is dead");
    if (target.user_id === userId && !selfProtect) {
      return fail("BAD_REQUEST", "not yourself");
    }
    targetId = target.user_id;
  }

  // N15/O19 — idempotent. The primary key is (room, night, actor), so a retried
  // request overwrites its own row and can never double-act.
  //
  // A retry that spends a bullet overwrites its own `used_bullet` with the same
  // `true`, which the partial unique index reads as the same row and permits. A
  // *second* night trying to spend a second one is a different row, and that is
  // the collision the index exists to lose. A same-night resubmit *without* the
  // bullet cannot clear it either: the `night_action_keep_bullet` trigger keeps
  // `used_bullet = existing OR requested` under the row lock (M5).
  const { error } = await db.from("night_actions").upsert({
    room_id: roomId,
    night: me.phaseNumber,
    actor_id: userId,
    action,
    target_id: targetId,
    note: note ?? null,
    action_id: asUuid(actionId),
    used_bullet: spending,
  });
  if (error) {
    // 23505 — the partial unique index. Two requests raced and this one lost.
    if (error.code === "23505") {
      return fail("RATE_LIMITED", "you have already used it");
    }
    // The phase guard on the table (migration `action_epoch`): the night was
    // resolved between this caller's read and its write. The move is not
    // lost quietly — the caller is told the night closed and resyncs.
    if (error.message?.includes("PHASE_CLOSED")) {
      return fail("PHASE_CLOSED", "the night is closed");
    }
    // The membership guard on the same trigger (migration `kicked_moves`):
    // the seat was removed between this caller's read and its write.
    if (error.message?.includes("NOT_A_MEMBER")) {
      return fail("NOT_A_MEMBER", "you are no longer in that room", 403);
    }
    throw error;
  }

  await closeNightIfEveryoneActed(db, roomId, me.phaseNumber);

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
    const { data: target, error: peekError } = await db
      .from("room_players")
      .select("role")
      .eq("room_id", roomId)
      .eq("user_id", targetId)
      .maybeSingle();
    if (peekError) throw peekError;
    return ok({ revealedRole: target?.role ?? null, bulletSpent: spending });
  }

  // The ack carries one fact about the caller and nothing about anybody else:
  // whether this move used their bullet. The client needs it to dim the tile,
  // and it needs it from the server rather than from its own optimism, because
  // the server is what decides whether the move was legal at all.
  return ok({ bulletSpent: spending });
}));

/**
 * Brings the night's clock to now once every living player has acted.
 *
 * The night runs 120 seconds because "a player who is thinking looks exactly
 * like a player who has left" (doc 10 §8.2, and `phases.ts` says so). The
 * moment the last living player acts, neither of those is true any more, and
 * the room is being made to wait out a timer that is protecting nobody.
 *
 * The clock is moved rather than the phase: `advance_phase` still applies the
 * defaults (there are none left to apply) and the host's client still asks for
 * the tally, so this adds no second route into the resolution — it only stops
 * the first one from being late.
 *
 * Nothing here is a tell. Every role acts every night — doc 05 rules 5 and 6
 * make the empty turn universal for exactly this reason — and the roster of
 * the living is already public, so "everybody has acted" is a fact the whole
 * table can already see and says nothing about anybody's role.
 */
async function closeNightIfEveryoneActed(
  // deno-lint-ignore no-explicit-any
  db: any,
  roomId: string,
  night: number,
): Promise<void> {
  const [living, acted] = await Promise.all([
    db.from("room_players").select("user_id").eq("room_id", roomId).eq(
      "alive",
      true,
    ),
    db.from("night_actions").select("actor_id").eq("room_id", roomId).eq(
      "night",
      night,
    ),
  ]);
  // A read that failed is not "nobody is alive" and not "nobody has acted":
  // the move above was saved, and closing the night early is a courtesy this
  // call may simply not extend when it cannot see the room.
  if (living.error || acted.error) return;
  const alive = new Set(
    (living.data ?? []).map((p: { user_id: string }) => p.user_id),
  );
  if (alive.size === 0) return;
  const done = new Set(
    (acted.data ?? []).map((a: { actor_id: string }) => a.actor_id),
  );
  for (const id of alive) {
    if (!done.has(id)) return;
  }
  // Guarded on the phase and the night so a late write cannot pull the clock
  // of a *different* night forward.
  await db.from("room_state")
    .update({ phase_ends_at: new Date().toISOString() })
    .eq("room_id", roomId)
    .eq("phase", "night")
    .eq("phase_number", night);
}
