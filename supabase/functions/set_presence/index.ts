/**
 * `set_presence` — a client saying what just happened to it.
 *
 * The ageing job (`age_presence`) is what makes presence *true* for a client
 * that crashed, lost its network, or had its battery pulled: it cannot report
 * anything, so a clock has to. This function is the other half — the client
 * that *can* report, reporting immediately, so that backgrounding the app
 * empties your ring on everybody else's table now rather than in twenty-five
 * seconds.
 *
 * Three states and no fourth. `connected` also refreshes `last_seen`, because
 * coming back to the foreground is a beat by any other name; `away` and `left`
 * deliberately do not, so the clock keeps running underneath them and an
 * `away` that never comes back still ages to `left`.
 *
 * A client may only ever say this about itself: the user id comes from the JWT
 * and there is no field in the request that names a player.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

const STATES = new Set(["connected", "away", "left"]);

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, status } = await req.json();
  if (!roomId || !status) return fail("BAD_REQUEST", "roomId and status required");
  if (!STATES.has(status)) return fail("BAD_REQUEST", "unknown status");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  const patch: Record<string, unknown> = { status };
  if (status === "connected") {
    patch.connected = true;
    patch.last_seen = new Date().toISOString();
  }
  if (status === "left") patch.connected = false;

  const { data: updated, error } = await db
    .from("room_players")
    .update(patch)
    .eq("room_id", roomId)
    .eq("user_id", userId)
    .eq("kicked", false)
    .select("user_id");
  if (error) throw error;
  if (!updated?.length) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  return ok({ status });
}));
