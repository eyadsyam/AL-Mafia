// node supabase/tests/case_of_day.test.mjs
import assert from 'node:assert/strict';
import {
  CASE_NAME_KEYS,
  CASE_PUZZLE_TEST_SALT,
  caseAnswerHash,
  casePuzzleState,
  clueAllows,
  generateCaseOfDay,
  publicCasePuzzle,
  puzzleDifficulty,
  revealChain,
  solutionsFor,
} from '../functions/_shared/case_of_day.ts';
import { casePuzzleRequest, refusalOf } from '../functions/_shared/economy_actions.ts';

const first = generateCaseOfDay('2026-09-28', 'fixed-salt');
assert.deepEqual(first, generateCaseOfDay('2026-09-28', 'fixed-salt'), 'not deterministic');
assert.notDeepEqual(first, generateCaseOfDay('2026-09-28', 'different-salt'), 'salt ignored');
assert.equal(Object.hasOwn(publicCasePuzzle(first), 'answer'), false, 'public puzzle leaked answer');
const liveState = casePuzzleState({ enabled: true, solved: false, failed: false }, first);
assert.equal(Object.hasOwn(liveState, 'reveal'), false, 'live state leaked reveal');
const solvedState = casePuzzleState({ enabled: true, solved: true, failed: false }, first);
assert.equal(solvedState.reveal.answer, first.answer, 'solved state withheld answer');
assert.deepEqual(casePuzzleState({ enabled: false }, first), { enabled: false });
assert.equal(caseAnswerHash(first.day, 'fixed-salt', first.answer),
  caseAnswerHash(first.day, 'fixed-salt', first.answer), 'answer hash unstable');

const semantics = {
  suspects: Array.from({ length: 5 }, (_, i) => ({ id: `s${i}`, name: `n0${i + 1}` })),
};
assert.equal(clueAllows(semantics, { id: 'c', kind: 'not_mafia', a: 's1' }, 's0'), true);
assert.equal(clueAllows(semantics, { id: 'c', kind: 'one_of', a: 's1', b: 's3' }, 's3'), true);
assert.equal(clueAllows(semantics, { id: 'c', kind: 'in_group', group: ['s0', 's2'] }, 's2'), true);
assert.equal(clueAllows(semantics, { id: 'c', kind: 'outside_group', group: ['s0', 's2'] }, 's1'), true);
assert.equal(clueAllows(semantics, { id: 'c', kind: 'next_to', a: 's0' }, 's4'), true);
assert.equal(clueAllows(semantics, { id: 'c', kind: 'not_next_to', a: 's0' }, 's2'), true);
assert.equal(clueAllows(semantics, { id: 'c', kind: 'distance', a: 's0', k: 2 }, 's3'), true);

const start = Date.parse('2026-01-01T00:00:00.000Z');
const difficulties = new Set();
const clueCounts = new Map();
const names = new Set(CASE_NAME_KEYS);
for (let offset = 0; offset < 365; offset++) {
  const day = new Date(start + offset * 86_400_000).toISOString().slice(0, 10);
  const puzzle = generateCaseOfDay(day, CASE_PUZZLE_TEST_SALT);
  const solutions = solutionsFor(puzzle);
  assert.deepEqual(solutions, [puzzle.answer], `${day} is not uniquely solvable`);
  assert.equal(puzzle.difficulty, puzzleDifficulty(day), `${day} difficulty`);
  assert.ok(puzzle.suspects.every((suspect) => names.has(suspect.name)), `${day} name key`);
  assert.equal(new Set(puzzle.suspects.map((suspect) => suspect.name)).size,
    puzzle.suspects.length, `${day} duplicate name`);
  assert.deepEqual(revealChain(puzzle).flatMap((step) => step.eliminates).sort(),
    puzzle.suspects.map((suspect) => suspect.id).filter((id) => id !== puzzle.answer).sort(),
    `${day} explanation does not eliminate every innocent`);
  difficulties.add(puzzle.difficulty);
  clueCounts.set(puzzle.difficulty, puzzle.clues.length);
}
assert.deepEqual([...difficulties].sort(), [1, 2, 3], 'difficulty spread');
assert.equal(clueCounts.get(1), 4);
assert.equal(clueCounts.get(2), 3);
assert.equal(clueCounts.get(3), 2);
assert.throws(() => generateCaseOfDay('2026-02-30'), /invalid UTC day/);

assert.deepEqual(casePuzzleRequest({ action: 'casePuzzle' }), { kind: 'read' });
assert.deepEqual(casePuzzleRequest({
  action: 'casePuzzleSolve', day: '2026-09-28', pick: 's3', p_correct: true,
}), { kind: 'solve', day: '2026-09-28', pick: 's3' });
assert.equal(casePuzzleRequest({ action: 'casePuzzleSolve', day: '28-09-2026', pick: 's3' }), null);
assert.equal(casePuzzleRequest({ action: 'casePuzzleSolve', day: '2026-09-28', pick: 's7' }), null);
assert.equal(casePuzzleRequest({ action: 'missionHub' }), undefined);
for (const code of ['DISABLED', 'DAY_CHANGED', 'NO_ATTEMPTS', 'ALREADY_SOLVED', 'BAD_REQUEST']) {
  assert.equal(refusalOf(`P0001: ${code}`), code);
}

console.log('PASS case of day: deterministic, 365/365 unique and solvable, difficulty 4→3→2 clues');
