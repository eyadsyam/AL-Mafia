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

  const { data: room } = await db
    .from("rooms")
    .select("id, host_id, status, match_seed")
    .eq("id", roomId)
    .maybeSingle();
  if (!room) return fail("ROOM_NOT_FOUND", "no such room", 404);
  if (room.host_id !== userId) return fail("NOT_HOST", "only the host may start");
  if (room.status !== "lobby") return fail("PHASE_CLOSED", "already started");

  const { data: players } = await db
    .from("room_players")
    .select("user_id, seat")
    .eq("room_id", roomId)
    .order("seat");
  const roster = players ?? [];

  // S1/S2/S4/S5, server-side. The client shows a friendlier version of each of
  // these at setup; this is the one that decides.
  if (roster.length < 5) return fail("BAD_REQUEST", "at least five players");
  const counts = roles as Record<string, number>;
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

  for (let i = 0; i < roster.length; i++) {
    await db
      .from("room_players")
      .update({ role: dealt[i] })
      .eq("room_id", roomId)
      .eq("user_id", roster[i].user_id);
  }

  // The rules the host chose, stored on the room rather than in the public
  // payload: every client renders against them and none of them may change
  // once the deal has happened.
  await db.from("rooms").update({
    status: "playing",
    ...(settings && typeof settings === "object" ? { settings } : {}),
  }).eq("id", roomId);
  await db.from("room_state").update({
    phase: "reveal",
    phase_number: 1,
    phase_ends_at: null,
    public_data: { playerCount: roster.length },
  }).eq("room_id", roomId);

  // Deliberately nothing about roles in the response.
  return ok({ started: true, playerCount: roster.length });
}));
