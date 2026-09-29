import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show GamePhase;
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/fun/award_ribbon.dart';
import 'package:mafia_master/ui/fun/founder_badge.dart';
import 'package:mafia_master/ui/fun/match_awards.dart';
import 'package:mafia_master/ui/fun/reactions.dart';
import 'package:mafia_master/ui/fun/welcome_back.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Phase 109: the award ribbon, the reactions bar and its gate, the floating
/// seals, and the welcome-back card — at 320 and 430 px, Arabic and English.
void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'result'),
      players: roster(5),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    EconomyCapabilities caps = const EconomyCapabilities(
      daily: true,
      fun: FunCapabilities(awards: true, reactions: true, known: true),
    ),
    Size size = const Size(320, 800),
    Locale locale = const Locale('ar'),
    List<Override> overrides = const [],
    bool warmCapabilities = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          economyCapabilitiesProvider.overrideWith((ref) async => caps),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
          awardsRetryDelayProvider.overrideWithValue(Duration.zero),
          ...overrides,
        ],
        child: localizedApp(
          // Home and the profile never start a capabilities read; the rest
          // of the app has usually asked by then. Stand in for that here.
          Consumer(
            builder: (context, ref, inner) {
              if (warmCapabilities) ref.watch(economyCapabilitiesProvider);
              return inner!;
            },
            child: Scaffold(body: child),
          ),
          locale: locale,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  const awards = [
    MatchAward(kind: AwardKind.mvp, seats: [2], names: ['منى عبد الرحمن']),
    MatchAward(kind: AwardKind.sharpEye, seats: [3], names: ['Karim']),
    MatchAward(kind: AwardKind.perfectCrime, seats: [0, 1], names: ['A', 'B']),
    MatchAward(
      kind: AwardKind.survivor,
      seats: [2, 3, 4, 5],
      names: ['Mona', 'Karim', 'Laila', 'Omar'],
    ),
  ];

  group('award ribbon', () {
    for (final width in [320.0, 430.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        testWidgets('reveals every card at ${width.toInt()} px, $locale', (
          tester,
        ) async {
          await pump(
            tester,
            const Center(child: AwardRibbon(awards: awards, granted: 20)),
            size: Size(width, 700),
            locale: locale,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(AwardRibbon.card(AwardKind.mvp)), findsOneWidget);
          expect(
            find.byKey(AwardRibbon.card(AwardKind.sharpEye)),
            findsOneWidget,
          );
          final strings = locale.languageCode == 'ar' ? arStrings : enStrings;
          expect(find.text(strings.awardsTitle), findsOneWidget);
          expect(find.text(strings.awardsYouEarned(20)), findsOneWidget);
          // Several winners read as the first name and a count (the card
          // is scrolled to on the narrowest phone).
          await tester.scrollUntilVisible(
            find.text('Mona +3'),
            FunTokens.awardCardWidth,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Mona +3'), findsOneWidget);
        });
      }
    }

    testWidgets('loading shows skeleton cards, not a spinner', (tester) async {
      await pump(tester, const AwardRibbon(awards: [], loading: true));
      expect(
        find.byKey(AwardRibbon.skeletonKey),
        findsNWidgets(FunTokens.skeletonCards),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'online: a live room shows nothing; the result shows the ribbon',
      (tester) async {
        var ready = false;
        backend.responders['economy'] = (body) {
          if (body['action'] != 'awards_get') return const {'ok': true};
          return ready
              ? {
                  'enabled': true,
                  'ready': true,
                  'awards': [
                    {
                      'code': 'mvp',
                      'seats': [0],
                      'names': ['Mona'],
                      'coins': 15,
                    },
                  ],
                  'mine': ['mvp'],
                  'granted': 15,
                }
              : {'enabled': true, 'ready': false, 'awards': []};
        };
        await pump(tester, const OnlineAwardsStrip(roomId: 'room-1'));
        await tester.pumpAndSettle();
        expect(find.byKey(AwardRibbon.card(AwardKind.mvp)), findsNothing);

        ready = true;
        await pump(tester, const OnlineAwardsStrip(roomId: 'room-2'));
        await tester.pumpAndSettle();
        expect(find.byKey(AwardRibbon.card(AwardKind.mvp)), findsOneWidget);
      },
    );

    testWidgets('awards off: no request, nothing drawn', (tester) async {
      await pump(
        tester,
        const OnlineAwardsStrip(roomId: 'room-1'),
        caps: const EconomyCapabilities(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AwardRibbon), findsNothing);
      expect(
        backend.calls.where((c) => c.body['action'] == 'awards_get'),
        isEmpty,
      );
    });
  });

  group('reactions', () {
    test('open only in the lobby and on a public result', () {
      for (final phase in GamePhase.values) {
        final expected =
            phase == GamePhase.setup ||
            phase == GamePhase.result ||
            phase == GamePhase.analytics;
        expect(
          reactionsOpen(phase, outcomePublic: true),
          expected,
          reason: '$phase',
        );
      }
      expect(
        reactionsOpen(GamePhase.result),
        isFalse,
        reason: 'outcome not public',
      );
    });

    for (final phase in GamePhase.values) {
      testWidgets('the bar in $phase', (tester) async {
        await pump(
          tester,
          ReactionBar(
            roomId: 'room-1',
            backend: backend,
            open: reactionsOpen(phase, outcomePublic: true),
          ),
        );
        final shown =
            phase == GamePhase.setup ||
            phase == GamePhase.result ||
            phase == GamePhase.analytics;
        expect(
          find.byKey(ReactionBar.barKey),
          shown ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('server switch off hides the bar', (tester) async {
      await pump(
        tester,
        ReactionBar(roomId: 'room-1', backend: backend, open: true),
        caps: const EconomyCapabilities(),
      );
      expect(find.byKey(ReactionBar.barKey), findsNothing);
    });

    testWidgets('sends through the server, a burst of three then slow down', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 9, 26, 12);
      await pump(
        tester,
        ReactionBar(roomId: 'room-1', backend: backend, open: true),
        overrides: [reactionClockProvider.overrideWithValue(() => now)],
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(ReactionBar.seal(ReactionKind.rose)));
        await tester.pump();
      }
      final sent = backend.calls
          .where((c) => c.body['action'] == 'react')
          .toList();
      expect(sent, hasLength(FunTokens.reactionBurst));
      expect(sent.first.body, {
        'action': 'react',
        'roomId': 'room-1',
        'kind': 'rose',
      });
      expect(find.text(arStrings.reactionSlowDown), findsOneWidget);
    });

    testWidgets('fits at 320 px in English', (tester) async {
      await pump(
        tester,
        ReactionBar(roomId: 'room-1', backend: backend, open: true),
        locale: const Locale('en'),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(ReactionBar.seal(ReactionKind.crown)), findsOneWidget);
    });

    testWidgets('a reaction floats over its seat and leaves', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 300,
          height: 300,
          child: ReactionScope(
            roomId: 'room-1',
            backend: backend,
            open: true,
            anchor: (seat, size) => Offset(40.0 * (seat + 1), 150),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(backend.reactionFeed.hasListener, isTrue);
      backend.reactionFeed.add(
        const RoomReactionRow(id: 1, seat: 2, kind: 'crown'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(ReactionFloats.floatKey), findsOneWidget);
      // A duplicate delivery is one seal.
      backend.reactionFeed.add(
        const RoomReactionRow(id: 1, seat: 2, kind: 'crown'),
      );
      await tester.pump();
      expect(find.byKey(ReactionFloats.floatKey), findsOneWidget);
      await tester.pump(FunTokens.reactionFloatDuration);
      await tester.pump();
      expect(find.byKey(ReactionFloats.floatKey), findsNothing);
    });

    testWidgets('closed scope never subscribes', (tester) async {
      await pump(
        tester,
        ReactionScope(
          roomId: 'room-1',
          backend: backend,
          open: false,
          child: const SizedBox.expand(),
        ),
      );
      expect(backend.reactionFeed.hasListener, isFalse);
    });
  });

  group('daily strip', () {
    final now = DateTime(2026, 9, 26, 20);
    const today = '2026-09-26';

    Map<String, dynamic> status({bool claimed = false, bool spun = false}) => {
      'enabled': true,
      'day': today,
      'coffer': {'claimed': claimed, 'amount': 20},
      'wheel': {'spun': spun, 'prizes': const []},
      'week': {'progress': 1, 'length': 7, 'bonus': 0},
      'ad': {'enabled': false},
    };

    Future<void> pumpHome(
      WidgetTester tester, {
      Duration? away,
      bool daily = true,
      bool claimed = false,
      bool spun = false,
      String? dismissedOn,
      Locale locale = const Locale('ar'),
    }) async {
      SharedPreferences.setMockInitialValues({
        if (away != null)
          welcomeBackLastSeenKey: now.subtract(away).millisecondsSinceEpoch,
        cofferStripDismissedKey: ?dismissedOn,
      });
      var isClaimed = claimed;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'daily_status' => status(claimed: isClaimed, spun: spun),
        'daily_coffer' => () {
          isClaimed = true;
          return {'granted': 20, 'daily': status(claimed: true, spun: spun)};
        }(),
        _ => const {'ok': true},
      };
      await pump(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: WelcomeBackCard(),
        ),
        caps: EconomyCapabilities(daily: daily),
        locale: locale,
        overrides: [welcomeBackClockProvider.overrideWithValue(() => now)],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('coffer waiting: the strip claims it in place, then offers '
        'the wheel', (tester) async {
      await pumpHome(tester);
      expect(find.byKey(WelcomeBackCard.cardKey), findsOneWidget);
      expect(find.text(arStrings.cofferStripReady), findsOneWidget);
      await tester.tap(find.byKey(WelcomeBackCard.claimKey));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.cofferStripGot(20)), findsOneWidget);
      expect(find.byKey(WelcomeBackCard.spinKey), findsOneWidget);
    });

    testWidgets('claimed with the wheel spun: the thanks lingers, then goes', (
      tester,
    ) async {
      await pumpHome(tester, spun: true);
      await tester.tap(find.byKey(WelcomeBackCard.claimKey));
      await tester.pumpAndSettle();
      expect(find.byKey(WelcomeBackCard.spinKey), findsNothing);
      await tester.pump(MafiaTiming.cofferStripLinger);
      await tester.pumpAndSettle();
      expect(find.byKey(WelcomeBackCard.cardKey), findsNothing);
    });

    testWidgets('already claimed today: no strip at all', (tester) async {
      await pumpHome(tester, claimed: true, away: const Duration(days: 5));
      expect(find.byKey(WelcomeBackCard.cardKey), findsNothing);
    });

    testWidgets('dismissed: gone for the rest of the day', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(WelcomeBackCard.dismissKey));
      await tester.pumpAndSettle();
      expect(find.byKey(WelcomeBackCard.cardKey), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(cofferStripDismissedKey), today);
      await pumpHome(tester, dismissedOn: today);
      expect(find.byKey(WelcomeBackCard.cardKey), findsNothing);
    });

    testWidgets('a long absence only changes the greeting', (tester) async {
      await pumpHome(tester, away: const Duration(days: 4));
      expect(find.text(arStrings.welcomeBackTitle), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(welcomeBackLastSeenKey), now.millisecondsSinceEpoch);
    });

    testWidgets('Home never starts a capabilities read of its own', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var asked = false;
      await pump(
        tester,
        const WelcomeBackCard(),
        warmCapabilities: false,
        overrides: [
          welcomeBackClockProvider.overrideWithValue(() => now),
          economyCapabilitiesProvider.overrideWith((ref) async {
            asked = true;
            return const EconomyCapabilities(daily: true);
          }),
        ],
      );
      await tester.pumpAndSettle();
      expect(asked, isFalse);
      expect(backend.calls, isEmpty);
      expect(find.byKey(WelcomeBackCard.cardKey), findsNothing);
    });

    testWidgets('founder badge: shown once earned, never fetched unasked', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => body['action'] == 'fun_profile'
          ? {
              'badges': ['founder'],
            }
          : const {'ok': true};
      await pump(tester, const FounderBadge(), warmCapabilities: false);
      await tester.pumpAndSettle();
      expect(find.byKey(FounderBadge.badgeKey), findsNothing);
      expect(backend.calls, isEmpty);
      await pump(tester, const FounderBadge());
      await tester.pumpAndSettle();
      expect(find.byKey(FounderBadge.badgeKey), findsOneWidget);
      expect(find.text(arStrings.founderBadge), findsOneWidget);
    });

    testWidgets('daily off: nothing to offer, no strip', (tester) async {
      await pumpHome(tester, away: const Duration(days: 3), daily: false);
      expect(find.byKey(WelcomeBackCard.cardKey), findsNothing);
    });

    testWidgets('fits at 320 px in English', (tester) async {
      await pumpHome(tester, locale: const Locale('en'));
      expect(tester.takeException(), isNull);
      expect(find.text(enStrings.cofferStripReady), findsOneWidget);
    });
  });
}
