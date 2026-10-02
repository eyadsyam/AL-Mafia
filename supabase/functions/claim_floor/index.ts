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
import { floorOwnerSeat, floorSecondsFor, micPolicyFor } from "../_shared/voice.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (!me.alive) return fail("NOT_ALIVE", "the dead do not hold the floor", 403);

  const policy = micPolicyFor(me.phase, me.settings);

  // Nothing to grant. In an open phase every microphone is already live, and
  // handing out a token would make the lobby quieter rather than louder.
  if (policy === "open") return ok({ granted: false, policy });

  // The night, the reveal, the ballot. Not an error and not a negotiation.
  if (policy === "muted") return ok({ granted: false, policy });

  const { data: state, error: stateError } = await db
    .from("room_state")
    .select("public_data")
    .eq("room_id", roomId)
    .maybeSingle();
  if (stateError) throw stateError;
  if (!state) throw new Error("room state missing");

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

  const granted = await db.rpc("claim_speaking_floor", {
    p_room: roomId,
    p_user: userId,
    p_seconds: floorSecondsFor(me.phase, me.settings),
  });

  if (granted.error) throw granted.error;

  return ok({ granted: granted.data === true, policy });
}));
