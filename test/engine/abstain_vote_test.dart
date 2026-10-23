import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

void main() {
  MatchEngine openBallot({required bool abstainAllowed}) {
    final engine = MatchEngine(clock: Clocks.monotonic());
    engine.start(
      names: const ['A', 'B', 'C', 'D', 'E'],
      roleCounts: const {Role.mafia: 1, Role.citizen: 4},
      settings: MatchSettings(abstainAllowed: abstainAllowed),
      seed: 1,
    );
    while (engine.match.currentActorSeat != null) {
      engine.confirmRevealed();
    }
    engine.beginNight();
    while (engine.match.currentActorSeat != null) {
      engine.skipNightAction(seat: engine.match.currentActorSeat!);
    }
    engine.resolveNight();
    engine.beginDiscussion();
    engine.beginVoting();
    return engine;
  }

  test('null ballot is refused without recording when abstaining is off', () {
    final engine = openBallot(abstainAllowed: false);
    final before = engine.match;
    final seat = before.currentActorSeat!;

    expect(
      () => engine.submitVote(seat: seat, voterSeat: seat, targetSeat: null),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'submitVote: abstaining is off (RL9)',
      )),
    );
    expect(identical(engine.match, before), isTrue);
    expect(engine.match.eventLog.whereType<VoteCast>(), isEmpty);
  });

  test('null ballot is recorded when abstaining is on', () {
    final engine = openBallot(abstainAllowed: true);
    final seat = engine.match.currentActorSeat!;

    engine.submitVote(seat: seat, voterSeat: seat, targetSeat: null);

    final votes = engine.match.eventLog.whereType<VoteCast>().toList();
    expect(votes, hasLength(1));
    expect(votes.single.voterSeat, seat);
    expect(votes.single.targetSeat, isNull);
  });
}
