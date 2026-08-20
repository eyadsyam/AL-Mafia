import 'dart:math';

import 'models/enums.dart';
import 'models/match.dart';
import 'models/match_settings.dart';
import 'models/player.dart';
import 'models/timeline_event.dart';
import 'resolver.dart';
import 'views.dart';
import 'win_check.dart';

/// The core pure-Dart game engine for Mafia Master.
/// No Flutter or dart:ui imports allowed (enforced by test).
class MatchEngine {
  /// The current match.
  ///
  /// Settable so a match restored from storage can be adopted wholesale
  /// (`MatchController.adoptMatch`). Every *rule* still goes through a command
  /// on this class — assigning here replaces state, it does not bypass logic.
  late Match match;

  /// Start a new match.
  /// Validates player count (5-20), role counts (sum == players, mafia >= 1, mafia < players/2),
  /// assigns roles, and transitions to distributing phase.
  Match start({
    required List<String> names,
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
    int? seed,
    int? id,
    DateTime? now,
  }) {
    // Validate player count
    if (names.length < 5 || names.length > 20) {
      throw ArgumentError('Player count must be 5-20, got ${names.length}');
    }

    // Validate role counts sum
    final totalRoles = roleCounts.values.fold<int>(0, (sum, count) => sum + count);
    if (totalRoles != names.length) {
      throw ArgumentError(
          'Role counts must sum to player count: got $totalRoles, expected ${names.length}');
    }

    // Validate mafia count
    final mafiaCount = roleCounts[Role.mafia] ?? 0;
    if (mafiaCount < 1) {
      throw ArgumentError('Must have at least 1 mafia, got $mafiaCount');
    }
    if (mafiaCount >= names.length / 2) {
      throw ArgumentError(
          'Mafia must be less than half the players: got $mafiaCount, max ${names.length ~/ 2}');
    }

    // A *fresh* seed unless the caller supplied one.
    //
    // This used to default to the constant 12345, which meant the shuffle below
    // ran the same way every time: seat 0 drew the same role in every match
    // anyone ever played, and a table that noticed would never need to guess
    // again. Tests and replays still pass an explicit seed, which is what keeps
    // them deterministic — determinism is a property of the *stored* seed, not
    // of the default.
    final finalSeed = seed ?? Random.secure().nextInt(1 << 32);

    // Build role list
    final roleList = <Role>[];
    for (final entry in roleCounts.entries) {
      for (int i = 0; i < entry.value; i++) {
        roleList.add(entry.key);
      }
    }

    // Shuffle roles deterministically
    final rng = Random(finalSeed);
    for (int i = roleList.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = roleList[i];
      roleList[i] = roleList[j];
      roleList[j] = temp;
    }

    // Create players with assigned roles
    final players = <Player>[];
    for (int i = 0; i < names.length; i++) {
      players.add(
        Player(
          seat: i,
          name: names[i],
          role: roleList[i],
          status: PlayerStatus.alive,
          eliminatedOn: null,
        ),
      );

      // Log role assignment
    }

    // The id is assigned here rather than by storage, so that every
    // `persistStep` for this match addresses the same row. Deriving it from the
    // creation instant keeps it stable across a reload without needing the
    // database to hand one back.
    final createdAt = now ?? DateTime.now();
    match = Match(
      id: id ?? createdAt.microsecondsSinceEpoch,
      createdAt: createdAt,
      seed: finalSeed,
      players: players,
      settings: settings,
      phase: GamePhase.distributing,
      dayNumber: 1,
      currentActorSeat: 0,
      eventLog: [],
    );

    // Log role assignments
    for (final player in players) {
      match = match.copyWith(
        eventLog: [
          ...match.eventLog,
          RoleAssigned(
            at: createdAt,
            phaseRef: PhaseRef(phase: GamePhase.distributing, number: 1),
            seat: player.seat,
            role: player.role,
          ),
        ],
      );
    }

    return match;
  }

