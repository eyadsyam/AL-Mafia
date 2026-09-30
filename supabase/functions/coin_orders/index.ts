/**
 * `coin_orders` — InstaPay / Vodafone Cash transfers with MANUAL VERIFICATION,
 * on the Android app and the web (Payments v2, migration 20260927000200).
 *
 * Player actions: `shop`, `create`, `submit` (proof: screenshot + sender name),
 * `cancel`. Admin actions (server-enforced via commerce_admins): `admin_whoami`,
 * `admin_list`, `admin_approve`, `admin_reject`, `admin_refund`, creator
 * entitlement grant/revoke, and the older `admin_review`.
 *
 * No gateway, no webhook, no automatic confirmation. `submit` stores the
 * screenshot in a private bucket and moves the order into review; it never
 * changes a balance. Only an admin approval credits, exactly once per order.
 *
 * Secrets: COIN_PAY_INSTAPAY_URL, COIN_PAY_VODAFONE_CASH_URL (https only),
 * TELEGRAM_BOT_TOKEN + TELEGRAM_ADMIN_CHAT_ID (optional; absent → no notice),
 * ADMIN_REVIEW_URL (optional). The per-platform kill switch lives in
 * economy_config.transfer_enabled_android / transfer_enabled_web (default off).
 */
import { fail, handler, ok } from "../_shared/api.ts";
import { sendPush, type PushTarget } from "../_shared/push.ts";
import { serviceAccountToken } from "../_shared/play_auth.ts";
import {
  parseClaim, parseCreate, parseFilter, parsePlatform, parseReject, parseReview,
  parseSubmit, paymentMethods, PROOF_BUCKET, proofPath, REFUSALS, sha256Hex,
  submitRefusal, telegramRequest,
} from "../_shared/coin_payments.ts";

