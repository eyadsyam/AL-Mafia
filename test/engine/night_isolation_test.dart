import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

/// Each night is resolved from *that night's* actions and no others.
///
/// # The bug this exists to prevent
///
/// `NightResolver` scanned the whole event log for `MafiaVoteCast` and
/// `ProtectCast`. The log is the entire match, so on night two it was still
/// counting night one's votes and honouring night one's protections.
///
/// What a table saw: the same player reported dead every single morning — their
/// vote from the first night either won outright again or forced a tie that the
/// seeded tie-break resolved the same way every time. And once a few nights had
/// passed, every living seat had been protected at some point, so nobody could
/// die at all and the game could not end.
///
/// Neither symptom looks like a scoping bug from the outside, which is why this
/// is asserted at the engine rather than left to the integration test.
void main() {
  /// A five-player match with one mafia, one doctor, one detective.
  ///
  /// Seats are assigned explicitly via the seed rather than searched for, and
  /// the helpers below locate each role by reading the dealt hand — the deal is
  /// random now, so a test that assumed seat 0 was the mafia would pass or fail
  /// by luck.
  MatchEngine freshMatch() {
    final engine = MatchEngine();
    engine.start(
      names: const ['A', 'B', 'C', 'D', 'E'],
      roleCounts: const {
        Role.mafia: 1,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 2,
      },
      settings: const MatchSettings(),
      seed: 4242,
    );
    return engine;
  }

  int seatOf(MatchEngine engine, Role role) =>
      engine.match.players.firstWhere((p) => p.role == role).seat;

  /// Walks distribution to its end so the night can open.
  void distribute(MatchEngine engine) {
    while (engine.match.currentActorSeat != null) {
      engine.revealFor(engine.match.currentActorSeat!);
      engine.confirmRevealed();
    }
  }

  /// Runs one night, with each living actor taking [target] where the role has
  /// a choice. Returns the morning report.
  ({int? victimSeat, bool saved}) playNight(
    MatchEngine engine, {
    required int mafiaTarget,
    required int doctorTarget,
  }) {
    engine.beginNight();
    while (engine.match.phase == GamePhase.night) {
      final seat = engine.match.currentActorSeat;
      if (seat == null) break;
      final role = engine.match.players[seat].role;
      final target = switch (role) {
        Role.mafia => mafiaTarget,
        Role.doctor => doctorTarget,
        // Anyone will do; the investigation does not affect the resolution.
        Role.detective || Role.citizen => _firstOther(engine, seat),
      };
      engine.submitNightAction(
        seat: seat,
        kind: switch (role) {
          Role.mafia => NightActionKind.mafiaVote,
          Role.doctor => NightActionKind.protect,
          Role.detective => NightActionKind.investigate,
          Role.citizen => NightActionKind.suspect,
        },
        targetSeat: target,
      );
    }
    final report = engine.resolveNight();
    return (victimSeat: report.victimSeat, saved: report.someoneSavedUnnamed);
  }

  /// Advances from morning back to the next night's lobby without eliminating
  /// anyone, so the test controls exactly who dies and when.
  void skipDayWithoutElimination(MatchEngine engine) {
    engine.beginDiscussion();
    engine.beginVoting();
    // Everyone abstains, so the ballot cannot remove a second player and
    // confuse the night-to-night comparison below.
    while (engine.match.phase == GamePhase.voting) {
      final seat = engine.match.currentActorSeat;
      if (seat == null) break;
      engine.submitVote(seat: seat, voterSeat: seat, targetSeat: null);
    }
    engine.resolveDayVote();
    engine.winCheck();
  }

  group('a night sees only its own actions', () {
    test('the second night kills the second night\'s target', () {
      final engine = freshMatch();
      distribute(engine);

      final mafia = seatOf(engine, Role.mafia);
      final doctor = seatOf(engine, Role.doctor);
      final victims = engine.match.players
          .where((p) => p.seat != mafia && p.seat != doctor)
          .map((p) => p.seat)
          .toList();
      final firstVictim = victims[0];
      final secondVictim = victims[1];

      // The doctor covers themselves and then the mafia — anyone but the two
      // targets, and never the same seat twice running, which the engine
      // forbids outright.
      final night1 = playNight(engine,
          mafiaTarget: firstVictim, doctorTarget: doctor);
      expect(night1.victimSeat, equals(firstVictim));

      skipDayWithoutElimination(engine);

      final night2 = playNight(engine,
          mafiaTarget: secondVictim, doctorTarget: mafia);
      expect(
        night2.victimSeat,
        equals(secondVictim),
        reason: 'night two reported seat ${night2.victimSeat} dead when the '
            'mafia voted for seat $secondVictim. If it reported $firstVictim, '
            'the resolver is still counting the first night\'s votes and every '
            'morning will name the same person.',
      );
    });

    test('a protection does not carry over to later nights', () {
      final engine = freshMatch();
      distribute(engine);

      final mafia = seatOf(engine, Role.mafia);
      final doctor = seatOf(engine, Role.doctor);
      final target = engine.match.players
          .firstWhere((p) => p.seat != mafia && p.seat != doctor)
          .seat;

      // Night one: the doctor covers the target, who survives.
      final night1 =
          playNight(engine, mafiaTarget: target, doctorTarget: target);
      expect(night1.victimSeat, isNull);
      expect(night1.saved, isTrue);

      skipDayWithoutElimination(engine);

      // Night two: the doctor covers somebody else. The same target must now
      // die — a protection that persisted would make them permanently immortal.
      final night2 =
          playNight(engine, mafiaTarget: target, doctorTarget: mafia);
      expect(
        night2.victimSeat,
        equals(target),
        reason: 'seat $target survived a second night with no protection on '
            'them, so last night\'s protect is still in force. Left alone, '
            'every seat eventually becomes unkillable and the match cannot end.',
      );
    });
  });

  group('the deal is random', () {
    test('two matches with the same names deal different hands', () {
      // Not a statistical claim — just that the default is not a constant. The
      // seed used to default to 12345, so seat 0 drew the same role in every
      // match ever played on every device.
      List<Role> deal() {
        final engine = MatchEngine();
        engine.start(
          names: const ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
          roleCounts: const {
            Role.mafia: 2,
            Role.doctor: 1,
            Role.detective: 1,
            Role.citizen: 4,
          },
          settings: const MatchSettings(),
        );
        return engine.match.players.map((p) => p.role).toList();
      }

      // Eight seats with this distribution have 420 arrangements, so twelve
      // identical deals in a row is a fixed seed rather than bad luck.
      final deals = <String>{for (var i = 0; i < 12; i++) deal().join(',')};
      expect(deals.length, greaterThan(1),
          reason: 'twelve matches dealt the identical hand, so the shuffle is '
              'running off a constant seed');
    });

    test('an explicit seed is still reproducible', () {
      // Determinism has to survive, or a stored match cannot be resumed and the
      // rest of the suite cannot rely on a fixed hand.
      List<Role> deal() {
        final engine = MatchEngine();
        engine.start(
          names: const ['A', 'B', 'C', 'D', 'E'],
          roleCounts: const {
            Role.mafia: 1,
            Role.doctor: 1,
            Role.detective: 1,
            Role.citizen: 2,
          },
          settings: const MatchSettings(),
          seed: 99,
        );
        return engine.match.players.map((p) => p.role).toList();
      }

      expect(deal(), equals(deal()));
    });
  });
}

int _firstOther(MatchEngine engine, int seat) => engine.match.players
    .firstWhere((p) => p.seat != seat && p.status == PlayerStatus.alive)
    .seat;
