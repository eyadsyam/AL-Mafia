/**
 * The scaffolding every Edge Function shares: auth, the service-role client,
 * the response shapes, and the four checks doc 10 §10 requires on every call.
 *
 * ## The rule that shapes all of it
 *
 * *"Edge Functions validate phase and role on every call — never trust the
 * client's claim about the current phase."* And, more sharply (§1.3): the
 * client never decides anything secret and never learns anything it should not.
 *
 * So: the caller's identity comes from the **JWT**, never from the body. That
 * one decision is what makes O17 ("post a vote for someone else") unreachable
 * rather than merely validated — there is no field in any request that names
 * the actor, so there is nothing to forge.
 */

import {
  createClient,
  type SupabaseClient,
} from "jsr:@supabase/supabase-js@2";

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export type ErrorCode =
  | "UNAUTHENTICATED"
  | "NOT_A_MEMBER"
  | "PHASE_CLOSED"
  | "WRONG_ROLE"
  | "NOT_ALIVE"
  | "NOT_HOST"
  | "ROOM_FULL"
  | "ROOM_FINISHED"
  | "ROOM_NOT_FOUND"
  | "ALREADY_JOINED"
  | "RATE_LIMITED"
  | "NEW_ROOMS_PAUSED"
  | "INSUFFICIENT_COINS"
  | "PURCHASE_REQUIRED"
  | "NOT_CONFIGURED"
  | "REBIND_LIMIT"
  | "SALES_DISABLED"
  | "ACCOUNT_NOT_RECOVERABLE"
  | "PACK_UNAVAILABLE"
  | "METHOD_UNAVAILABLE"
  | "ORDER_NOT_FOUND"
  | "ORDER_STATE"
  | "ORDER_OPEN"
  | "NOT_ADMIN"
  | "AMOUNT_MISMATCH"
  | "TRANSFER_ALREADY_USED"
  | "TOO_MANY_PENDING"
  | "DUPLICATE_PROOF"
  | "PROOF_REQUIRED"
  | "SENDER_REQUIRED"
  | "ALREADY_OWNED"
  | "FEATURE_OFF"
  | "STEP_ORDER"
  | "DAY_CHANGED"
  | "DAY_REQUIRED"
  | "IN_MATCH"
  | "DAILY_PAUSED"
  | "REWARD_NOT_ELIGIBLE"
  | "REWARD_NOT_SYNCED"
  | "REWARD_SCHEME_V2"
  | "ACCOUNT_MISMATCH"
  | "PRODUCT_UNKNOWN"
  | "ROOM_UNAVAILABLE"
  | "NAME_NOT_ALLOWED"
  | "ACCOUNT_RESTRICTED"
  | "REPORT_CLOSED"
  | "WITNESS_ONLY"
  | "BAD_REQUEST";

export function ok(body: unknown = { ok: true }): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/**
 * A refusal, with a code the client can act on.
 *
 * `PHASE_CLOSED` in particular is not an error the client should surface as
 * one: O7 and N16 both say the client force-resyncs from a snapshot and shows
 * the new phase. A generic 500 would put a red banner in front of a player
 * whose only mistake was tapping half a second late.
 */
export function fail(code: ErrorCode, message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: code, message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/**
 * The service-role client. Bypasses RLS, which is exactly why every function
 * that uses it re-checks membership, liveness, phase and role by hand.
 */
export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/**
 * The caller's user id, taken from the verified JWT.
 *
 * **Never from the request body.** This is the whole of O17: a client can put
 * whatever it likes in a payload, and none of it reaches a `voter_id`.
 */
export async function callerId(req: Request): Promise<string | null> {
  const header = req.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) return null;

  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: header } }, auth: { persistSession: false } },
  );
  const { data, error } = await anon.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

export interface Membership {
  roomId: string;
  userId: string;
  seat: number;
  role: string | null;
  alive: boolean;
  hostId: string;
  status: string;
  matchSeed: number;
  settings: Record<string, unknown>;
  phase: string;
  phaseNumber: number;
  phaseEndsAt: string | null;
}

