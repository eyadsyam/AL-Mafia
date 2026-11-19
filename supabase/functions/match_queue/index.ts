/**
 * `match_queue` — «استناني» and «ليلة اللعب». One endpoint, POST {action, ...}:
 *   join { name, gender }     -> { queued: true, count }  or, when the caller got a seat
 *                                (an existing one, or a public lobby with people in it),
 *                                the quick_match answer { roomId, code, seat, rejoined | created, ... }
 *   leave {}                  -> { left: true }
 *   status {}                 -> { queued, count, round: { id, deadline, confirmed, total } | null,
 *                                  me: { confirmed } | null, room: { roomId, code, seat } | null }
 *   ready { roundId, yes }    -> { queued, confirmed }
 *   playNightStatus {}        -> { startsAt, endsAt, active, reminded, remindedCount | null, queueCount }
 *   playNightRemind { on }    -> { reminded }
 * Every rule lives in SQL (20261119000800_match_queue.sql, 20261119000900_play_night.sql);
 * the caller is the JWT's user, never a body field. `quick_match` is unchanged for old builds.
 */
import { fail, handler, ok } from "../_shared/api.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const action = String(body?.action ?? "");

  const refuse = (error: { message?: string }): Response => {
    const message = String(error.message ?? "");
    if (message.includes("NEW_ROOMS_PAUSED")) {
      return fail("NEW_ROOMS_PAUSED", "new rooms are temporarily paused", 503);
    }
    if (message.includes("ACCOUNT_RESTRICTED")) {
      return fail("ACCOUNT_RESTRICTED", "this account cannot join public tables now", 403);
    }
    if (message.includes("NAME_NOT_ALLOWED")) return fail("NAME_NOT_ALLOWED", "that name is not allowed");
    if (message.includes("ROUND_CLOSED")) return fail("ROUND_CLOSED", "this round is closed");
    // The lobby filled or started between the pick and the seat: try again.
    if (message.includes("ROOM_FULL")) return fail("ROOM_FULL", "that room just filled", 409);
    if (message.includes("ROOM_UNAVAILABLE")) return fail("ROOM_UNAVAILABLE", "that room just closed", 409);
    if (message.includes("PHASE_CLOSED")) return fail("PHASE_CLOSED", "that room just started", 409);
    if (message.includes("BAD_REQUEST")) return fail("BAD_REQUEST", "invalid request");
    throw error;
  };

  switch (action) {
    case "join": {
      const name = String(body.name ?? "").trim();
      if (!name || name.length > 20) return fail("BAD_REQUEST", "valid name required");
      const gender = ["male", "female"].includes(body.gender) ? body.gender : "unspecified";
      const { data, error } = await db.rpc("queue_join", {
        p_user: userId, p_name: name, p_gender: gender,
      });
      if (error) return refuse(error);
      return ok(data);
    }
    case "leave": {
      const { error } = await db.rpc("queue_leave", { p_user: userId });
      if (error) return refuse(error);
      return ok({ left: true });
    }
    case "status": {
      const { data, error } = await db.rpc("queue_status", { p_user: userId });
      if (error) return refuse(error);
      return ok(data);
    }
    case "ready": {
      const roundId = String(body.roundId ?? "");
      if (!UUID.test(roundId) || typeof body.yes !== "boolean") {
        return fail("BAD_REQUEST", "roundId and yes required");
      }
      const { data, error } = await db.rpc("queue_ready", {
        p_user: userId, p_round: roundId, p_yes: body.yes,
      });
      if (error) return refuse(error);
      return ok(data);
    }
    case "playNightStatus": {
      const { data, error } = await db.rpc("play_night_status", { p_user: userId });
      if (error) return refuse(error);
      return ok(data);
    }
    case "playNightRemind": {
      if (typeof body.on !== "boolean") return fail("BAD_REQUEST", "on required");
      const { data, error } = await db.rpc("play_night_remind", { p_user: userId, p_on: body.on });
      if (error) return refuse(error);
      return ok({ reminded: data === true });
    }
    default:
      return fail("BAD_REQUEST", "unknown action");
  }
}));
