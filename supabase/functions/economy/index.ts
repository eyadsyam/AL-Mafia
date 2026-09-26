import { fail, handler, ok } from "../_shared/api.ts";
import { economyCall, refusalOf } from "../_shared/economy_actions.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const call = economyCall(body ?? {}, userId);
  if (!call) return fail("BAD_REQUEST", "invalid economy request");
  const { data, error } = await db.rpc(call.rpc, call.args);
  if (error) {
    const refusal = refusalOf(error.message);
    if (refusal === "INSUFFICIENT_COINS") {
      return fail("INSUFFICIENT_COINS", "not enough coins");
    }
    if (refusal === "ITEM_NOT_FOUND") {
      return fail("BAD_REQUEST", "item is not available");
    }
    if (refusal === "ITEM_NOT_OWNED") {
      return fail("BAD_REQUEST", "item cannot be equipped");
    }
    if (error.message === "BAD_REQUEST") {
      return fail("BAD_REQUEST", "item cannot be equipped");
    }
    if (refusal) return fail(refusal as never, refusal.toLowerCase(), 409);
    throw error;
  }
  return ok(data);
}));
