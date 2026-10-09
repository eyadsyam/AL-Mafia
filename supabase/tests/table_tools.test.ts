import { assertEquals } from "jsr:@std/assert@1";
import {
  appealUpheld, detectiveSees, floorBonusSeconds, halfDoorSeats, lockedSeats,
  toolVoteWeight, unsilenceable, whisperAnswer, type ToolUse,
} from "../functions/_shared/tools.ts";

const use = (seat: number, tool_code: string, phase_number: number,
  extra: Partial<ToolUse> = {}): ToolUse => ({
  user_id: `u${seat}`, seat, tool_code, phase: "discuss", phase_number,
  target_seats: [], note: null, ...extra,
});

Deno.test("a day lock covers the next night only", () => {
  const uses = [use(2, "lock_door", 1)];
  assertEquals([...lockedSeats(uses, 2)], [2]);
  assertEquals(lockedSeats(uses, 3).size, 0);
  assertEquals(halfDoorSeats(uses, 2).has(2), true);
});

Deno.test("detective faces: impersonate, camouflage, door", () => {
  assertEquals(detectiveSees([use(1, "impersonate", 1, { note: "citizen" })], 2, 1, "mafia"), "citizen");
  assertEquals(detectiveSees([use(1, "camouflage", 1)], 2, 1, "mafia"), "unclear");
  assertEquals(detectiveSees([use(1, "half_door", 1)], 2, 1, "mafia"), "unreachable");
  assertEquals(detectiveSees([], 2, 1, "mafia"), "mafia");
});

Deno.test("shield and weights and floor bonus", () => {
  assertEquals(unsilenceable([use(4, "vote_shield", 3)], 4).has(4), true);
  assertEquals(toolVoteWeight([use(4, "double_vote", 3)], 3, 4), 2);
  assertEquals(toolVoteWeight([use(4, "double_vote", 3)], 4, 4), 1);
  assertEquals(floorBonusSeconds([use(5, "extra_minute", 2), use(5, "objection", 2)], 2, 5), 75);
});

Deno.test("appeal needs more than two thirds", () => {
  assertEquals(appealUpheld(4, 6), false);
  assertEquals(appealUpheld(5, 6), true);
});

Deno.test("whisper answers whether a mafioso is among the seats", () => {
  const roles: Record<number, string> = { 1: "citizen", 2: "mafia", 3: "doctor" };
  assertEquals(whisperAnswer(use(0, "narrator_whisper", 1, { target_seats: [1, 2] }), (s) => roles[s]), true);
  assertEquals(whisperAnswer(use(0, "sense", 1, { target_seats: [1, 3] }), (s) => roles[s]), false);
});
