/**
 * The microphone policy table of doc 10 §6.3, on the server.
 *
 * It is a mirror of `lib/engine/voice_policy.dart`, phase for phase, and the
 * mirror is the point. The client hard-mutes itself against this table and the
 * server refuses the floor against it; if the two ever disagreed, the
 * disagreement would be a live microphone during a night — which is a leak of
 * the same kind as showing somebody a role, and doc 05 does not distinguish.
 *
 * The vocabularies differ because the schemas do: the Dart side names phases
 * after the state machine (`GamePhase.distributing`), the server after the
 * `room_state.phase` check constraint (`reveal`). `PHASE_NAMES` below is the
 * whole of the translation, and `test/engine/voice_policy_test.dart` walks both
 * lists to prove nothing was left out of either.
 */

export type MicPolicy = "open" | "activeSpeakerOnly" | "muted";

/** Every phase `room_state.phase` may hold. */
export const PHASE_NAMES = [
  "lobby",
  "reveal",
  "night",
  "morning",
  "opening",
  "confront",
  "discuss",
  "defense",
  "vote",
  "result",
] as const;

export type PhaseName = (typeof PHASE_NAMES)[number];

/**
 * What the phase permits. Never "may this player speak" — that is this answer
 * plus the floor, and the floor is a row.
 */
export function micPolicyFor(
  phase: string,
  settings: Record<string, unknown> = {},
): MicPolicy {
  switch (phase) {
    case "lobby":
    case "result":
      return "open";

    // Doc 10 §6.3: role reveal is "hard muted, server-enforced" and the night
    // is "hard muted for everyone, no exceptions".
    case "reveal":
    case "night":
      return "muted";

    // The app is speaking, and the trace is read once.
    case "morning":
      return "muted";

    // One seat at a time: the opening round points at a seat, the
    // confrontation names one, the defense belongs to the accused.
    case "opening":
    case "confront":
    case "defense":
      return "activeSpeakerOnly";

    case "discuss":
      return settings.discussionMode === "free" ? "open" : "activeSpeakerOnly";

    case "vote":
      return "muted";

    // A phase this table has not met is silence. The only safe default in a
    // game about hidden roles.
    default:
      return "muted";
  }
}

/**
 * The seat the floor belongs to in this phase, or null when it is open to
 * whoever asks first.
 *
 * `confront` and `opening` are not a race: the room is already pointed at one
 * player, and letting anybody else take the microphone would contradict the
 * screen every one of them is looking at.
 */
export function floorOwnerSeat(
  phase: string,
  publicData: Record<string, unknown>,
): number | null {
  if (phase === "confront" || phase === "defense") {
    const confrontation = publicData.confrontation as
      | { targetSeat?: number }
      | null
      | undefined;
    return confrontation?.targetSeat ?? null;
  }
  if (phase === "opening") {
    const seat = publicData.openingSeat;
    return typeof seat === "number" ? seat : null;
  }
  return null;
}

/** How long one grant of the floor lasts, in seconds. */
export function floorSecondsFor(
  phase: string,
  settings: Record<string, unknown>,
): number {
  switch (phase) {
    case "opening":
      return 10;
    case "confront":
    case "defense":
      return Number(settings.confrontationSeconds ?? 45);
    default:
      return Number(settings.speechSeconds ?? 60);
  }
}
