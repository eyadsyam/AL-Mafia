import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/banner_frame.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/waiting_banner.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// WP4 part A: the banner's place is reserved before the ad arrives, so
/// nothing above it moves when it fills; a failed ad leaves the place as it
/// was; a player who goes ad-free closes it over an ease, not a snap.

/// A banner whose ad arrives when the test says so: the real shared frame
/// around a stand-in 320x50 ad, exactly as the Google slot builds it.
class _TimedBanner implements BannerAds {
  final filled = ValueNotifier<bool>(false);
  static const fill = ValueKey('timed_banner_fill');

  @override
  bool get configured => true;

  @override
  Widget slot({
    Key? key,
    required String label,
    required double gap,
    BannerPlacement placement = BannerPlacement.lobby,
  }) => ValueListenableBuilder<bool>(
    key: key,
    valueListenable: filled,
    builder: (context, isFilled, _) => BannerFrame(
      label: label,
      gap: gap,
      ad: isFilled ? const SizedBox.expand(key: fill) : null,
    ),
  );
}

const _bannerOn = EconomyCapabilities(ads: AdsCapabilities(banner: true));
const _adFree = EconomyCapabilities(
  ads: AdsCapabilities(banner: true),
  adFree: true,
);

final _caps = StateProvider<EconomyCapabilities>((_) => _bannerOn);

/// Every text on screen and the ad box: what must not move.
List<Rect> _layout(WidgetTester tester) {
  final texts = find.byType(Text).evaluate().where(
    (e) => find
        .ancestor(of: find.byWidget(e.widget), matching: find.byType(BannerFrame))
        .evaluate()
        .isEmpty,
  );
  return [
    for (final e in texts) tester.getRect(find.byWidget(e.widget)),
    tester.getRect(find.byKey(BannerFrame.adKey)),
  ];
}

typedef _Surface = ({
  String name,
  Widget Function() build,
  List<Override> Function() extra,
  bool landscape,
});

