import 'dart:math';

/// Mints the seed a new match runs on.
///
/// # Why this is not in the engine
///
/// It used to be: `MatchEngine.start` defaulted its seed to
/// `Random.secure().nextInt(1 << 32)`. Reading the platform entropy pool is a
/// read of device state, and `lib/engine/` may not do that — it is the one rule
/// that makes a match reproducible from its stored seed, which the fuzz harness
/// and the online mode both stand on. The purity check now fails the build on
/// any `Random.secure()` under `lib/engine/`, so the minter lives out here
/// where acquiring entropy is an ordinary thing to do.
///
/// # Why it is still secure randomness
///
/// The seed determines the deal. A predictable seed is a readable deal: anyone
/// who could guess it would know every role at the table before the first card
/// turned. `Random()` is seeded from the current time on most platforms, which
/// for a match created at a moment an opponent watched happen is not a large
/// search space. `Random.secure()` is, and this is called once per match, so
/// its cost is irrelevant.
///
/// # The online counterpart
///
/// Online, the seed is minted server-side into `rooms.match_seed` (doc 10 §4)
/// and is deliberately **never sent to clients** — a client holding the seed
/// could predict every tie-break, which is the last item on doc 10's security
/// checklist. Nothing in the engine can tell which minter it was handed, and
/// that is what keeps one engine serving both transports.
/// # `1 << 32` was zero, and the offline game did not start
///
/// It used to read `nextInt(1 << 32)`, which is correct on the VM and **wrong
/// on the web**: dart2js compiles `<<` to JavaScript's 32-bit shift, so
/// `1 << 32` evaluates to `0` and `nextInt(0)` throws — *"max must be in range
/// 0 < max ≤ 2^32, was 0"*. Every offline match on the web died on the tap that
/// should have started it, with nothing on screen to say why.
///
/// The bound is written as a plain literal now. 2^32 is far inside the 2^53
/// integers dart2js represents exactly, so the constant is the same number on
/// both platforms — it was only ever the shift that could not survive the
/// crossing.
const int _seedSpace = 4294967296;

int newMatchSeed() => Random.secure().nextInt(_seedSpace);
