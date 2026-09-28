/**
 * `friends` — «أصحابك». One endpoint, five actions:
 *   status                    friends (with presence), requests, recent tablemates, invites
 *   request  { userId }       ask a recent tablemate (asking back accepts)
 *   respond  { userId, accept }
 *   remove   { userId }
 *   invite   { userId, roomId } into the lobby the caller sits in
 * All rules live in SQL (20260928000300_friends.sql); this only routes.
 */
import { fail, handler, loadMembership, ok, type ErrorCode } from "../_shared/api.ts";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? "status");
  const target = body.userId == null ? null : String(body.userId);
  if (target != null && !uuid.test(target)) return fail("BAD_REQUEST", "invalid userId");

  let call: { fn: string; args: Record<string, unknown> };
  switch (action) {
    case "status":
      call = { fn: "friends_status", args: { p_user: userId } };
      break;
    case "request":
      if (!target) return fail("BAD_REQUEST", "userId required");
      call = { fn: "friend_request", args: { p_user: userId, p_target: target } };
      break;
    case "respond":
      if (!target || typeof body.accept !== "boolean") return fail("BAD_REQUEST", "userId and accept required");
      call = { fn: "friend_respond", args: { p_user: userId, p_target: target, p_accept: body.accept } };
      break;
    case "remove":
      if (!target) return fail("BAD_REQUEST", "userId required");
      call = { fn: "friend_remove", args: { p_user: userId, p_target: target } };
      break;
    case "invite": {
      const roomId = String(body.roomId ?? "");
      if (!target || !uuid.test(roomId)) return fail("BAD_REQUEST", "userId and roomId required");
      // Only someone seated in the room can bring a friend to it (SQL checks
      // again; this refuses a stranger before any work).
      if (!(await loadMembership(db, roomId, userId))) {
        return fail("NOT_A_MEMBER", "not in this room", 403);
      }
      call = { fn: "friend_invite", args: { p_user: userId, p_target: target, p_room: roomId } };
      break;
    }
    default:
      return fail("BAD_REQUEST", "unknown action");
  }

  const { data, error } = await db.rpc(call.fn, call.args);
  if (error) {
    const known: Record<string, [ErrorCode, number]> = {
      FEATURE_OFF: ["BAD_REQUEST", 400],
      NOT_ALLOWED: ["BAD_REQUEST", 403],
      FRIENDS_FULL: ["BAD_REQUEST", 400],
      RATE_LIMITED: ["RATE_LIMITED", 429],
      NOT_A_MEMBER: ["NOT_A_MEMBER", 403],
      BAD_REQUEST: ["BAD_REQUEST", 400],
    };
    const hit = Object.keys(known).find((k) => error.message?.includes(k));
    if (hit) return fail(known[hit][0], hit, known[hit][1]);
    throw error;
  }
  return ok(data);
}));
