/**
 * Which roles play for the Mafia. The Silencer is on the Mafia's side: it
 * counts for parity, wins with them and is never a kill target for them.
 * One list for the whole server (the SQL twin is `public.is_mafia_team`).
 */
export const MAFIA_TEAM_ROLES = ["mafia", "silencer"] as const;

export function isMafiaTeam(role: string | null | undefined): boolean {
  return role === "mafia" || role === "silencer";
}
