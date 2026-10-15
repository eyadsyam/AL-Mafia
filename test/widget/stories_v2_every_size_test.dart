import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/narration_controller.dart';
import 'package:mafia_master/stories/v2/session.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_table_screen.dart';

import '../support/localized.dart';

final _world = StoryWorld.decode(
  File('assets/stories_v2/qahwet_el_moallem.json').readAsStringSync(),
);

const _names = [
  'أحمد',
  'مريم',
  'كريم',
  'ياسمين',
  'عمر',
  'سارة',
  'علي',
  'منى',
  'حسن',
  'ليلى',
];

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

Future<void> _tap(WidgetTester tester, Key key) async {
  if (find.byKey(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _hold(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(StoryTableScreen.holdKey)),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// A whole table at every size, on the smallest and a large phone, through
/// the real screens: no overflow, every seat passed once, and the decision
/// asks exactly what the mode asks.
void main() {
  for (final size in const [Size(360, 640), Size(430, 932)]) {
    for (var players = 1; players <= 10; players++) {
      for (final seed in const [3, 8]) {
        testWidgets('${size.width.toInt()}w · $players players · seed $seed', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final table = StoryTable.deal(
            world: _world,
            players: players == 1 ? const [''] : _names.take(players).toList(),
            seed: seed,
          );
          StorySessionV2? finished;
          await tester.pumpWidget(
            localizedApp(
              StoryTableScreen(
                table: table,
                seed: seed,
                narration: NarrationController(_Silent(), web: false),
                onExit: () {},
                onPlayAgain: () {},
                onFinished: (s) => finished = s,
                watchAdForSearch: () async => true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          switch (table.mode) {
            case StoryTableMode.detective:
              await _tap(tester, StoryTableScreen.beginKey);
              for (final seat in table.seats) {
                expect(find.text(seat.player), findsWidgets);
                await _tap(tester, StoryTableScreen.openKey);
                await _hold(tester);
                expect(find.byKey(StoryTableScreen.secretKey), findsOneWidget);
                await _tap(tester, StoryTableScreen.hideKey);
              }
            case StoryTableMode.allSuspects:
              await _tap(tester, StoryTableScreen.beginKey);
              // No private page at 2–4: nothing to hold.
              expect(find.byKey(StoryTableScreen.holdKey), findsNothing);
              for (var i = 0; i < table.seats.length; i++) {
                await _tap(tester, StoryTableScreen.nextIntroKey);
              }
            case StoryTableMode.solo:
              break;
          }

          for (final place in _world.places.take(StoryTable.searches)) {
            await _tap(tester, StoryTableScreen.placeKey(place.id));
            await _tap(tester, StoryTableScreen.foundBackKey);
          }
          await _tap(tester, StoryTableScreen.decideKey);
          // The decision opens at its top, faces first, however far down the
          // desk was scrolled (it used to open scrolled past them).
          expect(
            find.byKey(StoryTableScreen.pickKey(table.suspectIds.first)),
            findsOneWidget,
          );
          expect(
            tester
                .getRect(
                  find.byKey(StoryTableScreen.pickKey(table.suspectIds.first)),
                )
                .top,
            greaterThanOrEqualTo(0),
          );
          await _tap(tester, StoryTableScreen.pickKey(table.culpritId));
          if (table.mode == StoryTableMode.solo) {
            final guilt = _world.suspect(table.culpritId).guilty;
            await _tap(tester, StoryTableScreen.motiveKey(guilt.motive.id));
            await _tap(tester, StoryTableScreen.methodKey(guilt.method.id));
          } else {
            expect(
              find.byKey(
                StoryTableScreen.motiveKey(
                  _world.suspect(table.culpritId).guilty.motive.id,
                ),
              ),
              findsNothing,
            );
          }
          await _tap(tester, StoryTableScreen.confirmKey);
          await _tap(tester, StoryTableScreen.resultKey);
          expect(finished?.solved, isTrue);
          expect(find.byKey(StoryTableScreen.againKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
