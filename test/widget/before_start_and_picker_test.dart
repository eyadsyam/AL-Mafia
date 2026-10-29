import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/router.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/screens/setup/before_start_sheet.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart';

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// WP6 «قبل ما تبدأوا» before an offline deal, and WP9 the closed Stories
/// card on the mode picker.
/// The shipping fonts, so a line of Arabic wraps as it does on a phone (the
/// test default is a box font twice as wide, which makes every sheet scroll).
Future<void> loadAppFonts() async {
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
  const sizes = [Size(360, 640), Size(390, 844), Size(640, 360)];

  Future<ProviderContainer> launchSettings(
    WidgetTester tester, {
    Size size = const Size(430, 932),
    String at = Routes.settings,
  }) async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(
          MemoryMatchRepository(returningHostStore()),
        ),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    container.read(setupDraftProvider.notifier)
      ..setNames(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
      ..setRoleCounts({
        Role.mafia: 3,
        Role.detective: 1,
        Role.doctor: 1,
        Role.citizen: 3,
      });
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AmbientMotion(
          enabled: false,
          child: MafiaApp(initialLocation: at),
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(SettingsScreen.saveButton));
    await tester.pump();
    await tester.tap(find.byKey(SettingsScreen.saveButton));
    await tester.pumpAndSettle();
  }

  group('«قبل ما تبدأوا»', () {
    testWidgets('comes up before the deal, and «يلا نبدأ» deals', (
      tester,
    ) async {
      final container = await launchSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await save(tester);
      expect(find.byKey(BeforeStartKeys.sheet), findsOneWidget);
      expect(find.text(arStrings.beforeStartTitle), findsOneWidget);
      for (final line in [
        arStrings.beforeStartLine1,
        arStrings.beforeStartLine2,
        arStrings.beforeStartLine3,
        arStrings.beforeStartLine4,
        arStrings.beforeStartLine5,
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.text('يلا نبدأ'), findsOneWidget);
      expect(
        container.read(matchControllerProvider),
        isNull,
        reason: 'nothing is dealt while the sheet is up',
      );
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(BeforeStartKeys.go));
      await tester.pumpAndSettle();
      expect(find.byKey(BeforeStartKeys.sheet), findsNothing);
      expect(
        container.read(matchControllerProvider.notifier).engine.match.phase,
        GamePhase.distributing,
      );
    });

    testWidgets('closing it with the X starts nothing and stays on setup', (
      tester,
    ) async {
      final container = await launchSettings(tester);
      await save(tester);
      await tester.tap(find.byKey(DeckSheet.closeKey));
      await tester.pumpAndSettle();

      expect(find.byKey(BeforeStartKeys.sheet), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(container.read(matchControllerProvider), isNull);

      // And it can be asked for again.
      await save(tester);
      expect(find.byKey(BeforeStartKeys.sheet), findsOneWidget);
    });

    testWidgets('swiping it down or the system back starts nothing', (
      tester,
    ) async {
      final container = await launchSettings(tester);
      await save(tester);
      await tester.fling(
        find.text(arStrings.beforeStartTitle),
        const Offset(0, 600),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(BeforeStartKeys.sheet), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(container.read(matchControllerProvider), isNull);

      await save(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(BeforeStartKeys.sheet), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(container.read(matchControllerProvider), isNull);
    });

    for (final size in sizes) {
      testWidgets('fits $size with nothing overlapping', (tester) async {
        await tester.runAsync(loadAppFonts);
        await launchSettings(tester, size: size);
        await save(tester);
        expect(tester.takeException(), isNull);

        final go = tester.getRect(find.byKey(BeforeStartKeys.go));
        final screen = Offset.zero & size;
        expect(screen.contains(go.topLeft), isTrue);
        expect(screen.contains(go.bottomRight), isTrue);
        // The button is pinned under the lines, never over them.
        final sheetScroll = find.ancestor(
          of: find.byKey(BeforeStartKeys.sheet),
          matching: find.byType(Scrollable),
        );
        final scroll = tester.getRect(sheetScroll);
        expect(scroll.bottom, lessThanOrEqualTo(go.top));

        final last = find.byKey(BeforeStartKeys.line(5));
        final position = tester.state<ScrollableState>(sheetScroll).position;
        if (size.height >= 640) {
          expect(
            position.maxScrollExtent,
            0,
            reason: 'the five lines fit without scrolling at $size',
          );
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(go.top));
        } else {
          // Landscape: it may scroll, and the last line is reachable.
          await tester.ensureVisible(last);
          await tester.pump();
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(go.top));
        }
      });
    }
  });

  group('mode picker: Stories is «قريبا»', () {
    Widget picker({
      VoidCallback? stories,
      VoidCallback? bots,
      VoidCallback? offline,
      bool soon = true,
    }) => localizedApp(
      ModeScreen(
        onPlayOffline: offline ?? () {},
        onPlayOnline: () {},
        onPlayBots: bots,
        onPlayStories: stories,
        storiesSoon: soon,
        onBack: () {},
      ),
    );

    testWidgets('shows the image with only the label, and a tap does nothing', (
      tester,
    ) async {
      await tester.pumpWidget(picker());
      await tester.pumpAndSettle();
      expect(find.byKey(ModeScreen.storiesCard), findsOneWidget);
      expect(find.text('قريبا'), findsOneWidget);
      expect(find.text(arStrings.modeStoriesCardBody), findsNothing);
      expect(find.text(arStrings.modeStoriesCardTitle), findsNothing);

      await tester.tap(find.byKey(ModeScreen.storiesCard));
      await tester.pumpAndSettle();
      expect(find.byType(ModeScreen), findsOneWidget);
      expect(find.byKey(ModeScreen.mafiaCard).hitTestable(), findsOneWidget);
    });

    testWidgets('through the real router the tap goes nowhere', (tester) async {
      expect(kOfferStories, isFalse);
      await launchSettings(tester, at: Routes.mode);
      expect(find.byType(ModeScreen), findsOneWidget);
      expect(find.byKey(ModeScreen.soonLabel), findsOneWidget);
      await tester.tap(find.byKey(ModeScreen.storiesCard));
      await tester.pumpAndSettle();
      expect(find.byType(ModeScreen), findsOneWidget);
      expect(find.byType(StoriesScreen), findsNothing);
    });

    testWidgets('a playable Stories card still opens its hub', (tester) async {
      var opened = 0;
      await tester.pumpWidget(picker(stories: () => opened++, soon: false));
      await tester.pumpAndSettle();
      expect(find.text('قريبا'), findsNothing);
      await tester.tap(find.byKey(ModeScreen.storiesCard));
      expect(opened, 1);
    });

    for (final size in sizes) {
      for (final withBots in [false, true]) {
        testWidgets('fits $size closed and open (bots: $withBots)', (
          tester,
        ) async {
          await tester.runAsync(loadAppFonts);
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(picker(bots: withBots ? () {} : null));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Closed: both cards, apart, and the cards are not squeezed.
          final mafia = tester.getRect(find.byKey(ModeScreen.mafiaCard));
          final mafiaH = tester
              .getSize(find.byKey(ModeScreen.mafiaCard))
              .height;
          final storiesH = tester
              .getSize(find.byKey(ModeScreen.storiesCard))
              .height;
          final stories = tester.getRect(find.byKey(ModeScreen.storiesCard));
          // Sizes, not the tilted bounds: the cards lean 5 degrees.
          expect(storiesH, greaterThanOrEqualTo(ModeTokens.cardMinHeight - 1));
          expect(mafiaH, greaterThanOrEqualTo(ModeTokens.cardMinHeight - 1));
          for (final r in [mafia, stories]) {
            expect(r.left, greaterThanOrEqualTo(-1));
            expect(r.right, lessThanOrEqualTo(size.width + 1));
          }
          // The title above the cards is not covered by them.
          final title = tester.getRect(find.text(arStrings.modeTitle));
          expect(title.bottom, lessThanOrEqualTo(mafia.top));
          expect(title.bottom, lessThanOrEqualTo(stories.top));

          // Open: the small cards do not meet each other or the back button.
          await tester.tap(find.byKey(ModeScreen.mafiaCard));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final ways = [
            ModeScreen.offlineCard,
            ModeScreen.onlineCard,
            if (withBots) ModeScreen.botsCard,
          ].map((k) => tester.getRect(find.byKey(k))).toList();
          for (var i = 0; i < ways.length; i++) {
            expect(ways[i].height, greaterThan(0));
            for (var j = i + 1; j < ways.length; j++) {
              expect(ways[i].overlaps(ways[j]), isFalse);
            }
            expect(
              ways[i].overlaps(
                tester.getRect(find.byKey(ModeScreen.closeButton)),
              ),
              isFalse,
            );
            expect(ways[i].left, greaterThanOrEqualTo(0));
            expect(ways[i].right, lessThanOrEqualTo(size.width));
          }
        });
      }
    }
  });

  // The owner's rule: nothing sits on top of anything, nothing is cut.
  group('landscape 640×360: all of it in view, nothing on anything', () {
    const land = Size(640, 360);
    final screen = Offset.zero & land;

    void inView(WidgetTester tester, Finder f, String what) {
      final r = tester.getRect(f);
      expect(screen.contains(r.topLeft), isTrue, reason: '$what top-left $r');
      expect(
        screen.contains(r.bottomRight),
        isTrue,
        reason: '$what bottom-right $r',
      );
    }

    testWidgets('the sheet: every line fully inside, clear of the button', (
      tester,
    ) async {
      await tester.runAsync(loadAppFonts);
      await launchSettings(tester, size: land);
      await save(tester);
      final go = tester.getRect(find.byKey(BeforeStartKeys.go));
      inView(tester, find.byKey(BeforeStartKeys.go), 'button');
      final scroller = find.ancestor(
        of: find.byKey(BeforeStartKeys.sheet),
        matching: find.byType(Scrollable),
      );
      final view = tester.getRect(scroller);
      expect(
        tester.state<ScrollableState>(scroller).position.maxScrollExtent,
        0,
        reason: 'nothing to scroll: every line is at rest in view',
      );
      final lines = [
        for (var n = 1; n <= 5; n++) find.byKey(BeforeStartKeys.line(n)),
      ];
      for (final (i, f) in lines.indexed) {
        inView(tester, f, 'line ${i + 1}');
        final r = tester.getRect(f);
        expect(r.bottom, lessThanOrEqualTo(view.bottom + 0.5), reason: '$i');
        expect(r.overlaps(go), isFalse, reason: 'line ${i + 1} on the button');
        expect(r.bottom, lessThan(go.top), reason: 'line ${i + 1} below top');
        for (final (j, g) in lines.indexed.skip(i + 1)) {
          expect(
            r.overlaps(tester.getRect(g)),
            isFalse,
            reason: 'line ${i + 1} on line ${j + 1}',
          );
        }
      }
    });

    for (final withBots in [false, true]) {
      testWidgets(
        'the turned picker (bots: $withBots): no scroll, no overlap',
        (tester) async {
          await tester.runAsync(loadAppFonts);
          await tester.binding.setSurfaceSize(land);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            localizedApp(
              ModeScreen(
                onPlayOffline: () {},
                onPlayOnline: () {},
                onPlayBots: withBots ? () {} : null,
                storiesSoon: true,
                onBack: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ModeScreen.mafiaCard));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SingleChildScrollView), findsNothing);

          final header = tester.getRect(find.byType(DeckHeader).first);
          final keys = [
            ModeScreen.mafiaCard,
            ModeScreen.offlineCard,
            ModeScreen.onlineCard,
            if (withBots) ModeScreen.botsCard,
            ModeScreen.closeButton,
          ];
          final pick = find.text(arStrings.modeMafiaPick);
          final rects = <String, Rect>{
            for (final k in keys) '$k': tester.getRect(find.byKey(k)),
            'pick line': tester.getRect(pick),
          };
          for (final e in rects.entries) {
            expect(screen.contains(e.value.topLeft), isTrue, reason: e.key);
            expect(screen.contains(e.value.bottomRight), isTrue, reason: e.key);
            expect(
              e.value.top,
              greaterThanOrEqualTo(header.bottom - 0.5),
              reason: '${e.key} under the header',
            );
          }
          final all = rects.entries.toList();
          for (var i = 0; i < all.length; i++) {
            for (var j = i + 1; j < all.length; j++) {
              expect(
                all[i].value.overlaps(all[j].value),
                isFalse,
                reason: '${all[i].key} on ${all[j].key}',
              );
            }
          }
          // And «رجوع» works from where it stands.
          await tester.tap(find.byKey(ModeScreen.closeButton));
          await tester.pumpAndSettle();
          expect(
            find.byKey(ModeScreen.offlineCard).hitTestable(),
            findsNothing,
          );
        },
      );
    }
  });
}
