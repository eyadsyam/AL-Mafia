/**
 * `ice_servers` — public STUN, and the floor of the ICE ladder.
 *
 * ## Why this is no longer where the relay comes from
 *
 * It used to fetch TURN credentials from Metered's standalone TURN REST API.
 * That API is a separately-subscribed product and answered
 * `"please subscribe to a TURN Server plan"`, so the relay it promised was
 * never actually delivered to a single call.
 *
 * The relay now arrives somewhere better: Metered Realtime injects TURN
 * credentials into the signalling welcome frame, so a client that has a
 * signalling socket already has its relay — no second round trip, no second
 * credential to age out, and nothing for this function to fetch. See
 * `realtime_token` and `lib/transport/metered_voice_link.dart`.
 *
 * ## Why it still exists
 *
 * Builds already on phones call it, and a client that cannot reach Metered
 * still needs a ladder to climb. Both want the same answer — the two public
 * STUN servers this app has always fallen back to — so that is the whole of
 * this function now. It takes no upstream, holds no credential, and cannot
 * fail in a way that matters.
 *
 * Non-negotiable 5: voice is never load-bearing. A room whose ICE lookup
 * returned nothing still plays; a room whose ICE lookup threw would not.
 */
import { handler, ok } from "../_shared/api.ts";

/** Public, free, and no relay — good enough for a friendly network and honest
 * about being nothing more. Useless behind symmetric NAT, which is exactly why
 * the relay moved to the signalling welcome. */
const STUN_ONLY = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
];

Deno.serve(handler(async (_req, _userId, _db) => {
  return ok({ iceServers: STUN_ONLY, relay: false, reason: "stun-only" });
}));
