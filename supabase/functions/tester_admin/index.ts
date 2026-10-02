/**
 * `tester_admin` — the owner's `/admin/testers` page.
 *
 *   list  {}                      visits to /beta and every sign-up
 *   mark  { id, added }           ticks a sign-up as added to the Play list
 *
 * Both are refused by the database to anyone outside `commerce_admins`.
 */

import { fail, handler, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json();
  switch (body?.action) {
    case "list": {
      const { data, error } = await db.rpc("admin_testers", { p_admin: userId });
      if (error) {
        if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
        throw error;
      }
      return ok(data);
    }
    case "mark": {
      if (!Number.isInteger(body.id) || typeof body.added !== "boolean") {
        return fail("BAD_REQUEST", "invalid tester request");
      }
      const { error } = await db.rpc("admin_tester_mark", {
        p_admin: userId, p_id: body.id, p_added: body.added,
      });
      if (error) {
        if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
        throw error;
      }
      return ok({ ok: true });
    }
  }
  return fail("BAD_REQUEST", "invalid tester request");
}));
