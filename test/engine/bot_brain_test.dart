import 'package:mafia_master/engine/bots/bot_brain.dart';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/engine/presets.dart';
import 'package:test/test.dart';

/// Plays a whole match where every seat is a bot; the table's own steps
/// (begin night, resolve, open the vote …) take the first legal move.
MatchOutcome playOut(MatchPreset preset, int players, int seed) {
  final engine = MatchEngine(clock: Clocks.monotonic());
  engine.start(
    names: [for (var i = 0; i < players; i++) 'P$i'],
    roleCounts: preset.roleCounts(players),
    settings: preset.settings,
    seed: seed,
  );
  final brain = BotBrain(
    match: engine.match,
    botSeats: {for (var i = 0; i < players; i++) i},
    seed: seed,
  );
  var moves = 0;
  while (!isTerminal(engine.match)) {
    if (++moves > 5000) fail('no end: ${preset.name} @ $players seed $seed');
    if (brain.controls(engine.match)) {
      final move = brain.choose(engine.match);
      if (move is NightActionMove) {
        final r = engine.submitNightAction(
          seat: move.seat,
          kind: move.kind,
          targetSeat: move.targetSeat,
          useBullet: move.useBullet,
        );
        if (r is InvestigateResult) brain.observe(move.seat, r);
      } else {
        move.apply(engine);
      }
      continue;
    }
    final options = legalMoves(engine.match);
    final table = options.firstWhere(
      (m) => m is! SendWhisperMove,
      orElse: () => options.first,
    );
    table.apply(engine);
  }
  return engine.match.outcome!;
}

void main() {
  test('bots finish every preset at every table size', () {
    for (final preset in MatchPreset.values) {
      for (var n = 5; n <= 12; n++) {
        for (var seed = 1; seed <= 6; seed++) {
          expect(playOut(preset, n, seed).winner, isNotNull);
        }
      }
    }
  });

  test('both sides win sometimes', () {
    var mafia = 0;
    var town = 0;
    for (var seed = 1; seed <= 120; seed++) {
      final w = playOut(MatchPreset.classic, 8, seed).winner;
      if (w == Alignment.mafia) {
        mafia++;
      } else {
        town++;
      }
    }
    expect(mafia, greaterThan(10));
    expect(town, greaterThan(10));
  });
}
