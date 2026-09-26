/**
 * Transfer payments (InstaPay / Vodafone Cash) with manual verification, on
 * the Android app and the web (Payments v2). Pure helpers, testable in node;
 * the edge function `coin_orders` wires them to the database. Selling is
 * switched per platform in economy_config (transfer_enabled_*).
 *
 * There is no payment gateway and no webhook. A method is "available" only
 * when the operator configured an HTTPS destination for it. The destinations
 * live in function secrets, never in the app binary or public docs, and are
 * handed out exactly as configured: no amount, reference or account data is
 * appended (the provider's link format is not documented to us, and a link is
 * not a place for order data).
 */

export type PaymentMethod = "instapay" | "vodafone_cash";
export const PAYMENT_METHODS: PaymentMethod[] = ["instapay", "vodafone_cash"];

const SECRET_NAME: Record<PaymentMethod, string> = {
  instapay: "COIN_PAY_INSTAPAY_URL",
  vodafone_cash: "COIN_PAY_VODAFONE_CASH_URL",
};

export interface MethodInfo {
  code: PaymentMethod;
  available: boolean;
  /** Present only when available. */
  url?: string;
  /** Why not, when not: "not_configured" | "not_https". */
  reason?: string;
}

/** Reads the configured destinations. Anything but a clean https URL is off. */
export function paymentMethods(env: (name: string) => string | undefined): MethodInfo[] {
  return PAYMENT_METHODS.map((code) => {
    const raw = env(SECRET_NAME[code])?.trim();
    if (!raw) return { code, available: false, reason: "not_configured" };
    let url: URL;
    try { url = new URL(raw); } catch { return { code, available: false, reason: "not_https" }; }
    if (url.protocol !== "https:" || url.username || url.password) {
      return { code, available: false, reason: "not_https" };
    }
    return { code, available: true, url: url.toString() };
  });
}

const REFERENCE = /^[A-Za-z0-9 ._/-]{4,64}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Parsed<T> = { ok: true; value: T } | { ok: false; error: string };

export function parseCreate(body: any): Parsed<{ pack: string; method: PaymentMethod }> {
  if (typeof body?.pack !== "string" || !/^[a-z0-9_]{3,40}$/.test(body.pack)) {
    return { ok: false, error: "invalid pack" };
  }
  if (!PAYMENT_METHODS.includes(body?.method)) return { ok: false, error: "invalid method" };
  // Prices, amounts and coin counts are never read from the client.
  return { ok: true, value: { pack: body.pack, method: body.method } };
}

export function parseClaim(body: any): Parsed<{ order: string; reference: string; payerHint: string | null }> {
  if (typeof body?.order !== "string" || !UUID.test(body.order)) return { ok: false, error: "invalid order" };
  const reference = typeof body?.reference === "string" ? body.reference.trim() : "";
  if (!REFERENCE.test(reference)) return { ok: false, error: "invalid reference" };
  const hint = body?.payerHint == null ? null : String(body.payerHint).trim().slice(0, 60);
  // Never a PIN, password or OTP: anything that looks like a long digit run
  // other than the transfer reference is refused rather than stored.
  if (hint && /\d{7,}/.test(hint)) return { ok: false, error: "invalid payer hint" };
  return { ok: true, value: { order: body.order, reference, payerHint: hint || null } };
}

export function parseReview(body: any): Parsed<{
  order: string; decision: "approve" | "reject" | "needs_info";
  transaction: string | null; receivedPiastres: number | null; note: string | null;
}> {
  if (typeof body?.order !== "string" || !UUID.test(body.order)) return { ok: false, error: "invalid order" };
  if (!["approve", "reject", "needs_info"].includes(body?.decision)) return { ok: false, error: "invalid decision" };
  const received = body?.receivedPiastres;
  if (received != null && (!Number.isInteger(received) || received <= 0)) {
    return { ok: false, error: "invalid amount" };
  }
  return {
    ok: true,
    value: {
      order: body.order,
      decision: body.decision,
      transaction: typeof body?.transaction === "string" ? body.transaction.trim() : null,
      receivedPiastres: received ?? null,
      note: typeof body?.note === "string" ? body.note.trim().slice(0, 300) : null,
    },
  };
}

