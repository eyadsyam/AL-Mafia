/**
 * Pure deterministic generator for «قضية اليوم».
 *
 * It knows no database, room, player, match or role. The only inputs are a UTC
 * day and a deployment salt. The answer remains edge-only until the persisted
 * state says the case is over.
 */

export const CASE_PUZZLE_TEST_SALT = "mafia-master-case-puzzle-test-v1";

export const CASE_NAME_KEYS = Array.from(
  { length: 24 },
  (_, i) => `n${String(i + 1).padStart(2, "0")}`,
) as readonly string[];

export type ClueKind =
  | "not_mafia"
  | "one_of"
  | "in_group"
  | "outside_group"
  | "next_to"
  | "not_next_to"
  | "distance";

export interface CaseSuspect {
  id: string;
  name: string;
}

export interface CaseClue {
  id: string;
  kind: ClueKind;
  a?: string;
  b?: string;
  group?: string[];
  k?: number;
}

export interface GeneratedCasePuzzle {
  day: string;
  suspects: CaseSuspect[];
  seats: true;
  clues: CaseClue[];
  difficulty: 1 | 2 | 3;
  /** Edge-only. Never serialize this before the persisted case is over. */
  answer: string;
}

export interface PublicCasePuzzle {
  suspects: CaseSuspect[];
  seats: true;
  clues: CaseClue[];
  difficulty: 1 | 2 | 3;
}

export interface RevealStep {
  clue: string;
  eliminates: string[];
}

const DAY = /^\d{4}-\d{2}-\d{2}$/;

function hash32(value: string, basis = 0x811c9dc5): number {
  let hash = basis >>> 0;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

function randomFor(seed: string): () => number {
  let state = hash32(seed) || 0x9e3779b9;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0x1_0000_0000;
  };
}

