import { fail, handler, ok } from "../_shared/api.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const uuid = (v: unknown): string | null =>
  typeof v === "string" && UUID.test(v) ? v.toLowerCase() : null;

/**
 * F11 — Safety v11 actions, next to the original report/block/delete.
 *
 *   report_v11   {context, roomId?, seat?, targetId?, category, details?, requestId}
 *   block_user   {targetId}                     (the friends list has no seat)
 *   status       {}                             restrictions + unseen notices
 *   ack          {noticeId}
 *   admin_list   {status?, category?, cursor?}  owner only
 *   admin_resolve {reportId, decision, durationDays?, note?, requestId}
 *   admin_purge  {requestId}
 *   witness_report {roomId, whisperId, category, requestId}   (F21a, the dead)
 *
 * Every refusal is a fixed sentence; nothing a reporter sends comes back.
 */
async function v11(body: Record<string, unknown>, userId: string, db: any) {
  switch (body.action) {
    case "report_v11": {
      const requestId = uuid(body.requestId);
      if (!requestId || typeof body.context !== "string" || typeof body.category !== "string" ||
          (body.seat != null && !Number.isInteger(body.seat)) ||
          (body.details != null && typeof body.details !== "string")) {
        return fail("BAD_REQUEST", "invalid safety request");
      }
      const { data, error } = await db.rpc("safety_report", {
        p_user: userId, p_context: body.context, p_room: uuid(body.roomId),
        p_seat: body.seat ?? null, p_target: uuid(body.targetId), p_category: body.category,
        p_details: body.details ?? "", p_request: requestId,
      });
      if (error) {
        if (error.message === "NOT_A_MEMBER") return fail("NOT_A_MEMBER", "you cannot report this player", 403);
        if (error.message === "RATE_LIMITED") return fail("RATE_LIMITED", "report limit reached for today", 429);
        if (error.message === "BAD_REQUEST" || error.code === "22P02") return fail("BAD_REQUEST", "invalid safety request");
        throw error;
      }
      return ok(data);
    }
    case "block_user": {
      const target = uuid(body.targetId);
      if (!target) return fail("BAD_REQUEST", "invalid safety request");
      const { error } = await db.rpc("safety_block", { p_user: userId, p_target: target });
      if (error) {
        if (error.message === "RATE_LIMITED") return fail("RATE_LIMITED", "block limit reached", 429);
        if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid safety request");
        throw error;
      }
      return ok({ blocked: true });
    }
    case "status": {
      const { data, error } = await db.rpc("safety_my_status", { p_user: userId });
      if (error) throw error;
      return ok(data);
    }
    case "ack": {
      const notice = uuid(body.noticeId);
      if (!notice) return fail("BAD_REQUEST", "invalid safety request");
      const { data, error } = await db.rpc("safety_ack_notice", { p_user: userId, p_notice: notice });
      if (error) throw error;
      return ok({ acknowledged: data === true });
    }
    case "admin_list": {
      if ((body.status != null && typeof body.status !== "string") ||
          (body.category != null && typeof body.category !== "string") ||
          (body.cursor != null && typeof body.cursor !== "string")) {
        return fail("BAD_REQUEST", "invalid safety request");
      }
      const { data, error } = await db.rpc("admin_safety_list", {
        p_admin: userId, p_status: body.status ?? null, p_category: body.category ?? null,
        p_cursor: body.cursor ?? null, p_limit: 25,
      });
      if (error) {
        if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
        if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid safety request");
        throw error;
      }
      return ok(data);
    }
    case "admin_resolve": {
      const report = uuid(body.reportId);
      const requestId = uuid(body.requestId);
      if (!report || !requestId || typeof body.decision !== "string" ||
          (body.durationDays != null && !Number.isInteger(body.durationDays)) ||
          (body.note != null && typeof body.note !== "string")) {
        return fail("BAD_REQUEST", "invalid safety request");
      }
      const { data, error } = await db.rpc("admin_safety_resolve", {
        p_admin: userId, p_report: report, p_action: body.decision,
        p_days: body.durationDays ?? null, p_note: body.note ?? "", p_request: requestId,
      });
      if (error) {
        if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
        if (error.message === "REPORT_CLOSED") return fail("REPORT_CLOSED", "this report is already closed", 409);
        if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid safety request");
        throw error;
      }
      return ok(data);
    }
    case "witness_report": {
      const room = uuid(body.roomId);
      const whisper = uuid(body.whisperId);
      const requestId = uuid(body.requestId);
      if (!room || !whisper || !requestId || typeof body.category !== "string") {
        return fail("BAD_REQUEST", "invalid safety request");
      }
      const { data, error } = await db.rpc("witness_report", {
        p_user: userId, p_room: room, p_whisper: whisper,
        p_category: body.category, p_request: requestId,
      });
      if (error) {
        if (error.message === "WITNESS_ONLY") return fail("WITNESS_ONLY", "only an eliminated player reports a witnessed whisper", 403);
        if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid safety request");
        throw error;
      }
      return ok(data);
    }
    case "admin_purge": {
      const requestId = uuid(body.requestId);
      if (!requestId) return fail("BAD_REQUEST", "invalid safety request");
      const { data, error } = await db.rpc("purge_safety_evidence", { p_admin: userId, p_request: requestId });
      if (error) {
        if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
        throw error;
      }
      return ok(data);
    }
  }
  return null;
}

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json();
  if (body.action === "accept_terms") {
    if (typeof body.version !== "string" || body.adult !== true ||
        (body.acceptedAt != null && typeof body.acceptedAt !== "string")) {
      return fail("BAD_REQUEST", "invalid terms acceptance");
    }
    const { error } = await db.rpc("record_terms_acceptance", {
      p_user: userId, p_version: body.version, p_adult: true,
      p_accepted_at: body.acceptedAt ?? null,
    });
    if (error) {
      if (error.message === "BAD_REQUEST" || error.code === "23514") {
        return fail("BAD_REQUEST", "invalid terms acceptance");
      }
      throw error;
    }
    return ok({ recorded: true });
  }
  const handled = await v11(body, userId, db);
  if (handled) return handled;
  if (!["report", "block", "delete"].includes(body.action) ||
      (body.seat != null && !Number.isInteger(body.seat)) ||
      (body.details != null && typeof body.details !== "string")) {
    return fail("BAD_REQUEST", "invalid safety request");
  }
  const { data, error } = await db.rpc("submit_player_safety", {
    p_user: userId, p_action: body.action, p_room: body.roomId ?? null,
    p_seat: body.seat ?? null, p_reason: body.reason ?? "other", p_details: body.details ?? "",
  });
  if (error) {
    if (error.message === "NOT_A_MEMBER") return fail("NOT_A_MEMBER", "room membership required", 403);
    if (error.message === "RATE_LIMITED") return fail("RATE_LIMITED", "daily report limit reached", 429);
    if (error.message === "BAD_REQUEST" || error.code === "22P02") return fail("BAD_REQUEST", "invalid safety request");
    throw error;
  }
  return ok({ receipt: data });
}));
