import { fail, handler, ok } from "../_shared/api.ts";

const packageName = "com.mafiamaster.mafia_master";
const expectedProduct = "mafia_scenario_mastermind";

function b64url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = ""; for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function accessToken(): Promise<string> {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("PLAY_NOT_CONFIGURED");
  const account = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${b64url(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion,
    }),
  });
  if (!response.ok) throw new Error("PLAY_AUTH_FAILED");
  return (await response.json()).access_token;
}

async function verifyPurchase(productId: string, token: string) {
  if (productId !== expectedProduct) throw new Error("INVALID_PURCHASE");
  const bearer = await accessToken();
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
    throw error;
  }
}));
