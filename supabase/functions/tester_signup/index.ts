/**
 * `tester_signup` — the closed-test sign-up form on saidalmafia.com/beta.
 *
 *   { name, email, source?, website? }
 *
 * The one public function: a visitor from a Facebook post has no session and
 * must not be made to create one, so this is deployed with JWT verification
 * off and does not use [handler]. It can only append a row to
 * `tester_signups`; it reads nothing back, so a duplicate email gets the same
 * answer as a new one and the form cannot be used to check who signed up.
 *
 * Abuse bounds: every request is counted before anything else, duplicates and
 * honeypot hits included, by an atomic per-hour counter
 * (`tester_signup_attempt`): five per address, three hundred in all. The
 * address exists there only as an HMAC under its own secret (TESTER_HMAC_KEY) and is deleted
 * within two hours; the sign-up row never holds it. Bodies over 2 KB are
 * refused, reading stops at the cap. `website` is a field people never see (bots fill it).
 */

import { CORS_HEADERS, fail, ok, serviceClient } from "../_shared/api.ts";
import { readCapped } from "../_shared/body.ts";

const MAX_BODY = 2048;
const EMAIL = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[a-z]{2,}$/;

function clean(value: unknown, max: number): string {
  if (typeof value !== "string") return "";
  // Control and format characters: zero-width marks and bidi overrides.
  return value.replace(/[\p{Cc}\p{Cf}]/gu, "")
    .replace(/\s+/g, " ").trim().slice(0, max + 1);
}

async function addressHash(req: Request, secret: string): Promise<string> {
  const address = req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(address));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const JOIN_URL = "https://saidalmafia.com/beta/join/";

function escapeHtml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function welcomeText(name: string): string {
  return `أهلاً ${name}،\n\n` +
    "شكرًا لتسجيلك لتجربة سيد المافيا. تقدر تكمل خطوات الانضمام من موبايل أندرويد باستخدام حساب جوجل نفسه اللي سجلت بيه.\n\n" +
    `افتح صفحة الانضمام: ${JOIN_URL}\n\n` +
    "من الصفحة، انضم إلى مجموعة المختبرين أولًا. بعد قبول العضوية، ارجع للصفحة نفسها علشان تفتح رابط تنزيل اللعبة من Google Play. " +
    "لو رابط التنزيل ما ظهرش فورًا، ارجع للصفحة بعد شوية.\n\n" +
    "وصلتك الرسالة لأنك سجلت لتجربة سيد المافيا. لو التسجيل مش منك، تجاهلها.\n\n" +
    "إياد\nفريق سيد المافيا";
}

function welcomeHtml(name: string): string {
  return `<div dir="rtl" lang="ar" style="font-family:Tahoma,Arial,sans-serif;line-height:1.6;letter-spacing:0;text-align:right">` +
    `<h1>خطوات الانضمام لتجربة سيد المافيا</h1>` +
    `<p>أهلاً <span dir="auto">${escapeHtml(name)}</span>،</p>` +
    `<p>شكرًا لتسجيلك لتجربة سيد المافيا. تقدر تكمل خطوات الانضمام من موبايل أندرويد باستخدام حساب جوجل نفسه اللي سجلت بيه.</p>` +
    `<p><a href="${JOIN_URL}">افتح صفحة الانضمام</a></p>` +
    `<p>من الصفحة، انضم إلى مجموعة المختبرين أولًا. بعد قبول العضوية، ارجع للصفحة نفسها علشان تفتح رابط تنزيل اللعبة من Google Play. لو رابط التنزيل ما ظهرش فورًا، ارجع للصفحة بعد شوية.</p>` +
    `<p>وصلتك الرسالة لأنك سجلت لتجربة سيد المافيا. لو التسجيل مش منك، تجاهلها.</p>` +
    `<p>إياد<br>فريق سيد المافيا</p></div>`;
}

/** Best effort: only a provider-accepted new-row email sets mailed_at. */
async function sendWelcome(
  db: ReturnType<typeof serviceClient>,
  id: number,
  name: string,
  email: string,
): Promise<void> {
  const key = Deno.env.get("RESEND_API_KEY") ?? "";
  if (!key) return;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${key}`,
        "Content-Type": "application/json",
        "Idempotency-Key": `tester-welcome-${id}`,
      },
      body: JSON.stringify({
        from: "Mafia Master <eyad@saidalmafia.com>",
        to: [email],
        subject: "خطوات الانضمام لتجربة سيد المافيا",
        html: welcomeHtml(name),
        text: welcomeText(name),
        headers: {
          "Message-ID": `<tester-welcome-${id}@saidalmafia.com>`,
          "List-Unsubscribe": "<mailto:eyad@saidalmafia.com?subject=unsubscribe>",
        },
      }),
      signal: AbortSignal.timeout(10_000),
    });
    const answer = await res.json().catch(() => ({}));
    if (res.ok && typeof answer?.id === "string") {
      await db.from("tester_signups").update({ mailed_at: new Date().toISOString() }).eq("id", id);
    }
  } catch (_) {
    // Best effort; see above.
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return fail("BAD_REQUEST", "use POST", 405);
  try {
    if (Number(req.headers.get("content-length") ?? "0") > MAX_BODY) {
      return fail("BAD_REQUEST", "request is too large", 413);
    }
    const raw = await readCapped(req, MAX_BODY);
    if (raw === null) return fail("BAD_REQUEST", "request is too large", 413);

    const secret = Deno.env.get("TESTER_HMAC_KEY") ?? "";
    if (secret.length < 32) return fail("NOT_CONFIGURED", "sign-ups are closed", 503);
    const db = serviceClient();
    const allowed = await db.rpc("tester_signup_attempt", {
      p_address: await addressHash(req, secret),
    });
    if (allowed.error) throw new Error("limit check failed");
    if (allowed.data !== true) {
      return fail("RATE_LIMITED", "too many sign-ups, try again later", 429);
    }

    let body: Record<string, unknown> = {};
    try {
      body = JSON.parse(raw);
    } catch (_) {
      body = {};
    }
    if (clean(body?.website, 200) !== "") return ok({ ok: true });

    const name = clean(body?.name, 40);
    const email = clean(body?.email, 120).toLowerCase();
    const source = clean(body?.source, 40) || null;
    if (name.length < 2 || name.length > 40) {
      return fail("BAD_REQUEST", "name must be 2 to 40 characters");
    }
    if (email.length > 120 || !EMAIL.test(email)) {
      return fail("BAD_REQUEST", "email is not valid");
    }

    const { data: created, error } = await db.from("tester_signups").upsert(
      { name, email, source },
      { onConflict: "email", ignoreDuplicates: true },
    ).select("id");
    if (error) throw new Error("insert failed");
    // Only a new sign-up gets the welcome email; a repeat gets the same
    // answer and no second mail.
    const row = created?.[0];
    if (row) await sendWelcome(db, row.id, name, email);
    return ok({ ok: true });
  } catch (_) {
    return fail("BAD_REQUEST", "request could not be completed", 500);
  }
});
