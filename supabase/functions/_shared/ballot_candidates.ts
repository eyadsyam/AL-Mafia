/** Candidate eligibility comes only from the committed public revote payload. */
export function ballotTargetAllowed(round: number, tiedSeats: unknown, seat: unknown): boolean {
  if (seat === null) return true; // Abstention remains governed by existing rules.
  if (!Number.isInteger(seat) || (seat as number) < 0) return false;
  return round === 1 || (Array.isArray(tiedSeats) && tiedSeats.includes(seat));
}
