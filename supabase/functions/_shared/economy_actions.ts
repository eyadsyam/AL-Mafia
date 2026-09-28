/**
 * The economy function's request surface: which RPC an action runs, with
 * which arguments. The caller's id always comes from the verified session,
 * never from the body; amounts never come from the client at all.
 *
 * 1.0.0 actions are unchanged. 1.0.1 actions are new names, so an old client
 * never reaches them and a new client talking to an old server gets
 * BAD_REQUEST — which it reads as "capability absent".
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
/** ISO week, as the server names it: `2026-W39`. */
const WEEK = /^\d{4}-W\d{2}$/;
/** Invite codes: 7 characters from the room-code alphabet. */
const INVITE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$/;
/** The eight quick reactions (phase 109). */
const REACTION = /^(laugh|shock|suspicious|applause|rose|skull|coffee|crown)$/;
/** F10: the four gallery portraits a Partner can be. */
const PARTNER_SIDE = /^(detective|doctor|mafia|citizen)$/;
/** Server-owned catalogue identifiers, never free-form copy. */
const CASEBOOK_CODE = /^[a-z0-9_]{3,60}$/;

export type EconomyCall = { rpc: string; args: Record<string, unknown> };
export type CasePuzzleRequest =
  | { kind: "read" }
  | { kind: "solve"; day: string; pick: string; requestId?: string };

/** The server day a daily request was made for. Required: a retry without
 * one could otherwise land on the next UTC day as a fresh claim. */
function day(value: unknown): string | undefined {
  return typeof value === "string" && DAY.test(value) ? value : undefined;
}

/** Case puzzles are completed in the edge function because only it may know
 * the salted answer. Returning `undefined` means this is not a puzzle action;
 * returning `null` means it tried to be one but its input is malformed. */
export function casePuzzleRequest(
  body: Record<string, unknown>,
): CasePuzzleRequest | null | undefined {
  if (body.action === "casePuzzle") return { kind: "read" };
  if (body.action !== "casePuzzleSolve") return undefined;
  const d = day(body.day);
  if (d === undefined || typeof body.pick !== "string" || !/^s[0-6]$/.test(body.pick)) {
    return null;
  }
  // D2 — the id that makes a retried pick the same pick. Optional for older
  // clients; malformed is a malformed request, never silently dropped.
  if (body.requestId === undefined) return { kind: "solve", day: d, pick: body.pick };
  return typeof body.requestId === "string" && UUID.test(body.requestId)
    ? { kind: "solve", day: d, pick: body.pick, requestId: body.requestId.toLowerCase() }
    : null;
}

