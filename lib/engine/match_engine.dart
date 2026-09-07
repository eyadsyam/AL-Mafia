import 'dart:math';

import 'clock.dart';
import 'information/confrontation_generator.dart';
import 'bullets.dart';
import 'information/game_history.dart';
import 'information/records.dart';
import 'information/trace_generator.dart';
import 'invariants.dart';
import 'legal_moves.dart';
import 'models/enums.dart';
import 'models/match.dart';
import 'models/match_settings.dart';
import 'models/player.dart';
import 'models/timeline_event.dart';
import 'resolver.dart';
import 'seed.dart';
import 'views.dart';
import 'win_check.dart';

/// The core pure-Dart game engine for Mafia Master.
///
/// **Pure** means more than "no Flutter imports", and every clause is enforced
/// by `test/engine/engine_purity_test.dart` rather than trusted:
///
/// - no `package:flutter`, `dart:ui` or `dart:io`;
/// - no reads of the wall clock — time arrives through [clock];
/// - no unseeded or secure `Random` — every stream is derived from `Match.seed`
///   by way of `deriveSeed`.
///
/// Together those make a match a pure function of `(names, roles, settings,
/// seed, clock, moves)`. That is what lets the fuzz harness reproduce any
/// failure from a seed alone, and what will let an Edge Function and a phone
/// resolve the same night to the same bytes when the online mode lands
/// (`10-online-architecture.md` §5.1).
class MatchEngine {
  /// Where every timestamp this engine writes comes from.
  ///
  /// The app passes `DateTime.now`; tests and the fuzz harness pass
  /// [Clocks.monotonic]. Required, and deliberately not defaulted: a default
  /// would have to be one or the other, and whichever it was would be silently
  /// wrong half the time.
  final Clock clock;

  MatchEngine({required this.clock});

  Match? _match;

  /// The current match.
  ///
  /// Settable so a match restored from storage can be adopted wholesale
  /// (`MatchController.adoptMatch`). Every *rule* still goes through a command
  /// on this class — assigning here replaces state, it does not bypass logic.
  ///
  /// Reading it before a match exists is a programming error and throws, the
  /// same as the `late` field it replaces. The difference is [hasMatch]: the
  /// transport is constructed when the app starts, long before anybody taps
  /// "new match", and it needs a way to ask rather than a way to find out by
  /// crashing.
  Match get match {
    final current = _match;
    if (current == null) {
      throw StateError('MatchEngine: no match has been started');
    }
    return current;
  }

  set match(Match value) => _match = value;

  /// Whether a match has been started or adopted.
  bool get hasMatch => _match != null;

  /// Start a new match.
  /// Validates player count (5-20), role counts (sum == players, mafia >= 1, mafia < players/2),
  /// assigns roles, and transitions to distributing phase.
  Match start({
    required List<String> names,
    Map<String, PlayerGender> genders = const {},
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
    required int seed,
    int? id,
    DateTime? now,
  }) {
    // Validate player count
    if (names.length < 5 || names.length > 20) {
      throw ArgumentError('Player count must be 5-20, got ${names.length}');
    }

    // Validate role counts sum
    final totalRoles = roleCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    if (totalRoles != names.length) {
      throw ArgumentError(
        'Role counts must sum to player count: got $totalRoles, expected ${names.length}',
      );
    }

    // Validate mafia count
    final mafiaCount = roleCounts[Role.mafia] ?? 0;
    if (mafiaCount < 1) {
      throw ArgumentError('Must have at least 1 mafia, got $mafiaCount');
    }
    if (mafiaCount >= names.length / 2) {
      throw ArgumentError(
        'Mafia must be less than half the players: got $mafiaCount, max ${names.length ~/ 2}',
      );
    }

    // The seed is the caller's to mint, not the engine's.
    //
    // It used to be `seed ?? Random.secure().nextInt(1 << 32)` — a read of the
    // platform entropy pool, in the middle of the one class that is supposed to
    // be a pure function of its arguments. It made `start` the only command
    // whose output could not be predicted from its input, which is exactly the
    // property the fuzz harness and the online mode both depend on.
    //
    // So it moved out. `newMatchSeed()` in `lib/data/` is the app's minter;
    // online the seed comes from `rooms.match_seed` (doc 10 §4) and is never
    // sent to clients, so they cannot predict a tie-break. The engine cannot
    // tell the two apart and does not need to.
    final finalSeed = seed;

    // Build role list
    final roleList = <Role>[];
    for (final entry in roleCounts.entries) {
      for (int i = 0; i < entry.value; i++) {
        roleList.add(entry.key);
      }
    }

    // Shuffle roles deterministically, on the stream reserved for the deal.
    // Sharing one stream between the deal and the night tie-break would
    // correlate them; see `seed.dart`.
    final rng = Random(deriveSeed(finalSeed, SeedSalt.roleShuffle, 0));
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
          gender: genders[names[i]] ?? PlayerGender.unspecified,
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
    final createdAt = now ?? clock();
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

    assertMatchInvariants(match, 'start');
    return match;
  }

