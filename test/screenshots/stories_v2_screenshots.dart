/// Renders the Stories V2 pilot screens, for the owner to look at.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/stories_v2_screenshots.dart
///
/// Writes to `build/screens_stories_v2/`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_v2_memory.dart';
import 'package:mafia_master/platform/narration_controller.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_about_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_lobby_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_table_screen.dart';

import '../support/localized.dart';

const _phone = Size(412, 915);

final _world = StoryWorld.decode(
  File('assets/stories_v2/qahwet_el_moallem.json').readAsStringSync(),
);
final _cafe = StoryDefinition.decode(
  File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
);
const _names = ['أحمد', 'مريم', 'كريم', 'ياسمين', 'عمر'];

class _Silent implements NarrationPlayer {
  final _d = StreamController<Duration>.broadcast();
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<Duration> get durations => _d.stream;
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

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Aref Ruqaa': 'assets/fonts/ArefRuqaa-Bold.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final out = Directory('build/screens_stories_v2')
    ..createSync(recursive: true);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> start(WidgetTester tester, Widget child) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(child: localizedApp(child)),
      ),
    );
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  Future<void> hold(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(StoryTableScreen.holdKey)),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await settle(tester);
  }

  NarrationController narration() => NarrationController(_Silent(), web: false);

  testWidgets('about', (tester) async {
    await start(tester, StoryAboutScreen(onDone: () {}));
    await shot(tester, '00_about');
  });

  testWidgets('lobby', (tester) async {
    await start(
      tester,
      StoryLobbyScreen(
        world: _world,
        coverImage: _cafe.coverImage,
        narration: narration(),
        memory: MemoryStoryV2Memory(about: true)..names = _names,
        onExit: () {},
        onPlay: (_) {},
      ),
    );
    await shot(tester, '01_file');
    await tap(tester, StoryLobbyScreen.friendsKey);
    await shot(tester, '02_names');
    await tap(tester, StoryLobbyScreen.continueKey);
    await tap(tester, StoryLobbyScreen.nextKey);
    await shot(tester, '03_howto');
  });

  testWidgets('five at the table', (tester) async {
    final table = StoryTable.deal(world: _world, players: _names, seed: 11);
    await start(
      tester,
      StoryTableScreen(
        table: table,
        seed: 11,
        narration: narration(),
        onExit: () {},
        onPlayAgain: () {},
      ),
    );
    await shot(tester, '04_cast');
    await tap(tester, StoryTableScreen.beginKey);
    var innocentShot = false;
    var killerShot = false;
    for (final (i, seat) in table.seats.indexed) {
      if (i == 0) await shot(tester, '05_handoff');
      await tap(tester, StoryTableScreen.openKey);
      final role = table.roleOf(seat);
      if (i == 0) await shot(tester, '06_card');
      await hold(tester);
      if (role == StorySeatRole.killer && !killerShot) {
        await shot(tester, '07_secret_killer');
        killerShot = true;
      }
      if (role == StorySeatRole.innocent && !innocentShot) {
        await shot(tester, '08_secret_innocent');
        innocentShot = true;
      }
      await tap(tester, StoryTableScreen.hideKey);
    }
    await shot(tester, '09_desk');
    await tap(tester, StoryTableScreen.placeKey(_world.places[1].id));
    await shot(tester, '10_found');
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    await tap(tester, StoryTableScreen.decideKey);
    await tap(tester, StoryTableScreen.pickKey(table.culpritId));
    await shot(tester, '11_decision');
    await tap(tester, StoryTableScreen.confirmKey);
    await shot(tester, '12_reveal');
    await tap(tester, StoryTableScreen.resultKey);
    await shot(tester, '13_result');
  });

  testWidgets('three, and solo', (tester) async {
    final three = StoryTable.deal(
      world: _world,
      players: _names.take(3).toList(),
      seed: 6,
    );
    await start(
      tester,
      StoryTableScreen(
        table: three,
        seed: 6,
        narration: narration(),
        onExit: () {},
        onPlayAgain: () {},
      ),
    );
    await tap(tester, StoryTableScreen.beginKey);
    await shot(tester, '14_intro_three');
  });

  testWidgets('solo desk', (tester) async {
    final solo = StoryTable.deal(world: _world, players: const [''], seed: 7);
    await start(
      tester,
      StoryTableScreen(
        table: solo,
        seed: 7,
        narration: narration(),
        onExit: () {},
        onPlayAgain: () {},
        watchAdForSearch: () async => true,
      ),
    );
    await shot(tester, '15_solo_desk');
  });
}
