/**
 * Ballot rules (docs/specs/17, RL9 and RL13), pure so the Edge Functions that
 * apply them stay thin and a node test pins them.
 */

/**
 * RL9 — abstention follows the room's setting. A null target is an abstention;
 * it is refused unless the room turned `abstainAllowed` on (default off, as
 * `MatchSettings.abstainAllowed`). Grave votes follow the same rule. The timer
 * default `advance_phase` writes for a seat that said nothing is the server's
 * own record, not a client's choice, and does not pass through here.
 */
export function abstentionRefused(
  targetSeat: unknown,
  settings: Record<string, unknown>,
): boolean {
  return (targetSeat === null || targetSeat === undefined) &&
    settings.abstainAllowed !== true;
}

/** What a tallied ballot does next. */
export type BallotVerdict = "eliminate" | "revote" | "stand";

/**
 * RL13 — what happens to a ballot that has votes in it.
 *
 *  - one top seat: eliminated, unless a bought `revote` can narrow to at
 *    least two candidates (round 1)
 *  - several top seats (a tie): a second round among them when the room's
 *    `dayTieRule` is `revote` OR a revote was bought (round 1); otherwise the
 *    tie stands and nobody goes
 *  - round 2 never re-triggers anything: the second tie stands
 */
export function ballotVerdict(input: {
  round: number;
  topSeats: number;
  dayTieRule: unknown;
  revoteBought: boolean;
  narrowedCandidates?: number;
}): BallotVerdict {
  const { round, topSeats, dayTieRule, revoteBought, narrowedCandidates } = input;
  const firstRound = round === 1;
  if (topSeats <= 0) return "stand";
  if (topSeats === 1) return firstRound && revoteBought &&
      (narrowedCandidates === undefined || narrowedCandidates >= 2) ? "revote" : "eliminate";
  return firstRound && (dayTieRule === "revote" || revoteBought) ? "revote" : "stand";
}
