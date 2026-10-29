import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/app/router.dart' show Routes;
import 'package:mafia_master/app/update_gate.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/ui/economy/banner_frame.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/shell_banner_host.dart';
import 'package:mafia_master/ui/economy/waiting_banner.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/stores.dart';

/// WP4 part B: the one shell banner. A fake stands in for the Google ad: it
/// keeps its state for the host's lifetime, counts its loads, and draws the
/// real shared band frame.
class _FakeShell implements ShellBannerAds {
  int loads = 0;
  int mounts = 0;

  @override
  bool get configured => true;

  @override
  Widget band({Key? key, required String label, required bool visible}) =>
      _FakeBand(key: key, label: label, visible: visible, owner: this);
}

class _FakeBand extends StatefulWidget {
  final String label;
  final bool visible;
  final _FakeShell owner;
  const _FakeBand({
    super.key,
    required this.label,
    required this.visible,
    required this.owner,
  });

  @override
  State<_FakeBand> createState() => _FakeBandState();
}

class _FakeBandState extends State<_FakeBand> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    widget.owner.mounts++;
  }

  @override
  Widget build(BuildContext context) {
    // Like the real band: asks once, the first time it is shown.
    if (widget.visible && !_asked) {
      _asked = true;
      widget.owner.loads++;
    }
    if (!widget.visible) return const SizedBox.shrink();
    return ShellBandFrame(
      label: widget.label,
      ad: const SizedBox.expand(key: ValueKey('fake_shell_ad')),
    );
  }
}

const _bannerOn = EconomyCapabilities(ads: AdsCapabilities(banner: true));
const _bandHeight = AdTokens.bannerBandHeight;
const _bodyKey = ValueKey('body');

class _Harness {
  final ProviderContainer container;
  final _FakeShell ads;
  final ValueNotifier<String> path;
  _Harness(this.container, this.ads, this.path);
}