  /// Reveal role for the current actor.
  /// Returns a record: {Role role, List<String> teammateNames}
  ({Role role, List<String> teammateNames}) revealFor(int seat) {
    if (match.currentActorSeat != seat) {
      throw StateError(
          'revealFor: seat $seat is not current actor (${match.currentActorSeat})');
    }

    final player = match.players[seat];
    final role = player.role;

    // Teammates are other mafia if this player is mafia
    List<String> teammates = [];
    if (role == Role.mafia) {
      teammates = match.players
          .where((p) => p.role == Role.mafia && p.seat != seat)
          .map((p) => p.name)
          .toList();
    }

    return (role: role, teammateNames: teammates);
  }

  /// Confirm role reveal for current actor, advance to next.
  void confirmRevealed() {
    if (match.phase != GamePhase.distributing) {
      throw StateError('confirmRevealed: not in distributing phase');
    }

    // Advance to next seat
    final currentSeat = match.currentActorSeat ?? 0;
    int nextSeat = currentSeat + 1;
    if (nextSeat >= match.players.length) {
      // All revealed, go to preNightLobby
      match = match.copyWith(
        phase: GamePhase.preNightLobby,
        currentActorSeat: null,
        clearCurrentActorSeat: true,
      );
    } else {
      match = match.copyWith(currentActorSeat: nextSeat);
    }
  }

  /// Begin the night phase.
  void beginNight() {
    if (match.phase != GamePhase.preNightLobby &&
        match.phase != GamePhase.reveal &&
        match.phase != GamePhase.winCheck) {
      throw StateError('beginNight: not in preNightLobby, reveal, or winCheck phase');
    }

    final now = DateTime.now();
    match = match.copyWith(
      phase: GamePhase.night,
      currentActorSeat: _findFirstAliveActorSeat(),
      eventLog: [
        ...match.eventLog,
        NightOpened(
          at: now,
          phaseRef: PhaseRef(phase: GamePhase.night, number: match.dayNumber),
        ),
      ],
    );
  }

  /// Get the actor view for the current actor's turn.
  ActorTurnView actorView(int seat) {
    if (match.currentActorSeat != seat) {
      throw StateError('actorView: seat $seat is not current actor');
    }

    final player = match.players[seat];
    final role = player.role;

    // Build question text based on role
    final questionText = switch (role) {
      Role.mafia => 'Who is tonight\'s target?',
      Role.doctor => 'Who do you protect tonight?',
      Role.detective => 'Whose identity do you investigate?',
      Role.citizen => 'Who do you suspect is Mafia?',
    };

    // Get other alive players as targets
    final targets =
        match.players.where((p) => p.seat != seat && p.status == PlayerStatus.alive).map((p) => p.seat).toList();

    // Get teammate votes (only for mafia)
    final teammateVotes = <int>[];
    if (role == Role.mafia) {
      for (final event in match.eventLog) {
        if (event is MafiaVoteCast && event.phaseRef.number == match.dayNumber) {
          if (!teammateVotes.contains(event.targetSeat)) {
            teammateVotes.add(event.targetSeat);
          }
        }
      }
    }

    return ActorTurnView(
      actorSeat: seat,
      actorRole: role,
      questionText: questionText,
      targets: targets,
      teammateVotes: teammateVotes,
    );
  }

  /// Whether [seat] has already investigated on the current night.
  ///
  /// Derived from the event log rather than held in a field, so that a match
  /// rebuilt from storage after a force-quit enforces the same one-shot rule
  /// (L-14, repository contract inv. 2).
  bool _hasInvestigatedTonight(int seat) => match.eventLog.any(
        (e) =>
            e is InvestigateCast &&
            e.actorSeat == seat &&
            e.phaseRef.phase == GamePhase.night &&
            e.phaseRef.number == match.dayNumber,
      );

  /// Which balloting round of the current day is open.
  ///
  /// Round 1 is the opening ballot; each tie under [DayTieRule.revote] appends a
  /// [DayRevoteCalled] and opens the next round. Deriving it from the log keeps
  /// a resumed match on the round it was actually interrupted in.
  int get currentVoteRound =>
      1 +
      match.eventLog
          .where((e) =>
              e is DayRevoteCalled && e.phaseRef.number == match.dayNumber)
          .length;