export function economyCall(
  body: Record<string, unknown>,
  userId: string,
): EconomyCall | null {
  const action = body.action;
  const room = typeof body.roomId === "string" && UUID.test(body.roomId)
    ? body.roomId : null;
  switch (action) {
    case "summary":
      return { rpc: "wallet_snapshot", args: { p_user: userId } };
    case "sync":
      return { rpc: "sync_player_rewards", args: { p_user: userId } };
    case "buy":
      return typeof body.item === "string"
        ? { rpc: "buy_reward_item", args: { p_user: userId, p_item: body.item } }
        : null;
    case "equip":
      return typeof body.slot === "string" &&
          (body.item === null || typeof body.item === "string")
        ? {
          rpc: "equip_reward_item",
          args: { p_user: userId, p_slot: body.slot, p_item: body.item },
        }
        : null;
    case "create_ad_claim":
      return typeof body.roomId === "string"
        ? { rpc: "create_ad_reward_claim", args: { p_user: userId, p_room: body.roomId } }
        : null;
    case "ad_status":
      return typeof body.roomId === "string"
        ? { rpc: "ad_reward_status", args: { p_user: userId, p_room: body.roomId } }
        : null;
    // 1.0.1 ------------------------------------------------------------------
    case "capabilities":
      return { rpc: "economy_capabilities", args: { p_user: userId } };
    case "ad_steps_status_v2":
      return room ? { rpc: "ad_steps_status_v2", args: { p_user: userId, p_room: room } } : null;
    case "ad_step_claim_v2": {
      const step = body.step;
      return room && (step === 1 || step === 2)
        ? { rpc: "create_ad_step_claim_v2", args: { p_user: userId, p_room: room, p_step: step } }
        : null;
    }
    case "daily_status":
      return { rpc: "daily_status", args: { p_user: userId } };
    case "daily_coffer":
    case "daily_spin":
    case "daily_ad_claim": {
      const d = day(body.day);
      if (d === undefined) return null;
      const rpc = action === "daily_coffer"
        ? "claim_daily_coffer"
        : action === "daily_spin" ? "spin_daily_wheel" : "create_daily_ad_claim";
      return { rpc, args: { p_user: userId, p_day: d } };
    }
    // Phase 108: Ads v2 voluntary extras -------------------------------------------
    case "extras_status":
      return { rpc: "ad_extras_status", args: { p_user: userId } };
    case "extra_claim": {
      const d = day(body.day);
      const kind = body.kind;
      if (d === undefined) return null;
      if (kind === "spin" || kind === "coffer") {
        return { rpc: "create_ad_extra_claim", args: { p_user: userId, p_day: d, p_kind: kind, p_slot: null } };
      }
      const slot = body.slot;
      return kind === "swap" && (slot === 0 || slot === 1 || slot === 2)
        ? { rpc: "create_ad_extra_claim", args: { p_user: userId, p_day: d, p_kind: kind, p_slot: slot } }
        : null;
    }
    // Phase 107: Council Life ---------------------------------------------------
    case "contracts_get":
      return { rpc: "council_contracts", args: { p_user: userId } };
    case "contract_claim": {
      const d = day(body.day);
      const slot = body.slot;
      return d !== undefined && (slot === 0 || slot === 1 || slot === 2)
        ? { rpc: "claim_council_contract", args: { p_user: userId, p_day: d, p_slot: slot } }
        : null;
    }
    case "weekly_claim":
      return typeof body.week === "string" && WEEK.test(body.week)
        ? { rpc: "claim_council_weekly", args: { p_user: userId, p_week: body.week } }
        : null;
    case "rank_get":
      return { rpc: "council_rank", args: { p_user: userId } };
    // D7 — the result screen's one call: sync + contracts + rank + Casebook hub.
    // With a request id it is the room's summary: deltas, the receipt, and
    // the first answer replayed on retry. Without one, the 1.1.0 answer.
    case "resultSummary": {
      if (body.requestId === undefined) {
        return { rpc: "result_summary", args: { p_user: userId } };
      }
      return room && typeof body.requestId === "string" && UUID.test(body.requestId)
        ? {
          rpc: "result_summary_room",
          args: { p_user: userId, p_room: room, p_request: body.requestId.toLowerCase() },
        }
        : null;
    }
    case "leaderboard_get":
      return { rpc: "council_leaderboard", args: { p_user: userId } };
    case "leaderboard_visibility":
      return typeof body.visible === "boolean"
        ? {
          rpc: "set_council_leaderboard_visible",
          args: { p_user: userId, p_visible: body.visible },
        }
        : null;
    case "invite_get":
      return { rpc: "council_invite", args: { p_user: userId } };
    // Row 6: the inviter has read these notices («{name} لعب أول ماتش…»).
    case "invite_ack": {
      const ids = body.ids;
      return Array.isArray(ids) && ids.length >= 1 && ids.length <= 50 &&
          ids.every((id) => Number.isSafeInteger(id) && (id as number) > 0)
        ? { rpc: "invite_notices_ack", args: { p_user: userId, p_ids: ids } }
        : null;
    }
    case "invite_redeem": {
      const code = typeof body.code === "string"
        ? body.code.trim().toUpperCase() : "";
      return INVITE.test(code)
        ? { rpc: "redeem_council_invite", args: { p_user: userId, p_code: code } }
        : null;
    }
    // Phase 109: awards, reactions, Founder badge ------------------------------
    case "awards_get":
      return room ? { rpc: "match_awards_get", args: { p_user: userId, p_room: room } } : null;
    case "react":
      return room && typeof body.kind === "string" && REACTION.test(body.kind)
        ? { rpc: "send_room_reaction", args: { p_user: userId, p_room: room, p_kind: body.kind } }
        : null;
    case "fun_profile":
      return { rpc: "fun_profile", args: { p_user: userId } };
    // 1.1 Casebook ------------------------------------------------------------
    case "missionHub":
      return { rpc: "mission_hub", args: { p_user: userId } };
    case "missionClaim": {
      const layer = body.layer;
      const period = body.period;
      const slot = body.slot;
      const validPeriod = layer === "daily"
        ? typeof period === "string" && DAY.test(period)
        : layer === "weekly" && typeof period === "string" && WEEK.test(period);
      const validSlot = layer === "daily"
        ? slot === 0 || slot === 1 || slot === 2
        : layer === "weekly" && slot === 0;
      return validPeriod && validSlot
        ? {
          rpc: "claim_mission",
          args: { p_user: userId, p_layer: layer, p_period: period, p_slot: slot },
        }
        : null;
    }
    case "seasonClaim":
      return typeof body.season === "string" && CASEBOOK_CODE.test(body.season) &&
          Number.isInteger(body.level) && (body.level as number) >= 1 && (body.level as number) <= 20
        ? {
          rpc: "claim_season_reward",
          args: { p_user: userId, p_season: body.season, p_level: body.level },
        }
        : null;
    case "achievementClaim":
      return typeof body.code === "string" && CASEBOOK_CODE.test(body.code)
        ? { rpc: "claim_achievement", args: { p_user: userId, p_code: body.code } }
        : null;
    // 1.1 F10: titles and the core Partner ----------------------------------------
    case "titleHub":
      return { rpc: "title_hub", args: { p_user: userId } };
    case "titleEquip":
      return (body.code === null ||
          (typeof body.code === "string" && CASEBOOK_CODE.test(body.code))) &&
          typeof body.requestId === "string" && UUID.test(body.requestId)
        ? {
          rpc: "title_equip",
          args: { p_user: userId, p_code: body.code, p_request: body.requestId.toLowerCase() },
        }
        : null;
    case "roomTitles":
      return room ? { rpc: "room_titles", args: { p_user: userId, p_room: room } } : null;
    case "partnerGet":
      return { rpc: "partner_get", args: { p_user: userId } };
    case "partnerSet":
      return typeof body.side === "string" && PARTNER_SIDE.test(body.side) &&
          typeof body.requestId === "string" && UUID.test(body.requestId)
        ? {
          rpc: "partner_set",
          args: { p_user: userId, p_side: body.side, p_request: body.requestId.toLowerCase() },
        }
        : null;
    default:
      return null;
  }
}

