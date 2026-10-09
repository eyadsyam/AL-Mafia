import 'dart:math' show Random;

import 'story_model.dart';

enum StoryMode { solo, group }

enum StoryPhase {
  soloInvestigation,
  groupHandoff,
  groupPrivateClue,
  groupDiscussion,
  groupInvestigation,
  groupVoteHandoff,
  groupVote,
  reenactment,
  complete,
}

class StoryAccusation {
  const StoryAccusation({
    required this.culprit,
    required this.motive,
    required this.method,
  });

  final String culprit;
  final String motive;
  final String method;
}

class StoryScore {
  const StoryScore({
    required this.culpritPoints,
    required this.motivePoints,
    required this.methodPoints,
    required this.efficiencyPoints,
    required this.solveBonus,
  });

  final int culpritPoints;
  final int motivePoints;
  final int methodPoints;
  final int efficiencyPoints;
  final int solveBonus;

  int get total =>
      culpritPoints +
      motivePoints +
      methodPoints +
      efficiencyPoints +
      solveBonus;
}

class StorySession {
  const StorySession._({
    required this.story,
    required this.playerCount,
    required this.seed,
    required this.mode,
    required this.phase,
    required this.remainingBudget,
    required this.revealedClueIds,
    required this.usedActionIds,
    required this.round,
    required this.currentPlayer,
    required this.votes,
    required this.seating,
    this.soloAccusation,
    this.score,
  });

  factory StorySession.start({
    required StoryDefinition story,
    required int playerCount,
    required int seed,
  }) {
    StoryBucket.forPlayers(playerCount);
    return StorySession._(
      seating: _seatingFor(playerCount, seed),
      story: story,
      playerCount: playerCount,
      seed: seed,
      mode: playerCount == 1 ? StoryMode.solo : StoryMode.group,
      phase: playerCount == 1
          ? StoryPhase.soloInvestigation
          : StoryPhase.groupHandoff,
      remainingBudget: story.actionBudget,
      revealedClueIds: const {},
      usedActionIds: const {},
      round: 1,
      currentPlayer: 0,
      votes: const [],
    );
  }

  final StoryDefinition story;
  final int playerCount;
  final int seed;
  final StoryMode mode;
  final StoryPhase phase;
  final int remainingBudget;
  final Set<String> revealedClueIds;
  final Set<String> usedActionIds;
  final int round;
  final int currentPlayer;
  final List<StoryAccusation> votes;

  /// Seat -> index into `story.characters`. A seeded shuffle of the first
  /// [playerCount] characters, so the same seed always deals the same table
  /// and a new seed deals a new one; the set of seated characters never
  /// changes (the checker proves exactly that set).
  final List<int> seating;
  final StoryAccusation? soloAccusation;
  final StoryScore? score;

  /// The characters in seat order.
  List<StoryCharacter> get seated => [
    for (final index in seating) story.characters[index],
  ];

  StoryCharacter get currentCharacter =>
      story.characters[seating[currentPlayer]];

  static List<int> _seatingFor(int playerCount, int seed) {
    final order = List<int>.generate(playerCount, (i) => i);
    if (playerCount > 1) order.shuffle(Random(seed));
    return List.unmodifiable(order);
  }

  StoryClue get currentPrivateClue =>
      story.clue(currentCharacter.privateClueIds[round - 1]);

  List<StoryClue> get revealedClues => [
    for (final id in revealedClueIds) story.clue(id),
  ];

  bool canPerform(StoryInvestigationAction action) =>
      phase == StoryPhase.soloInvestigation &&
      !usedActionIds.contains(action.id) &&
      remainingBudget >= action.cost;

  StorySession performSoloAction(String actionId) {
    final action = story.action(actionId);
    if (!canPerform(action)) throw StateError('action is not available');
    final clues = {
      ...revealedClueIds,
      for (final id in action.clueIds)
        if (story.clue(id).appearsFor(playerCount)) id,
    };
    return _copy(
      remainingBudget: remainingBudget - action.cost,
      revealedClueIds: clues,
      usedActionIds: {...usedActionIds, action.id},
    );
  }

  /// The cheapest step still open, or null when every step was taken.
  int? get cheapestOpenCost {
    int? best;
    for (final a in story.actions) {
      if (usedActionIds.contains(a.id)) continue;
      if (best == null || a.cost < best) best = a.cost;
    }
    return best;
  }

  /// Extra budget for one more step (a watched rewarded ad).
  StorySession grantExtraBudget(int amount) {
    _expect(StoryPhase.soloInvestigation);
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    return _copy(remainingBudget: remainingBudget + amount);
  }

  StorySession submitSoloAccusation(StoryAccusation accusation) {
    _expect(StoryPhase.soloInvestigation);
    final result = _score(accusation, remainingBudget);
    return _copy(
      phase: StoryPhase.reenactment,
      soloAccusation: accusation,
      score: result,
    );
  }

