import { fail, handler, ok } from "../_shared/api.ts";
import { reviewActions, reviewAllowed, shapeReview } from "../_shared/owner_review.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json();
  const action = body?.action;
  if (typeof action !== "string" || !reviewActions.has(action) ||
      (body.query != null && (typeof body.query !== "string" || body.query.length > 40))) {
    return fail("BAD_REQUEST", "invalid owner review request");
  }
  // The edge boundary checks membership before any read, including the RPC.
  const { data: admin, error: adminError } = await db.from("commerce_admins")
    .select("user_id").eq("user_id", userId).maybeSingle();
  if (adminError) throw adminError;
  if (!reviewAllowed(admin != null)) return fail("NOT_ADMIN", "not an administrator", 403);
  const { data, error } = await db.rpc("owner_review", {
    p_admin: userId, p_action: action, p_query: body.query ?? "",
  });
  if (error) {
    if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
    if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid owner review request");
    throw error;
  }
  return ok(shapeReview(action, data ?? {}));
}));
