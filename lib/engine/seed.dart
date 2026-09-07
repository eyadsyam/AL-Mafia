/// Seed derivation — the single source of every random decision in a match.
///
/// # The rule
///
/// A match carries one `matchSeed`. Nothing anywhere may call `Random()` with
/// no argument, and nothing may call `Random.secure()`; every generator derives
/// its own stream from the match seed plus a *salt* naming what the stream is
/// for, plus an *index* naming which occurrence it is.
///
/// ```dart
/// final rng = Random(deriveSeed(match.seed, 'night-tiebreak', nightNumber));
/// ```
///
/// # Why a salt and an index, and not just `seed + n`
///
/// The night tie-break used `Random(match.seed + match.dayNumber)`. That is one
/// stream shared by every consumer that happens to pick the same arithmetic:
/// add a second seeded decision on the same night — the trace tie-break of doc
/// 09 §1.5, say — and it draws from the identical stream, so the two decisions
/// become correlated. Two mafia targets tied on night 3 and two traces tied on
/// morning 3 would break the same way, every match, forever. A table would not
/// notice; a determinism bug that only shows up as *suspiciously repetitive*
/// output is exactly the kind that survives to release.
///
/// The salt separates the streams by *purpose*, the index separates them by
/// *occasion*, and the large odd multipliers keep neighbouring indices from
/// landing on neighbouring seeds.
///
/// # Where the seed itself comes from
///
/// Not from here, and not from anywhere under `lib/engine/`. Acquiring entropy
/// is a read of device state, which is precisely what the engine may not do —
/// so the caller mints the seed and hands it in. `newMatchSeed()` in
/// `lib/data/` is the app's minter; the online mode will take its seed from the
/// `rooms.match_seed` column instead (doc 10 §4), and neither the engine nor
/// any generator can tell the difference. That is the whole point.
library engine.seed;

/// Derives an independent seed for the stream named [salt] at [index].
///
/// The shape is `09-information-engine.md` §4's, unchanged:
///
/// ```
/// matchSeed ^ (<salt as an int> * 31) ^ (index * 104729)
/// ```
///
/// **One deviation, and it is deliberate.** The spec writes the middle term as
/// `salt.hashCode`. Dart's `String.hashCode` is not a specified function — it
/// is whatever the running VM does today, it differs between the VM and dart2js,
/// and nothing promises it across SDK versions. Doc 10 §5.1 requires the
/// Deno/TypeScript implementation to produce *byte-identical* output and puts a
/// golden-vector test in CI to prove it, and no TypeScript can reproduce an
/// unspecified Dart hash. Taken literally, §4 and §5.1 cannot both be
/// satisfied.
///
/// So [_saltCode] below is a written-down 32-bit FNV-1a over the salt's code
/// units — six lines, portable to any language in ten minutes, and identical
/// forever. Every other term of the expression is exactly as specified.
///
/// [salt] identifies the consumer (`'night-tiebreak'`, `'trace'`,
/// `'confrontation'`). [index] identifies the occurrence — the night number,
/// the day number, the phase index.
int deriveSeed(int matchSeed, String salt, int index) =>
    (matchSeed ^ ((_saltCode(salt) * 31) & _mask32) ^
            ((index * 104729) & _mask32)) &
    _mask32;

/// Everything here is 32-bit, on purpose.
///
/// Dart integers are 64-bit; JavaScript's bitwise operators coerce to 32. The
/// spec's expression evaluated in both languages therefore gives two different
/// numbers as soon as any term exceeds 2^31 — which `saltCode * 31` does
/// immediately. Masking every term makes the two agree by construction rather
/// than by luck.
const int _mask32 = 0xFFFFFFFF;

/// FNV-1a, 32-bit, over UTF-16 code units.
///
/// Chosen because it is four lines with no tables and no endianness, which is
/// what a hash needs to be when its whole job is to be reimplemented correctly
/// in another language by somebody reading this comment.
int _saltCode(String salt) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < salt.length; i++) {
    hash ^= salt.codeUnitAt(i);
    // FNV prime 16777619, kept inside 32 bits at every step so the result does
    // not depend on the width of the host's integers.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Picks one of [count] equally-scoring candidates, deterministically.
///
/// # Why this exists instead of `Random(seed).nextInt(count)`
///
/// Doc 09 §1.5 and §2.4 both write the tie-break as `Random(seed).nextInt(n)`,
/// and doc 10 §5.1 requires the Deno implementation to produce **byte-identical
/// output**, checked by a golden-vector test in CI. Those two cannot both be
/// satisfied: `dart:math`'s `Random` is an unspecified algorithm, no JavaScript
/// runtime reproduces it, and nothing promises it across Dart SDK versions
/// either.
///
/// So the draw is written down. [_mix32] is splitmix32 — five lines, no tables,
/// and expressible identically in any language with 32-bit integer arithmetic
/// (`Math.imul` in JS is exactly Dart's `(a * b) & 0xFFFFFFFF`). The generators
/// call this; nothing in `lib/engine/information/` constructs a `Random` at all.
///
/// The engine's *other* seeded decisions — the role deal, the Mafia's night
/// tie-break — still use `Random(deriveSeed(...))`, and that is fine: online
/// they are made once, on the server, and no client re-derives them. Only the
/// two generators have to agree across a language boundary.
int tieBreakIndex(int seed, int count) {
  if (count <= 1) return 0;
  return _mix32(seed) % count;
}

/// splitmix32. Chosen for being short enough to reimplement correctly from
/// this comment alone, which is the only property that matters here.
int _mix32(int seed) {
  var x = (seed + 0x9E3779B9) & _mask32;
  x = ((x ^ (x >> 16)) * 0x21F0AAAD) & _mask32;
  x = ((x ^ (x >> 15)) * 0x735A2D97) & _mask32;
  return (x ^ (x >> 15)) & _mask32;
}

/// The salts in use. String literals scattered across call sites drift; a typo
/// in one of them silently produces a *different but still deterministic*
/// stream, which no test would ever catch.
class SeedSalt {
  const SeedSalt._();

  /// Shuffling the role list at match start.
  static const String roleShuffle = 'role-shuffle';

  /// Breaking a tie between the mafia's night targets.
  static const String nightTieBreak = 'night-tiebreak';

  /// Breaking a tie between equally-scoring traces (doc 09 §1.5).
  static const String trace = 'trace';

  /// Breaking a tie between equally-scoring confrontations (doc 09 §2.4).
  static const String confrontation = 'confrontation';

  /// Choosing a default target when a phase timer expires with no action
  /// submitted (doc 10 §8.2).
  static const String timerDefault = 'timer-default';

  /// Choosing which play hint a phase shows (doc 13 §4.3).
  ///
  /// A stream of its own for the reason the whole file exists: offline every
  /// phone must land on the same sentence at the same moment, and sharing a
  /// stream with the night tie-break would mean the hint a table read on
  /// morning 3 correlated with who died on night 3.
  static const String hint = 'hint';
}
