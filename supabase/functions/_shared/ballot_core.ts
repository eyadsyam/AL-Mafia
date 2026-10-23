/** Pure day-ballot decision. The caller owns reads, fingerprinting and commits. */
import { isMafiaTeam } from "./teams.ts";
import { ballotTargetAllowed } from "./ballot_candidates.ts";
import { ballotVerdict, boughtRevoteCausedSecondRound } from "./vote_rules.ts";
import {
  appealCounts, appealed, appealUpheld, graveVoters, revoteRequested,
  toolVoteWeight, type ToolUse,
} from "./tools.ts";

export type BallotInput = {
  roster: { user_id: string; seat: number; alive: boolean; role: string }[];
  cast: { voter_id: string; target_id: string | null; round: number }[];
  round: number;
  revoteState: { round?: number; tiedSeats?: unknown } | null;
  toolUses: ToolUse[];
  day: number;
  revealedElderSeats: number[];
  decidedOutcome: unknown;
  settings: Record<string, unknown>;
};

export function resolveBallotCore(input: BallotInput) {
  const { roster, cast, round, revoteState, toolUses, day, decidedOutcome } = input;
  const seatOf = new Map(roster.map((p) => [p.user_id, p.seat]));
  // A ballot counts only between two living seats: a voter the host removed
  // after casting it is out of the match, and a seat put out does not go on
  // deciding the town's verdict from outside it (see `resolve_night`).
  const alive = new Set(roster.filter((p) => p.alive).map((p) => p.user_id));
  const revealedElders = new Set(input.revealedElderSeats.map(Number));
  const graves = graveVoters(toolUses, day);
  // A ballot weighs 3 for a revealed Elder, times 2 for a bought double vote.
  const weightOf = (voter: { role: string; seat: number } | undefined) =>
    (voter?.role === "elder" && revealedElders.has(voter.seat) ? 3 : 1) *
    toolVoteWeight(toolUses, day, voter?.seat ?? -1);
  const tally = new Map<string, number>();
  // The ballots the tally accepted, with their weights: the appeal reads
  // numerator and denominator from these same ballots.
  const counted: { voter: string; target: string | null; weight: number }[] = [];
  for (const v of cast) {
    const voter = roster.find((p) => p.user_id === v.voter_id);
    // A dead seat counts only with a bought grave vote, in the opening round.
    const mayVote = alive.has(v.voter_id) ||
      (!!voter && round === 1 && graves.has(voter.seat));
    if (v.round !== round || !mayVote ||
        (v.target_id !== null && !alive.has(v.target_id))) continue;
    if (!ballotTargetAllowed(round, revoteState?.tiedSeats,
      v.target_id === null ? null : seatOf.get(v.target_id))) continue;
    const weight = weightOf(voter);
    counted.push({ voter: v.voter_id, target: v.target_id, weight });
    if (v.target_id !== null) {
      tally.set(v.target_id, (tally.get(v.target_id) ?? 0) + weight);
    }
  }
  const publicTally: Record<number, number> = {};
  for (const [id, n] of tally) publicTally[seatOf.get(id) ?? -1] = n;

  let eliminatedId: string | null = null;
  let tiedSeats: number[] = [];
  let revote = false;
  const revoteBought = round === 1 && revoteRequested(toolUses, day);
  let boughtRevoteWorked = false;
  if (tally.size > 0 && decidedOutcome !== "mafia" && decidedOutcome !== "town") {
    const top = Math.max(...tally.values());
    const tied = [...tally.entries()].filter(([, v]) => v === top).map(([k]) => k)
      .filter((id) => roster.find((p) => p.user_id === id)?.alive);
    if (tied.length > 1) {
      tiedSeats = tied.map((id) => seatOf.get(id) ?? -1).sort((a, b) => a - b);
    }
    // Round 1 is the opening ballot; anything above it has already had its
    // second chance. A bought `revote` (RL13) reopens the ballot in round 1
    // whether it was won clearly or tied, even under «محدش يخرج»; round 2
    // never re-triggers it.
    const ballot = {
      round, topSeats: tied.length,
      dayTieRule: input.settings.dayTieRule ?? "noElimination",
      revoteBought, narrowedCandidates: tally.size,
    };
    const verdict = ballotVerdict(ballot);
    boughtRevoteWorked = boughtRevoteCausedSecondRound(ballot);
    if (verdict === "eliminate") eliminatedId = tied[0];
    else if (verdict === "revote") {
      revote = true;
      // Over a clear winner the bought revote narrows the ballot to the
      // seats that drew a ballot; over a tie it is the tied seats.
      if (tied.length === 1) {
        tiedSeats = [...tally.keys()].map((id) => seatOf.get(id) ?? -1)
          .filter((s) => s >= 0).sort((a, b) => a - b);
      }
    }
  }
  // A bought `appeal`: the elimination stands only if more than two thirds of
  // the weighted ballots counted from everyone else (him excluded) confirm it. Otherwise nobody goes out today.
  let appealResult: { confirm: number; voters: number; upheld: boolean } | null = null;
  if (eliminatedId && appealed(toolUses, day).has(seatOf.get(eliminatedId) ?? -1)) {
    const { confirm, voters } = appealCounts(counted, eliminatedId);
    const upheld = appealUpheld(confirm, voters);
    appealResult = { confirm, voters, upheld };
    if (!upheld) eliminatedId = null;
  }
  // D11 — the reveal is never skipped. A day elimination is public by design
  // (FR-019); this is the one place a role legitimately reaches the table.
  const eliminatedSeat = eliminatedId ? seatOf.get(eliminatedId) ?? null : null;
  const eliminatedRole = eliminatedId
    ? roster.find((p) => p.user_id === eliminatedId)?.role ?? null : null;
  // W8 — the check runs after every death is applied, never mid-resolution.
  const living = roster.filter((p) => p.alive && p.user_id !== eliminatedId);
  const mafia = living.filter((p) => isMafiaTeam(p.role)).length;
  const town = living.length - mafia;
  let outcome: string | null = decidedOutcome === "mafia" || decidedOutcome === "town"
    ? decidedOutcome : null;
  if (!outcome && mafia === 0) outcome = "town";
  else if (!outcome && mafia >= town) outcome = "mafia";
  return { eliminatedId, eliminatedSeat, eliminatedRole, tiedSeats, revote,
    publicTally, appealResult, boughtRevoteWorked, outcome, revoteBought };
}
