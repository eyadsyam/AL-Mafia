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
