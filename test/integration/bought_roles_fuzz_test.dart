import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

import '../support/fuzz_driver.dart';

/// The store roles inside whole matches (owner, 2026-10-29: «كل حاجه تكون
/// شغالة صح … بكل حالاتها»).
///
/// The plain fuzz harness deals only Mafia, Doctor, Detective and Citizen, so
/// ten thousand matches never put a Silencer, an Elder or a Sniper on the
/// table. This run deals them at random, lets the Elder reveal at a random
/// moment of the day, and holds every match to the same four invariants and
/// the same stall guard — then checks the roles were really exercised.
void main() {
  test('5,000 matches with the store roles terminate cleanly', () {
    const runs = 5000;
    final failures = <FuzzOutcome>[];
    var silenced = 0;
    var revealed = 0;
    var revealedThenVoted = 0;
    var sniperDealt = 0;
    var mafiaWins = 0;
    var townWins = 0;

    for (var seed = 0; seed < runs; seed++) {
      final outcome = runFuzzedMatch(seed, boughtRoles: true);
      if (!outcome.ok) {
        failures.add(
          runFuzzedMatch(seed, boughtRoles: true, recordTrail: true),
        );
        if (failures.length >= 5) break;
        continue;
      }
      final match = outcome.finished!;
      final log = match.eventLog;
      if (log.whereType<SilenceCast>().isNotEmpty) silenced++;
      final reveal = log.whereType<ElderRevealed>().firstOrNull;
      if (reveal != null) {
        revealed++;
        final at = log.indexOf(reveal);
        if (log
            .skip(at)
            .whereType<VoteCast>()
            .any((v) => v.voterSeat == reveal.seat)) {
          revealedThenVoted++;
        }
      }
      if (match.players.any((p) => p.role == Role.sniper)) sniperDealt++;
      switch (match.outcome!.winner) {
        case Alignment.mafia:
          mafiaWins++;
        case Alignment.town:
          townWins++;
      }
    }

    expect(
      failures,
      isEmpty,
      reason: 'a store role can break a match:\n\n${failures.join('\n\n')}',
    );
    // Guards against a run that "passes" because no store role ever played.
    expect(silenced, greaterThan(runs ~/ 20), reason: 'silences cast');
    expect(revealed, greaterThan(runs ~/ 20), reason: 'elder reveals');
    expect(revealedThenVoted, greaterThan(0), reason: 'revealed elder voted');
    expect(sniperDealt, greaterThan(runs ~/ 10), reason: 'snipers dealt');
    expect(mafiaWins, greaterThan(0));
    expect(townWins, greaterThan(0));
  });

  test('the same seed replays the same match with the store roles', () {
    for (final seed in [3, 77, 1024]) {
      final a = runFuzzedMatch(seed, boughtRoles: true);
      final b = runFuzzedMatch(seed, boughtRoles: true);
      expect(a.moveCount, b.moveCount);
      expect(a.finished!.eventLog.length, b.finished!.eventLog.length);
      expect(a.finished!.outcome, b.finished!.outcome);
    }
  });
}
