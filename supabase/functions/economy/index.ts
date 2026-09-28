import { fail, handler, ok } from "../_shared/api.ts";
import {
  casePuzzleRequest,
  economyCall,
  refusalOf,
} from "../_shared/economy_actions.ts";
import {
  caseAnswerHash,
  casePuzzleState,
  CASE_PUZZLE_TEST_SALT,
  generateCaseOfDay,
} from "../_shared/case_of_day.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const puzzleRequest = casePuzzleRequest(body ?? {});
  if (puzzleRequest === null) return ok({ ok: false, code: "BAD_REQUEST" });
  if (puzzleRequest !== undefined) {
    const utcDay = new Date().toISOString().slice(0, 10);
    if (puzzleRequest.kind === "solve" && puzzleRequest.day !== utcDay) {
      return ok({ ok: false, code: "DAY_CHANGED" });
    }
    const salt = Deno.env.get("CASE_PUZZLE_SALT") ?? CASE_PUZZLE_TEST_SALT;
    const puzzle = generateCaseOfDay(utcDay, salt);
    if (puzzleRequest.kind === "read") {
      const { data, error } = await db.rpc("case_puzzle_status", { p_user: userId });
      if (error) throw error;
      return ok(casePuzzleState(data as Record<string, unknown>, puzzle));
    }
    if (!puzzle.suspects.some((suspect) => suspect.id === puzzleRequest.pick)) {
      return ok({ ok: false, code: "BAD_REQUEST" });
    }
    const { data, error } = await db.rpc("case_puzzle_record", {
      p_user: userId,
      p_day: utcDay,
      p_pick: puzzleRequest.pick,
      p_correct: puzzleRequest.pick === puzzle.answer,
      p_answer_hash: caseAnswerHash(utcDay, salt, puzzle.answer),
    });
    if (error) throw error;
    const result = data as Record<string, unknown>;
    if (result.ok !== true) return ok(result);
    return ok({
      ok: true,
      correct: result.correct === true,
      grant: result.grant ?? null,
      state: casePuzzleState(result.state as Record<string, unknown>, puzzle),
    });
  }
  const call = economyCall(body ?? {}, userId);
  if (!call) return fail("BAD_REQUEST", "invalid economy request");
  const { data, error } = await db.rpc(call.rpc, call.args);
  if (error) {
    const refusal = refusalOf(error.message);
    if (refusal === "INSUFFICIENT_COINS") {
      return fail("INSUFFICIENT_COINS", "not enough coins");
    }
    if (refusal === "ITEM_NOT_FOUND") {
      return fail("BAD_REQUEST", "item is not available");
    }
    if (refusal === "ITEM_NOT_OWNED") {
      return fail("BAD_REQUEST", "item cannot be equipped");
    }
    if (error.message === "BAD_REQUEST") {
      return fail("BAD_REQUEST", "item cannot be equipped");
    }
    if (refusal) return fail(refusal as never, refusal.toLowerCase(), 409);
    throw error;
  }
  return ok(data);
}));
