import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';

import '../support/fuzz_driver.dart';

void main() {
  test('complete pass-and-play matches with optional roles retain legal exits '
      'and reach a winner', () {
    final dealt = <Role>{};
    final phases = <GamePhase>{};
    final winners = <Alignment>{};
    final tieRules = <DayTieRule>{};
    final discussionModes = <DiscussionMode>{};
    for (var seed = 0; seed < 500; seed++) {
      final run = runFuzzedMatch(
        seed,
        boughtRoles: true,
        onState: (match) => phases.add(match.phase),
      );
      expect(run.ok, isTrue, reason: run.toString());
      expect(run.finished?.phase, GamePhase.result);
      dealt.addAll(run.finished!.players.map((p) => p.role));
      winners.add(run.finished!.outcome!.winner);
      tieRules.add(run.finished!.settings.dayTieRule);
      discussionModes.add(run.finished!.settings.discussionMode);
    }
    expect(dealt, containsAll(Role.values));
    expect(phases, containsAll([
      GamePhase.distributing,
      GamePhase.night,
      GamePhase.morning,
      GamePhase.voting,
      GamePhase.reveal,
    ]));
    expect(winners, containsAll(Alignment.values));
    expect(tieRules, containsAll(DayTieRule.values));
    expect(discussionModes, containsAll(DiscussionMode.values));
  });
}
