/**
 * `play_voided_sync` — revokes refunded and charged-back purchases without
 * waiting for the player to come back.
 *
 * Reads Google Play's Voided Purchases API from the last checkpoint and hands
 * every voided token/order to `revoke_voided_play_purchases`. Meant to run on
 * a schedule (every few hours is plenty; Google keeps 30 days of history).
 *
 * Not a player endpoint: it requires the `x-sync-secret` header to match the
 * PLAY_SYNC_SECRET function secret, and it refuses outright when that secret
 * or the Play service account is not configured.
 *
 * Deploy after migration 20260923000200. Deploy with --no-verify-jwt, because
 * the scheduler authenticates with the shared secret, not a user session.
 */
import { serviceClient } from "../_shared/api.ts";
import { playAccessToken } from "../_shared/play_auth.ts";

const packageName = "com.mafiamaster.mafia_master";

Deno.serve(async (request) => {
  const secret = Deno.env.get("PLAY_SYNC_SECRET");
  if (!secret || request.headers.get("x-sync-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const db = serviceClient();
    const { data: checkpoint } = await db.from("play_sync_state")
      .select("voided_since_ms").eq("id", "voided").maybeSingle();
    // First run: Google's own window is 30 days.
    const since = Math.max(
      Number(checkpoint?.voided_since_ms ?? 0),
      Date.now() - 30 * 24 * 60 * 60 * 1000,
    );
    const bearer = await playAccessToken();
    const tokens: string[] = []; const orders: string[] = [];
    let latest = since; let page: string | undefined;
    do {
      const url = new URL(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/voidedpurchases`);
      url.searchParams.set("startTime", String(since));
      url.searchParams.set("type", "0"); // one-time products
      url.searchParams.set("maxResults", "1000");
      if (page) url.searchParams.set("token", page);
      const response = await fetch(url, { headers: { authorization: `Bearer ${bearer}` } });
      if (!response.ok) {
        console.error("play_voided_sync: Play API", response.status);
        return new Response(`play api ${response.status}`, { status: 502 });
      }
      const body = await response.json();
      for (const item of body.voidedPurchases ?? []) {
        if (item.purchaseToken) tokens.push(String(item.purchaseToken));
        if (item.orderId) orders.push(String(item.orderId));
        latest = Math.max(latest, Number(item.voidedTimeMillis ?? 0));
      }
      page = body.tokenPagination?.nextPageToken;
    } while (page);

    const { data: revoked, error } = await db.rpc("revoke_voided_play_purchases", {
      p_tokens: tokens, p_orders: orders,
    });
    if (error) throw error;
    // Overlap by a minute so a void recorded at the boundary is read twice
    // (harmless, revocation is idempotent) rather than never.
    await db.from("play_sync_state").upsert({
      id: "voided", voided_since_ms: Math.max(since, latest - 60 * 1000),
      updated_at: new Date().toISOString(),
    });
    return new Response(JSON.stringify({ voided: tokens.length, revoked }), {
      headers: { "content-type": "application/json" },
    });
  } catch (error) {
    if (String(error).includes("PLAY_NOT_CONFIGURED")) {
      return new Response("not configured", { status: 503 });
    }
    // Codes only (PLAY_AUTH_FAILED, a Postgres error code…), never key material.
    const code = String((error as { code?: string; message?: string })?.code ??
      (error as Error)?.message ?? "unknown").slice(0, 80);
    console.error("play_voided_sync failed:", code);
    return new Response(`retry: ${code}`, { status: 500 });
  }
});
