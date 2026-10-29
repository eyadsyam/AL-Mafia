/// Renders what 1.2.0 (15) adds, for the owner to look at: the stories in
/// their Ruqaa headings, «العب ضد البوتات» from the mode screen through the
/// sheet to the table talk and the rematch.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/v15_screenshots.dart
///
/// Writes to `build/screens_v15/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/screens/setup/bot_match_sheet.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';
import 'package:mafia_master/ui/screens/stories/widgets/story_palette.dart';

import '../support/artwork.dart';
import '../support/localized.dart';
import '../support/reveal_flow.dart';

const _phone = Size(390, 844);

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Aref Ruqaa': 'assets/fonts/ArefRuqaa-Bold.ttf',
    'IBM Plex Mono': 'assets/fonts/IBMPlexMono-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final out = Directory('build/screens_v15')..createSync(recursive: true);

  Future<void> prepare(WidgetTester tester) async {
    await tester.runAsync(_fonts);
    await loadArtwork(tester);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 2), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 400));
    }
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

  Future<void> shoot(WidgetTester tester, String name, Widget child) async {
    await prepare(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(child: localizedApp(child)),
      ),
    );
    await capture(tester, name);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stories hub', (tester) async {
    await shoot(
      tester,
      '01_stories_hub',
      StoryPalette(child: StoriesScreen(onBack: () {})),
    );
  });

  for (final (n, id) in const [
    (2, 'qahwet_el_moallem'),
    (3, 'fondo2_shepheard'),
  ]) {
    testWidgets('story $id', (tester) async {
      final story = StoryDefinition.decode(
        File('assets/stories/$id.json').readAsStringSync(),
      );
      await shoot(
        tester,
        '0${n}_story_$id',
        StoryPalette(
          child: StoryFlowScreen(
            story: story,
            playerCount: 1,
            onExit: () {},
            onComplete: (_) async {},
            playNarration: (_) async {},
          ),
        ),
      );
    });
  }

  testWidgets('mode screen', (tester) async {
    await shoot(
      tester,
      '04_mode_bots_card',
      ModeScreen(
        onPlayOffline: () {},
        onPlayOnline: () {},
        onPlayBots: () {},
        onPlayStories: () {},
        onBack: () {},
      ),
    );
  });

  testWidgets('bot match sheet', (tester) async {
    await shoot(
      tester,
      '05_bot_match_sheet',
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showBotMatchSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await capture(tester, '05_bot_match_sheet');
  });

  testWidgets('a match against bots', (tester) async {
    const names = ['إنت', 'أمينة', 'كريم', 'سارة', 'يوسف', 'ليلى', 'حسن'];
    await prepare(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(matchControllerProvider.notifier);
    GamePhase phase() => controller.engine.match.phase;
    bool humanTurn() => controller.engine.match.currentActorSeat == 0;

    Future<void> hold() async {
      final pad = find.byType(HoldPad).first;
      final gesture = await tester.startGesture(tester.getCenter(pad));
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.holdToReveal);
      await gesture.up();
      await tester.pumpAndSettle();
    }

    Future<void> settle() async {
      await tester.pump(
        MafiaMotion.defaults.dramatic +
            MafiaTiming.defaults.phaseHold +
            MafiaMotion.defaults.dramatic,
      );
      await tester.pumpAndSettle();
    }

    controller.startMatch(
      names: names,
      roleCounts: const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      },
      settings: const MatchSettings(discussionMode: DiscussionMode.free),
      seed: 7,
      botSeats: const {1, 2, 3, 4, 5, 6},
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: MatchFlow(onExit: () {}, onAnalytics: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.confirmIdentity(hold: MafiaTiming.defaults.holdToReveal);
    await tester.swipeToFlip();
    await tester.awaitConceal();
    await tester.tap(find.byKey(RoleCard.dismiss));
    await tester.pumpAndSettle();

    var talked = false;
    var guard = 0;
    while (phase() != GamePhase.result && guard++ < 400) {
      await tester.pumpAndSettle();
      switch (phase()) {
        case GamePhase.night when humanTurn():
          await hold();
          await tester.tap(
            find
                .byWidgetPredicate((w) => w is NightGridTile && w.onTap != null)
                .first,
          );
          await tester.pump();
          await tester.pump(MafiaTiming.defaults.dwellGate);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(TurnShell.actionButton));
          await tester.pumpAndSettle();
          await tester.pump(MafiaTiming.defaults.turnFloor);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(TurnShell.actionButton));
          await tester.pumpAndSettle();
        case GamePhase.morning:
          if (find.text('ابدأ النقاش').evaluate().isNotEmpty) {
            await tester.tap(find.text('ابدأ النقاش'));
          }
          await settle();
        case GamePhase.openingRound when humanTurn():
          await tester.tap(find.byType(PlayerTile).first);
        case GamePhase.confrontation:
          await tester.tap(find.text('خلصت'));
        case GamePhase.discussion:
          if (!talked) {
            talked = true;
            await capture(tester, '06_bots_table_talk');
          }
          await tester.tap(find.text('خلص النقاش'));
          await tester.pump();
          await settle();
        case GamePhase.voting when humanTurn():
          await hold();
          await tester.tap(find.byType(PlayerTile).first);
          await tester.pump();
          await tester.tap(find.text('أكد صوتك'));
        case GamePhase.reveal:
          await tester.tap(find.text('كمل'));
        default:
          await settle();
      }
    }
    await tester.pump();
    await tester.pump(MafiaTiming.victoryReveal);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ResultScreen.playAgainKey));
    await tester.pumpAndSettle();
    await capture(tester, '07_bots_result_play_again');
  });
}
