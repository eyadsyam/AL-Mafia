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
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

/** The whole schema of `rooms.settings`, as far as the host may write it. */
//
// The names are the engine's own — `settingsFromJson` in `room_codec.dart`
// reads these keys — so the settings screen writes the same words the match
// later plays by. Durations are seconds even where the screen offers minutes;
// a unit that changes between the writer and the reader is a bug waiting for
// somebody to pick 3 and get three seconds.
const NUMBERS: Record<string, number[]> = {
  maxPlayers: [5, 8, 10, 15],
  speechSeconds: [30, 45, 60],
  discussionSeconds: [180, 300, 420],
};

const FLAGS = [
  "voice",
  "muteAllAtNight",
  "openVoting",
  "traceEnabled",
  "confrontationEnabled",
  "whisperEnabled",
];

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const roomId = body.roomId;
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.hostId !== userId) {
    return fail("NOT_HOST", "only the host changes the room", 403);
  }

  const { data: room } = await db
    .from("rooms")
    .select("id, status, settings")
    .eq("id", roomId)
    .maybeSingle();
  if (!room) return fail("ROOM_NOT_FOUND", "no such room", 404);
  if (room.status !== "lobby") {
    return fail("PHASE_CLOSED", "the match has started", 409);
  }

  const patch: Record<string, unknown> = {};

  if (body.visibility !== undefined) {
    if (!["private", "public"].includes(body.visibility)) {
      return fail("BAD_REQUEST", "visibility must be private or public");
    }
    patch.visibility = body.visibility;
  }

  if (body.title !== undefined) {
    const title = String(body.title ?? "").trim().slice(0, 40);
    patch.title = title.length === 0 ? null : title;
  }

  if (body.settings && typeof body.settings === "object") {
    const incoming = body.settings as Record<string, unknown>;
    const settings: Record<string, unknown> = {
      ...(room.settings && typeof room.settings === "object" ? room.settings : {}),
    };
    for (const [key, allowed] of Object.entries(NUMBERS)) {
      if (incoming[key] === undefined) continue;
      const value = Number(incoming[key]);
      if (!allowed.includes(value)) {
        return fail("BAD_REQUEST", `${key} must be one of ${allowed.join(", ")}`);
      }
      settings[key] = value;
    }
    for (const key of FLAGS) {
      if (incoming[key] === undefined) continue;
      settings[key] = incoming[key] === true;
    }
    patch.settings = settings;
  }

  if (Object.keys(patch).length === 0) return ok({ changed: false });

  const { error } = await db.from("rooms").update(patch).eq("id", roomId);
  if (error) throw error;

  return ok({ changed: true });
}));
