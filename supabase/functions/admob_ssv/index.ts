import { serviceClient } from "../_shared/api.ts";
import { COMMIT_RPC, isUuid, routeReward } from "../_shared/ad_rewards.ts";
import {
  cachedKeyLoader, fetchGoogleKeys, KeysUnavailable, verifySsv,
} from "./verify.ts";

const loadKeys = cachedKeyLoader(fetchGoogleKeys);
const PERMANENT = [
  "BAD_SSV", "CLAIM_NOT_FOUND", "CLAIM_ALREADY_USED", "TRANSACTION_ALREADY_USED",
  "STEP_ORDER", "CLAIM_IMMUTABLE",
];

Deno.serve(async (request) => {
  try {
    if (request.method !== "GET") return new Response("method", { status: 405 });
    const url = new URL(request.url);
    let verdict;
    try {
      verdict = await verifySsv(url, loadKeys);
    } catch (error) {
      // Google's keys were unreachable: this reward may be perfectly valid, so
      // ask AdMob to retry instead of rejecting it for good.
      if (error instanceof KeysUnavailable) {
        return new Response("verifier keys unavailable", { status: 503 });
      }
      throw error;
    }
    // Malformed or wrongly signed: permanent. A 5xx here would have AdMob
    // retry an invalid callback indefinitely.
    if (verdict !== "valid") return new Response("invalid signature", { status: 400 });
    const customData = url.searchParams.get("custom_data");
    // AdMob's "verify URL" ping is correctly signed but carries no claim.
    // Acknowledge it; nothing is granted without a claim to commit.
    if (!customData) return new Response("ok (no claim)", { status: 200 });
    const transaction = url.searchParams.get("transaction_id");
    const adUnit = url.searchParams.get("ad_unit");
    const userId = url.searchParams.get("user_id");
    const rewardAmount = Number(url.searchParams.get("reward_amount"));
    const route = routeReward(customData, adUnit, (name) => Deno.env.get(name));
    // A malformed user id is permanent, not a 5xx for AdMob to retry forever.
    if (!route.ok || !transaction || !isUuid(userId) ||
        !Number.isSafeInteger(rewardAmount) || rewardAmount <= 0) {
      return new Response("invalid reward", { status: 400 });
    }
    const db = serviceClient();
    const { error } = await db.rpc(COMMIT_RPC[route.scheme], {
      p_claim: route.claimId, p_transaction: transaction, p_ad_unit: adUnit,
      p_reward_amount: rewardAmount, p_ssv_user: userId,
    });
    if (error) {
      // Deterministic refusals from the ledger (unknown claim, a transaction
      // already spent on another claim) will never succeed on a retry.
      if (PERMANENT.some((code) => error.message?.includes(code))) {
        return new Response("rejected", { status: 400 });
      }
      throw error;
    }
    return new Response("ok", { status: 200 });
  } catch (_) {
    return new Response("retry", { status: 500 });
  }
});
