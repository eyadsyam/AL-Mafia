/**
 * `coin_orders` — web coin packs by bank/wallet transfer, MANUAL VERIFICATION.
 *
 * Player actions: `shop`, `create`, `claim`, `cancel`.
 * Admin actions (server-enforced via commerce_admins): `admin_list`,
 * `admin_review`, `admin_refund`.
 *
 * No gateway, no webhook, no automatic confirmation. `claim` records the
 * player's "I sent it" with a transfer reference; it never changes a balance.
 * Only `admin_review` with decision `approve` credits coins, after a person has
 * matched the money in the real account, and the database makes that happen
 * exactly once per order and once per provider transaction.
 *
 * Secrets: COIN_SALES_ENABLED ("true" to sell), COIN_PAY_INSTAPAY_URL,
 * COIN_PAY_VODAFONE_CASH_URL (https only; an http link is reported as
 * unavailable, not silently upgraded). Deploy after migration 20260924000500.
 */
import { fail, handler, ok } from "../_shared/api.ts";
import {
  parseClaim, parseCreate, parseReview, paymentMethods, REFUSALS, salesEnabled,
} from "../_shared/coin_payments.ts";

const env = (name: string) => Deno.env.get(name);

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  // Only the fixed refusal codes reach the client, never a raw error text.
  const refuse = (error: { message?: string }) => {
    const reason = error.message ?? "";
    const known = REFUSALS[reason];
    if (!known) throw error;
    return fail(known[0] as never, reason.toLowerCase(), known[1]);
  };
  const methods = paymentMethods(env);
  const enabled = salesEnabled(env);

  switch (body.action) {
    case "shop": {
      const { data, error } = await db.rpc("coin_shop", { p_user: userId });
      if (error) return refuse(error);
      return ok({ ...data, enabled, methods: enabled ? methods : [] });
    }
    case "create": {
      if (!enabled) return fail("SALES_DISABLED", "coin sales are not enabled", 403);
      const parsed = parseCreate(body);
      if (!parsed.ok) return fail("BAD_REQUEST", parsed.error);
      const method = methods.find((m) => m.code === parsed.value.method);
      if (!method?.available) {
        return fail("METHOD_UNAVAILABLE", "payment method is not available", 409);
      }
      const { data, error } = await db.rpc("create_coin_order", {
        p_user: userId, p_pack: parsed.value.pack, p_method: parsed.value.method,
      });
      if (error) return refuse(error);
      return ok(data);
    }
    case "claim": {
      const parsed = parseClaim(body);
      if (!parsed.ok) return fail("BAD_REQUEST", parsed.error);
      const { data, error } = await db.rpc("claim_coin_order", {
        p_user: userId, p_order: parsed.value.order,
        p_reference: parsed.value.reference, p_payer_hint: parsed.value.payerHint,
      });
      if (error) return refuse(error);
      return ok({ order: data });
    }
    case "cancel": {
      if (typeof body.order !== "string") return fail("BAD_REQUEST", "invalid order");
      const { data, error } = await db.rpc("cancel_coin_order", {
        p_user: userId, p_order: body.order,
      });
      if (error) return refuse(error);
      return ok({ order: data });
    }
    case "admin_list": {
      const status = typeof body.status === "string" ? body.status : null;
      const { data, error } = await db.rpc("admin_coin_orders", {
        p_admin: userId, p_status: status,
      });
      if (error) return refuse(error);
      return ok(data);
    }
    case "admin_review": {
      const parsed = parseReview(body);
      if (!parsed.ok) return fail("BAD_REQUEST", parsed.error);
      const { data, error } = await db.rpc("admin_review_coin_order", {
        p_admin: userId, p_order: parsed.value.order, p_decision: parsed.value.decision,
        p_provider_transaction: parsed.value.transaction,
        p_received_piastres: parsed.value.receivedPiastres, p_note: parsed.value.note,
      });
      if (error) return refuse(error);
      return ok({ order: data });
    }
    case "admin_refund": {
      if (typeof body.order !== "string" || typeof body.note !== "string") {
        return fail("BAD_REQUEST", "order and note required");
      }
      const { data, error } = await db.rpc("admin_refund_coin_order", {
        p_admin: userId, p_order: body.order, p_note: body.note,
      });
      if (error) return refuse(error);
      return ok({ order: data });
    }
    default:
      return fail("BAD_REQUEST", "invalid coin order request");
  }
}));