/** Refusals the client can act on; anything else is a generic failure. */
export const ECONOMY_REFUSALS = [
  "INSUFFICIENT_COINS", "ITEM_NOT_FOUND", "ITEM_NOT_OWNED", "FEATURE_OFF",
  "STEP_ORDER", "DAY_CHANGED", "DAY_REQUIRED", "IN_MATCH", "DAILY_PAUSED", "REWARD_NOT_ELIGIBLE",
  "REWARD_NOT_SYNCED", "REWARD_SCHEME_V2",
  "CONTRACT_INCOMPLETE", "WEEK_CHANGED", "WEEK_REQUIRED", "INVITE_SELF", "INVITE_EXPIRED",
  "INVITE_NOT_NEW", "INVITE_ALREADY", "INVITE_LOOP", "INVITE_LIMIT", "INVITE_RATE_LIMIT",
  "REACTION_RATE_LIMIT", "REACTION_CLOSED", "REACTION_UNKNOWN", "NOT_MEMBER",
  "EXTRA_NOT_READY", "DISABLED", "NOT_READY", "PERIOD_CHANGED", "SEASON_CLOSED",
  "NOT_FOUND", "ALREADY_CLAIMED", "NO_ATTEMPTS", "ALREADY_SOLVED", "BAD_REQUEST",
] as const;

export function refusalOf(message: string | undefined): string | null {
  if (!message) return null;
  return ECONOMY_REFUSALS.find((code) => message.includes(code)) ?? null;
}
