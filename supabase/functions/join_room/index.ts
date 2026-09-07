/**
 * `join_room` — seat assignment and name uniqueness (doc 10 §5).
 *
 * Covers O5, O6, O14, O15 and S7:
 *   O5  a new `user_id` cannot take an existing seat mid-match
 *   O6  the same account cannot hold two seats
 *   O14 a finished room is refused with a clear message
 *   O15 a full room (15) is refused with a clear message
 *   S7  a duplicate display name is suffixed, never silently merged
 */
import { fail, handler, ok } from "../_shared/api.ts";

/** Doc 10 §3.1: "Cap room size at 15." Mesh voice and message volume both. */
/** The hard ceiling. A room may choose less; nothing may choose more. */
const MAX_PLAYERS = 15;

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const code = String(body.code ?? "").trim().toUpperCase();
  const wanted = String(body.name ?? "").trim();
  if (!code || !wanted) return fail("BAD_REQUEST", "code and name are required");

  const { data: room } = await db
    .from("rooms")
    .select("id, status, banned_user_ids, settings")
    .eq("code", code)
    .maybeSingle();
  if (!room) return fail("ROOM_NOT_FOUND", "no room with that code", 404);
  if (room.status === "finished") {
    return fail("ROOM_FINISHED", "that match has already finished");
  }

  // Task 6 — a kick is not a disconnection. The whole point of the rejoin path
  // below is that a player who was thrown out cannot walk back in through it,
  // and the room code is not a secret once it has been read aloud once.
  if ((room.banned_user_ids ?? []).includes(userId)) {
    return fail("NOT_A_MEMBER", "the host removed you from that room", 403);
  }

  const { data: players } = await db
    .from("room_players")
    .select("user_id, name, seat")
    .eq("room_id", room.id)
    .order("seat");
  const roster = players ?? [];

  // O4 — a returning player with the same account is restored to their seat,
  // role and state. This is the rejoin path, and it is the *only* way back into
  // a match in progress (V9, O5).
  const existing = roster.find((p) => p.user_id === userId);
  if (existing) return ok({ roomId: room.id, seat: existing.seat, rejoined: true });

  if (room.status !== "lobby") {
    return fail("PHASE_CLOSED", "the match has already started");
  }
  // Task 10 — the host's chosen capacity, clamped to the hard ceiling. A room
  // that never set one is a ten-seat room, which is what the lobby has always
  // drawn.
  const chosen = Number((room.settings ?? {}).maxPlayers ?? 10);
  const capacity = Math.min(
    MAX_PLAYERS,
    [5, 8, 10, 15].includes(chosen) ? chosen : 10,
  );
  if (roster.length >= capacity) {
    return fail("ROOM_FULL", "that room is full");
  }

  // S7 — «أحمد ٢» rather than two players called أحمد. Never merged: a table
  // with two people of the same name is common, and the app's job is to make
  // them distinguishable, not to pretend they are one person.
  let name = wanted;
  let suffix = 2;
  while (roster.some((p) => p.name === name)) name = `${wanted} ${suffix++}`;

  const seat = roster.length;
  const { error } = await db
    .from("room_players")
    .insert({ room_id: room.id, user_id: userId, name, gender: ["male", "female"].includes(body.gender) ? body.gender : "unspecified", seat });
  if (error) {
    // The seat unique index caught a race with another joiner.
    if (error.code === "23505") return fail("BAD_REQUEST", "seat taken, retry");
    throw error;
  }

  return ok({ roomId: room.id, seat, name });
}));
