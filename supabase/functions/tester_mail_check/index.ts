/**
 * `tester_mail_check` — answers the welcome-mail script (tool/tester_mail/Code.gs)
 * before it sends: is this { email, token } a sign-up we made and have not
 * mailed yet? `token` is an HMAC of the email under TESTER_MAIL_KEY that only
 * `tester_signup` computes, so the script holds no secret and nobody without
 * the server key can make it send mail. Public (JWT off): the caller is
 * Google's Apps Script runtime. Answers only valid true/false.
 */

import { CORS_HEADERS, fail, ok, serviceClient } from "../_shared/api.ts";

export async function mailToken(secret: string, email: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`mail:${email}`));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") return fail("BAD_REQUEST", "use POST", 405);
    try {
      const secret = Deno.env.get("TESTER_MAIL_KEY") ?? "";
      if (secret.length < 32) return fail("NOT_CONFIGURED", "mail check is off", 503);
      const raw = await req.text();
      if (raw.length > 1024) return fail("BAD_REQUEST", "request is too large", 413);
      const body = JSON.parse(raw || "{}");
      const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
      const token = typeof body?.token === "string" ? body.token : "";
      if (!email || email.length > 120 || token.length !== 64) {
        return fail("BAD_REQUEST", "email and token are required");
      }
      if (!sameText(await mailToken(secret, email), token)) return ok({ valid: false });
      const { data, error } = await serviceClient().from("tester_signups")
        .select("id").eq("email", email).is("mailed_at", null).maybeSingle();
      if (error) throw new Error("lookup failed");
      return ok({ valid: data != null });
    } catch (_) {
      return fail("BAD_REQUEST", "request could not be completed", 500);
    }
  });
}