function shuffled<T>(source: readonly T[], random: () => number): T[] {
  const result = [...source];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function mod(value: number, size: number): number {
  return ((value % size) + size) % size;
}

export function puzzleDifficulty(day: string): 1 | 2 | 3 {
  if (!DAY.test(day)) throw new Error("invalid UTC day");
  const parsed = new Date(`${day}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== day) {
    throw new Error("invalid UTC day");
  }
  const weekday = parsed.getUTCDay();
  return weekday <= 2 ? 1 : weekday <= 4 ? 2 : 3;
}

function seatOf(puzzle: Pick<GeneratedCasePuzzle, "suspects">, id: string): number {
  return puzzle.suspects.findIndex((suspect) => suspect.id === id);
}

/** Exact clue truth for one proposed Mafia suspect. */
export function clueAllows(
  puzzle: Pick<GeneratedCasePuzzle, "suspects">,
  clue: CaseClue,
  proposed: string,
): boolean {
  const proposedSeat = seatOf(puzzle, proposed);
  if (proposedSeat < 0) return false;
  switch (clue.kind) {
    case "not_mafia":
      return proposed !== clue.a;
    case "one_of":
      return proposed === clue.a || proposed === clue.b;
    case "in_group":
      return clue.group?.includes(proposed) ?? false;
    case "outside_group":
      return !(clue.group?.includes(proposed) ?? true);
    case "next_to": {
      const target = seatOf(puzzle, clue.a ?? "");
      if (target < 0) return false;
      const n = puzzle.suspects.length;
      return mod(proposedSeat - target, n) === 1 || mod(target - proposedSeat, n) === 1;
    }
    case "not_next_to": {
      const target = seatOf(puzzle, clue.a ?? "");
      if (target < 0) return false;
      const n = puzzle.suspects.length;
      return mod(proposedSeat - target, n) !== 1 && mod(target - proposedSeat, n) !== 1;
    }
    case "distance": {
      const target = seatOf(puzzle, clue.a ?? "");
      if (target < 0 || clue.k == null) return false;
      const clockwise = mod(proposedSeat - target, puzzle.suspects.length);
      const distance = Math.min(clockwise, puzzle.suspects.length - clockwise);
      return distance === clue.k;
    }
  }
}

export function solutionsFor(
  puzzle: Pick<GeneratedCasePuzzle, "suspects" | "clues">,
): string[] {
  return puzzle.suspects
    .map((suspect) => suspect.id)
    .filter((candidate) => puzzle.clues.every((clue) => clueAllows(puzzle, clue, candidate)));
}

export function generateCaseOfDay(
  day: string,
  salt = CASE_PUZZLE_TEST_SALT,
): GeneratedCasePuzzle {
  const difficulty = puzzleDifficulty(day);
  const random = randomFor(`${salt}\u0000${day}`);
  const count = difficulty === 1 ? 5 : difficulty === 2 ? 6 : 7;
  const suspects = shuffled(CASE_NAME_KEYS, random).slice(0, count).map((name, seat) => ({
    id: `s${seat}`,
    name,
  }));
  const answerSeat = Math.floor(random() * count);
  const answer = suspects[answerSeat].id;
  let clues: CaseClue[];

  if (difficulty === 1) {
    // Sunday–Tuesday: every innocent receives a direct clearance.
    clues = shuffled(
      suspects.filter((suspect) => suspect.id !== answer).map((suspect) => ({
        id: "",
        kind: "not_mafia" as const,
        a: suspect.id,
      })),
      random,
    );
  } else if (difficulty === 2) {
    // Three narrowing statements; every clue removes at least one candidate.
    const innocent = shuffled(
      suspects.filter((suspect) => suspect.id !== answer).map((suspect) => suspect.id),
      random,
    );
    const [first, second] = innocent;
    clues = [
      { id: "", kind: "in_group", group: shuffled([answer, first, second], random) },
      { id: "", kind: "one_of", a: answer, b: first },
      { id: "", kind: "not_mafia", a: first },
    ];
  } else {
    // Friday–Saturday: two spatial clues. The first leaves the answer and one
    // neighbour; the second clears only that neighbour.
    const direction = random() < 0.5 ? 1 : -1;
    const anchor = suspects[mod(answerSeat - direction, count)].id;
    const blocker = suspects[mod(answerSeat - 3 * direction, count)].id;
    clues = [
      { id: "", kind: "next_to", a: anchor },
      { id: "", kind: "not_next_to", a: blocker },
    ];
  }

  clues = clues.map((clue, index) => ({ ...clue, id: `c${index + 1}` }));
  const puzzle: GeneratedCasePuzzle = {
    day,
    suspects,
    seats: true,
    clues,
    difficulty,
    answer,
  };
  const solutions = solutionsFor(puzzle);
  if (solutions.length !== 1 || solutions[0] !== answer) {
    throw new Error(`non-unique case puzzle for ${day}`);
  }
  return puzzle;
}

export function publicCasePuzzle(puzzle: GeneratedCasePuzzle): PublicCasePuzzle {
  return {
    suspects: puzzle.suspects.map((suspect) => ({ ...suspect })),
    seats: true,
    clues: puzzle.clues.map((clue) => ({
      ...clue,
      group: clue.group == null ? undefined : [...clue.group],
    })),
    difficulty: puzzle.difficulty,
  };
}

export function revealChain(puzzle: GeneratedCasePuzzle): RevealStep[] {
  let possible = puzzle.suspects.map((suspect) => suspect.id);
  return puzzle.clues.map((clue) => {
    const next = possible.filter((candidate) => clueAllows(puzzle, clue, candidate));
    const eliminates = possible.filter((candidate) => !next.includes(candidate));
    possible = next;
    return { clue: clue.id, eliminates };
  });
}

/** Merge server-owned attempt state with public puzzle material. The answer is
 * added only when Postgres says the case is solved or failed. */
export function casePuzzleState(
  stored: Record<string, unknown>,
  puzzle: GeneratedCasePuzzle,
): Record<string, unknown> {
  if (stored.enabled !== true) return { enabled: false };
  const over = stored.solved === true || stored.failed === true;
  return {
    ...stored,
    puzzle: publicCasePuzzle(puzzle),
    ...(over
      ? { reveal: { answer: puzzle.answer, chain: revealChain(puzzle) } }
      : {}),
  };
}

/** Salted audit marker stored by Postgres; correctness is still edge-owned. */
export function caseAnswerHash(day: string, salt: string, answer: string): string {
  const input = `${salt}\u0000${day}\u0000${answer}`;
  return hash32(input).toString(16).padStart(8, "0") +
    hash32(input, 0x9e3779b9).toString(16).padStart(8, "0");
}
