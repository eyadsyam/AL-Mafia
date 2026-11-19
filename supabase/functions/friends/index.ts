/**
 * `friends` — «أصحابك» and invites. One endpoint:
 *   status                    friends (with presence), requests, recent tablemates, invites, me
 *   request  { userId }       ask a recent tablemate (asking back accepts)
 *   respond  { userId, accept }
 *   remove   { userId }
 *   invite   { userId | handle, roomId }  into the lobby the caller sits in
 *   inbox / respondInvite { inviteId, accept }
 *   hello { name, gender, tz, locale } / me / setHandle { handle } / prefs
 *   search { query, page } / discover { filter, page }
 *   registerPush { token, platform }
 *   watchRooms { on } / watchRoomsStatus   «فكّرني لما ناس تتجمع» → { on }
 *   requestByHandle { handle }            S2: ask anyone by exact @handle
 *   privacy { whoCanAdd?, showOnline?, searchable? }   S6
 *   ping { userId, kind } / pings          S3: «يلا نلعب؟» and its answers
 *   profile { userId }                     S4: a friend's finished-match history
 * Routing and validation: _shared/friends_actions.ts. All rules live in SQL
 * (20260928000300_friends.sql, 20260930000100_invites_push.sql).
 */
import { fail, handler, loadMembership, ok, type ErrorCode } from "../_shared/api.ts";
import { friendsCall, needsMembership } from "../_shared/friends_actions.ts";
import { sendPush, type PushDeps, type PushTarget } from "../_shared/push.ts";
import { serviceAccountToken } from "../_shared/play_auth.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const call = friendsCall(body ?? {}, userId);
  if (!call) return fail("BAD_REQUEST", "invalid request");
  if (needsMembership.has(String(body.action))) {
    // Only someone seated in the room can bring a friend to it (SQL checks
    // again; this refuses a stranger before any work).
    if (!(await loadMembership(db, String(call.args.p_room), userId))) {
      return fail("NOT_A_MEMBER", "not in this room", 403);
    }
  }

  const { data, error } = await db.rpc(call.fn, call.args);
  if (error) {
    const known: Record<string, [ErrorCode, number]> = {
      FEATURE_OFF: ["BAD_REQUEST", 400],
      NOT_ALLOWED: ["BAD_REQUEST", 403],
      FRIENDS_FULL: ["BAD_REQUEST", 400],
      HANDLE_TAKEN: ["BAD_REQUEST", 409],
      HANDLE_LOCKED: ["HANDLE_LOCKED", 409],
      NAME_NOT_ALLOWED: ["NAME_NOT_ALLOWED", 400],
      RATE_LIMITED: ["RATE_LIMITED", 429],
      NOT_A_MEMBER: ["NOT_A_MEMBER", 403],
      BAD_REQUEST: ["BAD_REQUEST", 400],
    };
    const hit = Object.keys(known).find((k) => error.message?.includes(k));
    if (hit) return fail(known[hit][0], hit, known[hit][1]);
    throw error;
  }

  const deps: PushDeps = {
    secret: Deno.env.get("FCM_SERVICE_ACCOUNT_B64"),
    accessToken: (raw) => serviceAccountToken(raw, "https://www.googleapis.com/auth/firebase.messaging"),
    fetch,
    dropToken: async (token) => { await db.rpc("push_token_drop", { p_token: token }); },
    log: (line) => console.log(line),
  };

  // A fresh invite rings the recipient's phone. Best effort: a missing
  // secret, a dead token or FCM itself never fails the invite.
  if (call.fn === "room_invite_send" && data?.fresh === true && typeof data.inviteId === "string") {
    try {
      const { data: target } = await db.rpc("invite_push_targets", { p_invite: data.inviteId });
      await sendPush((target ?? { enabled: false }) as PushTarget, deps);
    } catch {
      console.log("push skipped: error");
    }
    return ok({ invited: true, inviteId: data.inviteId });
  }

  // S3: a fresh ping rings the friend, outside quiet hours (SQL decides).
  if (call.fn === "friend_ping") {
    if (typeof data?.pingId === "number") {
      try {
        const { data: target } = await db.rpc("friend_ping_push_targets", { p_ping: data.pingId });
        await sendPush((target ?? { enabled: false }) as PushTarget, deps);
      } catch {
        console.log("push skipped: error");
      }
    }
    return ok({ sent: true });
  }

  // D: a friend request, or accepting one, reaches the other phone quietly.
  const requested = call.fn === "friend_request_by_handle" ? data?.target : call.args.p_target;
  if (call.fn === "friend_request" || call.fn === "friend_request_by_handle" ||
    (call.fn === "friend_respond" && call.args.p_accept === true)) {
    try {
      const { data: target } = await db.rpc("friend_push_targets", {
        p_from: userId, p_to: requested,
      });
      await sendPush((target ?? { enabled: false }) as PushTarget, deps);
    } catch {
      console.log("push skipped: error");
    }
  }
  // The inbox is a list and the name rule a boolean; every answer is an object.
  if (call.fn === "safety_name_allowed") return ok({ allowed: data === true });
  if (call.fn === "room_watch_set" || call.fn === "room_watch_get") return ok({ on: data === true });
  if (call.fn === "friend_pings_inbox") return ok({ pings: data });
  // S3: the status answer carries my unexpired pings, so one read draws the sheet.
  if (call.fn === "friends_status" && data && typeof data === "object" && data.enabled !== false) {
    const { data: pings, error: pingsError } = await db.rpc("friend_pings_inbox", { p_user: userId });
    return ok({ ...(data as Record<string, unknown>), pings: pingsError ? [] : pings ?? [] });
  }
  if (call.fn === "friend_request_by_handle" && data && typeof data === "object") {
    // The target's id is for the push above only; the answer is the status.
    const { target: _target, ...status } = data as Record<string, unknown>;
    return ok(status);
  }
  return ok(call.fn === "invites_inbox" ? { invites: data } : data);
}));
