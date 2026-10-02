function b64url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = ""; for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemBytes(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/**
 * An OAuth access token for the Google Play Developer API, from the service
 * account in GOOGLE_PLAY_SERVICE_ACCOUNT_JSON. Throws PLAY_NOT_CONFIGURED when
 * the secret is absent, so callers can say "not configured" honestly.
 */
export async function playAccessToken(): Promise<string> {
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
