/**
 * `ice_servers` — the room's TURN credentials, fetched once per match.
 *
 * ## Why this function exists at all
 *
 * A mesh of peer connections with only STUN works on a friendly network and
 * fails silently on an unfriendly one: symmetric NAT and most mobile carrier
 * networks give every peer a different mapped port per destination, so the
 * candidates each side gathers are addresses the other side can never reach.
 * The connection asks for the microphone, gathers, tries, and dies — which is
 * exactly the symptom this repository has carried since voice landed.
 *
 * A relay fixes it, and a relay needs credentials.
 *
 * ## Why the credentials come from here and not from the app
 *
 * The Metered API key mints TURN credentials for the whole account. Shipped in
 * a Flutter binary it is public: `strings` on an APK, or the browser's network
 * tab on the web build, and anybody may relay traffic on this account for as
 * long as the key lives. So the key is a Supabase secret, this function is the
 * only thing that reads it, and what crosses to a client is the short-lived
 * credential set Metered hands back — never the key that minted it.
 *
 * The caller must be authenticated; `handler` refuses otherwise. That is not a
 * strong control on its own — anybody may create an anonymous session — but it
 * keeps the endpoint off the open internet and inside the same rate limits as
 * everything else.
 *
 * ## Failure is not fatal
 *
 * Non-negotiable 5: voice is never load-bearing. If Metered is down or the
 * secret is missing this returns Google's public STUN servers with
 * `relay: false`, and the client logs a warning and carries on. A match must
 * complete with voice fully broken, so a 500 here would be a worse answer than
 * a degraded one.
 */
import { CORS_HEADERS, handler, ok } from "../_shared/api.ts";

const METERED_DOMAIN = "mafia-master.metered.live";

/** The last resort. Public, free, and no relay — good enough for a friendly
 * network and honest about being nothing more. */
const STUN_ONLY = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
];

Deno.serve(handler(async (_req, _userId, _db) => {
  const key = Deno.env.get("METERED_API_KEY");
  if (!key) {
    console.warn("METERED_API_KEY is not set — falling back to STUN only");
    return ok({ iceServers: STUN_ONLY, relay: false, reason: "no-key" });
  }

  try {
    const res = await fetch(
      `https://${METERED_DOMAIN}/api/v1/turn/credentials?apiKey=${
        encodeURIComponent(key)
      }`,
      { headers: { accept: "application/json" } },
    );
    if (!res.ok) {
      console.warn(`metered returned ${res.status}`);
      return ok({ iceServers: STUN_ONLY, relay: false, reason: "upstream" });
    }
    const servers = await res.json();
    if (!Array.isArray(servers) || servers.length === 0) {
      console.warn("metered returned no servers");
      return ok({ iceServers: STUN_ONLY, relay: false, reason: "empty" });
    }
    // Unchanged, as handed back: the array is already in the shape
    // `RTCPeerConnection` wants, and reshaping it here would be one more place
    // for a field name to drift.
    return ok({ iceServers: servers, relay: true });
  } catch (e) {
    console.warn(`metered unreachable: ${e}`);
    return ok({ iceServers: STUN_ONLY, relay: false, reason: "unreachable" });
  }
}));

// The preflight is handled by `handler`, which answers OPTIONS before it looks
// for a session. Re-exported so the CORS headers are visibly part of this
// function's contract for the web build, which is the one that needs them.
export { CORS_HEADERS };
