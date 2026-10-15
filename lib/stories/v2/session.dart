import 'table.dart';

/// Where a Stories V2 table is (docs/plans/STORIES-V2-PLAN.md §2.6–2.8).
enum StoryStage {
  /// Public: who plays whom.
  cast,

  /// 5–10: «الموبايل مع …», before the named player opens it.
  handoff,

  /// 5–10: his card on screen, read aloud.
  card,

  /// 5–10: the one private line, behind a hold.
  secret,

  /// 2–4: each card in turn on a public screen.
  introductions,

  /// The detective's desk (5–10, solo) or the shared table (2–4).
  desk,
  decision,
  reveal,
  result,
}

class StoryAccusationV2 {
  const StoryAccusationV2({
    required this.suspectId,
    this.motiveId,
    this.methodId,
  });

  final String suspectId;

  /// Solo only: with friends the decision names who, never why or how.
  final String? motiveId;
  final String? methodId;
}

/// The pure state of one Stories V2 table. Every move returns a new session;
/// an illegal move throws, so a double tap can never advance twice.
class StorySessionV2 {
  const StorySessionV2._({
    required this.table,
    required this.stage,
    required this.turn,
    required this.searched,
    required this.bonusSearches,
    this.accusation,
  });

  factory StorySessionV2.start(StoryTable table) => StorySessionV2._(
    table: table,
    stage: table.mode == StoryTableMode.solo
        ? StoryStage.desk
        : StoryStage.cast,
    turn: 0,
    searched: const [],
    bonusSearches: 0,
  );

  /// At most one extra search, bought by a rewarded ad, solo only.
  static const maxBonusSearches = 1;

  final StoryTable table;
  final StoryStage stage;

  /// The seat being passed to (hand-off) or the card on screen (introductions).
  final int turn;

  /// Place ids in the order they were searched.
  final List<String> searched;
  final int bonusSearches;
  final StoryAccusationV2? accusation;

  StoryTableSeat get currentSeat => table.seats[turn];

  /// The suspect whose card is on screen during introductions.
  String get introducedSuspect => table.suspectIds[turn];

  int get searchBudget => StoryTable.searches + bonusSearches;
  int get searchesLeft => searchBudget - searched.length;

  bool canSearch(String placeId) =>
      stage == StoryStage.desk &&
      searchesLeft > 0 &&
      !searched.contains(placeId);

  bool get canBuySearch =>
      table.mode == StoryTableMode.solo &&
      stage == StoryStage.desk &&
      bonusSearches < maxBonusSearches &&
      searchesLeft == 0 &&
      searched.length < table.world.places.length;

  bool get solved => accusation?.suspectId == table.culpritId;

  bool? get motiveRight => accusation?.motiveId == null
      ? null
      : accusation!.motiveId ==
            table.world.suspect(table.culpritId).guilty.motive.id;

  bool? get methodRight => accusation?.methodId == null
      ? null
      : accusation!.methodId ==
            table.world.suspect(table.culpritId).guilty.method.id;

  StorySessionV2 begin() {
    _expect(StoryStage.cast);
    return _copy(
      stage: table.mode == StoryTableMode.detective
          ? StoryStage.handoff
          : StoryStage.introductions,
      turn: 0,
    );
  }

  StorySessionV2 openCard() {
    _expect(StoryStage.handoff);
    return _copy(stage: StoryStage.card);
  }

  StorySessionV2 revealSecret() {
    _expect(StoryStage.card);
    return _copy(stage: StoryStage.secret);
  }

  StorySessionV2 hideSecret() {
    _expect(StoryStage.secret);
    if (turn + 1 < table.seats.length) {
      return _copy(stage: StoryStage.handoff, turn: turn + 1);
    }
    return _copy(stage: StoryStage.desk, turn: 0);
  }

  StorySessionV2 nextIntroduction() {
    _expect(StoryStage.introductions);
    if (turn + 1 < table.suspectIds.length) return _copy(turn: turn + 1);
    return _copy(stage: StoryStage.desk, turn: 0);
  }

  StorySessionV2 search(String placeId) {
    if (!canSearch(placeId)) throw StateError('cannot search $placeId');
    return _copy(searched: List.unmodifiable([...searched, placeId]));
  }

  StorySessionV2 grantBonusSearch() {
    if (!canBuySearch) throw StateError('no bonus search available');
    return _copy(bonusSearches: bonusSearches + 1);
  }

  StorySessionV2 openDecision() {
    _expect(StoryStage.desk);
    return _copy(stage: StoryStage.decision);
  }

  StorySessionV2 backToDesk() {
    _expect(StoryStage.decision);
    return _copy(stage: StoryStage.desk);
  }

  StorySessionV2 accuse(StoryAccusationV2 accusation) {
    _expect(StoryStage.decision);
    if (!table.suspectIds.contains(accusation.suspectId)) {
      throw ArgumentError.value(accusation.suspectId, 'suspectId');
    }
    final solo = table.mode == StoryTableMode.solo;
    if (solo != (accusation.motiveId != null && accusation.methodId != null)) {
      throw ArgumentError('solo asks why and how; a group names who only');
    }
    return _copy(stage: StoryStage.reveal, accusation: accusation);
  }

  StorySessionV2 showResult() {
    _expect(StoryStage.reveal);
    return _copy(stage: StoryStage.result);
  }

  /// The app left the foreground while a private page was open: it is
  /// covered and the phone is back at that player's hand-off.
  StorySessionV2 coverForInterruption() => switch (stage) {
    StoryStage.card || StoryStage.secret => _copy(stage: StoryStage.handoff),
    _ => this,
  };

  void _expect(StoryStage expected) {
    if (stage != expected) throw StateError('expected $expected, at $stage');
  }

  StorySessionV2 _copy({
    StoryStage? stage,
    int? turn,
    List<String>? searched,
    int? bonusSearches,
    StoryAccusationV2? accusation,
  }) => StorySessionV2._(
    table: table,
    stage: stage ?? this.stage,
    turn: turn ?? this.turn,
    searched: searched ?? this.searched,
    bonusSearches: bonusSearches ?? this.bonusSearches,
    accusation: accusation ?? this.accusation,
  );
}
