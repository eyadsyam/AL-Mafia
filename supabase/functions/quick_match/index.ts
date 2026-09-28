import { fail, handler, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const name = String(body.name ?? "").trim();
  if (!name || name.length > 20) return fail("BAD_REQUEST", "valid name required");
  const gender = ["male", "female"].includes(body.gender) ? body.gender : "unspecified";
  const { data, error } = await db.rpc("quick_match_atomic", {
    p_user: userId, p_name: name, p_gender: gender,
  });
  if (error) {
    const message = String(error.message ?? "");
    if (message.includes("NEW_ROOMS_PAUSED")) {
      return fail("NEW_ROOMS_PAUSED", "new rooms are temporarily paused", 503);
    }
    if (message.includes("ACCOUNT_RESTRICTED")) {
      return fail("ACCOUNT_RESTRICTED", "this account cannot join public tables now", 403);
    }
    if (message.includes("NAME_NOT_ALLOWED")) return fail("NAME_NOT_ALLOWED", "that name is not allowed");
    throw error;
  }
  return ok(data);
}));