const env = (name: string) => Deno.env.get(name);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
  // Older web clients send no platform: they are the web build.
  const platform = parsePlatform(body.platform ?? "web");

  // The RPC commits wallet credit and order status in one transaction. Read
  // the old state first so retries cannot send the same notice twice.
  const decisionBefore = async (order: string) => {
    const { data } = await db.from("coin_orders").select("status").eq("id", order).maybeSingle();
    return data?.status as string | undefined;
  };
  const notifyDecision = async (order: string, before: string | undefined) => {
    try {
      const { data: row } = await db.from("coin_orders").select("user_id,status").eq("id", order).maybeSingle();
      if (!row?.user_id || row.status === before || !["paid", "rejected"].includes(row.status)) return;
      const { data: tokens } = await db.from("push_tokens").select("token,platform").eq("user_id", row.user_id);
      const target: PushTarget = {
        enabled: true, kind: row.status === "paid" ? "order_paid" : "order_rejected",
        tokens: (tokens ?? []) as PushTarget["tokens"],
      };
      await sendPush(target, {
        secret: env("FCM_SERVICE_ACCOUNT_B64"),
        accessToken: (raw) => serviceAccountToken(raw, "https://www.googleapis.com/auth/firebase.messaging"),
        fetch,
        dropToken: async (token) => { await db.rpc("push_token_drop", { p_token: token }); },
        log: (line) => console.log(line),
      });
    } catch { console.log("payment push skipped: error"); }
  };

  switch (body.action) {
    case "shop": {
      if (!platform) return fail("BAD_REQUEST", "invalid platform");
      const { data, error } = await db.rpc("coin_shop_v2", { p_user: userId, p_platform: platform });
      if (error) return refuse(error);
      const enabled = data.enabled === true && methods.some((m) => m.available);
      return ok({ ...data, enabled, platform, methods: enabled ? methods : [] });
    }
    case "create": {
      const parsed = parseCreate(body);
      if (!parsed.ok || !platform) return fail("BAD_REQUEST", parsed.ok ? "invalid platform" : parsed.error);
      const method = methods.find((m) => m.code === parsed.value.method);
      if (!method?.available) {
        return fail("METHOD_UNAVAILABLE", "payment method is not available", 409);
      }
      const { data, error } = await db.rpc("create_coin_order_v2", {
        p_user: userId, p_pack: parsed.value.pack, p_method: parsed.value.method,
        p_platform: platform,
      });
      if (error) return refuse(error);
      return ok({ ...data, url: method.url });
    }
    case "submit": {
      const parsed = parseSubmit(body);
      if (!parsed.ok) return fail(submitRefusal(parsed.error) as never, parsed.error);
      const { order, sender, image } = parsed.value;
      // Cheap checks before anything is stored: the platform's switch, the
      // order is this player's, and it can still take a proof. The submit
      // below repeats them under the lock; this only spares the bucket.
      const pre = await db.rpc("coin_order_proof_precheck", {
        p_user: userId, p_order: order, p_platform: parsed.value.platform,
      });
      if (pre.error) return refuse(pre.error);
      const sha = await sha256Hex(image.bytes);
      const path = proofPath(userId, order, crypto.randomUUID(), image.ext);
      const bucket = db.storage.from(PROOF_BUCKET);
      const upload = await bucket.upload(path, image.bytes, {
        contentType: image.mime, upsert: false,
      });
      if (upload.error) {
        console.error("proof upload failed");
        return fail("BAD_REQUEST", "proof could not be stored", 503);
      }
      const { data, error } = await db.rpc("submit_coin_order_proof", {
        p_user: userId, p_order: order, p_sender: sender, p_path: path,
        p_sha256: sha, p_platform: parsed.value.platform,
      });
      if (error) {
        // Nothing points at this image: remove it.
        await bucket.remove([path]).catch(() => undefined);
        return refuse(error);
      }
      if (typeof data.previousPath === "string") {
        await bucket.remove([data.previousPath]).catch(() => undefined);
      }
      const o = data.order ?? {};
      const telegram = telegramRequest(env, {
        id: o.id, reference: o.reference, pack: o.pack, coins: o.coins,
        amountPiastres: o.amountPiastres, method: o.method, senderName: sender,
        item: data.item, entitlement: data.entitlement,
      });
      if (telegram) {
        // Best effort, bounded, and silent: never the URL (it holds the token).
        await fetch(telegram.url, {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: telegram.body, signal: AbortSignal.timeout(4000),
        }).then((r) => { if (!r.ok) console.error("owner notice not sent"); })
          .catch(() => console.error("owner notice not sent"));
      }
      return ok({ order: o });
    }
    case "claim": {
      // 1.0.x web clients: a transfer reference without a screenshot.
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
      if (typeof body.order !== "string" || !UUID.test(body.order)) {
        return fail("BAD_REQUEST", "invalid order");
      }
      const { data, error } = await db.rpc("cancel_coin_order", {
        p_user: userId, p_order: body.order,
      });
      if (error) return refuse(error);
      return ok({ order: data });
    }
    case "admin_whoami": {
      const { data, error } = await db.rpc("is_commerce_admin", { p_user: userId });
      if (error) return refuse(error);
      return ok({ admin: data === true });
    }
    case "admin_list": {
      const { data, error } = await db.rpc("admin_coin_orders_v2", {
        p_admin: userId, p_filter: parseFilter(body.status),
      });
      if (error) return refuse(error);
      const bucket = db.storage.from(PROOF_BUCKET);
      // Retention runs while the owner reviews: images 90 days past settling
      // (or of deleted accounts) leave the bucket; the order rows stay.
      const due = await db.rpc("payment_proofs_due", { p_limit: 50 });
      const duePaths = (due.data ?? []).map((r: { path: string }) => r.path).filter(Boolean);
      if (duePaths.length) {
        const removed = await bucket.remove(duePaths);
        if (!removed.error) await db.rpc("mark_payment_proofs_purged", { p_paths: duePaths });
      }
      // deno-lint-ignore no-explicit-any
      const orders: any[] = data.orders ?? [];
      const paths = orders.map((o) => o.proofPath).filter((p) => typeof p === "string");
      const signed = paths.length ? await bucket.createSignedUrls(paths, 600) : { data: [] };
      const urls = new Map<string, string>();
      for (const s of signed.data ?? []) if (s.path && s.signedUrl) urls.set(s.path, s.signedUrl);
      return ok({
        orders: orders.map(({ proofPath, ...o }) => ({ ...o, proofUrl: urls.get(proofPath) ?? null })),
      });
    }
    case "admin_approve": {
      if (typeof body.order !== "string" || !UUID.test(body.order)) {
        return fail("BAD_REQUEST", "invalid order");
      }
      const transaction = typeof body.transaction === "string" ? body.transaction.trim().slice(0, 80) : null;
      const before = await decisionBefore(body.order);
      const { data, error } = await db.rpc("admin_approve_coin_order", {
        p_admin: userId, p_order: body.order, p_transaction: transaction || null,
      });
      if (error) return refuse(error);
      await notifyDecision(body.order, before);
      return ok({ order: data });
    }
    case "admin_reject": {
      const parsed = parseReject(body);
      if (!parsed.ok) return fail("BAD_REQUEST", parsed.error);
      const before = await decisionBefore(parsed.value.order);
      const { data, error } = await db.rpc("admin_reject_coin_order", {
        p_admin: userId, p_order: parsed.value.order, p_reason: parsed.value.reason,
      });
      if (error) return refuse(error);
      await notifyDecision(parsed.value.order, before);
      return ok({ order: data });
    }
    case "admin_review": {
      const parsed = parseReview(body);
      if (!parsed.ok) return fail("BAD_REQUEST", parsed.error);
      const before = await decisionBefore(parsed.value.order);
      const { data, error } = await db.rpc("admin_review_coin_order", {
        p_admin: userId, p_order: parsed.value.order, p_decision: parsed.value.decision,
        p_provider_transaction: parsed.value.transaction,
        p_received_piastres: parsed.value.receivedPiastres, p_note: parsed.value.note,
      });
      if (error) return refuse(error);
      await notifyDecision(parsed.value.order, before);
      return ok({ order: data });
    }
    case "admin_refund": {
      if (typeof body.order !== "string" || typeof body.note !== "string" || body.note.trim().length < 3) {
        return fail("BAD_REQUEST", "order and note required");
      }
      const { data, error } = await db.rpc("admin_refund_coin_order", {
        p_admin: userId, p_order: body.order, p_note: body.note,
      });
      if (error) return refuse(error);
      return ok({ order: data });
    }
    case "admin_creator_grant": {
      if (typeof body.creatorId !== "string" || !UUID.test(body.creatorId) ||
        typeof body.campaign !== "string" || body.campaign.length < 1 || body.campaign.length > 60 ||
        typeof body.startsAt !== "string" || Number.isNaN(Date.parse(body.startsAt)) ||
        (body.endsAt !== null && body.endsAt !== undefined &&
          (typeof body.endsAt !== "string" || Number.isNaN(Date.parse(body.endsAt)))) ||
        typeof body.requestId !== "string" || !UUID.test(body.requestId)) {
        return fail("BAD_REQUEST", "invalid creator entitlement grant");
      }
      const { data, error } = await db.rpc("operator_creator_entitlement_grant", {
        p_admin: userId, p_creator: body.creatorId, p_campaign: body.campaign,
        p_starts: body.startsAt, p_ends: body.endsAt ?? null, p_request: body.requestId,
      });
      if (error) return refuse(error);
      return ok({ entitlement: data });
    }
    case "admin_creator_revoke": {
      if (typeof body.creatorId !== "string" || !UUID.test(body.creatorId) ||
        typeof body.reason !== "string" || body.reason.trim().length < 1 ||
        body.reason.trim().length > 500 || typeof body.requestId !== "string" ||
        !UUID.test(body.requestId)) {
        return fail("BAD_REQUEST", "invalid creator entitlement revoke");
      }
      const { data, error } = await db.rpc("operator_creator_entitlement_revoke", {
        p_admin: userId, p_creator: body.creatorId, p_reason: body.reason.trim(),
        p_request: body.requestId,
      });
      if (error) return refuse(error);
      return ok({ entitlement: data });
    }
    default:
      return fail("BAD_REQUEST", "invalid coin order request");
  }
}));