  /// Seats that may legally be voted for right now, or null when every living
  /// player other than the voter is a legal target (the opening ballot).
  ///
  /// On a revote this is exactly the tied set — a revote is "among tied players
  /// only" (FR-020).
  List<int>? get currentVoteCandidates {
    DayRevoteCalled? last;
    for (final e in match.eventLog) {
      if (e is DayRevoteCalled && e.phaseRef.number == match.dayNumber) {
        last = e;
      }
    }
    return last?.tiedSeats;
  }

  /// Submit a night action for the current actor.
  /// For investigate: returns InvestigateResult once; second call throws.
  /// For protect: throws if this doctor protected the same target last night.
  InvestigateResult? submitNightAction({
    required int seat,
    required NightActionKind kind,
    required int targetSeat,
  }) {
    if (match.currentActorSeat != seat) {
      throw StateError('submitNightAction: seat $seat is not current actor');
    }

    if (match.players[seat].status != PlayerStatus.alive) {
      throw StateError('submitNightAction: actor is dead');
    }

    if (targetSeat < 0 || targetSeat >= match.players.length) {
      throw StateError('submitNightAction: invalid target seat $targetSeat');
    }

    final player = match.players[seat];
    final now = DateTime.now();
    final phaseRef = PhaseRef(phase: GamePhase.night, number: match.dayNumber);

    InvestigateResult? result;

    // Handle based on kind
    switch (kind) {
      case NightActionKind.mafiaVote:
        if (player.role != Role.mafia) {
          throw StateError('submitNightAction: non-mafia cannot mafiaVote');
        }
        match = match.copyWith(
          eventLog: [
            ...match.eventLog,
            MafiaVoteCast(
              at: now,
              phaseRef: phaseRef,
              actorSeat: seat,
              targetSeat: targetSeat,
            ),
          ],
        );
        break;

      case NightActionKind.protect:
        if (player.role != Role.doctor) {
          throw StateError('submitNightAction: non-doctor cannot protect');
        }
        if (NightResolver.wouldViolateDoctorNoRepeat(
          match: match,
          doctorSeat: seat,
          targetSeat: targetSeat,
        )) {
          throw StateError('submitNightAction: doctor cannot protect same seat on consecutive nights');
        }
        match = match.copyWith(
          eventLog: [
            ...match.eventLog,
            ProtectCast(
              at: now,
              phaseRef: phaseRef,
              actorSeat: seat,
              targetSeat: targetSeat,
            ),
          ],
        );
        break;

      case NightActionKind.investigate:
        if (player.role != Role.detective) {
          throw StateError('submitNightAction: non-detective cannot investigate');
        }
        // One investigation per detective per night (L-14, inv. 3).
        if (_hasInvestigatedTonight(seat)) {
          throw StateError('submitNightAction: detective already investigated this night');
        }

        // Get the exact role of the target
        final targetRole = match.players[targetSeat].role;
        result = InvestigateResult(
          targetSeat: targetSeat,
          revealedRole: targetRole,
        );

        match = match.copyWith(
          eventLog: [
            ...match.eventLog,
            InvestigateCast(
              at: now,
              phaseRef: phaseRef,
              actorSeat: seat,
              targetSeat: targetSeat,
            ),
          ],
        );
        break;

      case NightActionKind.suspect:
        if (player.role != Role.citizen) {
          throw StateError('submitNightAction: non-citizen cannot suspect');
        }
        match = match.copyWith(
          eventLog: [
            ...match.eventLog,
            SuspectCast(
              at: now,
              phaseRef: phaseRef,
              actorSeat: seat,
              targetSeat: targetSeat,
              reason: null,
            ),
          ],
        );
        break;
    }

    // Advance to next alive actor
    final nextSeat = _findNextAliveActorSeat(seat);
    if (nextSeat == null) {
      match = match.copyWith(
        phase: GamePhase.nightResolving,
        currentActorSeat: null,
        clearCurrentActorSeat: true,
      );
    } else {
      match = match.copyWith(currentActorSeat: nextSeat);
    }

    return result;
  }

