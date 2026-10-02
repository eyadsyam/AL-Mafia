/**
 * Web coin packs: transfer links, manual verification (docs/
 * CLAUDE-UX-ECONOMY-NEXT.md, newest instruction). Pure helpers, testable in
 * node; the edge function `coin_orders` wires them to the database.
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

export function salesEnabled(env: (name: string) => string | undefined): boolean {
  return env("COIN_SALES_ENABLED") === "true";
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
};
