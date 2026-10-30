/** Only participants who owe an action can keep a live phase open. */
export function nightComplete(
  players: { user_id: string; alive: boolean; role: string | null }[],
  actions: { actor_id: string }[],
): boolean {
  const done = new Set(actions.map((a) => a.actor_id));
  return players.every((p) => !p.alive || ["citizen", "elder"].includes(p.role ?? "") ||
    done.has(p.user_id));
}

export function voteComplete(
  players: { user_id: string; seat: number; alive: boolean }[],
  votes: { voter_id: string }[],
  silencedSeat: number | null,
): boolean {
  const done = new Set(votes.map((v) => v.voter_id));
  return players.every((p) => !p.alive || p.seat === silencedSeat || done.has(p.user_id));
}

export function discussionComplete(
  living: { seat: number }[], ready: { number?: number; seats?: number[] } | undefined,
  day: number,
): boolean {
  const seats = new Set(ready?.number === day ? ready.seats ?? [] : []);
  return living.every((p) => seats.has(p.seat));
}

export function firstDayPhase(settings: Record<string, unknown>): "opening" | "discuss" {
  return settings.openingRoundEnabled === true ? "opening" : "discuss";
}
