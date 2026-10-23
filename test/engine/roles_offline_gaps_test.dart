import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/engine/presets.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:test/test.dart';

void main() {
  const plain = MatchSettings(
    quietNightEnabled: false,
    traceEnabled: false,
    confrontationEnabled: false,
    abstainAllowed: true,
  );
  final withSilencer = plain.copyWith(silencerEnabled: true);

  MatchEngine start(Map<Role, int> counts, MatchSettings settings, {int seed = 3}) {
    final n = counts.values.fold<int>(0, (sum, count) => sum + count);
    final e = MatchEngine(clock: Clocks.monotonic());
    e.start(names: [for (var i = 0; i < n; i++) 'P$i'],
        roleCounts: counts, settings: settings, seed: seed);
    for (var i = 0; i < n; i++) {
      e.revealFor(i);
      e.confirmRevealed();
    }
    return e;
  }

  List<int> seats(MatchEngine e, Role role) => [
    for (final p in e.match.players) if (p.role == role) p.seat,
  ];
  int seat(MatchEngine e, Role role) => seats(e, role).first;

  void night(MatchEngine e,
      (NightActionKind, int, bool)? Function(int, Role) choice) {
    e.beginNight();
    while (e.match.currentActorSeat != null) {
      final actor = e.match.currentActorSeat!;
      final role = e.match.players[actor].role;
      final move = choice(actor, role);
      if (move != null) {
        e.submitNightAction(seat: actor, kind: move.$1,
            targetSeat: move.$2, useBullet: move.$3);
      } else if (role == Role.doctor) {
        final target = e.match.players.firstWhere((p) =>
            p.status == PlayerStatus.alive && p.seat != actor).seat;
        e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: target);
      } else {
        e.skipNightAction(seat: actor);
      }
    }
  }

  void voting(MatchEngine e) {
    e.beginDay();
    while (e.match.phase == GamePhase.openingRound) {
      final actor = e.match.currentActorSeat!;
      final target = e.match.players.firstWhere((p) =>
          p.status == PlayerStatus.alive && p.seat != actor).seat;
      e.submitOpeningAccusation(seat: actor, targetSeat: target);
    }
    if (e.match.phase == GamePhase.confrontation) e.endConfrontation();
    e.beginVoting();
  }

  void ballot(MatchEngine e, int? target) {
    while (e.match.phase == GamePhase.voting) {
      final actor = e.match.currentActorSeat!;
      if (e.silencedSeatToday == actor) {
        e.skipSilencedVote(actor);
      } else {
        e.submitVote(seat: actor, voterSeat: actor,
            targetSeat: actor == target ? null : target);
      }
    }
  }

  void nextNight(MatchEngine e) {
    voting(e);
    ballot(e, null);
    e.resolveDayVote();
    expect(e.winCheck(), isNull);
  }

  test('M2-15: idle Mafia has explicit skip and seeded fallback', () {
    final counts = {Role.mafia: 1, Role.citizen: 4};
    final a = start(counts, plain);
    final b = start(counts, plain);
    a.beginNight();
    b.beginNight();
    final mafia = seat(a, Role.mafia);
    while (a.match.currentActorSeat != mafia) {
      a.skipNightAction(seat: a.match.currentActorSeat!);
      b.skipNightAction(seat: b.match.currentActorSeat!);
    }
    expect(legalMoves(a.match).whereType<SkipNightActionMove>(), isNotEmpty);
    final x = defaultMoveOnExpiry(a.match, phaseIndex: 17);
    final y = defaultMoveOnExpiry(b.match, phaseIndex: 17);
    expect(x.runtimeType, y.runtimeType);
    expect(x.toString(), y.toString());
    a.skipNightAction(seat: mafia);
    expect(a.match.eventLog.whereType<NightActionSkipped>()
        .any((event) => event.actorSeat == mafia), isTrue);
  });

  test('M2-27: inherited kill rejects self and Mafia team', () {
    final e = start({Role.mafia: 1, Role.silencer: 1, Role.citizen: 5},
        withSilencer);
    final mafia = seat(e, Role.mafia), silencer = seat(e, Role.silencer);
    e.removePlayer(mafia);
    e.beginNight();
    while (e.match.currentActorSeat != silencer) {
      e.skipNightAction(seat: e.match.currentActorSeat!);
    }
    expect(legalMoves(e.match).whereType<NightActionMove>()
        .every((move) => move.targetSeat != mafia &&
            move.targetSeat != silencer), isTrue);
    expect(() => e.submitNightAction(seat: silencer,
        kind: NightActionKind.silence, targetSeat: silencer), throwsStateError);
    expect(() => e.submitNightAction(seat: silencer,
        kind: NightActionKind.silence, targetSeat: mafia), throwsStateError);
  });

  test('M2-29: Silencer acts once each night without spending a bullet', () {
    final e = start({Role.mafia: 1, Role.silencer: 1, Role.citizen: 5},
        withSilencer);
    final target = seat(e, Role.citizen);
    for (var day = 0; day < 2; day++) {
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, target, false) : null);
      expect(e.resolveNight().silencedSeat, target);
      if (day == 0) nextNight(e);
    }
    expect(e.match.eventLog.whereType<SilenceCast>(), hasLength(2));
    expect(e.match.eventLog.whereType<BulletSpent>(), isEmpty);
  });

  test('M2-33: morning names silenced seat and parity counts Silencer', () {
    final e = start({Role.mafia: 1, Role.silencer: 1, Role.citizen: 3},
        withSilencer);
    final target = seat(e, Role.citizen);
    night(e, (_, role) => role == Role.silencer
        ? (NightActionKind.silence, target, false) : null);
    expect(e.resolveNight().silencedSeat, target);
    expect(e.silencedSeatToday, target);
    e.removePlayer(target);
    expect(e.match.outcome?.winner, Alignment.mafia);
  });

  test('M2-37: vote reveals Silencer and remaining Silencer counts for parity', () {
    final counts = {Role.mafia: 1, Role.silencer: 1, Role.citizen: 3};
    final e = start(counts, withSilencer);
    final citizen = seat(e, Role.citizen);
    night(e, (_, _) => null);
    e.resolveNight();
    voting(e);
    ballot(e, citizen);
    final result = e.resolveDayVote();
    expect(result.eliminatedRole, Role.citizen);
    expect(e.winCheck(), Alignment.mafia);

    final other = start(counts, withSilencer);
    final silencer = seat(other, Role.silencer);
    night(other, (_, _) => null);
    other.resolveNight();
    voting(other);
    ballot(other, silencer);
    expect(other.resolveDayVote().eliminatedRole, Role.silencer);
  });

  test('M2-53: Doctor vote death is public and changes living-town parity', () {
    final e = start({Role.mafia: 2, Role.doctor: 1, Role.citizen: 2}, plain);
    final doctor = seat(e, Role.doctor);
    night(e, (_, _) => null);
    e.resolveNight();
    voting(e);
    ballot(e, doctor);
    final result = e.resolveDayVote();
    expect(result.eliminatedSeat, doctor);
    expect(result.eliminatedRole, Role.doctor);
    expect(e.winCheck(), Alignment.mafia);
  });

  test('M2-59: investigation returns exact role despite protection and silence', () {
    final e = start({Role.mafia: 1, Role.silencer: 1, Role.doctor: 1,
      Role.detective: 1, Role.citizen: 3}, withSilencer);
    final target = seat(e, Role.citizen);
    Role? answer;
    e.beginNight();
    while (e.match.currentActorSeat != null) {
      final actor = e.match.currentActorSeat!;
      final role = e.match.players[actor].role;
      if (role == Role.silencer) {
        e.submitNightAction(seat: actor, kind: NightActionKind.silence,
            targetSeat: target);
      } else if (role == Role.doctor) {
        e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: target);
      } else if (role == Role.detective) {
        answer = e.submitNightAction(seat: actor,
            kind: NightActionKind.investigate,
            targetSeat: target)?.revealedRole;
      } else {
        e.skipNightAction(seat: actor);
      }
    }
    expect(answer, Role.citizen);
    expect(e.resolveNight().silencedSeat, target);
  });

  test('M2-63: Detective skip records no investigation', () {
    final e = start({Role.mafia: 1, Role.detective: 1, Role.citizen: 3},
        plain);
    final detective = seat(e, Role.detective);
    night(e, (_, _) => null);
    expect(e.match.eventLog.whereType<NightActionSkipped>()
        .any((event) => event.actorSeat == detective), isTrue);
    expect(e.match.eventLog.whereType<InvestigateCast>(), isEmpty);
  });

  test('M2-77: Elder can skip and remains a town body for parity', () {
    final e = start({Role.mafia: 1, Role.elder: 1, Role.citizen: 4},
        plain.copyWith(elderEnabled: true));
    final elder = seat(e, Role.elder);
    night(e, (_, _) => null);
    expect(e.match.eventLog.whereType<NightActionSkipped>()
        .any((event) => event.actorSeat == elder), isTrue);
    final citizens = seats(e, Role.citizen);
    for (final x in citizens.take(3)) {
      e.removePlayer(x);
    }
    expect(e.match.outcome, isNull);
    e.removePlayer(citizens.last);
    expect(e.match.outcome?.winner, Alignment.mafia);
  });

  test('M2-93: Citizen suspects or skips without bullet and counts as town', () {
    final e = start({Role.mafia: 1, Role.citizen: 4}, plain);
    final citizens = seats(e, Role.citizen);
    night(e, (actor, role) => actor == citizens.first
        ? (NightActionKind.suspect, seat(e, Role.mafia), false) : null);
    expect(e.match.eventLog.whereType<SuspectCast>()
        .any((event) => event.actorSeat == citizens.first), isTrue);
    expect(e.match.eventLog.whereType<NightActionSkipped>()
        .any((event) => event.actorSeat == citizens.last), isTrue);
    expect(e.match.eventLog.whereType<BulletSpent>(), isEmpty);
    for (final x in citizens.take(3)) {
      e.removePlayer(x);
    }
    expect(e.match.outcome?.winner, Alignment.mafia);
  });

  test('M2-95: recorded Citizen suspicion produces an eligible fact', () {
    final e = start({Role.mafia: 1, Role.citizen: 4},
        plain.copyWith(traceEnabled: true));
    final citizen = seat(e, Role.citizen);
    final mafia = seat(e, Role.mafia);
    night(e, (actor, role) => role == Role.mafia
        ? (NightActionKind.mafiaVote, citizen, false)
        : actor == citizen
            ? (NightActionKind.suspect, mafia, false) : null);
    expect(e.resolveNight().victimSeats, [citizen]);
    expect(e.currentTrace?.type, TraceType.t1);
    expect(e.currentTrace?.subjectSeat, citizen);
    expect(e.currentTrace?.targetSeat, mafia);
  });

  test('M2-99: silenced Citizen cannot ballot, remains vote target, death changes parity', () {
    final e = start({Role.mafia: 1, Role.silencer: 1, Role.citizen: 3},
        withSilencer);
    final citizen = seat(e, Role.citizen);
    night(e, (_, role) => role == Role.silencer
        ? (NightActionKind.silence, citizen, false) : null);
    e.resolveNight();
    voting(e);
    while (e.match.currentActorSeat != citizen) {
      final actor = e.match.currentActorSeat!;
      e.submitVote(seat: actor, voterSeat: actor, targetSeat: citizen);
    }
    expect(() => e.submitVote(seat: citizen, voterSeat: citizen,
        targetSeat: null), throwsStateError);
    e.skipSilencedVote(citizen);
    while (e.match.phase == GamePhase.voting) {
      final actor = e.match.currentActorSeat!;
      e.submitVote(seat: actor, voterSeat: actor, targetSeat: citizen);
    }
    expect(e.resolveDayVote().eliminatedSeat, citizen);
    expect(e.winCheck(), Alignment.mafia);
  });

  test('M2-107: optional role thresholds and seat replacements', () {
    expect(OptionalRole.silencer.blockedBy(
        players: 5, mafia: 1, citizens: 2), 'silencer_needs_two_mafia');
    expect(OptionalRole.elder.blockedBy(
        players: 5, mafia: 1, citizens: 2), 'elder_min_players');
    expect(OptionalRole.sniper.blockedBy(
        players: 6, mafia: 2, citizens: 2), 'sniper_min_players');
    final base = {Role.mafia: 2, Role.doctor: 1,
      Role.detective: 1, Role.citizen: 4};
    final applied = OptionalRole.apply(base, OptionalRole.values.toSet());
    expect(applied[Role.mafia], 1);
    expect(applied[Role.silencer], 1);
    expect(applied[Role.elder], 1);
    expect(applied[Role.sniper], 1);
    expect(applied[Role.citizen], 2);
    expect(applied.values.fold<int>(0, (sum, n) => sum + n), 8);
  });

  test('M2-109: balance guard rejects multiple Elder and Sniper', () {
    for (final counts in [
      {Role.mafia: 1, Role.elder: 2, Role.citizen: 4},
      {Role.mafia: 1, Role.sniper: 2, Role.citizen: 4},
    ]) {
      expect(BalanceGuard.evaluate(playerCount: 7,
          roleCounts: counts).valid, isFalse);
    }
  });

  test('M2-107: each threshold table size itself is accepted', () {
    expect(OptionalRole.silencer.blockedBy(
        players: 5, mafia: 2, citizens: 2), isNull);
    expect(OptionalRole.elder.blockedBy(
        players: 6, mafia: 1, citizens: 3), isNull);
    expect(OptionalRole.sniper.blockedBy(
        players: 7, mafia: 1, citizens: 4), isNull);
  });

  test('M2-109: guard names every duplicate and a half-table Mafia; engine start refuses the ones it owns', () {
    List<String> codes(int players, Map<Role, int> counts) => [
      for (final issue in BalanceGuard.evaluate(
          playerCount: players, roleCounts: counts).issues)
        if (issue.blocking) issue.code,
    ];
    expect(codes(7, {Role.mafia: 1, Role.detective: 2, Role.citizen: 4}),
        contains('one_detective_only'));
    expect(codes(7, {Role.mafia: 1, Role.silencer: 2, Role.citizen: 4}),
        contains('one_silencer_only'));
    expect(codes(7, {Role.mafia: 1, Role.elder: 2, Role.citizen: 4}),
        contains('one_elder_only'));
    expect(codes(7, {Role.mafia: 1, Role.sniper: 2, Role.citizen: 4}),
        contains('one_sniper_only'));
    expect(codes(6, {Role.mafia: 3, Role.citizen: 3}),
        contains('mafia_too_many'));
    expect(BalanceGuard.evaluate(playerCount: 5,
        roleCounts: {Role.mafia: 2, Role.citizen: 3}).valid, isTrue);

    void refused(Map<Role, int> counts, MatchSettings settings) {
      expect(() => MatchEngine(clock: Clocks.monotonic()).start(
          names: [for (var i = 0; i < 7; i++) 'P$i'],
          roleCounts: counts, settings: settings, seed: 1),
          throwsArgumentError);
    }
    refused({Role.mafia: 1, Role.silencer: 2, Role.citizen: 4}, withSilencer);
    refused({Role.mafia: 1, Role.elder: 2, Role.citizen: 4},
        plain.copyWith(elderEnabled: true));
    refused({Role.mafia: 1, Role.sniper: 2, Role.citizen: 4},
        plain.copyWith(sniperEnabled: true));
    refused({Role.mafia: 4, Role.citizen: 3}, plain);
  });

  test('M2-111: same seed deals identically and private team view excludes town', () {
    final counts = {Role.mafia: 1, Role.silencer: 1, Role.citizen: 5};
    final a = MatchEngine(clock: Clocks.monotonic());
    final b = MatchEngine(clock: Clocks.monotonic());
    final names = [for (var i = 0; i < 7; i++) 'P$i'];
    for (final e in [a, b]) {
      e.start(names: names, roleCounts: counts, settings: withSilencer, seed: 91);
    }
    expect(a.match.players.map((p) => p.role).toList(),
        b.match.players.map((p) => p.role).toList());
    for (var i = 0; i < 7; i++) {
      final view = a.revealFor(i);
      final team = a.match.players.where((p) =>
          p.role.alignment == Alignment.mafia && p.seat != i)
          .map((p) => p.name).toList();
      if (view.role.alignment == Alignment.mafia) {
        expect(view.teammateNames, team);
      } else {
        expect(view.teammateNames, isEmpty);
      }
      a.confirmRevealed();
    }
    expect(() => MatchEngine(clock: Clocks.monotonic()).start(
        names: names, roleCounts: {Role.mafia: 1, Role.citizen: 5},
        settings: plain, seed: 91), throwsArgumentError);
  });

  test('M2-115: twenty-player match plays through to either outcome', () {
    const counts = {Role.mafia: 5, Role.citizen: 15};
    expect(MatchPreset.classic.roleCounts(20)[Role.mafia], 3);
    expect(BalanceGuard.evaluate(playerCount: 20, roleCounts: counts).valid,
        isTrue);
    for (final winner in Alignment.values) {
      final e = start(counts, plain);
      while (e.match.outcome == null) {
        night(e, (_, _) => null);
        e.resolveNight();
        voting(e);
        final target = e.match.players.firstWhere((p) =>
            p.status == PlayerStatus.alive &&
            p.role.alignment != winner).seat;
        ballot(e, target);
        expect(e.resolveDayVote().eliminatedSeat, target);
        e.winCheck();
      }
      expect(e.match.outcome?.winner, winner);
    }
  });
}