  /// Reveal role for the current actor.
  /// Returns a record: {Role role, List<String> teammateNames}
  ({Role role, List<String> teammateNames}) revealFor(int seat) {
    if (match.currentActorSeat != seat) {
      throw StateError(
        'revealFor: seat $seat is not current actor (${match.currentActorSeat})',
      );
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
    assertMatchInvariants(match, 'confirmRevealed');
  }

  /// Begin the night phase.
  void beginNight() {
    if (match.phase != GamePhase.preNightLobby &&
        match.phase != GamePhase.reveal &&
        match.phase != GamePhase.winCheck) {
      throw StateError(
        'beginNight: not in preNightLobby, reveal, or winCheck phase',
      );
    }

    // A night may not open on a match that is already decided.
    //
    // Doc 11 N14 — *"Every living player is Mafia -> win check fires before the
    // night begins"* — and there was nothing making it so. `winCheck()` is the
    // only route the UI takes into `preNightLobby` and it does end the match,
    // so this was unreachable through the app; it was reachable through the
    // engine, because `beginNight` also accepts `reveal` and `winCheck` as
    // source phases and neither of those has looked at the roster yet. The cost
    // of the gap is a full pass of the phone around a table whose game ended
    // before the night started.
    final decided = WinChecker.checkWin(match);
    if (decided != null) {
      throw StateError(
        'beginNight: ${decided.name} has already won - run winCheck first',
      );
    }

    final now = clock();
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
    assertMatchInvariants(match, 'beginNight');
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
    final targets = match.players
        .where((p) => p.seat != seat && p.status == PlayerStatus.alive)
        .map((p) => p.seat)
        .toList();

    // Get teammate votes (only for mafia)
    final teammateVotes = <int>[];
    if (role == Role.mafia) {
      for (final event in match.eventLog) {
        if (event is MafiaVoteCast &&
            event.phaseRef.number == match.dayNumber) {
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
  bool _hasInvestigatedTonight(int seat) => hasInvestigatedTonight(match, seat);

  /// Which balloting round of the current day is open.
  ///
  /// Round 1 is the opening ballot; each tie under [DayTieRule.revote] appends a
  /// [DayRevoteCalled] and opens the next round. Deriving it from the log keeps
  /// a resumed match on the round it was actually interrupted in.
  int get currentVoteRound => voteRoundFor(match);

  /// Seats that may legally be voted for right now, or null when every living
  /// player other than the voter is a legal target (the opening ballot).
  ///
  /// On a revote this is exactly the tied set — a revote is "among tied players
  /// only" (FR-020).
  List<int>? get currentVoteCandidates => voteCandidatesFor(match);

  /// Submit a night action for the current actor.
  /// For investigate: returns InvestigateResult once; second call throws.
  /// For protect: throws if this doctor protected the same target last night.
  ///
  /// [useBullet] arms «الطلقة الواحدة» (doc 13 §2) on the same turn. It is one
  /// parameter for all four roles because it is one control in one slot on all
  /// four screens: what it *means* differs by role, what it costs and how it is
  /// armed does not. See [_spendBullet] for what each one does.
  InvestigateResult? submitNightAction({
    required int seat,
    required NightActionKind kind,
    required int targetSeat,
    bool useBullet = false,
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
    final now = clock();
    final phaseRef = PhaseRef(phase: GamePhase.night, number: match.dayNumber);

    // Spent first, so that everything below - including the Doctor's target,
    // which the bullet replaces - reads a log that already knows about it.
    if (useBullet) _spendBullet(seat: seat, now: now, phaseRef: phaseRef);

    // «حماية النفس». The bullet *is* the target: the Doctor's grid has never
    // held their own name and doc 05 rule 6 is why it never will, so a Doctor
    // who arms this is protecting themselves whoever they happened to have
    // highlighted. Redirected rather than refused, because refusing would mean
    // the confirm button behaves differently for one role.
    if (useBullet && player.role == Role.doctor) targetSeat = seat;

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
        if (targetSeat == seat && !useBullet) {
          throw StateError(
            'submitNightAction: doctor cannot protect themselves without '
            'the self-protection bullet',
          );
        }
        if (targetSeat != seat &&
            NightResolver.wouldViolateDoctorNoRepeat(
              match: match,
              doctorSeat: seat,
              targetSeat: targetSeat,
            )) {
          throw StateError(
            'submitNightAction: doctor cannot protect same seat on consecutive nights',
          );
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
          throw StateError(
            'submitNightAction: non-detective cannot investigate',
          );
        }
        // One investigation per detective per night (L-14, inv. 3).
        if (_hasInvestigatedTonight(seat)) {
          throw StateError(
            'submitNightAction: detective already investigated this night',
          );
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

    _advanceNightActor(seat);

    assertMatchInvariants(match, 'submitNightAction');
    return result;
  }

  /// Take the current actor's night turn without choosing anybody.
  ///
  /// ## Why every role can do this and not just the Citizen
  ///
  /// Doc 11 N10 names one case — *"Citizen skips their suspicion → recorded as
  /// `null`. Feeds `T6` and `C10`"* — and if that were the only case, the skip
  /// control would exist on one role's screen and not on the other three. That
  /// is doc 05 rule 6 (single layout tree) and rule 5 (identical tap count) in
  /// one stroke: an extra button for one role is the cleanest structural tell
  /// in the app, and it would be handed to the table for free.
  ///
  /// So the option is universal, and it happens to be the right game rule too.
  /// Doc 10 §8.2's expiry defaults already require three of the four to have a
  /// null action — "no protection", "no investigation", "recorded as skipped" —
  /// so the model needs to hold them regardless. The Mafia's expiry default is
  /// a *seeded random target* rather than a skip, but a Mafia who deliberately
  /// kills nobody is a legal, and occasionally very good, night; the resolver
  /// has always handled zero mafia votes.
  ///
  /// The trace never says who skipped. `T6` is «فيه لاعب رفض يسجّل شكه» —
  /// aggregate, unnamed, exactly like every other trace but `T1`.
  /// [useBullet] arms the bullet without choosing anybody, which is the whole
  /// of the Mafia's «الليلة الهادية» and of a Detective who opens a file and
  /// investigates nobody else tonight.
  void skipNightAction({required int seat, bool useBullet = false}) {
    if (match.players[seat].role == Role.doctor && !useBullet) {
      // Expiry and legacy callers still need a deterministic action. The UI
      // requires an explicit choice; the engine's safety default protects the
      // first legal living target so a doctor can never submit "nothing".
      final target = match.players.firstWhere(
        (p) =>
            p.status == PlayerStatus.alive &&
            p.seat != seat &&
            !NightResolver.wouldViolateDoctorNoRepeat(
              match: match,
              doctorSeat: seat,
              targetSeat: p.seat,
            ),
      );
      submitNightAction(
        seat: seat,
        kind: NightActionKind.protect,
        targetSeat: target.seat,
      );
      return;
    }
    if (match.phase != GamePhase.night) {
      throw StateError('skipNightAction: not in night phase');
    }
    if (match.currentActorSeat != seat) {
      throw StateError('skipNightAction: seat $seat is not current actor');
    }
    if (match.players[seat].status != PlayerStatus.alive) {
      throw StateError('skipNightAction: actor is dead');
    }

    final now = clock();
    final phaseRef = PhaseRef(phase: GamePhase.night, number: match.dayNumber);

    if (useBullet) _spendBullet(seat: seat, now: now, phaseRef: phaseRef);

    // A Doctor's self-protection is an *action*, not an absence, so arming it
    // with nobody selected still protects them. Every other bullet leaves the
    // turn itself empty, which is exactly what it was before.
    if (useBullet && match.players[seat].role == Role.doctor) {
      match = match.copyWith(
        eventLog: [
          ...match.eventLog,
          ProtectCast(
            at: now,
            phaseRef: phaseRef,
            actorSeat: seat,
            targetSeat: seat,
          ),
        ],
      );
      _advanceNightActor(seat);
      assertMatchInvariants(match, 'skipNightAction');
      return;
    }

    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        NightActionSkipped(
          at: now,
          phaseRef: phaseRef,
          actorSeat: seat,
          kind: match.players[seat].role.nightAction,
        ),
      ],
    );

    _advanceNightActor(seat);
    assertMatchInvariants(match, 'skipNightAction');
  }

  /// Records that [seat] spent their one bullet, and refuses if they have not
  /// got one.
  ///
  /// A `StateError` rather than a silent no-op: every caller has already been
  /// told by [Bullets.canArm] whether the control should be there at all, so
  /// reaching here with a spent bullet is a wiring bug and the loudest place
  /// to find out is here.
  void _spendBullet({
    required int seat,
    required DateTime now,
    required PhaseRef phaseRef,
  }) {
    if (!Bullets.canArm(match, seat)) {
      throw StateError(
        'bullet: seat $seat has none left, or this match has '
        'none to give',
      );
    }
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        BulletSpent(
          at: now,
          phaseRef: phaseRef,
          actorSeat: seat,
          // Non-null by construction: [Bullets.canArm] above is false for
          // every role that holds nothing, so reaching this line means there
          // is a kind to record.
          kind: match.players[seat].role.bullet!,
        ),
      ],
    );
  }

  /// Whether the current actor may still arm a bullet. False when this match
  /// has the mechanic turned off, so the control is never built rather than
  /// built and disabled.
  bool canArmBullet(int seat) => Bullets.canArm(match, seat);

  /// Moves the phone on after a night turn, or closes the night.
  void _advanceNightActor(int seat) {
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
  }

  /// Resolve the night: tally mafia votes, apply doctor protect, update match.
  MorningReport resolveNight() {
    if (match.phase != GamePhase.nightResolving) {
      throw StateError('resolveNight: not in nightResolving phase');
    }

    final now = clock();
    final resolution = NightResolver.resolveNight(match: match, now: now);
    final report = resolution.report;

    // Update players if there's a victim
    List<Player> updatedPlayers = match.players;
    if (report.victimSeat != null) {
      updatedPlayers = updatedPlayers.map((p) {
        if (p.seat == report.victimSeat) {
          return p.copyWith(
            status: PlayerStatus.dead,
            eliminatedOn: PhaseRef(
              phase: GamePhase.night,
              number: match.dayNumber,
            ),
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
          // The seat comes from the resolution, not from `report.victimSeat` -
          // the report has already cleared that to null precisely because the
          // save meant nobody died, so reading it back here recorded nothing.
          savedSeat: resolution.savedSeat,
        ),
      ],
    );

    if (report.victimSeat != null) _voidWhispersTo(report.victimSeat!, now);
    _publishTrace(now);

    assertMatchInvariants(match, 'resolveNight');
    return report;
  }

  /// Chooses and records the morning's trace (doc 09 §1).
  ///
  /// Runs here, at the moment the night resolves, rather than when the morning
  /// screen builds. Two reasons, and both are about the answer being *fixed*:
  /// the generator reads the history up to this night, and the history keeps
  /// growing; and the online transport resolves the night in an Edge Function
  /// (doc 10 §5) and broadcasts the result, so the trace has to be part of the
  /// resolution rather than something each client works out for itself.
  ///
  /// `T0` is recorded like any other outcome. "Nothing was eligible" is a fact
  /// about the night and the table is told it — the alternative is an empty
  /// space where a sentence usually is, which reads as a bug.
  void _publishTrace(DateTime now) {
    if (!match.settings.traceEnabled) return;

    final history = buildHistory(match);
    final night = history.nightAt(match.dayNumber);
    if (night == null) return;

    final earlier = history.resolvedNights
        .where((n) => n.nightNumber < match.dayNumber)
        .toList();

    final trace = selectTrace(
      night: night,
      history: earlier,
      players: match.players,
      nightNumber: match.dayNumber,
      matchSeed: match.seed,
      // Doc 13 §8. `T2` says a kill was blocked, and a morning in which
      // nobody died has to be unreadable once the Mafia can buy one.
      allowSaveTrace: !match.settings.quietNightEnabled,
    );

    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        TracePublished(
          at: now,
          phaseRef: PhaseRef(phase: GamePhase.morning, number: match.dayNumber),
          type: trace.type,
          subjectSeat: trace.subjectSeat,
          targetSeat: trace.targetSeat,
          count: trace.count,
        ),
      ],
    );
  }

  /// This morning's trace, as it was published. Null when the layer is off or
  /// the night has not resolved.
  TraceResult? get currentTrace {
    for (final e in match.eventLog.reversed) {
      if (e is TracePublished && e.phaseRef.number == match.dayNumber) {
        return TraceResult(
          type: e.type,
          subjectSeat: e.subjectSeat,
          targetSeat: e.targetSeat,
          count: e.count,
        );
      }
    }
    return null;
  }

  /// Today's confrontation, as it was issued. Null when there was none.
  Confrontation? get currentConfrontation {
    for (final e in match.eventLog.reversed) {
      if (e is ConfrontationIssued && e.phaseRef.number == match.dayNumber) {
        return Confrontation(
          type: e.type,
          targetSeat: e.targetSeat,
          evidenceSeat: e.evidenceSeat,
          evidenceSeat2: e.evidenceSeat2,
          evidenceDay: e.evidenceDay,
          count: e.count,
        );
      }
    }
    return null;
  }

  /// The accusations recorded so far in today's «اسم واحد» round.
  Map<int, int> get openingAccusations => {
    for (final e in match.eventLog)
      if (e is OpeningAccusationCast && e.phaseRef.number == match.dayNumber)
        e.actorSeat: e.targetSeat,
  };

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

  /// Opens the day after the table has read the morning.
  ///
  /// The single door out of `morning`. Which screen the table lands on is the
  /// engine's decision, not the caller's, because it depends on facts only the
  /// engine holds — the day number, the settings, and whether the confrontation
  /// generator found anything:
  ///
  /// ```
  /// day 1, opener on   → openingRound   («اسم واحد»)
  /// day 2+, evidence   → confrontation  (exactly one, never two)
  /// otherwise          → discussion
  /// ```
  ///
  /// [beginDiscussion] remains the way into `discussion` and is still callable
  /// from `morning` directly, which is what a match with all three layers
  /// switched off does — and what the classic-Mafia tests do.
  void beginDay() {
    if (match.phase != GamePhase.morning) {
      throw StateError('beginDay: not in morning phase');
    }
    final decided = outcomeAfterNight();
    if (decided != null) {
      throw StateError(
        'beginDay: ${decided.name} won overnight - call concludeAfterNight',
      );
    }

    if (match.dayNumber == 1 && match.settings.openingRoundEnabled) {
      final first = _findFirstAliveActorSeat();
      if (first != null) {
        match = match.copyWith(
          phase: GamePhase.openingRound,
          currentActorSeat: first,
        );
        assertMatchInvariants(match, 'beginDay (opening round)');
        return;
      }
    }

    _openConfrontationOrDiscussion();
  }

  /// Records one public accusation in the «اسم واحد» round and passes on.
  ///
  /// A forced choice: doc 09 §2.2 — *"No explanation permitted. No 'I don't
  /// know' permitted."* There is deliberately no skip. That is what converts a
  /// dead opening into a full suspicion map, and it is safe to force because
  /// naming somebody out loud on Day 1 costs a player nothing they have not
  /// already been asked for.
  void submitOpeningAccusation({required int seat, required int targetSeat}) {
    if (match.phase != GamePhase.openingRound) {
      throw StateError('submitOpeningAccusation: not in openingRound phase');
    }
    if (match.currentActorSeat != seat) {
      throw StateError(
        'submitOpeningAccusation: seat $seat is not current actor',
      );
    }
    if (seat == targetSeat) {
      throw ArgumentError('submitOpeningAccusation: cannot accuse yourself');
    }
    if (targetSeat < 0 || targetSeat >= match.players.length) {
      throw ArgumentError('submitOpeningAccusation: invalid seat $targetSeat');
    }
    if (match.players[targetSeat].status != PlayerStatus.alive) {
      throw StateError('submitOpeningAccusation: cannot accuse a dead player');
    }

    final now = clock();
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        OpeningAccusationCast(
          at: now,
          phaseRef: PhaseRef(
            phase: GamePhase.openingRound,
            number: match.dayNumber,
          ),
          actorSeat: seat,
          targetSeat: targetSeat,
        ),
      ],
    );

    final next = _findNextAliveActorSeat(seat);
    if (next != null) {
      match = match.copyWith(currentActorSeat: next);
      assertMatchInvariants(match, 'submitOpeningAccusation');
      return;
    }

    match = match.copyWith(currentActorSeat: null, clearCurrentActorSeat: true);
    _openConfrontationOrDiscussion();
  }

  /// Closes the confrontation window and opens the discussion.
  ///
  /// [silent] records that the named player said nothing — a timer that ran
  /// out at the table, or a disconnect online. C-E5: silence is recorded, and
  /// is itself information.
  void endConfrontation({bool silent = false}) {
    if (match.phase != GamePhase.confrontation) {
      throw StateError('endConfrontation: not in confrontation phase');
    }
    final issued = currentConfrontation;
    final now = clock();
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        ConfrontationAnswered(
          at: now,
          phaseRef: PhaseRef(
            phase: GamePhase.confrontation,
            number: match.dayNumber,
          ),
          targetSeat: issued?.targetSeat ?? -1,
          silent: silent,
        ),
      ],
    );
    _openDiscussion();
    assertMatchInvariants(match, 'endConfrontation');
  }

  /// Runs the confrontation generator, or falls straight through to discussion.
  void _openConfrontationOrDiscussion() {
    if (match.settings.confrontationEnabled && match.dayNumber > 1) {
      final confrontation = selectConfrontation(
        history: buildHistory(match),
        players: match.players,
        dayNumber: match.dayNumber,
        matchSeed: match.seed,
        settings: match.settings,
      );
      if (confrontation != null) {
        final now = clock();
        match = match.copyWith(
          phase: GamePhase.confrontation,
          currentActorSeat: null,
          clearCurrentActorSeat: true,
          eventLog: [
            ...match.eventLog,
            ConfrontationIssued(
              at: now,
              phaseRef: PhaseRef(
                phase: GamePhase.confrontation,
                number: match.dayNumber,
              ),
              targetSeat: confrontation.targetSeat,
              type: confrontation.type,
              evidenceSeat: confrontation.evidenceSeat,
              evidenceSeat2: confrontation.evidenceSeat2,
              evidenceDay: confrontation.evidenceDay,
              count: confrontation.count,
            ),
          ],
        );
        assertMatchInvariants(match, 'beginDay (confrontation)');
        return;
      }
    }
    _openDiscussion();
    assertMatchInvariants(match, 'beginDay (discussion)');
  }

  void _openDiscussion() {
    match = match.copyWith(
      phase: GamePhase.discussion,
      currentActorSeat: null,
      clearCurrentActorSeat: true,
    );
  }

  /// Begin discussion phase.
  void beginDiscussion() {
    if (match.phase != GamePhase.morning) {
      throw StateError('beginDiscussion: not in morning phase');
    }

    // The doc comment on [concludeAfterNight] said this class was "separate
    // from beginDiscussion so the caller cannot accidentally open a discussion
    // on a finished game". Separating the two methods expressed that intent; it
    // did not enforce it. A caller that read the morning and then reached for
    // the wrong one got a whole day - discussion, ballot, elimination - on a
    // match whose winner was already fixed, and the table would only find out
    // after voting somebody out for nothing.
    final decided = outcomeAfterNight();
    if (decided != null) {
      throw StateError(
        'beginDiscussion: ${decided.name} won overnight - '
        'call concludeAfterNight',
      );
    }

    match = match.copyWith(phase: GamePhase.discussion);
    assertMatchInvariants(match, 'beginDiscussion');
  }

  /// Ends the match on a night that already decided it.
  ///
  /// Separate from [beginDiscussion] so the caller cannot accidentally open a
  /// discussion on a finished game, and separate from [winCheck] because that
  /// one also rolls the day number forward when nobody has won.
  Alignment? concludeAfterNight() {
    final result = outcomeAfterNight();
    if (result == null) return null;

    final now = clock();
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
    assertMatchInvariants(match, 'concludeAfterNight');
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
    assertMatchInvariants(match, 'beginVoting');
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
          'submitVote: seat $targetSeat is not on the revote ballot $candidates',
        );
      }
    }

    final now = clock();
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
    assertMatchInvariants(match, 'submitVote');
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

    final now = clock();

    if (tally.isEmpty) {
      // No votes, nobody eliminated
      match = match.copyWith(phase: GamePhase.reveal);
      assertMatchInvariants(match, 'resolveDayVote (no votes)');
      return DayVoteResult();
    }

    // Find max votes
    final maxVotes = tally.values.reduce((a, b) => a > b ? a : b);
    final tiedTargets = tally.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    // Filter to alive players only
    final aliveTiedTargets = tiedTargets
        .where((seat) => match.players[seat].status == PlayerStatus.alive)
        .toList();

    if (aliveTiedTargets.isEmpty) {
      // No valid targets, nobody eliminated
      match = match.copyWith(phase: GamePhase.reveal);
      assertMatchInvariants(match, 'resolveDayVote (no living target)');
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
        assertMatchInvariants(match, 'resolveDayVote (tie stands)');
        return DayVoteResult(
          tie: true,
          tally: tally,
          tiedSeats: [...aliveTiedTargets]..sort(),
        );
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
              phaseRef: PhaseRef(
                phase: GamePhase.voting,
                number: match.dayNumber,
              ),
              tiedSeats: sortedTied,
            ),
          ],
        );
        assertMatchInvariants(match, 'resolveDayVote (revote called)');
        return DayVoteResult(tie: true, tally: tally, tiedSeats: sortedTied);
      }
    }

    // Single target eliminated
    final eliminatedSeat = aliveTiedTargets.first;
    List<Player> updatedPlayers = match.players.map((p) {
      if (p.seat == eliminatedSeat) {
        return p.copyWith(
          status: PlayerStatus.dead,
          eliminatedOn: PhaseRef(
            phase: GamePhase.voting,
            number: match.dayNumber,
          ),
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

    _voidWhispersTo(eliminatedSeat, now);

    assertMatchInvariants(match, 'resolveDayVote (elimination)');
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
      final now = clock();
      match = match.copyWith(
        phase: GamePhase.result,
        outcome: MatchOutcome(winner: result, completedAt: now),
        eventLog: [
          ...match.eventLog,
          WinReached(
            at: now,
            phaseRef: PhaseRef(
              phase: GamePhase.result,
              number: match.dayNumber,
            ),
            alignment: result,
          ),
        ],
      );
      assertMatchInvariants(match, 'winCheck (match over)');
      return result;
    }

    // Continue to next cycle
    match = match.copyWith(dayNumber: match.dayNumber + 1);
    match = match.copyWith(phase: GamePhase.preNightLobby);
    assertMatchInvariants(match, 'winCheck (next cycle)');
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

    final now = clock();
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

    _voidWhispersTo(seat, now);

    // Run win check. It asserts the invariants on the way out, which is why
    // there is none between the roster edit above and this call: a removal that
    // brings the mafia to parity leaves the match momentarily
    // decided-but-still-playing, and that is exactly the state `winCheck`
    // exists to clear.
    winCheck();
  }

  // ---------------------------------------------------------------------------
  // Layer 3 — the Whisper (doc 09 §3)
  //
  // The engine handles the *graph* and every rule about it. It never sees a
  // body for longer than it takes to measure one: [sendWhisper] validates the
  // length and returns an id, and the caller puts the body in the whisper
  // store. That is the offline half of §5's storage split, and it is why no
  // amount of reading `Match` can recover what anybody wrote.
  // ---------------------------------------------------------------------------

  /// Records one whisper and returns its id. Throws if any rule is broken.
  ///
  /// [body] is validated and discarded. Store it under the returned id.
  String sendWhisper({
    required int fromSeat,
    required int toSeat,
    required String body,
  }) {
    if (!match.settings.whisperEnabled) {
      throw StateError('sendWhisper: whispers are switched off for this match');
    }
    if (match.phase != GamePhase.discussion) {
      throw StateError('sendWhisper: whispers are written during discussion');
    }
    if (fromSeat == toSeat) {
      throw ArgumentError('sendWhisper: cannot whisper to yourself');
    }
    for (final seat in [fromSeat, toSeat]) {
      if (seat < 0 || seat >= match.players.length) {
        throw ArgumentError('sendWhisper: invalid seat $seat');
      }
      if (match.players[seat].status != PlayerStatus.alive) {
        throw StateError('sendWhisper: seat $seat is not alive');
      }
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      // H-E10. An empty whisper is still a public edge on the graph, so
      // sending one would be a free, costless signal — «أنا وهو بنتكلم» with
      // nothing said. Rejected.
      throw ArgumentError('sendWhisper: empty body');
    }
    if (trimmed.length > WhisperLimits.maxLength) {
      // H-E6: blocked, never silently truncated.
      throw ArgumentError(
        'sendWhisper: ${trimmed.length} characters, limit is '
        '${WhisperLimits.maxLength}',
      );
    }
    if (whispersSentBy(fromSeat, match.dayNumber) >=
        WhisperLimits.perPlayerPerDay) {
      // H-E1. The UI disables the control after the first, and this is what
      // makes that a rule rather than a courtesy.
      throw StateError(
        'sendWhisper: seat $fromSeat has already whispered today',
      );
    }

    final id = WhisperMeta.idFor(
      day: match.dayNumber,
      fromSeat: fromSeat,
      toSeat: toSeat,
    );
    final now = clock();
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        WhisperSent(
          at: now,
          phaseRef: PhaseRef(
            phase: GamePhase.discussion,
            number: match.dayNumber,
          ),
          id: id,
          fromSeat: fromSeat,
          toSeat: toSeat,
        ),
      ],
    );
    assertMatchInvariants(match, 'sendWhisper');
    return id;
  }

  /// The whisper graph for [day] — senders and recipients, never bodies.
  ///
  /// Public: doc 09 §3.1 puts the graph on the table on purpose, because a
  /// visible alliance map that everyone can argue about is the point of the
  /// layer. What it deliberately cannot reach is the body, which is not in
  /// `Match` at all.
  List<WhisperMeta> whispersOn(int day) => [
    for (final w in _whisperGraph().values)
      if (w.day == day) w,
  ]..sort((a, b) => a.fromSeat.compareTo(b.fromSeat));

  /// How many whispers [seat] has sent on [day].
  int whispersSentBy(int seat, int day) => match.eventLog
      .whereType<WhisperSent>()
      .where((e) => e.fromSeat == seat && e.phaseRef.number == day)
      .length;

  /// Whispers waiting for [seat] — sent, not yet read, not voided.
  ///
  /// Offline these are delivered on the recipient's next private turn (doc 09
  /// §3.6). The card that shows them appears on **every** player's turn, empty
  /// or not; see `WhisperCard`.
  List<WhisperMeta> pendingWhispersFor(int seat) {
    final all = _whisperGraph();
    return [
      for (final w in all.values)
        if (w.toSeat == seat && !w.delivered && !w.voided) w,
    ]..sort((a, b) => a.day.compareTo(b.day));
  }

  /// Whispers this player sent that will never arrive («الهمسة ماوصلتش»).
  List<WhisperMeta> voidedWhispersFrom(int seat) => [
    for (final w in _whisperGraph().values)
      if (w.fromSeat == seat && w.voided) w,
  ];

  /// Marks a whisper read. Idempotent.
  void markWhisperDelivered(String id) {
    final existing = _whisperGraph()[id];
    if (existing == null || existing.delivered || existing.voided) return;
    final now = clock();
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        WhisperDelivered(
          at: now,
          phaseRef: PhaseRef(phase: match.phase, number: match.dayNumber),
          id: id,
        ),
      ],
    );
    assertMatchInvariants(match, 'markWhisperDelivered');
  }

  /// Voids everything still in flight to a player who has just died (§3.4).
  ///
  /// Called from every path that kills somebody, which is why it takes the
  /// timestamp: the void belongs to the same instant as the death, not to
  /// whenever the UI next asks.
  void _voidWhispersTo(int seat, DateTime now) {
    final pending = pendingWhispersFor(seat);
    if (pending.isEmpty) return;
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        for (final w in pending)
          WhisperVoided(
            at: now,
            phaseRef: PhaseRef(phase: match.phase, number: match.dayNumber),
            id: w.id,
          ),
      ],
    );
  }

  Map<String, WhisperMeta> _whisperGraph() {
    final graph = <String, WhisperMeta>{};
    for (final e in match.eventLog) {
      switch (e) {
        case WhisperSent():
          graph[e.id] = WhisperMeta(
            id: e.id,
            day: e.phaseRef.number,
            fromSeat: e.fromSeat,
            toSeat: e.toSeat,
          );
        case WhisperDelivered():
          final existing = graph[e.id];
          if (existing != null) {
            graph[e.id] = existing.copyWith(delivered: true);
          }
        case WhisperVoided():
          final existing = graph[e.id];
          if (existing != null) graph[e.id] = existing.copyWith(voided: true);
        default:
          break;
      }
    }
    return graph;
  }

  /// Records how long [seat] held the floor today. Feeds `C6`.
  void recordSpeaking({required int seat, required int seconds}) {
    if (seconds <= 0) return;
    final now = clock();
    match = match.copyWith(
      eventLog: [
        ...match.eventLog,
        SpeakingRecorded(
          at: now,
          phaseRef: PhaseRef(
            phase: GamePhase.discussion,
            number: match.dayNumber,
          ),
          seat: seat,
          seconds: seconds,
        ),
      ],
    );
  }

  /// Get the public view of the match (no roles exposed).
  PublicMatchView publicView() {
    final publicPlayers = match.players
        .map((p) => PublicPlayer.from(p))
        .toList();

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