/**
 * Loads the caller's membership, or null if they are not in the room.
 *
 * One call for the four things every handler needs to check, so that "did we
 * remember to validate?" is answered by whether the handler called this rather
 * than by reading four scattered `if`s.
 *
 * ## Why it is two queries and not one embed
 *
 * It was one: `room_players` with `rooms!inner(...)` **and**
 * `room_state:room_state!inner(...)` hung off the same select. PostgREST
 * refuses that, and every function in this directory calls this one, so the
 * whole server answered
 *
 *     PGRST200: Could not find a relationship between 'room_players' and
 *     'room_state' in the schema cache
 *
 * ...to every request. The embed looks reasonable and is not: PostgREST
 * resolves an embed across a foreign key *between the two tables*, and there
 * is none here. `room_players` and `room_state` are siblings — both point at
 * `rooms` — and PostgREST does not walk a relationship transitively.
 *
 * The repair is not a foreign key invented to satisfy the query planner. It is
 * to ask for the two things separately and in parallel: `rooms` really is
 * embedded through a real key, and `room_state` is a single row addressed by
 * its primary key. Two round trips inside the same region cost about what one
 * did, and neither of them depends on a relationship that does not exist.
 */
export async function loadMembership(
  db: SupabaseClient,
  roomId: string,
  userId: string,
): Promise<Membership | null> {
  const [player, phase] = await Promise.all([
    db
      .from("room_players")
      .select("seat, role, alive, kicked, rooms!inner(host_id, status, match_seed, settings)")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .maybeSingle(),
    db
      .from("room_state")
      .select("phase, phase_number, phase_ends_at")
      .eq("room_id", roomId)
      .maybeSingle(),
  ]);

  if (player.error) throw player.error;
  if (phase.error) throw phase.error;
  if (!player.data) return null;
  if (!phase.data) throw new Error("room state missing");

  // deno-lint-ignore no-explicit-any
  const data = player.data as any;
  // A removed seat keeps its row so the removal reaches the removed client
  // and the ban survives, but the row is not a membership: a kicked player
  // used to keep heartbeating (flipping its own status back to `connected`,
  // which also kept it out of `remove_player`'s three-minute silence) and
  // could still cast a ballot into the match it was banned from.
  if (data.kicked) return null;
  const room = data.rooms;
  // deno-lint-ignore no-explicit-any
  const state = phase.data as any;

  return {
    roomId,
    userId,
    seat: data.seat,
    role: data.role,
    alive: data.alive,
    hostId: room.host_id,
    status: room.status,
    matchSeed: room.match_seed,
    settings: room.settings ?? {},
    // A room with no state row is a room that has not been opened yet, which
    // is the lobby by definition.
    phase: state?.phase ?? "lobby",
    phaseNumber: state?.phase_number ?? 0,
    phaseEndsAt: state?.phase_ends_at ?? null,
  };
}

/**
 * An idempotency key, or null if the client sent something that is not one.
 *
 * `night_actions.action_id` and `votes.action_id` are `uuid` columns, so a key
 * of any other shape is refused by Postgres as `22P02` — and because the key
 * rides along on the row carrying the move, the *move* is refused with it. A
 * client that sends a malformed key has made a mistake about bookkeeping, not
 * about the game, and the game is what the request was for.
 *
 * Dropping the key costs nothing that matters: both tables are keyed on
 * (room, night|day, actor), so a retry overwrites its own row and O19 holds by
 * construction. The column exists to tell a *different* second action apart
 * from a replayed first one, which is a finer distinction than the one being
 * given up here.
 */
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function asUuid(value: unknown): string | null {
  return typeof value === "string" && UUID.test(value) ? value : null;
}

/** The night action a role is permitted to submit. Mirrors `RoleNightAction`. */
export function actionForRole(role: string | null): string | null {
  switch (role) {
    case "mafia":
      return "kill";
    case "doctor":
      return "protect";
    case "detective":
      return "investigate";
    case "citizen":
      return "suspect";
    default:
      return null;
  }
}

/**
 * Room codes: six characters, no ambiguous glyphs (doc 10 §10).
 *
 * `I`/`1`, `O`/`0` and `Z`/`2` are the pairs people mistype when reading a code
 * aloud to a friend, which is the only way a code is ever transmitted.
 */
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function generateCode(): string {
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  let out = "";
  for (const b of bytes) out += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return out;
}

/** A 32-bit match seed. Never leaves the server (doc 10 §10). */
export function newMatchSeed(): number {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return bytes[0];
}

/** Wraps a handler with CORS, auth and a uniform failure shape. */
export function handler(
  fn: (req: Request, userId: string, db: SupabaseClient) => Promise<Response>,
): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: CORS_HEADERS });
    }
    const userId = await callerId(req);
    if (!userId) {
      return fail("UNAUTHENTICATED", "no valid session", 401);
    }
    try {
      return await fn(req, userId, serviceClient());
    } catch (e) {
      // Never echo the exception: a stack trace from a function that touched
      // the role table is a leak of a different kind.
      console.error("request failed");
      return fail("BAD_REQUEST", "request could not be completed", 400);
    }
  };
}
