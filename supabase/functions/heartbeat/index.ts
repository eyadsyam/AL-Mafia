/**
 * `heartbeat` — presence, at no more than one call per ten seconds.
 *
 * Doc 10 §3.1: "No presence heartbeat faster than 10s." The cost model's
 * binding constraint is realtime messages, and a chatty heartbeat is the
 * easiest way to spend them on nothing.
 *
 * **The night freeze (doc 10 §6.3) is not implemented here** and must not be:
 * `connected` keeps updating, and it is the *client* that stops rendering
 * per-player status for the whole night phase. Freezing the data would lose the
 * disconnect detection that §8.1 depends on; freezing the display loses
 * nothing, because there is nothing a player may act on during the night
 * anyway.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  await db
    .from("room_players")
    // A beat is the definition of `connected`. The ageing job walks the same
    // column in the other direction, so this write is the only thing that
    // stops a row sliding to `away` and then to `left`.
    .update({
      connected: true,
      status: "connected",
      last_seen: new Date().toISOString(),
    })
    .eq("room_id", roomId)
    .eq("user_id", userId);

  return ok();
}));
