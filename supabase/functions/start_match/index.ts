/**
 * `start_match` — assigns roles from the room's seed (doc 10 §5).
 *
 * **Returns nothing about roles.** Each client then asks `my_team` for its
 * own, which is the only route by which a role leaves the database: no client
 * role holds a column privilege for `room_players.role`, so there is no view
 * and no PostgREST request that could return it. The whole point of putting
 * the deal here is that no client ever holds the table.
 */
import { fail, handler, ok } from "../_shared/api.ts";
import { roomConfiguration } from "../_shared/room_configuration.ts";
import { deadlineFor } from "../_shared/phases.ts";
import { ensureScenarioAccess } from "../_shared/purchase_access.ts";

/** Mirrors the Fisher–Yates in `MatchEngine.start`, seeded the same way. */
function shuffle<T>(items: T[], seed: number): T[] {
  const out = [...items];
  let state = seed >>> 0;
  for (let i = out.length - 1; i > 0; i--) {
    // xorshift32, written down for the same reason the tie-break is: an
    // unspecified PRNG cannot be reproduced by a reviewer or a second runtime.
    state ^= state << 13; state >>>= 0;
    state ^= state >>> 17;
    state ^= state << 5;  state >>>= 0;
    const j = state % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

Deno.serve(handler(async (req, userId, db) => {
  const { roomId, roles, settings } = await req.json();
  if (!roomId || !roles) return fail("BAD_REQUEST", "roomId and roles required");

  const { data: room, error: roomError } = await db
    .from("rooms")
    .select("id, host_id, status, match_seed, settings")
    .eq("id", roomId)
    .maybeSingle();
  if (roomError) throw roomError;
  if (!room) return fail("ROOM_NOT_FOUND", "no such room", 404);
  if (room.host_id !== userId) return fail("NOT_HOST", "only the host may start");
  if (room.status !== "lobby") return fail("PHASE_CLOSED", "already started");

  const { data: players, error: playersError } = await db
    .from("room_players")
    .select("user_id, seat")
    .eq("room_id", roomId)
    .eq("kicked", false)
    .order("seat");
  if (playersError) throw playersError;
  const roster = players ?? [];

  // S1/S2/S4/S5, server-side. The client shows a friendlier version of each of
  // these at setup; this is the one that decides.
  if (roster.length < 5) return fail("BAD_REQUEST", "at least five players");
  const counts = roles as Record<string, number>;
  if (!counts || Array.isArray(counts) || typeof counts !== "object" ||
      Object.entries(counts).some(([role, n]) => !["mafia", "doctor", "detective", "citizen"].includes(role) || !Number.isInteger(n) || n < 0 || n > 15)) {
    return fail("BAD_REQUEST", "invalid role counts");
  }
  let effectiveSettings;
  try {
    effectiveSettings = roomConfiguration({settings: {
      ...(settings && typeof settings === "object" ? settings : {}),
      ...(room.settings ?? {}),
    }}).settings;
  } catch { return fail("BAD_REQUEST", "invalid match settings"); }
  if (!await ensureScenarioAccess(db, userId, effectiveSettings)) {
    return fail("PURCHASE_REQUIRED", "scenario is not owned", 403);
  }
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  if (total !== roster.length) return fail("BAD_REQUEST", "roles must sum to the roster");
  const mafia = counts.mafia ?? 0;
  if (mafia < 1) return fail("BAD_REQUEST", "at least one mafia");
  if (mafia * 2 >= roster.length) return fail("BAD_REQUEST", "mafia may not reach parity at the start");

  const deck: string[] = [];
  for (const [role, n] of Object.entries(counts)) {
    for (let i = 0; i < n; i++) deck.push(role);
  }
  const dealt = shuffle(deck, room.match_seed);

  // One database transaction. Previously these were N+2 independent writes
  // whose errors were ignored; one failed player update could open `reveal`
  // with no role for that guest. The RPC either deals everybody and opens the
  // phase, or rolls the whole attempt back so the host can retry safely.
  const { data: applied, error: applyError } = await db.rpc(
    "apply_match_deal",
    {
      p_room_id: roomId,
      p_host_id: userId,
      p_roles: dealt,
      p_settings: effectiveSettings,
      // The deal runs on a clock like every other phase (doc 10 s8.2). Without
      // one it was the single phase a room could be stranded in for good.
      p_phase_ends_at: deadlineFor("reveal", effectiveSettings ?? {}),
    },
  );
  if (applyError || applied !== true) {
    return fail("BAD_REQUEST", "match could not be started", 500);
  }

  // Deliberately nothing about roles in the response.
  return ok({ started: true, playerCount: roster.length });
}));
