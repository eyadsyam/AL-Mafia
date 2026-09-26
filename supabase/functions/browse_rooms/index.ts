/**
 * `browse_rooms` — the «أوض عامة» list, which is the only way a player picks
 * a public room.
 *
 * A thin wrapper over security-definer listing functions whose shape is fixed
 * in migrations: `rooms` has RLS and a browser is by definition not a member
 * of the rooms they are browsing.
 *
 * Before listing it asks `ensure_system_waiting_room`, which keeps at most one
 * empty server-owned waiting room per pool, and only when this player has no
 * joinable public lobby. Nothing here seats anybody: the first player to join
 * that room by tapping it becomes its host (join_room_atomic).
 *
 * Authenticated, like every other function here. The client re-reads it every
 * fifteen seconds while the list is on screen.
 *
 * Deploy order: migration 20260924000200 first. Against an older database the
 * provisioning call is skipped (PGRST202) and the list falls back to
 * `public_room_listing`, then to `public_rooms()`.
 */
import { handler, ok } from "../_shared/api.ts";

const missing = (error: { code?: string } | null) =>
  error?.code === "PGRST202";

Deno.serve(handler(async (_req, userId, db) => {
  const provision = await db.rpc("ensure_system_waiting_room", {
    p_user: userId, p_pool: "default",
  });
  // Provisioning is a convenience; a failure never hides the list.
  if (provision.error && !missing(provision.error)) {
    console.error("ensure_system_waiting_room", provision.error.code);
  }
  for (const rpc of ["public_room_listing_v2", "public_room_listing"]) {
    const listing = await db.rpc(rpc, { p_user: userId });
    if (!listing.error) return ok({ rooms: listing.data ?? [] });
    if (!missing(listing.error)) throw listing.error;
  }
  const { data, error } = await db.rpc("public_rooms");
  if (error) throw error;
  return ok({ rooms: data ?? [] });
}));
