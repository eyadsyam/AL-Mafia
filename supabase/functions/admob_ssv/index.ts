import { serviceClient } from "../_shared/api.ts";

const keyUrl = "https://www.gstatic.com/admob/reward/verifier-keys.json";
let cachedKeys: { at: number; keys: Map<number, string> } | null = null;

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function derToRaw(signature: Uint8Array, width = 32): Uint8Array {
  if (signature[0] !== 0x30) throw new Error("invalid DER signature");
  let cursor = signature[1] & 0x80 ? 2 + (signature[1] & 0x7f) : 2;
  if (signature[cursor++] !== 0x02) throw new Error("invalid DER r");
  const rLength = signature[cursor++];
  const r = signature.slice(cursor, cursor + rLength); cursor += rLength;
  if (signature[cursor++] !== 0x02) throw new Error("invalid DER s");
  const sLength = signature[cursor++];
  const s = signature.slice(cursor, cursor + sLength);
  const raw = new Uint8Array(width * 2);
  raw.set(r.slice(Math.max(0, r.length - width)), width - Math.min(width, r.length));
  raw.set(s.slice(Math.max(0, s.length - width)), width * 2 - Math.min(width, s.length));
  return raw;
}

async function keys(): Promise<Map<number, string>> {
  if (cachedKeys && Date.now() - cachedKeys.at < 60 * 60 * 1000) return cachedKeys.keys;
  const response = await fetch(keyUrl);
  if (!response.ok) throw new Error("key fetch failed");
  const body = await response.json();
  const map = new Map<number, string>();
  for (const key of body.keys ?? []) map.set(Number(key.keyId), String(key.base64));
  if (!map.size) throw new Error("no verifier keys");
  cachedKeys = { at: Date.now(), keys: map };
  return map;
}

async function verify(url: URL): Promise<boolean> {
  const rawQuery = url.search.slice(1);
  const marker = "&signature=";
  const signatureAt = rawQuery.indexOf(marker);
  if (signatureAt < 1) return false;
  const signed = new TextEncoder().encode(rawQuery.slice(0, signatureAt));
  const signature = url.searchParams.get("signature");
  const keyId = Number(url.searchParams.get("key_id"));
  if (!signature || !Number.isSafeInteger(keyId)) return false;
  const encodedKey = (await keys()).get(keyId);
  if (!encodedKey) return false;
  const publicKey = await crypto.subtle.importKey(
    "spki", Uint8Array.from(atob(encodedKey), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
  );
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, publicKey,
    derToRaw(decodeBase64Url(signature)), signed,
  );
}

Deno.serve(async (request) => {
  try {
    if (request.method !== "GET") return new Response("method", { status: 405 });
    const url = new URL(request.url);
    let authentic = false;
    try {
      authentic = await verify(url);
    } catch (_) {
      // Malformed callbacks are permanent client errors. Returning 5xx would
      // make the sender retry an invalid signature indefinitely.
    }
    if (!authentic) return new Response("invalid signature", { status: 400 });
    const claimId = url.searchParams.get("custom_data");
    const transaction = url.searchParams.get("transaction_id");
    const adUnit = url.searchParams.get("ad_unit");
    const userId = url.searchParams.get("user_id");
    const rewardAmount = Number(url.searchParams.get("reward_amount"));
    const expected = Deno.env.get("ADMOB_REWARDED_ANDROID_ID")?.split("/").pop();
    if (!claimId || !transaction || !adUnit || !userId || !expected || adUnit !== expected ||
        !Number.isSafeInteger(rewardAmount) || rewardAmount <= 0) {
      return new Response("invalid reward", { status: 400 });
    }
    const db = serviceClient();
    const { error } = await db.rpc("commit_ad_reward", {
      p_claim: claimId, p_transaction: transaction, p_ad_unit: adUnit,
      p_reward_amount: rewardAmount, p_ssv_user: userId,
    });
    if (error) throw error;
    return new Response("ok", { status: 200 });
  } catch (_) {
    return new Response("retry", { status: 500 });
  }
});
