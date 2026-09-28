import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/host_handover.dart';

import '../support/localized.dart';

GameSnapshot room(GamePhase phase, int? host) => GameSnapshot(
  public: PublicMatchView(
    phase: phase,
    dayNumber: 1,
    players: [
      for (var seat = 0; seat < 5; seat++)
        PublicPlayer(seat: seat, name: 'لاعب$seat', status: PlayerStatus.alive),
    ],
  ),
  viewerSeat: 3,
  hostSeat: host,
);

/// Row 4: the public hand-off line «{name} بقى الهوست». Shown once for a new
/// host in every phase, never for the first host, and it leaves nothing.
void main() {
  Future<void> show(WidgetTester tester, GameSnapshot snapshot) =>
      tester.pumpWidget(localizedApp(Scaffold(body: HostHandover(snapshot: snapshot))));

  testWidgets('the first host is not announced', (tester) async {
    await show(tester, room(GamePhase.setup, 0));
    expect(find.textContaining('بقى الهوست'), findsNothing);
  });

  for (final phase in [
    GamePhase.setup,
    GamePhase.distributing,
    GamePhase.night,
    GamePhase.morning,
    GamePhase.openingRound,
    GamePhase.confrontation,
    GamePhase.discussion,
    GamePhase.voting,
    GamePhase.result,
  ]) {
    testWidgets('a hand-off in ${phase.name} names the new host, then clears', (
      tester,
    ) async {
      await show(tester, room(phase, 0));
      await show(tester, room(phase, 2));
      await tester.pump();
      expect(find.text('لاعب2 بقى الهوست'), findsOneWidget);
      await tester.pump(HostHandover.visible);
      await tester.pump();
      expect(find.textContaining('بقى الهوست'), findsNothing);
      // The same host again is not a second announcement.
      await show(tester, room(phase, 2));
      await tester.pump();
      expect(find.textContaining('بقى الهوست'), findsNothing);
    });
  }
}
