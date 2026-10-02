/** The public population a resolution counted; roles never enter this token. */
export function rosterFingerprint(players: {user_id: string; seat: number; alive: boolean}[]): string {
  return [...players].sort((a, b) => a.user_id < b.user_id ? -1 : a.user_id > b.user_id ? 1 : 0)
    .map((p) => `${p.user_id}|${p.seat}|${p.alive ? 1 : 0}`).join(";");
}
