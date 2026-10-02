/**
 * AdMob server-side verification, without I/O of its own so it can be tested.
 *
 * The distinction this module exists for: a callback that is malformed or
 * carries a bad signature is permanently wrong (HTTP 400, AdMob stops), but a
 * callback we could not check because Google's verifier keys were unreachable
 * is a correct reward we must not lose (HTTP 503, AdMob retries).
 */

export type VerifierKeys = Map<number, string>;

/** Google's key list could not be fetched or read. Retryable. */
export class KeysUnavailable extends Error {}

export type SsvResult = "valid" | "invalid";

function decodeBase64Url(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function derToRaw(signature: Uint8Array, width = 32): Uint8Array<ArrayBuffer> {
  if (signature[0] !== 0x30) throw new Error("invalid DER signature");
  let cursor = signature[1] & 0x80 ? 2 + (signature[1] & 0x7f) : 2;
  if (signature[cursor++] !== 0x02) throw new Error("invalid DER r");
  const rLength = signature[cursor++];
  const r = signature.slice(cursor, cursor + rLength); cursor += rLength;
  if (signature[cursor++] !== 0x02) throw new Error("invalid DER s");
  const sLength = signature[cursor++];
  const s = signature.slice(cursor, cursor + sLength);
  if (r.length === 0 || s.length === 0) throw new Error("invalid DER length");
  const raw = new Uint8Array(width * 2);
  raw.set(r.slice(Math.max(0, r.length - width)), width - Math.min(width, r.length));
  raw.set(s.slice(Math.max(0, s.length - width)), width * 2 - Math.min(width, s.length));
  return raw;
}

/**
 * Checks the callback's signature.
 *
 * [loadKeys] is called with `fresh=false` first; if the callback names a key id
 * the (possibly cached) list does not have, it is called once more with
 * `fresh=true`, because Google rotates keys and a cache can predate the new
 * one. Only a key id that is absent from a fresh list is "invalid".
 *
 * Throws [KeysUnavailable] when the keys cannot be obtained; every other
 * failure — bad query, bad key id, bad DER, wrong signature — is "invalid".
 */
export async function verifySsv(
  url: URL,
  loadKeys: (fresh: boolean) => Promise<VerifierKeys>,
): Promise<SsvResult> {
  const rawQuery = url.search.slice(1);
  const marker = "&signature=";
  const signatureAt = rawQuery.indexOf(marker);
  if (signatureAt < 1) return "invalid";
  const signed = new TextEncoder().encode(rawQuery.slice(0, signatureAt));
  const signature = url.searchParams.get("signature");
  const keyId = Number(url.searchParams.get("key_id"));
  if (!signature || !Number.isSafeInteger(keyId)) return "invalid";

  let encodedKey = (await loadKeys(false)).get(keyId);
  if (!encodedKey) encodedKey = (await loadKeys(true)).get(keyId);
  if (!encodedKey) return "invalid";

  try {
    const publicKey = await crypto.subtle.importKey(
      "spki", Uint8Array.from(atob(encodedKey), (c) => c.charCodeAt(0)),
      { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
    );
    const ok = await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" }, publicKey,
      derToRaw(decodeBase64Url(signature)), signed,
    );
    return ok ? "valid" : "invalid";
  } catch {
    return "invalid";
  }
}

/**
 * A key loader over [fetcher] with an hour's cache. A forced refresh is
 * rate-limited to one a minute, so a stream of callbacks naming a bogus key id
 * cannot turn this function into a proxy hammering Google.
 */
export function cachedKeyLoader(
  fetcher: () => Promise<VerifierKeys>,
  now: () => number = Date.now,
): (fresh: boolean) => Promise<VerifierKeys> {
  let cache: { at: number; keys: VerifierKeys } | null = null;
  return async (fresh) => {
    const age = cache ? now() - cache.at : Infinity;
    if (cache && age < 60 * 60 * 1000 && (!fresh || age < 60 * 1000)) {
      return cache.keys;
    }
    let keys: VerifierKeys;
    try {
      keys = await fetcher();
    } catch (error) {
      throw error instanceof KeysUnavailable
        ? error
        : new KeysUnavailable(String(error));
    }
    if (!keys.size) throw new KeysUnavailable("no verifier keys");
    cache = { at: now(), keys };
    return keys;
  };
}

export async function fetchGoogleKeys(): Promise<VerifierKeys> {
  const response = await fetch(
    "https://www.gstatic.com/admob/reward/verifier-keys.json",
  );
  if (!response.ok) throw new KeysUnavailable(`key fetch ${response.status}`);
  const body = await response.json();
  const map: VerifierKeys = new Map();
  for (const key of body.keys ?? []) map.set(Number(key.keyId), String(key.base64));
  return map;
}
