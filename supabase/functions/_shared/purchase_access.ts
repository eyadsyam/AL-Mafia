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
