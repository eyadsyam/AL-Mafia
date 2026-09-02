/// The engine's only source of time.
///
/// # Why this exists
///
/// Every timestamp the engine writes — `Match.createdAt`, `TimelineEvent.at`,
/// `MatchOutcome.completedAt` — used to come from a bare `DateTime.now()` inside
/// `match_engine.dart`. That made the engine impure in the one way that matters
/// most here: **the same inputs did not produce the same match**. Two devices
/// resolving the same night produced two different event logs, which is fatal
/// for the online mode (`10-online-architecture.md` §5.1: the server runs the
/// generator, the client renders it, and the two must agree byte for byte), and
/// it makes the fuzz harness unable to reproduce a failure from its seed alone.
///
/// So time became an argument. The engine asks its [Clock] and never asks the
/// platform. The app passes `DateTime.now`; tests and the fuzz harness pass
/// [Clocks.monotonic], which is deterministic.
///
/// This is the same rule doc 09 §4 states for the information-engine
/// generators — *"No `DateTime.now()` inside generators — pass timestamps in as
/// data"* — applied one layer down, to the engine that will host them.
///
/// It is enforced, not merely documented: `test/engine/engine_purity_test.dart`
/// fails the build if `DateTime.now()` appears anywhere under `lib/engine/`.
library engine.clock;

/// A source of wall-clock instants.
///
/// `DateTime.now` satisfies this signature directly, so the production wiring
/// is a tear-off and nothing more.
typedef Clock = DateTime Function();

/// The clocks the engine ships with.
///
/// Deliberately none of them read the platform: a clock that could do so would
/// defeat the point of injecting one, and the purity check would reject it.
class Clocks {
  const Clocks._();

  /// The instant every deterministic clock counts from.
  ///
  /// An arbitrary, obviously-synthetic date. It is far enough in the past to
  /// never collide with a real `createdAt`, which makes a fixture that leaked a
  /// test clock into a stored match easy to spot.
  static final DateTime epoch = DateTime.utc(2000, 1, 1);

  /// A clock that advances by [step] on every read, starting at [from].
  ///
  /// Strictly increasing, because the timeline is sorted by `at`
  /// (`analytics_builder.dart`) and `List.sort` is **not** stable in Dart — a
  /// clock that returned one constant would let equal keys reorder the
  /// post-game timeline arbitrarily between runs. Monotonic ticks make the sort
  /// total, so the ordering is the insertion order and nothing else.
  ///
  /// Each call returns a *fresh* counter, so two engines built in one test do
  /// not share a cursor.
  static Clock monotonic({
    DateTime? from,
    Duration step = const Duration(milliseconds: 1),
  }) {
    var next = from ?? epoch;
    return () {
      final value = next;
      next = next.add(step);
      return value;
    };
  }

  /// A clock frozen at [instant].
  ///
  /// For tests that assert on an exact timestamp. Do not use it to drive a
  /// whole match — see the ordering note on [monotonic].
  static Clock fixed(DateTime instant) => () => instant;
}
