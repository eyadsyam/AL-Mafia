export async function ensureScenarioAccess(
  db: any,
  userId: string,
  settings: Record<string, unknown> | undefined,
): Promise<boolean> {
  if (settings?.scenarioCode !== "shadows") return true;
  const { data, error } = await db.rpc("user_owns_entitlement", {
    p_user: userId,
    p_item: "scenario_shadows",
  });
  if (error) throw error;
  return data === true;
}

/**
 * A host may dress a room only with packs they own. Checked when a value is
 * being set (create_room, room_settings), never at start: a pack already on
 * the room stays after a host hand-over, and cosmetics never block a match.
 */
/** The coin-store item that unlocks each new role for the host's rooms. */
export const ROLE_UNLOCKS: Record<string, string> = {
  silencerEnabled: "role_silencer",
  elderEnabled: "role_elder",
  sniperEnabled: "role_sniper",
};

/**
 * A new role can be switched on only by a host who bought it (plan v3: the
 * role unlocks in the buyer's rooms and is still dealt at random).
 */
export async function ensureRoleAccess(
  // deno-lint-ignore no-explicit-any
  db: any,
  userId: string,
  settings: Record<string, unknown> | undefined,
): Promise<boolean> {
  for (const [key, item] of Object.entries(ROLE_UNLOCKS)) {
    if (settings?.[key] !== true) continue;
    const { data, error } = await db.rpc("user_owns_item", { p_user: userId, p_item: item });
    if (error) throw error;
    if (data !== true) return false;
  }
  return true;
}

export async function ensureCosmeticAccess(
  db: any,
  userId: string,
  settings: Record<string, unknown> | undefined,
): Promise<boolean> {
  for (const key of ["presentationPack", "narratorPack"]) {
    const code = settings?.[key];
    if (code === undefined || code === null || code === "classic") continue;
    const { data, error } = await db.rpc("user_owns_item", {
      p_user: userId,
      p_item: String(code),
    });
    if (error) throw error;
    if (data !== true) return false;
  }
  return true;
}
