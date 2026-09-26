/**
 * Reads Google Play's `purchases.products.get` answer into the facts the
 * ledger needs. Pure, so the decisions are tested without Google.
 *
 * https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products
 */

export type PlayState = "active" | "pending" | "revoked";

export type ProductPurchaseFacts = {
  state: PlayState;
  orderId: string | null;
  purchasedAt: string | null;
  quantity: number;
  acknowledged: boolean;
  consumed: boolean;
  accountTag: string | null;
};

export type Evaluation =
  | { ok: true; facts: ProductPurchaseFacts }
  | { ok: false; reason: "product_mismatch" | "quantity" | "malformed" };

// deno-lint-ignore no-explicit-any
export function evaluateProductPurchase(purchase: any, productId: string): Evaluation {
  if (!purchase || typeof purchase !== "object") return { ok: false, reason: "malformed" };
  // Newer responses carry the product id; when present it must match the
  // product the token was presented for.
  if (typeof purchase.productId === "string" && purchase.productId !== productId) {
    return { ok: false, reason: "product_mismatch" };
  }
  const quantity = purchase.quantity === undefined || purchase.quantity === null
    ? 1 : Number(purchase.quantity);
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 10) {
    return { ok: false, reason: "quantity" };
  }
  const state: PlayState = purchase.purchaseState === 0
    ? "active"
    : purchase.purchaseState === 2 ? "pending" : "revoked";
  const millis = Number(purchase.purchaseTimeMillis);
  const tag = typeof purchase.obfuscatedExternalAccountId === "string" &&
      purchase.obfuscatedExternalAccountId.length > 0
    ? purchase.obfuscatedExternalAccountId : null;
  return {
    ok: true,
    facts: {
      state,
      orderId: typeof purchase.orderId === "string" ? purchase.orderId : null,
      purchasedAt: Number.isFinite(millis) && millis > 0
        ? new Date(millis).toISOString() : null,
      quantity,
      acknowledged: purchase.acknowledgementState === 1,
      consumed: purchase.consumptionState === 1,
      accountTag: tag,
    },
  };
}

/** What still has to be told to Google after the ledger committed. */
export function followUps(
  facts: ProductPurchaseFacts,
  committed: { needsAcknowledge?: boolean; needsConsume?: boolean },
): { acknowledge: boolean; consume: boolean; alreadyConsumed: boolean } {
  const active = facts.state === "active";
  return {
    acknowledge: active && committed.needsAcknowledge === true && !facts.acknowledged,
    // Only after a durable credit (needsConsume comes from the ledger).
    consume: active && committed.needsConsume === true && !facts.consumed,
    alreadyConsumed: committed.needsConsume === true && facts.consumed,
  };
}
