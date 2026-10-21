/// Identity review harness. Capture a baseline BEFORE editing the UI with
/// --dart-define=IDENTITY_STAGE=before; the default destination is after.
/// Includes the v15 story/match walkthrough and the main public destinations.
/// Renders what 1.2.0 (15) adds, for the owner to look at: the stories in
/// their Ruqaa headings, «العب ضد البوتات» from the mode screen through the
/// sheet to the table talk and the rematch.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/v15_screenshots.dart
///
/// Writes to `build/identity_before/` or `build/identity_after/`.
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
import 'package:mafia_master/ui/screens/stories/story_case_widgets.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_sheet.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_sheet.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/fun/characters_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_play_screen.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/fun/match_awards.dart';
import 'package:mafia_master/ui/missions/casebook_data.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:mafia_master/ui/screens/postgame/match_file.dart';
import '../support/artwork.dart';
import '../support/casebook_fixture.dart';
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
  final out = Directory(
    'build/identity_${const String.fromEnvironment('IDENTITY_STAGE', defaultValue: 'after')}',
  )..createSync(recursive: true);

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
    expect(tester.takeException(), isNull, reason: '$name must render cleanly');
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

  final publicScreens = <String, Widget>{
    '00_mode': ModeScreen(
      onPlayOffline: () {},
      onPlayOnline: () {},
      onPlayBots: () {},
      onPlayStories: () {},
      onBack: () {},
    ),
    '15_help': HowToPlayScreen(onBack: () {}, onStartMatch: () {}),
    '16_profile': ProfileScreen(onBack: () {}),
    '17_onboarding': const FirstRunScreen(),
    '08_home': HomeScreen(
      onNewMatch: () {},
      onHistory: () {},
      onSettings: () {},
      onHowToPlay: () {},
    ),
    '09_settings': SettingsScreen(
      initial: const MatchSettings(),
      onSave: (_) {},
      onBack: () {},
    ),
    '10_players': AddPlayersScreen(
      onNext: (_) {},
      onBack: () {},
      initialNames: const ['أحمد', 'منة', 'كريم', 'سلمى', 'يوسف', 'نور', 'عمر'],
    ),
    '11_roles': RolesScreen(playerCount: 7, onNext: (_) {}, onBack: () {}),
    '12_history_empty': HistoryScreen(onOpen: (_) {}, onBack: () {}),
    '13_characters': CharactersScreen(onBack: () {}),
    '14_online': OnlineEntryScreen(onJoined: () {}, onBack: () {}),
  };
  for (final entry in publicScreens.entries) {
    testWidgets(entry.key, (tester) async {
      await shoot(tester, entry.key, entry.value);
    });
  }

  testWidgets('00_mode turned over', (tester) async {
    await shoot(tester, '00_mode', publicScreens['00_mode']!);
    await tester.tap(find.byKey(ModeScreen.mafiaCard));
    await tester.pump(const Duration(milliseconds: 420));
    await capture(tester, '00_mode_flipping');
    await tester.pumpAndSettle();
    await capture(tester, '00_mode_open');
  });

  testWidgets('public screens fit a narrow phone', (tester) async {
    await prepare(tester);
    tester.view.physicalSize = const Size(360, 844) * 2;
    for (final entry in publicScreens.entries) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: ProviderScope(child: localizedApp(entry.value)),
        ),
      );
      await capture(tester, '${entry.key}_360');
    }
  });

  testWidgets('first run steps', (tester) async {
    await shoot(tester, '17_first_run_0_intro', const FirstRunScreen());
    await tester.pump(const Duration(milliseconds: 1400));
    await capture(tester, '17_first_run_1_fan');
    await tester.pumpAndSettle();
    await capture(tester, '17_first_run_2_kind');
    await tester.tap(find.byKey(FirstRunScreen.agreeKey));
    await tester.pumpAndSettle();
    await capture(tester, '17_first_run_3_kind_agreed');
    await tester.tap(find.byKey(FirstRunScreen.girlKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'منة');
    await tester.pumpAndSettle();
    await capture(tester, '17_first_run_4_name');
  });

  for (final (name, show) in <(String, Future<void> Function(BuildContext))>[
    ('09_settings_sheet', showSettingsSheet),
    (
      '15_how_to_sheet',
      (c) => showHowToSheet(c, onVideo: () {}),
    ),
  ]) {
    testWidgets(name, (tester) async {
      await shoot(
        tester,
        name,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await capture(tester, name);
    });
  }

  testWidgets('stories hub', (tester) async {
    await shoot(tester, '01_stories_hub', StoriesScreen(onBack: () {}));
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
        StoryFlowScreen(
          story: story,
          playerCount: 1,
          onExit: () {},
          onComplete: (_) async {},
          playNarration: (_) async {},
        ),
      );
    });
  }

  testWidgets('story solo: notes pinned, accusation', (tester) async {
    final story = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
    await shoot(
      tester,
      '02_story_solo_moves',
      StoryFlowScreen(
        story: story,
        playerCount: 1,
        onExit: () {},
        onComplete: (_) async {},
      ),
    );
    await tester.tap(find.text(story.actions.first.title));
    await tester.pump(const Duration(seconds: 1));
    await capture(tester, '02_story_solo_pinned');
    await tester.tap(find.byKey(StoryFlowScreen.accusationButtonKey));
    await tester.pumpAndSettle();
    await capture(tester, '02_story_solo_accusation');
  });

  testWidgets('story with friends: cast, files, table, ballot', (tester) async {
    final story = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
    Future<void> hold() async {
      final g = await tester.startGesture(
        tester.getCenter(find.byType(HoldPad)),
      );
      await tester.pump(StoryTokens.privateHold);
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await shoot(
      tester,
      '07_group_cast',
      StoryFlowScreen(
        story: story,
        playerCount: 2,
        onExit: () {},
        onComplete: (_) async {},
      ),
    );
    await tester.tap(find.byKey(StoryFlowScreen.dealKey));
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, '07_group_pass');
    // Seat 1 (innocent) and seat 2 (the culprit): the same page.
    for (final name in const ['innocent', 'culprit']) {
      await hold();
      await capture(tester, '07_group_dossier_$name');
      await tester.pump(StoryTokens.dossierHold);
      await tester.tap(find.byKey(StoryFlowScreen.hideFileKey));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture(tester, '07_group_table');
    await tester.tap(find.text(arStrings.storiesSearchTogether));
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, '07_group_search');
    for (var round = 1; round <= StoryTokens.rounds; round++) {
      await tester.tap(find.text(story.actions[round - 1].title));
      await tester.pump(const Duration(milliseconds: 100));
      if (round == StoryTokens.rounds) break;
      for (var seat = 0; seat < 2; seat++) {
        await hold();
        await tester.pump(StoryTokens.dossierHold);
        await tester.tap(find.byKey(StoryFlowScreen.hideFileKey));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text(arStrings.storiesSearchTogether));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await hold();
    await tester.tap(
      find.byKey(StoryAccusationForm.suspectKey(story.truth.primaryCulprit)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await capture(tester, '07_group_ballot');
  });

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
    tester.view.physicalSize = const Size(360, 844) * 2;
    await tester.pump();
    await capture(tester, '05_bot_match_sheet_360');
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

  // P10/P11: the dark case file at both phone sizes (end state, reduced motion).
  for (final size in const [Size(360, 640), Size(430, 932)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    Widget stills(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

    Future<void> shootAt(WidgetTester tester, String name, Widget child) async {
      await prepare(tester);
      tester.view.physicalSize = size * 2;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: ProviderScope(
            overrides: [
              casebookProvider.overrideWith(FakeCasebookController.new),
              walletProvider.overrideWith(_ShotWallet.new),
            ],
            child: localizedApp(stills(child)),
          ),
        ),
      );
      await capture(tester, '${name}_$tag');
    }

    const rows = [
      ResultRow(seat: 0, name: 'انت', role: engine.Role.detective),
      ResultRow(seat: 1, name: 'منة', role: engine.Role.doctor),
      ResultRow(
        seat: 2,
        name: 'كريم',
        role: engine.Role.mafia,
        eliminatedLabel: 'اليوم 2',
      ),
      ResultRow(
        seat: 3,
        name: 'سلمى',
        role: engine.Role.citizen,
        eliminatedLabel: 'الليلة 1',
      ),
      ResultRow(
        seat: 4,
        name: 'يوسف',
        role: engine.Role.silencer,
        eliminatedLabel: 'اليوم 3',
      ),
      ResultRow(seat: 5, name: 'نور', role: engine.Role.elder),
      ResultRow(
        seat: 6,
        name: 'عمر',
        role: engine.Role.sniper,
        eliminatedLabel: 'اليوم 1',
      ),
      ResultRow(seat: 7, name: 'هنا', role: engine.Role.citizen),
    ];
    const file = MatchFile(
      days: 3,
      nights: [
        MatchFileNight(
          day: false,
          number: 1,
          lines: [MatchFileLine(MatchFileKind.killed, seats: [3])],
        ),
        MatchFileNight(
          day: true,
          number: 1,
          lines: [MatchFileLine(MatchFileKind.expelled, seats: [6], votes: 5)],
        ),
        MatchFileNight(
          day: false,
          number: 2,
          lines: [MatchFileLine(MatchFileKind.saved, seats: [1])],
        ),
      ],
    );

    testWidgets('18_result_town $tag', (tester) async {
      await shootAt(
        tester,
        '18_result_town',
        ResultScreen(
          winner: engine.Alignment.town,
          rows: rows,
          viewerSeat: 0,
          coinRows: const [
            ResultCoinRow(label: 'فزت على الكمبيوتر', coins: 25),
          ],
          matchFile: file,
          onHome: () {},
        ),
      );
    });

    testWidgets('18_result_mafia $tag', (tester) async {
      await shootAt(
        tester,
        '18_result_mafia',
        ResultScreen(
          winner: engine.Alignment.mafia,
          rows: rows,
          viewerSeat: 0,
          matchFile: file,
          onPlayAgain: () {},
          onHome: () {},
        ),
      );
    });

    testWidgets('18_match_file $tag', (tester) async {
      await shootAt(
        tester,
        '18_match_file',
        Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              showMatchFile(
                context,
                file: file,
                rows: rows,
                awards: const [
                  MatchAward(kind: AwardKind.mvp, seats: [1], names: ['منة']),
                ],
                onShare: () {},
              );
            });
            return const SizedBox.expand();
          },
        ),
      );
    });

    testWidgets('19_profile_file $tag', (tester) async {
      await shootAt(tester, '19_profile_file', ProfileScreen(onBack: () {}));
    });

    testWidgets('19_casebook_board $tag', (tester) async {
      await shootAt(
        tester,
        '19_casebook_board',
        const Scaffold(body: CasebookSheet()),
      );
    });
  }
}

class _ShotWallet extends WalletController {
  @override
  Future<WalletState?> build() async => const WalletState(
    balance: 340,
    catalog: [],
    owned: {},
    equipped: {},
    history: [],
  );
}
