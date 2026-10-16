/**
 * The once-per-match moves (doc 13 §2) and the rules that read them.
 *
 * Pure over rows and settings, so each rule has a node test and the Edge
 * Functions that apply them stay thin. The Dart twin is `lib/engine/bullets.dart`
 * and `lib/engine/resolver.dart`; where they differ the Dart side is the
 * reference (`docs/specs/17-roles-and-tools.md` RL1, RL2, RL17).
 */

/** The once-per-match move each role holds, or null for the two that hold none. */
export type Bullet = "quietNight" | "selfProtect" | "sniperShot";

export function bulletFor(role: string | null): Bullet | null {
  switch (role) {
    case "mafia":
      return "quietNight";
    case "doctor":
      return "selfProtect";
    case "sniper":
      return "sniperShot";
    default:
      return null;
  }
}

/**
 * Whether the room turned this bullet on.
 *
 * Read from `rooms.settings`, never from the request — a client that lied about
 * its own settings would be spending a move the rest of the table is not
 * playing with. Absent means on, matching `MatchSettings`' defaults, because a
 * room created by an older client is playing the same game as this one.
 */
export function bulletEnabled(
  settings: Record<string, unknown>,
  kind: Bullet,
): boolean {
  if (kind === "selfProtect") return true;
  if (kind === "sniperShot") return settings.sniperEnabled === true;
  if (settings.bulletsEnabled === false) return false;
  const key = kind === "quietNight" ? "quietNightEnabled" : "selfProtectEnabled";
  return settings[key] !== false;
}

/** A night move as far as the bullet rules care: who made it and whether it spent one. */
export type BulletRow = { actor_id: string; used_bullet?: boolean | null };

/**
 * RL1 — the quiet night is the Mafia team's one bullet. True when a Mafioso
 * other than [exceptActor] has already spent it, on any night. Only role
 * exactly `mafia` counts: the Silencer is on the team but holds no bullet.
 * [rows] are the room's `night_actions` (all nights); [mafiosoIds] the user ids
 * whose role is `mafia`.
 */
export function teamBulletSpent(
  rows: readonly BulletRow[],
  mafiosoIds: ReadonlySet<string> | readonly string[],
  exceptActor: string | null = null,
): boolean {
  const mafiosi = mafiosoIds instanceof Set ? mafiosoIds : new Set(mafiosoIds);
  return rows.some((r) =>
    r.used_bullet === true && mafiosi.has(r.actor_id) && r.actor_id !== exceptActor
  );
}

// deno-lint-ignore no-explicit-any
type Db = any;

/**
 * Reads the room and answers [teamBulletSpent]: who the Mafiosi are (role
 * exactly `mafia`), and which night rows spent a bullet. Two small reads,
 * shared by `submit_night_action` (before it lets a Mafioso spend) and
 * `my_team` (so the team can see the bullet is gone).
 */
export async function loadTeamBulletSpent(
  db: Db,
  roomId: string,
  exceptActor: string | null = null,
): Promise<boolean> {
  const { data: mafiosi, error: mafiosiError } = await db
    .from("room_players")
    .select("user_id")
    .eq("room_id", roomId)
    .eq("role", "mafia");
  if (mafiosiError) throw mafiosiError;
  const { data: spent, error: spentError } = await db
    .from("night_actions")
    .select("actor_id, used_bullet")
    .eq("room_id", roomId)
    .eq("used_bullet", true);
  if (spentError) throw spentError;
  return teamBulletSpent(
    spent ?? [],
    (mafiosi ?? []).map((p: { user_id: string }) => p.user_id),
    exceptActor,
  );
}

/**
 * RL1 — whether the Mafia go quiet tonight: a living Mafioso's move tonight
 * spent the team's bullet. [tonight] are tonight's `night_actions`; a dead or
 * removed seat has no move (see `resolve_night`).
 */
export function mafiaWentQuiet(
  tonight: readonly BulletRow[],
  mafiosoIds: ReadonlySet<string>,
  alive: ReadonlySet<string>,
): boolean {
  return tonight.some((r) =>
    r.used_bullet === true && mafiosoIds.has(r.actor_id) && alive.has(r.actor_id)
  );
}

/**
 * RL2 — whether the room has a quiet night the Mafia could be hiding behind.
 * With bullets on and the quiet night on, a morning that nobody died reads
 * the same whether the Doctor saved or the Mafia went quiet, and only that
 * ambiguity makes the Doctor's save safe to hide; without it the save is told.
 */
export function quietNightAvailable(settings: Record<string, unknown>): boolean {
  return bulletEnabled(settings, "quietNight");
}

/**
 * RL17 — a save is a save only if the covered player sees the morning. The
 * Sniper's shot is outside protection and can still take him; recording the
 * save anyway would let a trace announce a survival that did not happen.
 * Returns the saved player, or null when there is no save to record.
 */
export function survivingSave<T>(
  saved: T | null | undefined,
  deaths: Iterable<T>,
): T | null {
  if (saved === null || saved === undefined) return null;
  for (const dead of deaths) if (dead === saved) return null;
  return saved;
}

/**
 * RL2 and RL17 — whether the morning may tell that somebody was saved
 * (`someoneSavedUnnamed`, and trace T2's `saveOccurred`). Two conditions, both
 * required: the room has no quiet night to hide behind, and the covered seat
 * is alive after tonight's deaths.
 */
export function saveIsTold<T>(input: {
  savedSeat: T | null | undefined;
  deaths: Iterable<T>;
  settings: Record<string, unknown>;
}): boolean {
  if (quietNightAvailable(input.settings)) return false;
  return survivingSave(input.savedSeat, input.deaths) !== null;
}