/** Database refusals the client can act on, and their HTTP status. */
export const REFUSALS: Record<string, [string, number]> = {
  ACCOUNT_NOT_RECOVERABLE: ["ACCOUNT_NOT_RECOVERABLE", 403],
  PACK_UNAVAILABLE: ["PACK_UNAVAILABLE", 409],
  ALREADY_OWNED: ["ALREADY_OWNED", 409],
  ORDER_NOT_FOUND: ["ORDER_NOT_FOUND", 404],
  ORDER_NOT_CLAIMABLE: ["ORDER_STATE", 409],
  ORDER_NOT_CANCELLABLE: ["ORDER_STATE", 409],
  ORDER_NOT_REVIEWABLE: ["ORDER_STATE", 409],
  ORDER_NOT_REFUNDABLE: ["ORDER_STATE", 409],
  ORDER_OPEN: ["ORDER_OPEN", 409],
  NOT_ADMIN: ["NOT_ADMIN", 403],
  AMOUNT_MISMATCH: ["AMOUNT_MISMATCH", 409],
  TRANSFER_ALREADY_USED: ["TRANSFER_ALREADY_USED", 409],
  TRANSACTION_REQUIRED: ["BAD_REQUEST", 400],
  NOTE_REQUIRED: ["BAD_REQUEST", 400],
  BAD_REQUEST: ["BAD_REQUEST", 400],
  SALES_DISABLED: ["SALES_DISABLED", 403],
  TOO_MANY_PENDING: ["TOO_MANY_PENDING", 409],
  DUPLICATE_PROOF: ["DUPLICATE_PROOF", 409],
  PROOF_REQUIRED: ["PROOF_REQUIRED", 400],
  SENDER_REQUIRED: ["SENDER_REQUIRED", 400],
};

// ---------------------------------------------------------------------------
// Payments v2 (migration 20260927000200): transfers on Android and web, proof
// screenshots, admin review and the owner's Telegram notice.

export type Platform = "android" | "web";

/** The client says which build it is; each platform has its own kill switch
 * on the server (economy_config.transfer_enabled_*), so a wrong claim only
 * picks the other switch. Anything else is refused. */
export function parsePlatform(value: unknown): Platform | null {
  return value === "android" || value === "web" ? value : null;
}

/** A 1600px JPEG is well under 1 MB; 3 MB leaves room for PNG/WebP. */
export const PROOF_MAX_BYTES = 3 * 1024 * 1024;
export const PROOF_BUCKET = "payment-proofs";

/** Letters of any script, digits (Vodafone Cash may show a number), spaces
 * and the punctuation names use. Exactly as the payment app shows it. */
