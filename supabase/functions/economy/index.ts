import { fail, handler, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const action = body.action;
  let rpc: string;
  let args: Record<string, unknown>;
  if (action === "summary") {
    rpc = "wallet_snapshot";
    args = { p_user: userId };
  } else if (action === "sync") {
    rpc = "sync_player_rewards";
    args = { p_user: userId };
  } else if (action === "buy" && typeof body.item === "string") {
    rpc = "buy_reward_item";
    args = { p_user: userId, p_item: body.item };
  } else if (action === "create_ad_claim" && typeof body.roomId === "string") {
    rpc = "create_ad_reward_claim";
    args = { p_user: userId, p_room: body.roomId };
  } else if (action === "ad_status" && typeof body.roomId === "string") {
    rpc = "ad_reward_status";
    args = { p_user: userId, p_room: body.roomId };
  } else {
    return fail("BAD_REQUEST", "invalid economy request");
  }
  const { data, error } = await db.rpc(rpc, args);
  if (error) {
    if (error.message === "INSUFFICIENT_COINS") {
      return fail("INSUFFICIENT_COINS", "not enough coins");
    }
    if (error.message === "ITEM_NOT_FOUND") {
      return fail("BAD_REQUEST", "item is not available");
    }
    throw error;
  }
  return ok(data);
}));
