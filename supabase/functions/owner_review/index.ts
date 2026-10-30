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
  if (action === "feedback" && body.status != null &&
      !["new", "read", "planned"].includes(body.status)) {
    return fail("BAD_REQUEST", "invalid status");
  }
  if (action === "feedbackMark" &&
      (typeof body.id !== "string" || !/^[0-9a-f-]{36}$/i.test(body.id) ||
        !["read", "planned"].includes(body.status))) {
    return fail("BAD_REQUEST", "invalid mark");
  }
  const { data, error } = action === "feedback"
    ? await db.rpc("admin_feedback", { p_admin: userId, p_status: body.status ?? null })
    : action === "feedbackMark"
    ? await db.rpc("admin_feedback_mark", { p_admin: userId, p_id: body.id, p_status: body.status })
    : action === "usage"
    ? await db.rpc("owner_review_usage", { p_admin: userId })
    : await db.rpc("owner_review", {
      p_admin: userId, p_action: action, p_query: body.query ?? "",
    });
  if (error) {
    if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
    if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid owner review request");
    throw error;
  }
  return ok(shapeReview(action, data ?? {}));
}));