const SENDER = /^[\p{L}\p{M}\p{N} .,'’_\-@+()]{2,80}$/u;

export function parseSender(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const name = value.replace(/\s+/g, " ").trim();
  return SENDER.test(name) ? name : null;
}

export type ProofImage = { bytes: Uint8Array; mime: "image/jpeg" | "image/png" | "image/webp"; ext: string };

/** Base64 image from the client, checked by its bytes (never its name). */
export function decodeProofImage(base64: unknown): Parsed<ProofImage> {
  if (typeof base64 !== "string" || base64.length < 16) return { ok: false, error: "image required" };
  const clean = base64.replace(/^data:image\/[a-z]+;base64,/, "").replace(/\s/g, "");
  if (clean.length > Math.ceil(PROOF_MAX_BYTES / 3) * 4 + 4) return { ok: false, error: "image too large" };
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(clean)) return { ok: false, error: "invalid image" };
  let bytes: Uint8Array;
  try {
    const raw = atob(clean);
    bytes = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  } catch {
    return { ok: false, error: "invalid image" };
  }
  if (bytes.length > PROOF_MAX_BYTES) return { ok: false, error: "image too large" };
  const at = (i: number) => bytes[i];
  if (at(0) === 0xff && at(1) === 0xd8 && at(2) === 0xff) {
    return { ok: true, value: { bytes, mime: "image/jpeg", ext: "jpg" } };
  }
  if (at(0) === 0x89 && at(1) === 0x50 && at(2) === 0x4e && at(3) === 0x47) {
    return { ok: true, value: { bytes, mime: "image/png", ext: "png" } };
  }
  const tag = (from: number) => String.fromCharCode(...bytes.slice(from, from + 4));
  if (bytes.length > 12 && tag(0) === "RIFF" && tag(8) === "WEBP") {
    return { ok: true, value: { bytes, mime: "image/webp", ext: "webp" } };
  }
  return { ok: false, error: "not an image" };
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** `<user>/<order>/<nonce>.<ext>`: the player's own folder, never guessable. */
export function proofPath(user: string, order: string, nonce: string, ext: string): string {
  return `${user}/${order}/${nonce}.${ext}`;
}

export function parseSubmit(body: any): Parsed<{
  order: string; sender: string; platform: Platform; image: ProofImage;
}> {
  if (typeof body?.order !== "string" || !UUID.test(body.order)) return { ok: false, error: "invalid order" };
  const platform = parsePlatform(body?.platform);
  if (!platform) return { ok: false, error: "invalid platform" };
  const sender = parseSender(body?.senderName);
  if (!sender) return { ok: false, error: "sender name required" };
  const image = decodeProofImage(body?.image);
  if (!image.ok) return image;
  return { ok: true, value: { order: body.order, sender, platform, image: image.value } };
}

export function parseReject(body: any): Parsed<{ order: string; reason: string }> {
  if (typeof body?.order !== "string" || !UUID.test(body.order)) return { ok: false, error: "invalid order" };
  const reason = typeof body?.reason === "string" ? body.reason.trim().slice(0, 300) : "";
  if (reason.length < 3) return { ok: false, error: "reason required" };
  return { ok: true, value: { order: body.order, reason } };
}

export const ADMIN_FILTERS = ["pending", "approved", "rejected", "expired"] as const;
export function parseFilter(value: unknown): string {
  return typeof value === "string" && (ADMIN_FILTERS as readonly string[]).includes(value) ? value : "pending";
}

export function egp(piastres: number): string {
  return piastres % 100 === 0 ? String(piastres / 100) : (piastres / 100).toFixed(2);
}

export interface OrderNotice {
  id: string; reference: string; pack: string; coins: number; amountPiastres: number;
  method: string; senderName: string; item?: string | null; entitlement?: string | null;
}

export const ADMIN_URL = "https://almafia.vercel.app/admin";

function productName(o: OrderNotice): string {
  if (o.entitlement === "remove_interruptions") return "Quiet Pass (remove interruptions)";
  if (o.item) return `Starter Bundle (${o.coins} coins + ${o.item})`;
  return `${o.coins} coins (${o.pack})`;
}

/** Plain text (no parse mode, so a sender name cannot inject markup). */
export function telegramText(o: OrderNotice, adminUrl = ADMIN_URL): string {
  const method = o.method === "instapay" ? "InstaPay" : o.method === "vodafone_cash" ? "Vodafone Cash" : o.method;
  return [
    "New payment order to review",
    `Order: ${o.reference} (#${o.id.slice(0, 8)})`,
    `Product: ${productName(o)}`,
    `Price: ${egp(o.amountPiastres)} EGP`,
    `Method: ${method}`,
    `Sender: ${o.senderName}`,
    `Review: ${adminUrl}?order=${encodeURIComponent(o.id)}`,
  ].join("\n");
}

/** The Bot API request, or null when the secrets are absent (skip silently).
 * The token is only ever inside the returned URL; never log this object. */
export function telegramRequest(
  env: (name: string) => string | undefined, o: OrderNotice,
): { url: string; body: string } | null {
  const token = env("TELEGRAM_BOT_TOKEN")?.trim();
  const chat = env("TELEGRAM_ADMIN_CHAT_ID")?.trim();
  if (!token || !chat || !/^[0-9]+:[A-Za-z0-9_-]{20,}$/.test(token) || !/^-?[0-9]{3,20}$/.test(chat)) return null;
  const adminUrl = env("ADMIN_REVIEW_URL")?.trim() || ADMIN_URL;
  return {
    url: `https://api.telegram.org/bot${token}/sendMessage`,
    body: JSON.stringify({ chat_id: chat, text: telegramText(o, adminUrl), disable_web_page_preview: true }),
  };
}