  /// Resolve the night: tally mafia votes, apply doctor protect, update match.
  MorningReport resolveNight() {
    if (match.phase != GamePhase.nightResolving) {
      throw StateError('resolveNight: not in nightResolving phase');
    }

    final now = DateTime.now();
    final report = NightResolver.resolveNight(match: match, now: now);

    // Update players if there's a victim
    List<Player> updatedPlayers = match.players;
    if (report.victimSeat != null) {
      updatedPlayers = updatedPlayers.map((p) {
        if (p.seat == report.victimSeat) {
          return p.copyWith(
            status: PlayerStatus.dead,
            eliminatedOn: PhaseRef(phase: GamePhase.night, number: match.dayNumber),
          );
        }
        return p;
      }).toList();
    }

    match = match.copyWith(
      phase: GamePhase.morning,
      players: updatedPlayers,
      eventLog: [
        ...match.eventLog,
        NightResolved(
          at: now,
          phaseRef: PhaseRef(phase: GamePhase.night, number: match.dayNumber),
          victimSeat: report.victimSeat,
          savedSeat: report.someoneSavedUnnamed ? report.victimSeat : null,
        ),
      ],
    );

    return report;
  }

  /// Whether the night that just resolved already decided the match.
  ///
  /// The alive set changes at night, so the win condition has to be evaluated
  /// there — doc 06 §3, evaluation point 1. It was not, and the cost was a whole
  /// wasted day: a kill that brought the mafia to parity was not noticed until
  /// the *next* day's vote reveal, so the table sat through a discussion and a
  /// ballot whose outcome could not matter.
  ///
  /// It is a query rather than a transition on purpose. Doc 06 §4 is explicit
  /// that the morning announcement comes first and the result second — learning
  /// who died and only then learning the game is over is the payoff for the
  /// whole match, and collapsing the two throws it away. So the engine reports
  /// that the match is decided and the flow still shows the morning.
  Alignment? outcomeAfterNight() =>
      match.phase == GamePhase.morning ? WinChecker.checkWin(match) : null;

  /// Begin discussion phase.
  void beginDiscussion() {
    if (match.phase != GamePhase.morning) {
      throw StateError('beginDiscussion: not in morning phase');
    }

    match = match.copyWith(phase: GamePhase.discussion);
  }

  /// Ends the match on a night that already decided it.
  ///
  /// Separate from [beginDiscussion] so the caller cannot accidentally open a
  /// discussion on a finished game, and separate from [winCheck] because that
  /// one also rolls the day number forward when nobody has won.
  Alignment? concludeAfterNight() {
    final result = outcomeAfterNight();
    if (result == null) return null;

    final now = DateTime.now();
    match = match.copyWith(
      phase: GamePhase.result,
      outcome: MatchOutcome(winner: result, completedAt: now),
      eventLog: [
        ...match.eventLog,
        WinReached(
          at: now,
          phaseRef: PhaseRef(phase: GamePhase.result, number: match.dayNumber),
          alignment: result,
        ),
      ],
    );
    return result;
  }

  /// Begin voting phase.
  void beginVoting() {
    if (match.phase != GamePhase.discussion) {
      throw StateError('beginVoting: not in discussion phase');
    }

    match = match.copyWith(
      phase: GamePhase.voting,
      currentActorSeat: _findFirstAliveActorSeat(),
    );
  }

