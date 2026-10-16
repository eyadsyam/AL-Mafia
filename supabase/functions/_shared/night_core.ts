/** Pure night decision shared by the edge function and cross-engine vectors. */
import { isMafiaTeam } from "./teams.ts";
import { mafiaWentQuiet, saveIsTold, survivingSave } from "./bullets.ts";
import { deriveSeed, SeedSalt, tieBreakIndex } from "./seed.ts";

export type NightCorePlayer = { user_id: string; seat: number; role: string; alive: boolean };
export type NightCoreAction = {
  actor_id: string;
  action: string;
  target_id: string | null;
  used_bullet: boolean | null;
};
export type NightCoreInput = {
  roster: NightCorePlayer[];
  actions: NightCoreAction[];
  matchSeed: number;
  night: number;
  settings: Record<string, unknown>;
  lockedSeatSet: ReadonlySet<number>;
  noSilenceSeatSet: ReadonlySet<number>;
};
export type NightCoreOutput = {
  victimId: string | null;
  deathIds: string[];
  savedId: string | null;
  saveTold: boolean;
  silencedId: string | null;
};

export function resolveNightCore(input: NightCoreInput): NightCoreOutput {
  const { roster, actions, matchSeed, night, settings, lockedSeatSet, noSilenceSeatSet } = input;
  const seatOf = new Map(roster.map((p) => [p.user_id, p.seat]));
  const isLocked = (id: string | null | undefined) => !!id && lockedSeatSet.has(seatOf.get(id) ?? -1);
  const isUnsilenceable = (id: string | null | undefined) =>
    !!id && noSilenceSeatSet.has(seatOf.get(id) ?? -1);

  const alive = new Set(roster.filter((p) => p.alive).map((p) => p.user_id));
  const mafiaIds = new Set(roster.filter((p) => isMafiaTeam(p.role)).map((p) => p.user_id));
  const tally = new Map<string, number>();
  for (const a of actions ?? []) {
    if (a.action !== "kill" || !a.target_id || !alive.has(a.target_id) || !alive.has(a.actor_id)) continue;
    if (mafiaIds.has(a.target_id)) continue;
    tally.set(a.target_id, (tally.get(a.target_id) ?? 0) + 1);
  }
  let victimId: string | null = null;
  if (tally.size > 0) {
    const top = Math.max(...tally.values());
    const tied = [...tally.entries()]
      .filter(([, v]) => v === top)
      .map(([k]) => k)
      .sort((a, b) => (seatOf.get(a) ?? 0) - (seatOf.get(b) ?? 0));
    victimId = tied[
      tieBreakIndex(deriveSeed(matchSeed, SeedSalt.nightTieBreak, night), tied.length)
    ];
  }

  const protectTally = new Map<string, number>();
  for (const a of actions ?? []) {
    if (a.action !== "protect" || !a.target_id || !alive.has(a.actor_id)) continue;
    protectTally.set(a.target_id, (protectTally.get(a.target_id) ?? 0) + 1);
  }
  const protectedIds = new Set<string>();
  if (protectTally.size > 0) {
    const top = Math.max(...protectTally.values());
    const tied = [...protectTally.entries()]
      .filter(([, v]) => v === top)
      .map(([k]) => k)
      .sort((a, b) => (seatOf.get(a) ?? 0) - (seatOf.get(b) ?? 0));
    protectedIds.add(tied[
      tieBreakIndex(deriveSeed(matchSeed, SeedSalt.doctorTieBreak, night), tied.length)
    ]);
  }

  if (isLocked(victimId)) victimId = null;

  let savedId: string | null = null;
  if (victimId && protectedIds.has(victimId)) {
    savedId = victimId;
    victimId = null;
  }

  const mafiosoIds = new Set(roster.filter((p) => p.role === "mafia").map((p) => p.user_id));
  if (mafiaWentQuiet(actions ?? [], mafiosoIds, alive)) victimId = null;

  const deaths = new Set<string>();
  if (victimId) deaths.add(victimId);
  for (const a of actions ?? []) {
    const actor = roster.find((p) => p.user_id === a.actor_id);
    const target = roster.find((p) => p.user_id === a.target_id);
    if (!a.used_bullet || a.action !== "suspect" || actor?.role !== "sniper" ||
        !target || !alive.has(actor.user_id) || !alive.has(target.user_id) ||
        isLocked(target.user_id)) continue;
    deaths.add(target.user_id);
    if (!isMafiaTeam(target.role)) deaths.add(actor.user_id);
  }
  const deathIds = [...deaths].sort(
    (a, b) => (seatOf.get(a) ?? 0) - (seatOf.get(b) ?? 0),
  );
  savedId = survivingSave(savedId, deaths);
  const saveTold = saveIsTold({ savedSeat: savedId, deaths, settings });
  const silencedId = (actions ?? []).find((a) =>
    a.action === "silence" && !!a.target_id && alive.has(a.actor_id) && alive.has(a.target_id) &&
    !isLocked(a.target_id) && !isUnsilenceable(a.target_id) && !deaths.has(a.target_id)
  )?.target_id ?? null;
  return { victimId, deathIds, savedId, saveTold, silencedId };
}
