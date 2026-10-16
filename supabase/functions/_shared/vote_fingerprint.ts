import { rosterFingerprint } from "./roster_fingerprint.ts";
import type { ToolUse } from "./tools.ts";

const voteToolCodes = new Set(["revote", "appeal", "double_vote", "grave_vote", "last_word"]);

export function voteFingerprint(
  cast: { voter_id: string; target_id: string | null }[],
  roster: { user_id: string; seat: number; alive: boolean }[],
  uses: ToolUse[],
  day: number,
): string {
  const ballots = [...cast]
    .sort((a, b) => a.voter_id < b.voter_id ? -1 : a.voter_id > b.voter_id ? 1 : 0)
    .map((v) => `${v.voter_id}|${v.target_id ?? "-"}`)
    .join(";");
  const ids = uses.filter((u) => u.phase_number === day && voteToolCodes.has(u.tool_code))
    .map((u) => u.id).sort((a, b) => (a ?? 0) - (b ?? 0));
  return ballots + "#roster:" + rosterFingerprint(roster) +
    (ids.length ? "#tools:" + ids.join(";") : "");
}