void main() {
  setUp(seedReturningProfile);
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  FakeBackend backendFor() => FakeBackend(
    roomId: 'room-1',
    state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
    players: roster(5),
    own: const OwnSeat(seat: 0),
    userId: 'u0',
  )..responses['browse_rooms'] = {'rooms': <Map<String, dynamic>>[]};

  final surfaces = <_Surface>[
    (
      name: 'home',
      build: () => HomeScreen(
        onNewMatch: () {},
        onHistory: () {},
        onSettings: () {},
        onHowToPlay: () {},
        tiltSource: const LevelTiltSource(),
      ),
      extra: () => [audioDirectorProvider.overrideWithValue(AudioDirector())],
      landscape: true,
    ),
    (
      name: 'profile',
      build: () => ProfileScreen(onSaved: () {}, onBack: () {}),
      extra: () => const <Override>[],
      landscape: true,
    ),
    (
      name: 'online hub',
      build: () => OnlineEntryScreen(onJoined: () {}, onBack: () {}),
      extra: () => [
        onlineBackendFactoryProvider.overrideWithValue(
          () async => backendFor(),
        ),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
      landscape: true,
    ),
    (
      name: 'lobby',
      build: () => LobbyScreen(onStarted: () {}, onLeave: () {}),
      extra: () => [
        onlineBackendFactoryProvider.overrideWithValue(
          () async => backendFor(),
        ),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
      // The lobby draws no banner on a phone on its side (no room for the
      // clearance under Start); that rule is unchanged.
      landscape: false,
    ),
  ];

  Future<(ProviderContainer, _TimedBanner)> pump(
    WidgetTester tester,
    _Surface surface,
    Size size,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final ads = _TimedBanner();
    final container = ProviderContainer(
      overrides: [
        bannerAdsProvider.overrideWithValue(ads),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => ref.watch(_caps),
        ),
        ...surface.extra(),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ads.filled.dispose);
    container.read(_caps.notifier).state = _bannerOn;
    container.read(playerProfileProvider);
    await container.read(economyCapabilitiesProvider.future);
    if (surface.name == 'lobby') {
      await container.read(onlineSessionProvider.notifier).host('A');
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(surface.build()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (container, ads);
  }

  for (final surface in surfaces) {
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(640, 360),
    ]) {
      if (size.width > size.height && !surface.landscape) continue;
      group('${surface.name} at $size', () {
        testWidgets('nothing moves when the ad fills', (tester) async {
          final (_, ads) = await pump(tester, surface, size);
          expect(find.byKey(BannerFrame.adKey), findsOneWidget);
          expect(find.byKey(_TimedBanner.fill), findsNothing);
          final before = _layout(tester);

          ads.filled.value = true;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byKey(_TimedBanner.fill), findsOneWidget);
          expect(_layout(tester), before);
          expect(tester.takeException(), isNull);
        });

        testWidgets('no fill: the place stays as it was', (tester) async {
          final (_, _) = await pump(tester, surface, size);
          final before = _layout(tester);
          await tester.pump(const Duration(seconds: 3));
          expect(find.byKey(BannerFrame.adKey), findsOneWidget);
          expect(find.byKey(_TimedBanner.fill), findsNothing);
          // A quiet surface: the frame has no text in it.
          expect(
            find.descendant(
              of: find.byType(BannerFrame),
              matching: find.byType(Text),
            ),
            findsNothing,
          );
          expect(_layout(tester), before);
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  testWidgets('the reserved slot is as tall as the token says', (tester) async {
    final (_, ads) = await pump(tester, surfaces.first, const Size(390, 844));
    final frame = tester.getRect(find.byType(BannerFrame));
    expect(
      frame.height,
      closeTo(AdTokens.bannerSlotHeight + _gapOf(tester), 0.01),
    );
    ads.filled.value = true;
    await tester.pump();
    expect(tester.getRect(find.byType(BannerFrame)), frame);
    final ad = tester.getRect(find.byKey(BannerFrame.adKey));
    expect(ad.height, AdTokens.bannerAdHeight);
    expect(ad.width, AdTokens.bannerAdWidth);
  });

  testWidgets('ad-free mid-screen closes the place over an ease', (
    tester,
  ) async {
    final (container, _) = await pump(
      tester,
      surfaces.first,
      const Size(390, 844),
    );
    final start = find.byKey(HomeScreen.startButton);
    final startBefore = tester.getRect(start);
    expect(find.byKey(BannerFrame.adKey), findsOneWidget);

    container.read(_caps.notifier).state = _adFree;
    await container.read(economyCapabilitiesProvider.future);
    await tester.pump();
    // Mid-ease: the band is on its way out, not snapped away.
    await tester.pump(AdTokens.bannerCollapse ~/ 2);
    final during = tester.getRect(find.byType(WaitingBanner)).height;
    expect(during, greaterThan(0));
    expect(during, lessThan(AdTokens.bannerSlotHeight));

    await tester.pump(AdTokens.bannerCollapse);
    await tester.pump();
    expect(tester.getRect(find.byType(WaitingBanner)).height, 0);
    expect(find.byKey(BannerFrame.adKey), findsNothing);
    // Nothing is in its place any more, and the Start button went down into
    // the room the band gave back (it is bottom-anchored, never up).
    expect(tester.getRect(start).bottom, greaterThanOrEqualTo(startBefore.bottom));
  });

  testWidgets('capabilities not loaded yet: nothing is reserved', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        bannerAdsProvider.overrideWithValue(_TimedBanner()),
        onlineBackendFactoryProvider.overrideWithValue(
          () async => throw StateError('offline'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(playerProfileProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(ProfileScreen(onSaved: () {}, onBack: () {})),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(BannerFrame), findsNothing);
    expect(container.exists(economyCapabilitiesProvider), isFalse);
  });
}

double _gapOf(WidgetTester tester) {
  final padding = tester.widget<Padding>(
    find.descendant(
      of: find.byType(BannerFrame),
      matching: find.byType(Padding),
    ).first,
  );
  return (padding.padding as EdgeInsets).top;
}
