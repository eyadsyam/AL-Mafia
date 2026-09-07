import 'models/enums.dart';
import 'models/match.dart';
import 'models/match_settings.dart';

/// The pressure curve — doc 13 §3.
///
/// The endgame used to play at the tempo of the opening: five living players
/// argued for the same five minutes that nine did, which is four minutes of a
/// conversation that ran out after one. Nothing about the *rules* changes here.
/// The clock closes.
///
/// ## Why this is a function of the living count and of nothing else
///
/// Doc 13 §8 requires it, and the requirement is not arbitrary. The living
/// count is on the screen: everybody can see how many cards are still face
/// down, so a timer derived from it tells the table something it already knows.
/// A timer derived from anything else — how many Mafia are left, whether the
/// Doctor is alive, whether a role acted tonight — would be a channel, and a
/// very good one, because a clock is a number every player reads every round.
///
/// So [bandFor] takes an `int`. Not a `Match`, not a set of players, not a
/// phase: an int, which cannot accidentally be given a role.
abstract final class PressureCurve {
  /// Doc 13 §3's table, in descending order of comfort. Matched top-down on
  /// `living >= from`.
  static const List<PressureBand> bands = [
    PressureBand(
      from: 9,
      discussionSeconds: 300,
      speechSeconds: 45,
      confrontationsPerDay: 1,
    ),
    PressureBand(
      from: 7,
      discussionSeconds: 240,
      speechSeconds: 45,
      confrontationsPerDay: 1,
    ),
    PressureBand(
      from: 5,
      discussionSeconds: 180,
      speechSeconds: 30,
      confrontationsPerDay: 1,
    ),
    PressureBand(
      from: 4,
      discussionSeconds: 120,
      speechSeconds: 30,
      confrontationsPerDay: 2,
    ),
    // Three living players is the last day a match can have, and it is the one
    // that should feel like it. `from: 0` rather than `from: 3` so the table is
    // total: a two-player table is already a finished match, but a function
    // that can return null for it is a function every caller has to check.
    PressureBand(
      from: 0,
      discussionSeconds: 90,
      speechSeconds: 20,
      confrontationsPerDay: 2,
    ),
  ];

  /// The band [living] players are in. Total, by construction.
  static PressureBand bandFor(int living) =>
      bands.firstWhere((b) => living >= b.from);

  /// The band this match is in right now.
  static PressureBand bandOf(Match match) => bandFor(livingCount(match));

  static int livingCount(Match match) =>
      match.players.where((p) => p.status == PlayerStatus.alive).length;

  /// How long the discussion runs, with the curve applied if it is on.
  ///
  /// The curve **tightens and never loosens**. A host who set a two-minute
  /// discussion because their group is fast gets two minutes at nine players
  /// and ninety seconds at three; they do not get handed five minutes back
  /// because a table full of people is nominally allowed them. Doc 13 §3's
  /// promise is "the walls come in", and a setting that a mechanic could widen
  /// would not be a setting.
  static int discussionSeconds(MatchSettings settings, int living) {
    final configured = settings.discussionSeconds;
    if (!settings.pressureCurveEnabled) return configured;
    final band = bandFor(living).discussionSeconds;
    return band < configured ? band : configured;
  }

  /// How long one speaking turn runs. Same rule as [discussionSeconds].
  static int speechSeconds(MatchSettings settings, int living) {
    final configured = settings.speechSeconds;
    if (!settings.pressureCurveEnabled) return configured;
    final band = bandFor(living).speechSeconds;
    return band < configured ? band : configured;
  }

  /// How many confrontations today may carry.
  ///
  /// One, until the table is down to four — and then a second one, opened from
  /// inside the discussion rather than before it. With the curve off it is
  /// always one, which is exactly what the game did before doc 13.
  static int confrontationsPerDay(MatchSettings settings, int living) {
    // Two ways to get the second one, and the higher of them wins: the curve
    // gives it to a table down to four, and «قاسية» (doc 13 §5) gives it from
    // the first day. Neither has to know the other exists.
    final fromCurve =
        settings.pressureCurveEnabled ? bandFor(living).confrontationsPerDay : 1;
    final fromPreset = settings.midDiscussionConfrontation ? 2 : 1;
    return fromCurve > fromPreset ? fromCurve : fromPreset;
  }

  /// Which of the five bands this is, 0 (roomiest) to 4 (tightest).
  ///
  /// This is what the turn-change chime is pitched from (doc 13 §3). It is an
  /// index into a fixed table keyed by the living count — so the pitch is a
  /// property of the timer setting, as doc 13 §8 requires, and never a reaction
  /// to anything that happened.
  static int bandIndex(int living) =>
      bands.indexWhere((b) => living >= b.from);
}

/// One row of doc 13 §3's table.
class PressureBand {
  /// The smallest living count in this band.
  final int from;
  final int discussionSeconds;
  final int speechSeconds;

  /// 1 everywhere until four players are left, then 2 — "1 per day + 1
  /// mid-discussion".
  final int confrontationsPerDay;

  const PressureBand({
    required this.from,
    required this.discussionSeconds,
    required this.speechSeconds,
    required this.confrontationsPerDay,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PressureBand &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          discussionSeconds == other.discussionSeconds &&
          speechSeconds == other.speechSeconds &&
          confrontationsPerDay == other.confrontationsPerDay;

  @override
  int get hashCode =>
      Object.hash(from, discussionSeconds, speechSeconds, confrontationsPerDay);

  @override
  String toString() => 'PressureBand(from=$from, discussion=${discussionSeconds}s, '
      'speech=${speechSeconds}s, confrontations=$confrontationsPerDay)';
}

/// The phases the curve has an opinion about.
///
/// Named so a caller cannot pass `GamePhase.night` and get a number back: the
/// night has no clock the table shares, and giving it one would be the tell the
/// whole of doc 05 §L-08 is about.
enum PressurePhase { discussion, speech }

extension PressureFor on MatchSettings {
  /// Seconds for [phase] at [living] players.
  int pressureSeconds(PressurePhase phase, int living) => switch (phase) {
        PressurePhase.discussion =>
          PressureCurve.discussionSeconds(this, living),
        PressurePhase.speech => PressureCurve.speechSeconds(this, living),
      };
}
