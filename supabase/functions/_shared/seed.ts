/**
 * Seed derivation — the TypeScript half of `lib/engine/seed.dart`.
 *
 * Every line here has a counterpart in that file, and the golden-vector test
 * (`supabase/tests/golden_vectors.test.ts`) fails the build if the two ever
 * disagree. Read them side by side; do not change one alone.
 *
 * ## Why 32-bit arithmetic, explicitly, everywhere
 *
 * Dart integers are 64-bit and JavaScript's bitwise operators coerce to 32.
 * `saltCode * 31` exceeds 2^31 immediately, so the spec's expression evaluated
 * naively in the two languages gives two different numbers. Both sides mask
 * every term instead.
 *
 * `Math.imul(a, b) >>> 0` is exactly Dart's `(a * b) & 0xFFFFFFFF`: it computes
 * the low 32 bits of the product. A plain `a * b` would lose precision above
 * 2^53 and silently diverge.
 */

const MASK32 = 0xffffffff;

/** FNV-1a, 32-bit, over UTF-16 code units. Mirrors `_saltCode`. */
function saltCode(salt: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < salt.length; i++) {
    hash ^= salt.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

/** Mirrors `deriveSeed`. */
export function deriveSeed(
  matchSeed: number,
  salt: string,
  index: number,
): number {
  const a = matchSeed >>> 0;
  const b = (Math.imul(saltCode(salt), 31) >>> 0) & MASK32;
  const c = (Math.imul(index, 104729) >>> 0) & MASK32;
  return ((a ^ b ^ c) >>> 0) & MASK32;
}

/** splitmix32. Mirrors `_mix32`. */
function mix32(seed: number): number {
  let x = (seed + 0x9e3779b9) >>> 0;
  x = Math.imul(x ^ (x >>> 16), 0x21f0aaad) >>> 0;
  x = Math.imul(x ^ (x >>> 15), 0x735a2d97) >>> 0;
  return (x ^ (x >>> 15)) >>> 0;
}

/**
 * Mirrors `tieBreakIndex`.
 *
 * The Dart side does not call `Random` here and neither does this: doc 10 §5.1
 * asks for byte-identical output, and `dart:math`'s `Random` is not a specified
 * algorithm that any other language could reproduce.
 */
export function tieBreakIndex(seed: number, count: number): number {
  if (count <= 1) return 0;
  return mix32(seed) % count;
}

export const SeedSalt = {
  roleShuffle: "role-shuffle",
  nightTieBreak: "night-tiebreak",
  trace: "trace",
  confrontation: "confrontation",
  timerDefault: "timer-default",
} as const;
