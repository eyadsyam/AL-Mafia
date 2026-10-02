/**
 * `metered_realtime` — the Metered Realtime signalling credential, minted here
 * and nowhere else.
 *
 * ## What this replaces
 *
 * Signalling used to go through Postgres: an `INSERT` into `signals`, a
 * realtime delta, a read back through RLS. That works, and it is slow in the
 * one place latency is felt — an SDP round trip on the moment a match starts.
 * Metered Realtime carries the same offers and candidates over a WebSocket,
 * and it injects TURN credentials into the welcome frame, which is what the
 * mesh has never had.
 *
 * ## Why the token is signed here rather than fetched
 *
 * Metered offers both: `POST https://rms.metered.ca/v1/tokens` with the secret
 * as a bearer, or an HS256 JWT signed with that secret directly. Signing is one
 * HMAC against a key we already hold, so it adds no network hop to the slowest
 * moment of the lobby and no upstream that can be down while Supabase is up.
 * The `kid` header names which signing key was used, which is what lets the
 * account rotate a key without every live token dying.
 *
 * ## The `channels` claim is a boundary, but not the whole one
 *
 * Metered enforces the claim server-side for the operations it scopes: a peer
 * whose JWT lists `mafia-master/match/<A>` does not get match B's channel
 * traffic. So the one thing that must never happen is a channel derived from
 * anything the caller sent, and `channelFor` takes a room id the caller has
 * already been checked against.
 *
 * What the claim does *not* scope is direct messaging. `send` is addressed by
 * peer id, and Metered documents it as needing no channel — confirmed against
 * the live service, where a token minted for one match successfully delivered a
 * direct frame to a peer in another. That is why [sessionIdFor] exists and why
 * every signalling envelope carries it: the missing scope is re-imposed by the
 * client, against a value only this endpoint hands out.
 *
 * ## What is deliberately not in the token
 *
 * `peerMetadata`. Metered stamps it onto every presence entry and every direct
 * message, visible to every other peer in the channel — so it is precisely the
 * wrong place for anything about a player. The app already knows who is at
 * which seat, from Supabase, which is the only source doc 05 allows to be
 * authoritative about the table. A Metered peer id is a Supabase user id and
 * nothing more, and there is no role, seat, name, or match seed anywhere in
 * this file's output.
 *
 * `metadata.iceServers` is likewise absent, and that absence is load-bearing:
 * setting it would *override* the account's TURN auto-injection. Leaving it out
 * is what makes the welcome frame carry Metered's own relay credentials.
 */

/** The signing key, as configured on this deployment. */
export interface RealtimeKey {
  /** `sk_id_…`, the `kid` header. Names the key; not itself a secret. */
  keyId: string;
  /** `sk_secret_…`. Never leaves this module. */
  secret: string;
}

/**
 * Null when the deployment was not given a Realtime key — a legitimate state
 * that degrades to the previous signalling path rather than failing a match.
 */
export function realtimeKey(): RealtimeKey | null {
  const secret = Deno.env.get("METERED_REALTIME_SECRET_KEY");
  const keyId = Deno.env.get("METERED_REALTIME_KEY_ID");
  if (!secret || !keyId) return null;
  return { keyId, secret };
}

/**
 * The signalling channel for one match.
 *
 * Derived from the room id on this side of the wire, always. A caller who is
 * not in that room never reaches this function — `loadMembership` refuses
 * first — so a channel name and a proof of membership are minted together or
 * not at all.
 */
export function channelFor(roomId: string): string {
  return `mafia-master/match/${roomId}`;
}

/** How long a minted credential lives. The SDK re-mints on every reconnect, so
 * this is a ceiling on a stolen token's usefulness, not a session length. */
export const TOKEN_TTL_SECONDS = 3600;

/**
 * The permissions this app actually uses, and no others.
 *
 * `subscribe` + `presence` to see who is on the channel; `send` to carry SDP
 * and ICE to one named peer. `publish` is absent on purpose: every signalling
 * message in this app is addressed to a single peer, so a broadcast right would
 * be a right to put a message in front of the whole table — which, in a game
 * about who is telling the truth, is not a capability worth handing out for
 * nothing.
 */
export const PERMISSIONS = ["subscribe", "presence", "send"] as const;

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function encodeSegment(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

/** What the client is given, and the whole of it. */
export interface RealtimeGrant {
  token: string;
  channel: string;
  peerId: string;
  expiresAt: number;
}

/**
 * An HS256 JWT scoped to one match's channel.
 *
 * [userId] becomes `sub`, and therefore the peer id every other client
 * addresses. That is deliberate: the mesh already identifies peers by Supabase
 * user id, so signalling addresses and game addresses are the same namespace
 * and there is no mapping table to get wrong.
 */
export async function mintRealtimeToken(
  key: RealtimeKey,
  userId: string,
  roomId: string,
  now: number = Math.floor(Date.now() / 1000),
): Promise<RealtimeGrant> {
  const channel = channelFor(roomId);
  const expiresAt = now + TOKEN_TTL_SECONDS;

  const header = { alg: "HS256", typ: "JWT", kid: key.keyId };
  const payload = {
    sub: userId,
    iat: now,
    exp: expiresAt,
    channels: [channel],
    permissions: PERMISSIONS,
  };

  const signingInput = `${encodeSegment(header)}.${encodeSegment(payload)}`;
  const hmac = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key.secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    hmac,
    new TextEncoder().encode(signingInput),
  );

  return {
    token: `${signingInput}.${base64url(new Uint8Array(signature))}`,
    channel,
    peerId: userId,
    expiresAt,
  };
}

/**
 * An opaque, deterministic identifier for one voice session.
 *
 * ## What it is for
 *
 * Metered's direct messages are addressed by peer id and are *not* scoped to
 * the JWT's `channels` claim — verified against the live service. So a peer
 * holding a valid token for match B can put a frame on match A's socket, and
 * "Metered authenticated the sender" says nothing about which match the sender
 * was authenticated *for*. Every signalling envelope therefore carries this,
 * and a receiver drops anything that does not match its own.
 *
 * ## Why it is an HMAC and not the room id
 *
 * Two reasons. It keeps the Supabase room id off the signalling wire, where it
 * would otherwise sit in every candidate exchange. And because the key is a
 * secret no client holds, a session id cannot be *computed* for a match — only
 * received from this endpoint, which hands it out solely to members.
 *
 * ## Why `match_seed` is in it
 *
 * It binds the id to one incarnation of the room rather than to the row. The
 * seed is written once at creation and never rewritten — checked, not assumed —
 * so this is stable for the room's whole life and a reconnect an hour later
 * derives the same value. It is also never sent: an HMAC of it is not it, which
 * is what lets a value the client must never learn safely contribute to a value
 * the client must have.
 */
export async function sessionIdFor(
  key: RealtimeKey,
  roomId: string,
  matchSeed: number | string,
): Promise<string> {
  const hmac = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key.secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    hmac,
    new TextEncoder().encode(`voice-session:${roomId}:${matchSeed}`),
  );
  return Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 32);
}
