/**
 * `delete_account` — the player deletes their own account and data from
 * inside the app (Google Play's account-deletion requirement).
 *
 *   { confirm: true }
 *
 * The account is the JWT's: there is no field naming whose data to delete, so
 * there is nobody else's account to reach. The work is `delete_my_account`,
 * which runs the same `complete_data_deletion` chain the operator uses. It
 * refuses while the player is in an unfinished room (`IN_MATCH`) or has a
 * payment under review (`ORDER_OPEN`); both are fixed sentences the app
 * translates, and nothing has been deleted when they are sent.
 */

import { fail, handler, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  if (body?.confirm !== true) return fail("BAD_REQUEST", "confirmation required");
  const { data, error } = await db.rpc("delete_my_account", { p_user: userId });
  if (error) {
    if (error.message === "ACTIVE_ROOM") {
      return fail("IN_MATCH", "leave your room before deleting the account", 409);
    }
    if (error.message === "ORDER_UNDER_REVIEW") {
      return fail("ORDER_OPEN", "a payment is still under review", 409);
    }
    throw error;
  }
  return ok(data ?? { deleted: true });
}));
