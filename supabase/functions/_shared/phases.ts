/**
 * The phase table: what may follow what, how long each phase runs, and what it
 * clears from the public payload.
 *
 * Three functions need the same answers — `open_phase` when the host advances,
 * `submit_accusation` when the «اسم واحد» round passes itself on, and
 * `advance_phase` when a deadline expires — and three copies of a transition
 * table is how a room ends up in a phase two of them agree is impossible.
 */

/** Which phase may follow which. Anything not listed is refused. */
export const TRANSITIONS: Record<string, string[]> = {
  lobby: [],
  reveal: ["night"],
  // A night ends by being resolved, never by being advanced past.
  night: [],
  morning: ["opening", "discuss", "result"],
  opening: ["discuss"],
  confront: ["discuss"],
  discuss: ["vote"],
  defense: ["vote"],
  vote: [],
  result: [],
};

/**
 * Seconds each phase runs for, or null for the phases that end when somebody
 * decides they have.
 *
 * The two numbers that are not arbitrary come from the specs: ten seconds per
 * seat in the «اسم واحد» round (doc 09 §2.2) and forty-five for a
 * confrontation (doc 09 §2.6, and `MatchSettings.confrontationSeconds`). The
 * night and the ballot are generous on purpose — they are the two phases where
 * a player who is thinking looks exactly like a player who has left, and the
 * cost of being wrong is a forced default on somebody who was still deciding.
 */
export function durationFor(
  phase: string,
  settings: Record<string, unknown>,
): number | null {
  switch (phase) {
    case "night":
      return 120;
    case "opening":
      return 10;
    case "confront":
      return Number(settings.confrontationSeconds ?? 45);
    case "discuss":
      return Number(settings.speechSeconds ?? 60) * 3;
    case "vote":
      return 60;
    default:
      return null;
  }
}

/** `phase_ends_at` for a phase opening now, or null when it has no clock. */
export function deadlineFor(
  phase: string,
  settings: Record<string, unknown>,
): string | null {
  const seconds = durationFor(phase, settings);
  return seconds === null
    ? null
    : new Date(Date.now() + seconds * 1000).toISOString();
}

/**
 * What each phase clears from the public payload.
 *
 * A JSON null rather than a deletion: the client reads a missing key and a null
 * key the same way, and a jsonb merge cannot remove a key. What matters is that
 * the *archives* — `resolvedNights`, `confrontations`, `openingAccusations`,
 * `speakingSeconds` — are never in this list, because the generators read them
 * for the whole match.
 */
export function clearedFor(phase: string): Record<string, unknown> {
  switch (phase) {
    case "night":
      return {
        morning: null,
        lastVote: null,
        confrontation: null,
        confrontationSilent: null,
        openingSeat: null,
        revote: null,
      };
    case "opening":
      return { lastVote: null, confrontation: null, openingAccusations: {} };
    case "vote":
      return { lastVote: null };
    default:
      return {};
  }
}
