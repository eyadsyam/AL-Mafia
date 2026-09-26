import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/waiting_banner.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// A banner unit that is configured and always fills: a fixed box under the
/// gap the surface asked for, standing in for the framed AdMob slot.
class _FilledBanner implements BannerAds {
  const _FilledBanner();

  static const fill = ValueKey('fake_banner_fill');

  @override
  bool get configured => true;

  @override
  Widget slot({Key? key, required String label, required double gap}) =>
      Padding(
        key: key,
        padding: EdgeInsets.only(top: gap),
        child: const SizedBox(key: fill, height: 60, width: 320),
      );
}

const _bannerOn = EconomyCapabilities(ads: AdsCapabilities(banner: true));

void main() {
  group('offline waiting surfaces never ask the server (M1)', () {
    late int backendAsked;

    setUp(() {
      seedReturningProfile();
      backendAsked = 0;
    });

    // No capabilities override: the real provider would build a backend
    // (and sign in anonymously) the moment anything watched it.
    List<Override> offline() => [
      bannerAdsProvider.overrideWithValue(const _FilledBanner()),
      onlineBackendFactoryProvider.overrideWithValue(() async {
        backendAsked++;
        throw StateError('offline: no backend');
      }),
    ];

    testWidgets('History', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          ...offline(),
          matchRepositoryProvider.overrideWithValue(
            MemoryMatchRepository(MemoryMatchStore()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(HistoryScreen(onOpen: (_) {}, onBack: () {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WaitingBanner), findsOneWidget);
      expect(find.byKey(WaitingBanner.slotKey), findsNothing);
      expect(container.exists(economyCapabilitiesProvider), isFalse);
      expect(backendAsked, 0);
    });

    testWidgets('Profile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(overrides: offline());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(ProfileScreen(onSaved: () {}, onBack: () {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WaitingBanner), findsOneWidget);
      expect(find.byKey(WaitingBanner.slotKey), findsNothing);
      expect(container.exists(economyCapabilitiesProvider), isFalse);
      expect(backendAsked, 0);
    });

    testWidgets('once something else has asked, the banner shows', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...offline(),
          economyCapabilitiesProvider.overrideWith((ref) async => _bannerOn),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          // The banner builds first; a widget after it on the same screen
          // starts the read in that frame. The banner looks again after it.
          child: localizedApp(
            Scaffold(
              body: Column(
                children: [
                  const WaitingBanner(),
                  Consumer(
                    builder: (context, ref, _) {
                      ref.watch(economyCapabilitiesProvider);
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(WaitingBanner.slotKey), findsOneWidget);
      expect(backendAsked, 0);
    });
  });

  group('lobby banner stays clear of Start (M3)', () {
    for (final size in [
      const Size(360, 600),
      const Size(360, 640),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets('at $size', (tester) async {
        seedReturningProfile();
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        final backend = FakeBackend(
          roomId: 'room-1',
          state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
          players: roster(5),
          own: const OwnSeat(seat: 0),
          userId: 'u0',
        );
        final container = ProviderContainer(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            onlineHeartbeatProvider.overrideWithValue(Duration.zero),
            voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
            bannerAdsProvider.overrideWithValue(const _FilledBanner()),
            economyCapabilitiesProvider.overrideWith((ref) async => _bannerOn),
          ],
        );
        addTearDown(container.dispose);
        container.read(playerProfileProvider);
        await container.read(economyCapabilitiesProvider.future);
        await container.read(onlineSessionProvider.notifier).host('A');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedApp(LobbyScreen(onStarted: () {}, onLeave: () {})),
          ),
        );
        await tester.pump();
        await tester.pump();

        final start = find.byKey(LobbyScreen.startButton);
        final ad = find.byKey(_FilledBanner.fill);
        expect(start, findsOneWidget);
        if (size.height < AdTokens.bannerMinLobbyHeight) {
          // Too short for the clearance: no banner at all.
          expect(ad, findsNothing);
          return;
        }
        expect(ad, findsOneWidget);
        final gap = tester.getTopLeft(ad).dy - tester.getBottomLeft(start).dy;
        expect(gap, greaterThanOrEqualTo(AdTokens.bannerActionClearance));
        expect(AdTokens.bannerActionClearance, greaterThanOrEqualTo(72));
      });
    }
  });

  tearDown(() => SharedPreferences.setMockInitialValues({}));
}
