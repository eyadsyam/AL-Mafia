/**
 * `ghost_say` — the write half of doc 12 §4.1's wall.
 *
 * *"Ghost chat — text chat with other eliminated players only. **Hard-walled:
 * no channel from dead to living exists in the app**."*
 *
 * The read half is `ghost_messages_dead_read`, which refuses the rows to a
 * living member of the same room. This is the other direction, and it is worth
 * having as a function rather than as an insert policy for one reason: a living
 * player who *wrote* into ghost chat would be visible to every dead player, and
 * a dead player who believed they were talking to the dead would be talking to
 * a living one. That is the same leak running backwards, so it is refused here
 * with the service key rather than left to a policy the client also has to
 * satisfy.
 *
 * There is no room-wide broadcast and no notification. A ghost message reaches
 * exactly the set of people the read policy admits, and it reaches them through
 * Realtime, whose subscription is filtered by that same policy.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

/** Matches `ghost_body_length`. Refused, never truncated — see `send_whisper`. */
const MAX_LENGTH = 240;

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, body } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const text = String(body ?? "").trim();
  if (text.length === 0) return fail("BAD_REQUEST", "nothing to say");
  if (text.length > MAX_LENGTH) {
    return fail("BAD_REQUEST", `at most ${MAX_LENGTH} characters`);
  }

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // The inversion of every other check in this directory, and the whole point
  // of the function: here it is the *living* who are refused.
  if (me.alive) {
    return fail("NOT_ALIVE", "the living do not speak in the graveyard", 403);
  }

  const { data, error } = await db
    .from("ghost_messages")
    .insert({ room_id: roomId, author_id: userId, body: text })
    .select("id, created_at")
    .single();
  if (error) throw error;

  return ok({ id: data.id, createdAt: data.created_at });
}));
