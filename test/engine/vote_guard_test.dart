import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

/// A ballot is cast only in the vote and only by the seat whose turn it is:
/// otherwise its weight (a revealed Elder counts three) and its name would land
/// on another seat's record.
void main() {
  MatchEngine started() {
    final e = MatchEngine(clock: Clocks.monotonic());
    e.start(
      names: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.citizen: 4},
      settings: const MatchSettings(),
      seed: 5,
    );
    for (var i = 0; i < 7; i++) {
      e.revealFor(i);
      e.confirmRevealed();
    }
    return e..beginNight();
  }

  /// Everybody points at one citizen, the Doctor covers them: nobody dies.
  void quietNight(MatchEngine e) {
    final covered = e.match.players.firstWhere((p) => p.role == Role.citizen);
    final other = e.match.players.firstWhere(
      (p) => p.role == Role.citizen && p.seat != covered.seat,
    );
    while (e.match.currentActorSeat != null) {
      final seat = e.match.currentActorSeat!;
      final role = e.match.players[seat].role;
      e.submitNightAction(
        seat: seat,
        kind: switch (role) {
          Role.mafia => NightActionKind.mafiaVote,
          Role.doctor => NightActionKind.protect,
          _ => NightActionKind.suspect,
        },
        targetSeat: seat == covered.seat ? other.seat : covered.seat,
      );
    }
    e.resolveNight();
  }

  test('no ballot outside the vote', () {
    final e = started();
    final seat = e.match.currentActorSeat!;
    expect(
      () =>
          e.submitVote(seat: seat, voterSeat: seat, targetSeat: (seat + 1) % 7),
      throwsStateError,
    );
    expect(e.match.eventLog.whereType<VoteCast>(), isEmpty);
  });

  test('a ballot cannot be filed under another seat', () {
    final e = started();
    quietNight(e);
    e.beginDiscussion();
    e.beginVoting();
    final seat = e.match.currentActorSeat!;
    final other = e.match.players
        .firstWhere((p) => p.seat != seat && p.status == PlayerStatus.alive)
        .seat;
    expect(
      () => e.submitVote(seat: seat, voterSeat: other, targetSeat: null),
      throwsArgumentError,
    );
    expect(e.match.eventLog.whereType<VoteCast>(), isEmpty);
    e.submitVote(seat: seat, voterSeat: seat, targetSeat: other);
    expect(e.match.eventLog.whereType<VoteCast>().single.voterSeat, seat);
  });
}
