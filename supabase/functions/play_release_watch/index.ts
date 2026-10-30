/**
 * `play_release_watch` — notices when Google Play approves a new build.
 *
 * Asks Play which production build is published and hands it to
 * `app_update_announce`, which raises latest_build_android and queues the
 * update notice once per build. Runs every ten minutes on a schedule.
 *
 * Not a player endpoint: it requires the `x-sync-secret` header to match the
 * PLAY_SYNC_SECRET function secret. Deploy after migration 20261030005000 with
 * --no-verify-jwt, because the scheduler authenticates with the shared secret.
 */
import { serviceClient } from "../_shared/api.ts";
import { playAccessToken } from "../_shared/play_auth.ts";
import { publishedBuild } from "../_shared/play_release.ts";
import { sameSecret } from "../_shared/same_secret.ts";

const packageName = "com.mafiamaster.mafia_master";

Deno.serve(async (request) => {
  const secret = Deno.env.get("PLAY_SYNC_SECRET");
  if (!secret || !sameSecret(request.headers.get("x-sync-secret") ?? "", secret)) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const bearer = await playAccessToken();
    const response = await fetch(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/tracks/production/releases`,
      { headers: { authorization: `Bearer ${bearer}` } },
    );
    if (!response.ok) {
      console.error("play_release_watch: Play API", response.status);
      return new Response(`play api ${response.status}`, { status: 502 });
    }
    const build = publishedBuild(await response.json());
    let result: unknown = { announced: false };
    if (build !== null) {
      const { data, error } = await serviceClient().rpc("app_update_announce", { p_build: build });
      if (error) throw error;
      result = data;
    }
    return new Response(JSON.stringify(result), {
      headers: { "content-type": "application/json" },
    });
  } catch (error) {
    if (String(error).includes("PLAY_NOT_CONFIGURED")) {
      return new Response("not configured", { status: 503 });
    }
    // Codes only (PLAY_AUTH_FAILED, a Postgres error code…), never key material.
    const code = String((error as { code?: string; message?: string })?.code ??
      (error as Error)?.message ?? "unknown").slice(0, 80);
    console.error("play_release_watch failed:", code);
    return new Response(`retry: ${code}`, { status: 500 });
  }
});
