/**
 * `room_settings` — the host's room settings screen, server side (task 10).
 *
 * ## Why every field is filtered here
 *
 * The client sends an object; this decides what a room may contain. A settings
 * blob that a client could write freely is a blob a modified client could put
 * anything in, and `rooms.settings` is read by the *engine* — a room whose
 * `nightDuration` is a string, or whose `openVoting` is a nested object, is a
 * match that breaks for nine honest players.
 *
 * So the allow-list below is the schema. Anything not in it is dropped, and
 * every value is coerced to the type the engine expects and clamped to the
 * range the settings screen offers. The screen and this list must agree; when
 * they disagree, this wins.
 *
 * ## What locks, and when
 *
 * Visibility. Doc 12's browse list only ever shows rooms in the lobby, so a
 * started match cannot appear in it anyway — but a host who could flip the
 * switch mid-match would be changing a fact about a room whose players joined
 * under the other one. It refuses after the deal; every other setting refuses
 * too, because the rules of a match may not change once cards are out.
 *
 * The refusal is decided under the room lock (`commit_room_settings`), in the
 * same statement as the write, so a start or a join racing this request finds
 * either the old rules or the new ones — never a mix.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { roomConfiguration } from "../_shared/room_configuration.ts";
import { ensureCosmeticAccess, ensureScenarioAccess } from "../_shared/purchase_access.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const roomId = body.roomId;
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) {
    return fail("NOT_HOST", "only the host changes the room", 403);
  }

  // Only the allow-list runs here; the host check, the lobby check, the
  // capacity check and the write are one statement under the room lock in
  // `commit_room_settings`. Reading status here and writing later let a start
  // or a join land in between: a started match's rules could change, or the
  // capacity could drop below a population the door had already admitted.
  let patch;
  try { patch = roomConfiguration(body, {}); }
  // A fixed sentence: the validator's own words never leave the function.
  catch { return fail("BAD_REQUEST", "invalid room settings"); }
  if (!await ensureScenarioAccess(db, userId, patch.settings)) {
    return fail("PURCHASE_REQUIRED", "scenario is not owned", 403);
  }
  if (!await ensureCosmeticAccess(db, userId, patch.settings)) {
    return fail("PURCHASE_REQUIRED", "presentation pack is not owned", 403);
  }
  if (Object.keys(patch).length === 0) return ok({ changed: false });

  const { error } = await db.rpc("commit_room_settings", {
    p_room: roomId, p_host: userId, p_patch: patch,
  });
  if (error) {
    const message = String(error.message ?? "");
    if (message.includes("ROOM_NOT_FOUND")) return fail("ROOM_NOT_FOUND", "no such room", 404);
    if (message.includes("NOT_HOST")) return fail("NOT_HOST", "only the host changes the room", 403);
    if (message.includes("PHASE_CLOSED")) return fail("PHASE_CLOSED", "the match has started", 409);
    if (message.includes("NAME_NOT_ALLOWED")) return fail("NAME_NOT_ALLOWED", "that name is not allowed");
    if (message.includes("BAD_REQUEST")) return fail("BAD_REQUEST", "capacity below current player count");
    throw error;
  }

  return ok({ changed: true });
}));
