/**
 * Night rules that need a lookup of earlier moves (docs/specs/17, RL3 and RL5).
 *
 * Pure over the rows the caller already read, so `submit_night_action` and
 * `advance_phase` apply the same rule and one node test pins both.
 */

/** The part of a `night_actions` row these rules read. */
export type NightMove = {
  night?: number;
  actor_id?: string;
  action: string;
  target_id: string | null;
};

export type InvestigationVerdict = "open" | "same" | "refused";

/**
 * RL5 — one investigation a night. [existing] is the caller's row for this
 * night, if any. Once it holds an investigation with a target the night's
 * investigation is made: the same target again is the same request arriving
 * twice (answered as before), anything else is refused. The database enforces
 * the same thing in `night_action_one_investigation`, so two racing requests
 * cannot both win.
 */
export function investigationVerdict(
  existing: NightMove | null | undefined,
  requested: { action: string; targetId: string | null },
): InvestigationVerdict {
  if (!existing || existing.action !== "investigate" || existing.target_id === null) {
    return "open";
  }
  return requested.action === "investigate" && requested.targetId === existing.target_id
    ? "same"
    : "refused";
}

/**
 * RL3 — who this Doctor covered on night [night] - 1, or null. [rows] are
 * `night_actions` of any nights; only the previous night's protect row of
 * [actorId] counts.
 */
export function previousProtectTarget(
  rows: readonly (NightMove & { night: number; actor_id: string })[],
  actorId: string,
  night: number,
): string | null {
  const last = rows.find((r) =>
    r.actor_id === actorId && r.night === night - 1 && r.action === "protect"
  );
  return last?.target_id ?? null;
}

/**
 * RL3 — the Doctor may not cover the same player two nights running.
 * Self-protection (the Doctor's bullet) is exempt, as in `wouldViolateDoctorNoRepeat`.
 */
export function protectsSameTwice(
  previousTarget: string | null,
  targetId: string | null,
  selfProtect: boolean,
): boolean {
  return !selfProtect && previousTarget !== null && previousTarget === targetId;
}

/**
 * RL3 — the timer-expiry default for a Doctor who said nothing: a living
 * player other than himself, and other than last night's. Ordered by seat so
 * the seeded pick is stable. Empty means there is nothing legal to default to,
 * and the seat is left without a move.
 */
export function defaultProtectTargets<T extends { user_id: string; seat: number }>(
  living: readonly T[],
  doctorId: string,
  previousTarget: string | null,
): T[] {
  return living
    .filter((p) => p.user_id !== doctorId && p.user_id !== previousTarget)
    .sort((a, b) => a.seat - b.seat);
}

/** N8/N9: an absent kill holder follows a teammate's move; only an entirely
 * absent kill team gets seeded targets. A Silencer holds the kill only when no
 * living Mafioso does, matching submit_night_action. */
export function nightDefaultFor(
  player: { user_id: string; role: string },
  livingRoles: readonly { user_id: string; role: string }[],
  actedIds: ReadonlySet<string>,
): "kill" | "protect" | "skip" {
  const mafiosi = livingRoles.filter((p) => p.role === "mafia");
  const holders = mafiosi.length > 0
    ? mafiosi
    : livingRoles.filter((p) => p.role === "silencer");
  if (holders.some((p) => p.user_id === player.user_id)) {
    return holders.some((p) => actedIds.has(p.user_id)) ? "skip" : "kill";
  }
  return player.role === "doctor" ? "protect" : "skip";
}

/** Only a Doctor protecting their own seat spends selfProtect. */
export function bulletActionAllowed(
  bullet: string | null,
  action: string,
  targetSeat: number | null,
  ownSeat: number,
): boolean {
  return bullet !== "selfProtect" || (action === "protect" && targetSeat === ownSeat);
}
