import { fail, handler, ok } from "../_shared/api.ts";

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
