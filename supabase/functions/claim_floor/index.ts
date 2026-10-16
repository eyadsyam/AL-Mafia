/**
 * `claim_floor` — the server's answer to "may I speak".
 *
 * Doc 10 §6.1: *"the server sets `active_speaker`, and every client hard-mutes
 * its own mic unless it holds the token. Never trust the client to mute itself
 * politely."* This is the half of V4 that stops an honest client; the other
 * half is every receiver silencing the inbound track of anybody who is not the
 * active speaker, because a mesh has no server in the media path.
 *
 * A refusal is the ordinary case. For most of a match — the whole night, the
 * whole ballot, and every second somebody else has the floor — the honest
 * answer is no, and it is returned as a 200 with `granted: false` rather than
 * as an error, because a player who tapped a button at the wrong moment has
 * not done anything wrong.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { floorOwnerSeat, floorSecondsFor, micPolicyForSeat } from "../_shared/voice.ts";
import { silencedSeatOf } from "../_shared/silence.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead do not hold the floor", 403);

  const { data: state, error: stateError } = await db
    .from("room_state")
    .select("public_data")
    .eq("room_id", roomId)
    .maybeSingle();
  if (stateError) throw stateError;
  if (!state) throw new Error("room state missing");
  if (silencedSeatOf(state.public_data) === me.seat) {
    return ok({ granted: false, policy: "muted", reason: "silenced" });
  }

  const policy = micPolicyForSeat(
    me.phase,
    me.settings,
    (state.public_data ?? {}) as Record<string, unknown>,
    me.seat,
  );

  // Nothing to grant. In an open phase every microphone is already live, and
  // handing out a token would make the lobby quieter rather than louder.
  if (policy === "open") return ok({ granted: false, policy });

  // The night, the reveal, the ballot. Not an error and not a negotiation.
  if (policy === "muted") return ok({ granted: false, policy });

  const owner = floorOwnerSeat(
    me.phase,
    (state?.public_data ?? {}) as Record<string, unknown>,
  );

  // A phase with a named speaker is not first-come-first-served. The
  // confrontation belongs to the player who was named, and the opening round
  // to the seat the room is currently pointed at.
  if (owner !== null && owner !== me.seat) {
    return ok({ granted: false, policy, owner });
  }

  // «أدوات القعدة»: extra_minute / objection add seconds to this seat's first
  // granted claim after the purchase, and to no later one.
  const granted = await db.rpc("claim_floor_with_tools", {
    p_room: roomId,
    p_user: userId,
    p_seconds: floorSecondsFor(me.phase, me.settings),
    p_phase: me.phase,
    p_number: me.phaseNumber,
  });

  if (granted.error) throw granted.error;

  return ok({ granted: granted.data === true, policy });
}));