  /// Submit a vote during day voting.
  void submitVote({
    required int seat,
    required int voterSeat,
    required int? targetSeat,
  }) {
    if (voterSeat == targetSeat && targetSeat != null) {
      throw ArgumentError('submitVote: cannot vote for yourself');
    }

    if (match.currentActorSeat != seat) {
      throw StateError('submitVote: seat $seat is not current actor');
    }

    if (match.players[seat].status != PlayerStatus.alive) {
      throw StateError('submitVote: voter is dead');
    }

    if (targetSeat != null) {
      if (targetSeat < 0 || targetSeat >= match.players.length) {
        throw ArgumentError('submitVote: invalid target seat $targetSeat');
      }
      if (match.players[targetSeat].status != PlayerStatus.alive) {
        throw StateError('submitVote: cannot vote for a dead player');
      }
      // On a revote the ballot is restricted to the tied seats (FR-020).
      final candidates = currentVoteCandidates;
      if (candidates != null && !candidates.contains(targetSeat)) {
        throw StateError(
            'submitVote: seat $targetSeat is not on the revote ballot $candidates');
      }
    }

    final now = DateTime.now();
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        VoteCast(
          at: now,
          phaseRef: PhaseRef(phase: GamePhase.voting, number: match.dayNumber),
          voterSeat: voterSeat,
          targetSeat: targetSeat,
          round: currentVoteRound,
        ),
      ],
    );

    // Advance to next alive voter
    final nextSeat = _findNextAliveActorSeat(seat);
    if (nextSeat == null) {
      match = match.copyWith(
        phase: GamePhase.voteResolving,
        currentActorSeat: null,
        clearCurrentActorSeat: true,
      );
    } else {
      match = match.copyWith(currentActorSeat: nextSeat);
    }
  }

  /// Resolve day votes and eliminate someone (or not).
  DayVoteResult resolveDayVote() {
    if (match.phase != GamePhase.voteResolving) {
      throw StateError('resolveDayVote: not in voteResolving phase');
    }

    // Tally only the round that is actually being resolved. Without the round
    // filter a revote would be counted on top of the ballot that tied.
    final round = currentVoteRound;
    final tally = <int, int>{};
    for (final event in match.eventLog) {
      if (event is VoteCast &&
          event.phaseRef.number == match.dayNumber &&
          event.round == round) {
        final target = event.targetSeat;
        if (target != null) {
          tally[target] = (tally[target] ?? 0) + 1;
        }
      }
    }

    final now = DateTime.now();

    if (tally.isEmpty) {
      // No votes, nobody eliminated
      match = match.copyWith(phase: GamePhase.reveal);
      return DayVoteResult();
    }

    // Find max votes
    final maxVotes = tally.values.reduce((a, b) => a > b ? a : b);
    final tiedTargets = tally.entries.where((e) => e.value == maxVotes).map((e) => e.key).toList();

    // Filter to alive players only
    final aliveTiedTargets = tiedTargets.where((seat) => match.players[seat].status == PlayerStatus.alive).toList();

    if (aliveTiedTargets.isEmpty) {
      // No valid targets, nobody eliminated
      match = match.copyWith(phase: GamePhase.reveal);
      return DayVoteResult();
    }

    // Handle tie
    if (aliveTiedTargets.length > 1) {
      // A revote that ties again ends the day with nobody eliminated.
      //
      // Without the `round` check this was unbounded: a revote narrows the
      // ballot to exactly the seats that tied, so a table that splits evenly
      // once tends to split evenly again, and the app kept calling revotes with
      // no way out of the day. It is a hang for a real table and it was a hang
      // in the suite — `scriptedMatch` votes deterministically, so it tied
      // identically forever.
      //
      // One revote is also the ordinary table rule: you get a second chance to
      // break it, and if you cannot, the day passes. `DayTieRule.noElimination`
      // is the setting for hosts who do not want even that.
      // Round 1 is the opening ballot — see [currentVoteRound]. Anything above
      // it is already a second chance.
      final isRevote = round > 1;
      if (match.settings.dayTieRule == DayTieRule.noElimination || isRevote) {
        // Nobody eliminated
        match = match.copyWith(phase: GamePhase.reveal);
        return DayVoteResult(tie: true, tally: tally, tiedSeats: [...aliveTiedTargets]..sort());
      } else {
        // Revote among tied seats only. Logging the call is what opens the next
        // round and narrows the ballot; both are then re-derivable from the log.
        final sortedTied = [...aliveTiedTargets]..sort();
        match = match.copyWith(
          phase: GamePhase.voting,
          currentActorSeat: _findFirstAliveActorSeat(),
          eventLog: [
            ...match.eventLog,
            DayRevoteCalled(
              at: now,
              phaseRef: PhaseRef(phase: GamePhase.voting, number: match.dayNumber),
              tiedSeats: sortedTied,
            ),
          ],
        );
        return DayVoteResult(
          tie: true,
          tally: tally,
          tiedSeats: sortedTied,
        );
      }
    }

    // Single target eliminated
    final eliminatedSeat = aliveTiedTargets.first;
    List<Player> updatedPlayers = match.players.map((p) {
      if (p.seat == eliminatedSeat) {
        return p.copyWith(
          status: PlayerStatus.dead,
          eliminatedOn: PhaseRef(phase: GamePhase.voting, number: match.dayNumber),
        );
      }
      return p;
    }).toList();

    match = match.copyWith(
      phase: GamePhase.reveal,
      players: updatedPlayers,
      eventLog: [
        ...match.eventLog,
        DayResolved(
          at: now,
          phaseRef: PhaseRef(phase: GamePhase.voting, number: match.dayNumber),
          eliminatedSeat: eliminatedSeat,
          tally: tally,
        ),
      ],
    );

    return DayVoteResult(
      eliminatedSeat: eliminatedSeat,
      tally: tally,
      eliminatedRole: match.players[eliminatedSeat].role,
    );
  }

  /// Check for win conditions. Returns winner alignment or null to continue.
  Alignment? winCheck() {
    if (match.phase != GamePhase.reveal && match.phase != GamePhase.winCheck) {
      throw StateError('winCheck: not in reveal or winCheck phase');
    }

    final result = WinChecker.checkWin(match);

    if (result != null) {
      // Game over
      final now = DateTime.now();
      match = match.copyWith(
        phase: GamePhase.result,
        outcome: MatchOutcome(winner: result, completedAt: now),
        eventLog: [
          ...match.eventLog,
          WinReached(
            at: now,
            phaseRef: PhaseRef(phase: GamePhase.result, number: match.dayNumber),
            alignment: result,
          ),
        ],
      );
      return result;
    }

    // Continue to next cycle
    match = match.copyWith(dayNumber: match.dayNumber + 1);
    match = match.copyWith(phase: GamePhase.preNightLobby);
    return null;
  }

  /// Remove a player from the game (host action).
  void removePlayer(int seat) {
    if (seat < 0 || seat >= match.players.length) {
      throw ArgumentError('removePlayer: invalid seat $seat');
    }

    List<Player> updatedPlayers = match.players.map((p) {
      if (p.seat == seat) {
        return p.copyWith(
          status: PlayerStatus.dead,
          eliminatedOn: PhaseRef(phase: match.phase, number: match.dayNumber),
        );
      }
      return p;
    }).toList();

    final now = DateTime.now();
    match = match.copyWith(
      players: updatedPlayers,
      eventLog: [
        ...match.eventLog,
        PlayerRemoved(
          at: now,
          phaseRef: PhaseRef(phase: match.phase, number: match.dayNumber),
          seat: seat,
        ),
      ],
    );

    // Run win check
    winCheck();
  }

  /// Get the public view of the match (no roles exposed).
  PublicMatchView publicView() {
    final publicPlayers =
        match.players.map((p) => PublicPlayer.from(p)).toList();

    return PublicMatchView(
      phase: match.phase,
      dayNumber: match.dayNumber,
      players: publicPlayers,
      currentActorSeat: match.currentActorSeat,
      morningReport: null, // Set by UI based on MorningReport from resolveNight
      lastTally: null, // Set by UI based on DayVoteResult from resolveDayVote
      outcome: match.outcome,
    );
  }

  /// Find the first alive actor seat (from 0 onwards).
  int? _findFirstAliveActorSeat() {
    for (int i = 0; i < match.players.length; i++) {
      if (match.players[i].status == PlayerStatus.alive) {
        return i;
      }
    }
    return null;
  }

  /// Find the next alive actor seat after the given seat (circular).
  int? _findNextAliveActorSeat(int currentSeat) {
    // Forward-only in seating order: the actor loop (night/voting) ends when no
    // alive player has a higher seat than the current one. Wrapping around here
    // would make the loop never terminate (nightResolving/voteResolving unreached)
    // and re-ask earlier actors — see contract inv. 2 and data-model §9.
    final count = match.players.length;
    for (int s = currentSeat + 1; s < count; s++) {
      if (match.players[s].status == PlayerStatus.alive) {
        return s;
      }
    }
    return null;
  }
}
