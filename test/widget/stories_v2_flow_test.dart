import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_catalog.dart';
import 'package:mafia_master/data/story_progress_store.dart';
import 'package:mafia_master/data/story_v2_memory.dart';
import 'package:mafia_master/data/story_world_catalog.dart';
import 'package:mafia_master/platform/narration_controller.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/v2/session.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/lamp_kit.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_about_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_lobby_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_table_screen.dart';

import '../support/localized.dart';

final _world = StoryWorld.decode(
  File('assets/stories_v2/qahwet_el_moallem.json').readAsStringSync(),
);
final _cafe = StoryDefinition.decode(
  File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
);

class _OneStory extends StoryCatalog {
  const _OneStory();

  @override
  Future<List<StoryDefinition>> load() async => [_cafe];
}

class _FakePlayer implements NarrationPlayer {
  final calls = <String>[];
  final _pos = StreamController<Duration>.broadcast(sync: true);
  final _dur = StreamController<Duration>.broadcast(sync: true);
  final _done = StreamController<void>.broadcast(sync: true);

  @override
  Stream<Duration> get positions => _pos.stream;
  @override
  Stream<Duration> get durations => _dur.stream;
  @override
  Stream<void> get completions => _done.stream;

  void length(Duration d) => _dur.add(d);

  @override
  Future<void> start(String assetKey) async => calls.add('start');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> seek(Duration to) async => calls.add('seek');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async {}
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  // Lists build lazily: scroll the screen's list until the target exists.
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
  // The tap lands after the press deadline; then the hold runs frame by frame.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _table(
  StoryTable table, {
  _FakePlayer? player,
  void Function()? again,
}) => localizedApp(
  StoryTableScreen(
    table: table,
    seed: 1,
    narration: NarrationController(player ?? _FakePlayer(), web: false),
    onExit: () {},
    onPlayAgain: again ?? () {},
    watchAdForSearch: () async => true,
  ),
);

List<String> _names(int n) => [
  for (final name in [
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
  ].take(n))
    name,
];

