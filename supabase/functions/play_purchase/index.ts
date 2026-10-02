import { fail, handler, ok } from "../_shared/api.ts";
import { playAccessToken } from "../_shared/play_auth.ts";

const packageName = "com.mafiamaster.mafia_master";
const expectedProduct = "mafia_scenario_mastermind";

async function verifyPurchase(productId: string, token: string) {
  if (productId !== expectedProduct) throw new Error("INVALID_PURCHASE");
  const bearer = await playAccessToken();
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${productId}/tokens/${encodeURIComponent(token)}`;
  const response = await fetch(base, { headers: { authorization: `Bearer ${bearer}` } });
  if (response.status === 404) return { state: "revoked" };
  if (!response.ok) throw new Error("PLAY_VERIFY_FAILED");
  const purchase = await response.json();
  const state = purchase.purchaseState === 0 ? "active" :
    purchase.purchaseState === 2 ? "pending" : "revoked";
  if (state === "active" && purchase.acknowledgementState === 0) {
    const ack = await fetch(`${base}:acknowledge`, {
      method: "POST", headers: {
        authorization: `Bearer ${bearer}`, "content-type": "application/json",
      }, body: "{}",
    });
    if (!ack.ok) throw new Error("PLAY_ACK_FAILED");
  }
  return {
    state, orderId: purchase.orderId ?? null,
    purchasedAt: purchase.purchaseTimeMillis
      ? new Date(Number(purchase.purchaseTimeMillis)).toISOString() : null,
  };
}

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  if (body.action === "summary") {
    const { data, error } = await db.rpc("purchase_snapshot", { p_user: userId });
    if (error) throw error; return ok(data);
  }
  if (body.action !== "verify" || typeof body.token !== "string" ||
      typeof body.productId !== "string") {
    return fail("BAD_REQUEST", "invalid purchase request");
  }
  try {
    const verified = await verifyPurchase(body.productId, body.token);
    const { data, error } = await db.rpc("commit_play_purchase", {
      p_user: userId, p_token: body.token, p_product: body.productId,
      p_order: verified.orderId ?? null, p_state: verified.state,
      p_purchased_at: verified.purchasedAt ?? null,
    });
    if (error) throw error; return ok(data);
  } catch (error) {
    if (String(error).includes("PLAY_NOT_CONFIGURED")) {
      return fail("NOT_CONFIGURED", "purchases are not configured");
    }
    if (String((error as { message?: string })?.message ?? error).includes("REBIND_LIMIT")) {
      return fail("REBIND_LIMIT", "this purchase was restored too many times", 409);
    }
    throw error;
  }
}));
