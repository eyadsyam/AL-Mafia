/**
 * Which ledger a signed AdMob reward callback settles, and whether the unit
 * that served it may settle that ledger.
 *
 * `custom_data` is chosen by the client, so its prefix only names the table
 * to look in: the claim must still exist there for the signed `user_id`
 * (checked in SQL), and the ad unit must be one this deployment accepts for
 * that kind of reward. Everything here runs after the signature check.
 *
 *   <uuid>        1.0.0 one-ad claim            → commit_ad_reward
 *   s2:<uuid>     1.0.1 post-match step claim   → commit_ad_step_v2
 *   d1:<uuid>     1.0.1 daily vault ad claim    → commit_daily_ad
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isUuid = (value: string | null): value is string =>
  value !== null && UUID.test(value);

export type RewardScheme = "v1" | "step" | "daily";

export const COMMIT_RPC: Record<RewardScheme, string> = {
  v1: "commit_ad_reward",
  step: "commit_ad_step_v2",
  daily: "commit_daily_ad",
};

/** The numeric unit id AdMob puts in `ad_unit`: the part after the slash. */
export function unitNumber(configured: string | undefined): string | null {
  const value = configured?.trim();
  if (!value) return null;
  const last = value.split("/").pop() ?? "";
  return /^\d{6,}$/.test(last) ? last : null;
}

export type Route =
  | { ok: true; scheme: RewardScheme; claimId: string }
  | { ok: false; reason: "bad_claim" | "unit_not_accepted" | "not_configured" };

export function routeReward(
  customData: string | null,
  adUnit: string | null,
  env: (name: string) => string | undefined,
): Route {
  const primary = unitNumber(env("ADMOB_REWARDED_ANDROID_ID"));
  const second = unitNumber(env("ADMOB_REWARDED_V2_ANDROID_ID"));
  if (!primary && !second) return { ok: false, reason: "not_configured" };
  if (!customData) return { ok: false, reason: "bad_claim" };

  let scheme: RewardScheme;
  let claimId: string;
  if (customData.startsWith("s2:")) {
    scheme = "step";
    claimId = customData.slice(3);
  } else if (customData.startsWith("d1:")) {
    scheme = "daily";
    claimId = customData.slice(3);
  } else {
    scheme = "v1";
    claimId = customData;
  }
  if (!UUID.test(claimId)) return { ok: false, reason: "bad_claim" };

  // 1.0.0 only ever used the primary unit; the new offers may use either.
  const accepted = scheme === "v1" ? [primary] : [primary, second];
  if (!adUnit || !accepted.includes(adUnit)) {
    return { ok: false, reason: "unit_not_accepted" };
  }
  return { ok: true, scheme, claimId: claimId.toLowerCase() };
}