void main() {
  setUp(seedReturningProfile);
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  Future<_Harness> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    String path = Routes.home,
    BannerMode mode = BannerMode.shell,
    EconomyCapabilities caps = _bannerOn,
    Widget? home,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final ads = _FakeShell();
    final where = ValueNotifier<String>(path);
    addTearDown(where.dispose);
    final container = ProviderContainer(
      overrides: [
        shellBannerAdsProvider.overrideWithValue(ads),
        bannerAdsProvider.overrideWithValue(_PerScreenFake()),
        economyCapabilitiesProvider.overrideWith((ref) async => caps),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    addTearDown(container.dispose);
    container.read(bannerModeProvider.notifier).state = mode;
    container.read(playerProfileProvider);
    await container.read(economyCapabilitiesProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MafiaTheme.dark,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => ShellBannerHost(
            currentPath: () => where.value,
            routeChanges: where,
            child: child!,
          ),
          home: home ?? const Scaffold(body: SizedBox.expand(key: _bodyKey)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return _Harness(container, ads, where);
  }

  final band = find.byKey(ShellBandFrame.adKey);

  testWidgets('shows the band on Home and shortens the body by its height', (
    tester,
  ) async {
    await pump(tester);
    expect(band, findsOneWidget);
    final body = tester.getRect(find.byKey(_bodyKey));
    expect(body.bottom, 844 - _bandHeight);
    final ad = tester.getRect(band);
    expect(ad.top, greaterThanOrEqualTo(body.bottom));
    expect(ad.bottom, lessThanOrEqualTo(844));
    expect(ad.height, AdTokens.bannerAdHeight);
  });

  testWidgets('going to History and back does not load a new ad', (
    tester,
  ) async {
    final h = await pump(tester);
    expect(h.ads.loads, 1);
    h.path.value = Routes.history;
    await tester.pump();
    await tester.pump();
    expect(band, findsOneWidget);
    h.path.value = Routes.home;
    await tester.pump();
    await tester.pump();
    expect(band, findsOneWidget);
    expect(h.ads.loads, 1);
    expect(h.ads.mounts, 1);
  });

  testWidgets('hiding on a match route and coming back never reloads', (
    tester,
  ) async {
    final h = await pump(tester);
    h.path.value = Routes.match;
    await tester.pump();
    await tester.pump();
    expect(band, findsNothing);
    expect(
      tester.getRect(find.byKey(_bodyKey)),
      const Rect.fromLTWH(0, 0, 390, 844),
    );
    h.path.value = Routes.mode;
    await tester.pump();
    await tester.pump();
    expect(band, findsOneWidget);
    expect(h.ads.loads, 1);
    expect(h.ads.mounts, 1);
  });

  testWidgets('no band on any in-match or pass-the-phone route', (
    tester,
  ) async {
    final h = await pump(tester);
    for (final path in const [
      Routes.match,
      Routes.players,
      Routes.roles,
      Routes.settings,
      Routes.groups,
      Routes.analytics,
      Routes.howToPlay,
      Routes.onboarding,
      '/history/7',
    ]) {
      h.path.value = path;
      await tester.pump();
      await tester.pump();
      expect(band, findsNothing, reason: path);
      expect(
        tester.getRect(find.byKey(_bodyKey)),
        const Rect.fromLTWH(0, 0, 390, 844),
        reason: path,
      );
    }
  });

  testWidgets('the band is the same for every seat: it reads the path only', (
    tester,
  ) async {
    // Doc 05: nothing here can see a role. The only input besides the path
    // is the player's own ad-free state, which no other seat can observe on
    // a match screen, because there is no band on one.
    for (final path in const [
      Routes.match,
      '/match/night',
      '/match/day',
      '/match/vote',
      '/match/result',
    ]) {
      expect(shellBannerRoute(path), isFalse, reason: path);
    }
    for (final path in const [
      Routes.home,
      Routes.profile,
      Routes.characters,
      Routes.mode,
      Routes.online,
      Routes.lobby,
      Routes.history,
      '/join/ABC123',
    ]) {
      expect(shellBannerRoute(path), isTrue, reason: path);
    }
    expect(shellBannerRoute('/history/3'), isFalse);
  });

  testWidgets('the band is gone while the keyboard is open', (tester) async {
    final h = await pump(tester);
    expect(band, findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    expect(band, findsNothing);
    tester.view.resetViewInsets();
    await tester.pump();
    await tester.pump();
    expect(band, findsOneWidget);
    expect(h.ads.loads, 1);
  });

  testWidgets('a bottom sheet opens above the band, not over it', (
    tester,
  ) async {
    await pump(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(
                  key: ValueKey('sheet'),
                  height: 200,
                  width: double.infinity,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    final bandTop = tester.getRect(band).top;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
    expect(sheet.bottom, lessThanOrEqualTo(bandTop));
    expect(band, findsOneWidget);
  });

  testWidgets('Home keeps its layout and WaitingBanner draws nothing', (
    tester,
  ) async {
    await pump(
      tester,
      home: HomeScreen(
        onNewMatch: () {},
        onHistory: () {},
        onSettings: () {},
        onHowToPlay: () {},
        tiltSource: const LevelTiltSource(),
      ),
    );
    expect(find.byType(WaitingBanner), findsOneWidget);
    expect(find.byType(BannerFrame), findsNothing);
    expect(band, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(640, 360)]) {
    testWidgets('Home with the band: no overflow at $size', (tester) async {
      await pump(
        tester,
        size: size,
        home: HomeScreen(
          onNewMatch: () {},
          onHistory: () {},
          onSettings: () {},
          onHowToPlay: () {},
          tiltSource: const LevelTiltSource(),
        ),
      );
      expect(band, findsOneWidget);
      expect(tester.takeException(), isNull);
      final body = tester.getRect(find.byType(HomeScreen));
      expect(body.bottom, size.height - _bandHeight);
    });
  }

  testWidgets('per_screen mode: the host adds no band', (tester) async {
    await pump(tester, mode: BannerMode.perScreen);
    expect(band, findsNothing);
    expect(
      tester.getRect(find.byKey(_bodyKey)),
      const Rect.fromLTWH(0, 0, 390, 844),
    );
  });

  testWidgets('an ad-free player gets no band', (tester) async {
    await pump(
      tester,
      caps: const EconomyCapabilities(
        ads: AdsCapabilities(banner: true),
        adFree: true,
      ),
    );
    expect(band, findsNothing);
  });

  testWidgets('the lobby on a phone on its side has no band', (tester) async {
    await pump(tester, size: const Size(640, 360), path: Routes.lobby);
    expect(band, findsNothing);
  });
}

class _PerScreenFake implements BannerAds {
  @override
  bool get configured => true;

  @override
  Widget slot({
    Key? key,
    required String label,
    required double gap,
    BannerPlacement placement = BannerPlacement.lobby,
  }) => BannerFrame(key: key, label: label, gap: gap, ad: null);
}
