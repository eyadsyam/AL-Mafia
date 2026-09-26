import { fail, handler, ok } from "../_shared/api.ts";
import { playAccessToken } from "../_shared/play_auth.ts";
import { evaluateProductPurchase, followUps } from "../_shared/play_verify.ts";

const packageName = "com.mafiamaster.mafia_master";
// The original scenario product: kept verifiable for anyone who bought it,
// never offered for sale again.
const legacyScenario = "mafia_scenario_mastermind";
const PRODUCT_ID = /^[a-z0-9_.]{3,100}$/;

function purchaseUrl(productId: string, token: string) {
  return `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${productId}/tokens/${encodeURIComponent(token)}`;
}

async function verifyLegacy(token: string) {
  const bearer = await playAccessToken();
  const base = purchaseUrl(legacyScenario, token);
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

async function post(url: string, bearer: string): Promise<boolean> {
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { authorization: `Bearer ${bearer}`, "content-type": "application/json" },
      body: "{}",
    });
    return response.ok;
  } catch (_) {
    return false;
  }
}

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  if (body.action === "summary") {
    const { data, error } = await db.rpc("purchase_snapshot", { p_user: userId });
    if (error) throw error; return ok(data);
  }
  if (body.action !== "verify" || typeof body.token !== "string" ||
      typeof body.productId !== "string" || !PRODUCT_ID.test(body.productId)) {
    return fail("BAD_REQUEST", "invalid purchase request");
  }
  try {
    if (body.productId === legacyScenario) {
      const verified = await verifyLegacy(body.token);
      const { data, error } = await db.rpc("commit_play_purchase", {
        p_user: userId, p_token: body.token, p_product: body.productId,
        p_order: verified.orderId ?? null, p_state: verified.state,
        p_purchased_at: verified.purchasedAt ?? null,
      });
      if (error) throw error; return ok(data);
    }

    const bearer = await playAccessToken();
    const base = purchaseUrl(body.productId, body.token);
    const response = await fetch(base, { headers: { authorization: `Bearer ${bearer}` } });
    let purchase: unknown;
    if (response.status === 404 || response.status === 410) {
      purchase = { purchaseState: 1 };
    } else if (!response.ok) {
      throw new Error("PLAY_VERIFY_FAILED");
    } else {
      purchase = await response.json();
    }
    const evaluation = evaluateProductPurchase(purchase, body.productId);
    if (!evaluation.ok) return fail("BAD_REQUEST", "purchase does not match", 409);
    const facts = evaluation.facts;
    const { data, error } = await db.rpc("commit_play_product", {
      p_user: userId, p_token: body.token, p_product: body.productId,
      p_order: facts.orderId, p_state: facts.state, p_purchased_at: facts.purchasedAt,
      p_quantity: facts.quantity, p_account_tag: facts.accountTag,
    });
    if (error) {
      const message = String(error.message ?? "");
      if (message.includes("ACCOUNT_MISMATCH")) {
        return fail("ACCOUNT_MISMATCH", "purchase belongs to another account", 409);
      }
      if (message.includes("PRODUCT_UNKNOWN")) {
        return fail("PRODUCT_UNKNOWN", "product is not sold here", 409);
      }
      if (message.includes("REBIND_LIMIT")) {
        return fail("REBIND_LIMIT", "this purchase was restored too many times", 409);
      }
      throw error;
    }
    const committed = data as { needsAcknowledge?: boolean; needsConsume?: boolean };
    const next = followUps(facts, committed);
    let acknowledgePending = false;
    let consumePending = false;
    if (next.acknowledge) acknowledgePending = !(await post(`${base}:acknowledge`, bearer));
    if (next.alreadyConsumed) {
      await db.rpc("mark_play_consumed", { p_token: body.token });
    } else if (next.consume) {
      // Credited durably above; consuming now lets the pack be bought again.
      // A failure here is retried by the next verify, which cannot credit twice.
      if (await post(`${base}:consume`, bearer)) {
        await db.rpc("mark_play_consumed", { p_token: body.token });
      } else {
        consumePending = true;
      }
    }
    return ok({ ...(data as Record<string, unknown>), acknowledgePending, consumePending });
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