  StorySession revealPrivateCard() {
    if (phase != StoryPhase.groupHandoff) {
      throw StateError('not at a private handoff');
    }
    return _copy(phase: StoryPhase.groupPrivateClue);
  }

  StorySession coverPrivateCard() {
    _expect(StoryPhase.groupPrivateClue);
    if (currentPlayer + 1 < playerCount) {
      return _copy(
        phase: StoryPhase.groupHandoff,
        currentPlayer: currentPlayer + 1,
      );
    }
    return _copy(phase: StoryPhase.groupDiscussion, currentPlayer: 0);
  }

  StorySession finishDiscussion() {
    _expect(StoryPhase.groupDiscussion);
    return _copy(phase: StoryPhase.groupInvestigation);
  }

  StorySession pickSharedInvestigation(String actionId) {
    _expect(StoryPhase.groupInvestigation);
    if (usedActionIds.contains(actionId)) {
      throw StateError('investigation already used');
    }
    final action = story.action(actionId);
    final clues = {
      ...revealedClueIds,
      for (final id in action.clueIds)
        if (story.clue(id).appearsFor(playerCount)) id,
    };
    return _afterSearch(clues, {...usedActionIds, action.id});
  }

  /// Moves on when no open search would yield anything for this table.
  StorySession skipSharedInvestigation() {
    _expect(StoryPhase.groupInvestigation);
    return _afterSearch(revealedClueIds, usedActionIds);
  }

  StorySession _afterSearch(Set<String> clues, Set<String> used) {
    if (round == 3) {
      return _copy(
        phase: StoryPhase.groupVoteHandoff,
        currentPlayer: 0,
        revealedClueIds: clues,
        usedActionIds: used,
      );
    }
    return _copy(
      phase: StoryPhase.groupHandoff,
      round: round + 1,
      currentPlayer: 0,
      revealedClueIds: clues,
      usedActionIds: used,
    );
  }

  /// The app left the foreground while a private page was open: the page is
  /// covered and the phone is back at its pass state for the same seat. A
  /// half-made ballot is dropped, never kept.
  StorySession coverForInterruption() => switch (phase) {
    StoryPhase.groupPrivateClue => _copy(phase: StoryPhase.groupHandoff),
    StoryPhase.groupVote => _copy(phase: StoryPhase.groupVoteHandoff),
    _ => this,
  };

  StorySession revealVoteCard() {
    _expect(StoryPhase.groupVoteHandoff);
    return _copy(phase: StoryPhase.groupVote);
  }

  StorySession submitSecretVote(StoryAccusation accusation) {
    _expect(StoryPhase.groupVote);
    final nextVotes = [...votes, accusation];
    if (currentPlayer + 1 < playerCount) {
      return _copy(
        phase: StoryPhase.groupVoteHandoff,
        currentPlayer: currentPlayer + 1,
        votes: nextVotes,
      );
    }
    final points = nextVotes
        .map((vote) => _score(vote, 0).total)
        .fold<int>(0, (total, value) => total + value);
    return _copy(
      phase: StoryPhase.reenactment,
      votes: nextVotes,
      score: StoryScore(
        culpritPoints: 0,
        motivePoints: 0,
        methodPoints: 0,
        efficiencyPoints: 0,
        solveBonus: points ~/ playerCount,
      ),
    );
  }

  StorySession finishReenactment() {
    _expect(StoryPhase.reenactment);
    return _copy(phase: StoryPhase.complete);
  }

  StoryScore _score(StoryAccusation accusation, int budget) {
    final culprit = accusation.culprit == story.truth.primaryCulprit ? 300 : 0;
    final motive = accusation.motive == story.truth.motive ? 250 : 0;
    final method = accusation.method == story.truth.method ? 250 : 0;
    final solved = culprit > 0 && motive > 0 && method > 0;
    return StoryScore(
      culpritPoints: culprit,
      motivePoints: motive,
      methodPoints: method,
      efficiencyPoints: solved ? budget * 25 : 0,
      solveBonus: solved ? 200 + story.difficulty * 50 : 0,
    );
  }

  void _expect(StoryPhase expected) {
    if (phase != expected) throw StateError('expected $expected, found $phase');
  }

  StorySession _copy({
    StoryPhase? phase,
    int? remainingBudget,
    Set<String>? revealedClueIds,
    Set<String>? usedActionIds,
    int? round,
    int? currentPlayer,
    List<StoryAccusation>? votes,
    StoryAccusation? soloAccusation,
    StoryScore? score,
  }) => StorySession._(
    story: story,
    playerCount: playerCount,
    seed: seed,
    mode: mode,
    phase: phase ?? this.phase,
    remainingBudget: remainingBudget ?? this.remainingBudget,
    revealedClueIds: revealedClueIds ?? this.revealedClueIds,
    usedActionIds: usedActionIds ?? this.usedActionIds,
    round: round ?? this.round,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    votes: votes ?? this.votes,
    seating: seating,
    soloAccusation: soloAccusation ?? this.soloAccusation,
    score: score ?? this.score,
  );
}