void main() {
  testWidgets(
    'first visit explains Stories, then the pilot opens its own file',
    (tester) async {
      _phone(tester);
      final player = _FakePlayer();
      await tester.pumpWidget(
        localizedApp(
          StoriesScreen(
            onBack: () {},
            catalog: const _OneStory(),
            progressStore: MemoryStoryProgressStore(),
            v2Memory: MemoryStoryV2Memory(),
            culpritHistory: MemoryStoryCulpritHistory(),
            narrationFactory: () => NarrationController(player, web: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoryAboutScreen), findsOneWidget);
      await _tap(tester, StoryAboutScreen.goKey);
      expect(find.byKey(StoriesHub.hubKey), findsOneWidget);
      await _tap(tester, StoriesHub.startKey(_cafe.id));
      expect(find.byType(StoryLobbyScreen), findsOneWidget);
      expect(find.text(_world.opening), findsOneWidget);
      await _tap(tester, StoryNarratorPlayer.playKey);
      expect(player.calls, contains('start'));
    },
  );

  testWidgets(
    'five friends: names, the how-to, one pass, the desk, a decision',
    (tester) async {
      _phone(tester);
      final memory = MemoryStoryV2Memory(about: true);
      List<String>? players;
      await tester.pumpWidget(
        localizedApp(
          StoryLobbyScreen(
            world: _world,
            coverImage: _cafe.coverImage,
            narration: NarrationController(_FakePlayer(), web: false),
            memory: memory,
            onExit: () {},
            onPlay: (p) async => players = p,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, StoryLobbyScreen.friendsKey);
      await _tap(tester, StoryLobbyScreen.countKey(5));
      await _tap(tester, StoryLobbyScreen.continueKey);
      expect(find.text(arStrings.sv2NamesEmpty), findsOneWidget);
      for (final (i, name) in _names(5).indexed) {
        await tester.enterText(find.byKey(StoryLobbyScreen.nameKey(i)), name);
      }
      await _tap(tester, StoryLobbyScreen.continueKey);
      // First time: the how-to cannot be skipped.
      expect(find.byKey(StoryLobbyScreen.skipKey), findsNothing);
      for (var i = 0; i < 5; i++) {
        await _tap(tester, StoryLobbyScreen.nextKey);
      }
      expect(players, _names(5));
      expect(memory.names, _names(5));
      expect(await memory.howToSeen(StoryTableMode.detective.name), isTrue);

      final table = StoryTable.deal(world: _world, players: players!, seed: 11);
      StorySessionV2? finished;
      await tester.pumpWidget(
        localizedApp(
          StoryTableScreen(
            table: table,
            seed: 11,
            narration: NarrationController(_FakePlayer(), web: false),
            onExit: () {},
            onPlayAgain: () {},
            onFinished: (s) => finished = s,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(arStrings.sv2CastTitle), findsOneWidget);
      await _tap(tester, StoryTableScreen.beginKey);
      for (final seat in table.seats) {
        expect(find.text(seat.player), findsWidgets);
        await _tap(tester, StoryTableScreen.openKey);
        await _hold(tester);
        expect(find.byKey(StoryTableScreen.secretKey), findsOneWidget);
        await _tap(tester, StoryTableScreen.hideKey);
      }
      for (final place in _world.places.take(3)) {
        await _tap(tester, StoryTableScreen.placeKey(place.id));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
      expect(find.text(arStrings.sv2SearchesLeft(0, 3)), findsOneWidget);
      await _tap(tester, StoryTableScreen.decideKey);
      // A group names who only: no why or how.
      expect(find.text(arStrings.sv2Why), findsNothing);
      await _tap(tester, StoryTableScreen.pickKey(table.culpritId));
      await _tap(tester, StoryTableScreen.confirmKey);
      await _tap(tester, StoryTableScreen.resultKey);
      expect(find.text(arStrings.sv2DetectiveWon), findsOneWidget);
      expect(finished?.solved, isTrue);
    },
  );

  testWidgets('every role sees the private line in the same box (Doc 05)', (
    tester,
  ) async {
    _phone(tester);
    final table = StoryTable.deal(world: _world, players: _names(7), seed: 3);
    await tester.pumpWidget(_table(table));
    await tester.pumpAndSettle();
    await _tap(tester, StoryTableScreen.beginKey);
    final boxes = <Rect>{};
    final buttons = <Rect>{};
    for (var i = 0; i < table.seats.length; i++) {
      await _tap(tester, StoryTableScreen.openKey);
      await _hold(tester);
      boxes.add(tester.getRect(find.byKey(StoryTableScreen.secretKey)));
      buttons.add(tester.getRect(find.byKey(StoryTableScreen.hideKey)));
      await _tap(tester, StoryTableScreen.hideKey);
    }
    expect(boxes, hasLength(1));
    expect(buttons, hasLength(1));
  });

  testWidgets('leaving the app on a private page covers it', (tester) async {
    _phone(tester);
    final table = StoryTable.deal(world: _world, players: _names(5), seed: 4);
    await tester.pumpWidget(_table(table));
    await tester.pumpAndSettle();
    await _tap(tester, StoryTableScreen.beginKey);
    await _tap(tester, StoryTableScreen.openKey);
    await _hold(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(StoryTableScreen.secretKey), findsNothing);
    expect(find.byKey(StoryTableScreen.openKey), findsOneWidget);
  });

  testWidgets('three friends meet the characters in public, no private pages', (
    tester,
  ) async {
    _phone(tester);
    final table = StoryTable.deal(world: _world, players: _names(3), seed: 6);
    await tester.pumpWidget(_table(table));
    await tester.pumpAndSettle();
    await _tap(tester, StoryTableScreen.beginKey);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(StoryTableScreen.holdKey), findsNothing);
      await _tap(tester, StoryTableScreen.nextIntroKey);
    }
    expect(find.text(arStrings.sv2Agree), findsOneWidget);
  });

  testWidgets('a search shows every line of the place and no blank paper', (
    tester,
  ) async {
    _phone(tester);
    final table = StoryTable.deal(world: _world, players: const [''], seed: 7);
    await tester.pumpWidget(_table(table));
    await tester.pumpAndSettle();
    // cafe_floor has no base trace of its own; coal_yard has one.
    expect(_world.place('cafe_floor').baseTrace, isEmpty);
    expect(_world.place('coal_yard').baseTrace, isNotEmpty);
    for (final id in ['cafe_floor', 'coal_yard']) {
      final before = find.byType(LampPaper).evaluate().length;
      await _tap(tester, StoryTableScreen.placeKey(id));
      final lines = table.tracesAt(id);
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(find.text(line), findsOneWidget, reason: id);
      }
      expect(
        find.byType(LampPaper).evaluate().length - before,
        lines.length,
        reason: '$id: one paper per line',
      );
      expect(find.text(''), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('solo: three searches, one bought with an ad, then who/why/how', (
    tester,
  ) async {
    _phone(tester);
    final table = StoryTable.deal(world: _world, players: const [''], seed: 7);
    await tester.pumpWidget(_table(table));
    await tester.pumpAndSettle();
    expect(find.byKey(StoryTableScreen.bonusKey), findsNothing);
    for (final place in _world.places.take(3)) {
      await _tap(tester, StoryTableScreen.placeKey(place.id));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
    await _tap(tester, StoryTableScreen.bonusKey);
    expect(find.text(arStrings.sv2SearchesLeft(1, 4)), findsOneWidget);
    await _tap(tester, StoryTableScreen.decideKey);
    await _tap(tester, StoryTableScreen.pickKey(table.culpritId));
    final confirm = find.byKey(StoryTableScreen.confirmKey);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(of: confirm, matching: find.byType(TextButton)),
          )
          .onPressed,
      isNull,
    );
    final guilt = _world.suspect(table.culpritId).guilty;
    await _tap(tester, StoryTableScreen.motiveKey(guilt.motive.id));
    await _tap(tester, StoryTableScreen.methodKey(guilt.method.id));
    await _tap(tester, StoryTableScreen.confirmKey);
    await _tap(tester, StoryTableScreen.resultKey);
    expect(find.text(arStrings.sv2SoloWon), findsOneWidget);
  });
}
