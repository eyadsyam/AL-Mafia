/**
 * `realtime_token` — the one credential a client needs to signal, and the only
 * place membership is turned into access.
 *
 * ## The chain this endpoint is a link in
 *
 * ```
 * Supabase session  →  this function  →  membership re-checked  →  scoped JWT
 *                                                              →  Metered
 * ```
 *
 * The client never names a channel. It sends a room id, and it gets back a
 * channel derived from that room id — after `loadMembership` has confirmed the
 * caller is seated in it. Those two facts together are what make a channel name
 * a proof rather than a request: there is no argument to this function that
 * widens what it returns.
 *
 * ## Why it is called again on every reconnect
 *
 * The SDK's `tokenProvider` runs on the first connect and on every reconnect,
 * which means this runs again too — and every one of the checks below runs
 * with it. A player kicked while their phone was in a tunnel does not come back
 * when the socket does: the refresh is refused, the socket closes, and the mesh
 * degrades to text. A long-lived token could not do that.
 *
 * ## What is refused
 *
 *   - no Supabase session                      → 401, from `handler`
 *   - a room the caller is not seated in       → 403 NOT_A_MEMBER
 *   - a seat the caller has left or been kicked from → 403 NOT_A_MEMBER
 *   - a match that has finished                → 403 ROOM_FINISHED
 *
 * ## What comes back
 *
 * A token, the channel it is scoped to, this peer's id, an opaque session id,
 * an expiry, and public STUN. Nothing about a role, a seat, another player, the match seed, or the
 * signing key. The relay credentials are deliberately *not* here: Metered
 * injects those into the welcome frame at connect time, so they never pass
 * through this response at all.
 *
 * ## Failure is a value
 *
 * Non-negotiable 5: voice is never load-bearing. A deployment with no Realtime
 * key answers 200 with `token: null` and the STUN ladder, and the client falls
 * back to signalling over Postgres exactly as it did before. A 500 here would
 * take the match down with the microphone.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import {
  mintRealtimeToken,
  realtimeKey,
  sessionIdFor,
} from "../_shared/metered_realtime.ts";

/** The floor of the ICE ladder, and what a client uses until the welcome frame
 * arrives with Metered's relay. */
const STUN_ONLY = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
];

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const roomId = String(body.roomId ?? "");
  if (!roomId) return fail("BAD_REQUEST", "roomId is required");

  const membership = await loadMembership(db, roomId, userId);
  if (!membership) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // A finished match keeps its rows, so membership alone would still say yes.
  if (membership.status === "finished") {
    return fail("ROOM_FINISHED", "that match is over", 403);
  }

  // `loadMembership` reports the *room's* status; this is the seat's. A player
  // who was kicked still has a row — `kick_player` sets it to 'left' rather
  // than deleting it, so that the ban survives — and this is where that row
  // stops being a credential.
  const seat = await db
    .from("room_players")
    .select("status")
    .eq("room_id", roomId)
    .eq("user_id", userId)
    .maybeSingle();
  if (seat.data?.status === "left") {
    return fail("NOT_A_MEMBER", "you are no longer in that room", 403);
  }

  // F11: a voice restriction takes this account off voice, and only voice.
  // The match does not need it (non-negotiable 5).
  const { data: restricted } = await db.rpc("safety_restricted", { p_user: userId, p_kind: "voice" });
  if (restricted === true) {
    return fail("ACCOUNT_RESTRICTED", "voice is restricted for this account", 403);
  }

  const key = realtimeKey();
  if (!key) {
    console.warn("METERED_REALTIME_SECRET_KEY unset — signalling over Postgres");
    return ok({
      token: null,
      channel: null,
      peerId: userId,
      sessionId: null,
      expiresAt: null,
      iceServers: STUN_ONLY,
      reason: "no-realtime-key",
    });
  }

  const grant = await mintRealtimeToken(key, userId, roomId);
  // Every member of this room derives the same value, and nobody outside it can
  // derive it at all. It is what binds a signalling envelope to this match.
  const sessionId = await sessionIdFor(key, roomId, membership.matchSeed);
  return ok({ ...grant, sessionId, iceServers: STUN_ONLY, reason: null });
}));
