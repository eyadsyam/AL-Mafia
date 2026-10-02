/**
 * send_push: drains the push outbox (20261002000100_push_outbox.sql).
 *
 * Called by Postgres (pg_net, right after a trigger or cron job enqueued
 * rows, and a five-minute sweep) with an empty body. It takes no input and
 * trusts none: it claims pending rows through a service-role-only RPC and
 * sends them over FCM HTTP v1 with the same service account the invite push
 * uses (env `FCM_SERVICE_ACCOUNT_B64`). Calling it by hand only drains the
 * queue earlier, so it is deployed without JWT verification.
 *
 * Doc 05: the wording lives in `_shared/push.ts` (EVENT_TEXT) and says
 * nothing a single seat alone knows.
 */
import { CORS_HEADERS, fail, ok, serviceClient } from "../_shared/api.ts";
import { sendPush, type PushDeps, type PushTarget } from "../_shared/push.ts";
import { serviceAccountToken } from "../_shared/play_auth.ts";

interface Row {
  id: number;
  kind: PushTarget["kind"];
  tokens: { token: string; platform: "android" | "web" }[];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return fail("BAD_REQUEST", "use POST", 405);
  try {
    const db = serviceClient();
    const deps: PushDeps = {
      secret: Deno.env.get("FCM_SERVICE_ACCOUNT_B64"),
      accessToken: (raw) => serviceAccountToken(raw, "https://www.googleapis.com/auth/firebase.messaging"),
      fetch,
      dropToken: async (token) => { await db.rpc("push_token_drop", { p_token: token }); },
      log: (line) => console.log(line),
    };
    let sent = 0;
    let rows = 0;
    for (let round = 0; round < 5; round++) {
      const { data, error } = await db.rpc("push_outbox_claim", { p_limit: 100 });
      if (error) throw error;
      const batch = (data ?? []) as Row[];
      rows += batch.length;
      for (const row of batch) {
        const outcome = await sendPush(
          { enabled: true, kind: row.kind, variant: row.id, tokens: row.tokens },
          deps,
        );
        if (outcome.result === "sent") sent += outcome.sent;
      }
      if (batch.length < 100) break;
    }
    return ok({ rows, sent });
  } catch (error) {
    console.log(`send_push failed: ${String((error as Error)?.message ?? error).slice(0, 80)}`);
    return fail("NOT_CONFIGURED", "send failed", 500);
  }
});
