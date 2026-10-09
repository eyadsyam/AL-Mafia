/**
 * «أدوات القعدة» — what a used tool does to the match.
 *
 * `use_table_tool` (SQL) charges the player and writes one row in
 * `room_tool_uses`; the match functions read those rows through the helpers
 * below. Every helper is pure over the rows so each effect has a unit test,
 * and no function takes anything from a client.
 *
 * Phase numbers: night N is followed by day N. A protection bought in the
 * day (lock_door, half_door, impersonate, camouflage) covers the night that
 * follows it, N + 1.
 */

import { isMafiaTeam } from "./teams.ts";

export type ToolUse = {
  /** Row id; present on rows read from the database. */
  id?: number;
  /** Set once a one-shot effect (the floor bonus) has been spent. */
  consumed_at?: string | null;
  user_id: string;
  seat: number;
  tool_code: string;
  phase: string;
  phase_number: number;
  target_seats: number[];
  note: string | null;
};

// deno-lint-ignore no-explicit-any
type Db = any;

export async function loadToolUses(db: Db, roomId: string): Promise<ToolUse[]> {
  const { data, error } = await db
    .from("room_tool_uses")
    .select("id, user_id, seat, tool_code, phase, phase_number, target_seats, note, consumed_at")
    .eq("room_id", roomId);
  if (error) throw error;
  return (data ?? []) as ToolUse[];
}

const used = (uses: ToolUse[], code: string, phaseNumber: number) =>
  uses.filter((u) => u.tool_code === code && u.phase_number === phaseNumber);

/** Tools bought in the day that cover the next night. */
const coversNight = (uses: ToolUse[], code: string, night: number) =>
  uses.filter((u) => u.tool_code === code && u.phase_number === night - 1 &&
    u.phase !== "night");

/** Seats nothing reaches tonight: no kill, silence, shot or investigation. */
export function lockedSeats(uses: ToolUse[], night: number): Set<number> {
  return new Set(coversNight(uses, "lock_door", night).map((u) => u.seat));
}

/** Seats no silence or investigation reaches tonight (a kill still does). */
export function halfDoorSeats(uses: ToolUse[], night: number): Set<number> {
  const s = new Set(coversNight(uses, "half_door", night).map((u) => u.seat));
  for (const seat of lockedSeats(uses, night)) s.add(seat);
  return s;
}

/**
 * What the Detective is told about [seat] tonight, given the true [role].
 * `impersonate` shows the face its user chose; `camouflage` shows nothing
 * clear; a closed door is not reached at all (null).
 */
export function detectiveSees(
  uses: ToolUse[],
  night: number,
  seat: number,
  role: string | null,
): string | null {
  if (halfDoorSeats(uses, night).has(seat)) return "unreachable";
  const face = coversNight(uses, "impersonate", night).find((u) => u.seat === seat);
  if (face && (face.note === "citizen" || face.note === "mafia")) return face.note;
  if (coversNight(uses, "camouflage", night).some((u) => u.seat === seat)) return "unclear";
  return role;
}

/**
 * Seats a silence cannot land on tonight. A `vote_shield` is bought in the
 * day and protects the ballot of the day the night's silence would hit, so it
 * covers night N + 1 like the doors do.
 */
export function unsilenceable(uses: ToolUse[], night: number): Set<number> {
  const s = new Set(coversNight(uses, "vote_shield", night).map((u) => u.seat));
  for (const seat of halfDoorSeats(uses, night)) s.add(seat);
  return s;
}

/**
 * Ballot weight per voter seat on day [day]: 1, or 2 with `double_vote`.
 * The role multiplier (the Elder's 3) is applied by the caller on top.
 */
export function toolVoteWeight(uses: ToolUse[], day: number, seat: number): number {
  return used(uses, "double_vote", day).some((u) => u.seat === seat) ? 2 : 1;
}

/** Dead seats allowed to cast one ballot on day [day]: the day it was bought. */
export function graveVoters(uses: ToolUse[], day: number): Set<number> {
  return new Set(used(uses, "grave_vote", day).map((u) => u.seat));
}

/** Unspent floor-bonus uses (extra_minute, objection) of [seat] on [phaseNumber]. */
export function pendingFloorBonuses(
  uses: ToolUse[],
  phaseNumber: number,
  seat: number,
): ToolUse[] {
  return uses.filter((u) =>
    (u.tool_code === "extra_minute" || u.tool_code === "objection") &&
    u.phase_number === phaseNumber && u.seat === seat && !u.consumed_at
  );
}

/**
 * Extra floor seconds for [seat]: only the bonuses not yet spent. The caller
 * marks them consumed once the claim is granted, so the bonus belongs to the
 * first floor claim after the purchase and to no later one.
 */
export function floorBonusSeconds(
  uses: ToolUse[],
  phaseNumber: number,
  seat: number,
): number {
  let extra = 0;
  for (const u of pendingFloorBonuses(uses, phaseNumber, seat)) {
    extra += u.tool_code === "extra_minute" ? 45 : 30;
  }
  return extra;
}

/** Whether a `revote` was spent on day [day] and not yet honoured. */
export function revoteRequested(uses: ToolUse[], day: number): boolean {
  return used(uses, "revote", day).length > 0;
}

/** Seats that appealed their elimination on day [day]. */
export function appealed(uses: ToolUse[], day: number): Set<number> {
  return new Set(used(uses, "appeal", day).map((u) => u.seat));
}

/**
 * The two sides of an appeal from the same ballots: [counted] are the ballots
 * the tally accepted (eligible voter, valid target), each with the weight the
 * tally gave it. The appellant's own ballot is left out of both sides.
 */
export function appealCounts(
  counted: { voter: string; target: string; weight: number }[],
  appellant: string,
): { confirm: number; voters: number } {
  let confirm = 0;
  let voters = 0;
  for (const b of counted) {
    if (b.voter === appellant) continue;
    voters += b.weight;
    if (b.target === appellant) confirm += b.weight;
  }
  return { confirm, voters };
}

/**
 * An appeal holds unless more than two thirds of the [voters] (weighted
 * ballots, the appellant excluded) confirm the elimination.
 */
export function appealUpheld(confirm: number, voters: number): boolean {
  return voters > 0 && confirm * 3 > voters * 2;
}

/**
 * The narrator's private answer for `narrator_whisper` and `sense`: whether a
 * mafioso sits among the chosen seats. [roleOf] gives each seat's true role.
 */
export function whisperAnswer(
  use: ToolUse,
  roleOf: (seat: number) => string | null,
): boolean {
  return use.target_seats.some((s) => {
    return isMafiaTeam(roleOf(s));
  });
}
