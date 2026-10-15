import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/narration_controller.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_table_screen.dart';

import '../support/localized.dart';

final _world = StoryWorld.decode(
  File('assets/stories_v2/qahwet_el_moallem.json').readAsStringSync(),
);

class _Silent implements NarrationPlayer {
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<Duration> get durations => const Stream.empty();
  @override
  Stream<void> get completions => const Stream.empty();
  @override
  Future<void> start(String assetKey) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// The browser's back asks an open table the same question as the app's
/// back, and a finished table lets it go.
void main() {
  testWidgets('the browser back asks before a table closes', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final guard = StoryExitGuard();
    expect(await guard.mayLeave(), isTrue, reason: 'nothing open');

    var exited = 0;
    final table = StoryTable.deal(
      world: _world,
      players: const ['أحمد', 'مريم', 'كريم'],
      seed: 4,
    );
    await tester.pumpWidget(
      localizedApp(
        StoryTableScreen(
          table: table,
          seed: 4,
          narration: NarrationController(_Silent(), web: false),
          onExit: () => exited++,
          onPlayAgain: () {},
          exitGuard: guard,
        ),
      ),
    );
    await tester.pumpAndSettle();

    var answer = guard.mayLeave();
    await tester.pumpAndSettle();
    expect(find.text(arStrings.sv2ExitTitle), findsOneWidget);
    await tester.tap(find.text(arStrings.sv2ExitNo));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
    expect(find.byType(StoryTableScreen), findsOneWidget);

    answer = guard.mayLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text(arStrings.sv2ExitYes));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
    expect(exited, 0, reason: 'the route closes it, not the table');

    await tester.pumpWidget(const SizedBox());
    expect(await guard.mayLeave(), isTrue, reason: 'a closed table frees it');
  });
}
