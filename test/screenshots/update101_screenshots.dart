/// Renders the new 1.0.1 screens (Council Life, Rewards, Play offers, the
/// web coin purchase flow, the online result screen, the lobby and Home)
/// for the owner to look at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `test/widget/council_screenshots.dart` and `test/widget/journey_screenshots.dart`,
/// whose fake-backend approach this file reuses: a [FakeBackend] with
/// capability responders that turn features on, real fonts and the real
/// asset bundle.
///
///     flutter test test/screenshots/update101_screenshots.dart
///
/// Writes to `build/screens101/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';
import 'package:mafia_master/platform/monetization/play_billing.dart';
import 'package:mafia_master/platform/monetization/purchase_store.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/economy/account_protection.dart' show accountServiceProvider;
import 'package:mafia_master/ui/economy/coin_packs.dart';
import 'package:mafia_master/ui/economy/cosmetic_art_cache.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/play_offers.dart';
import 'package:mafia_master/ui/fun/welcome_back.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';

import '../support/fake_backend.dart';
import '../support/fake_voice_engine.dart';
import '../support/localized.dart';

const _phone = Size(412, 915);

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

// ---------------------------------------------------------------------------
// Capability / economy fixtures — one dispatcher covers every screen, since
// every screen only reads the corner of the answer it cares about.
// ---------------------------------------------------------------------------

Map<String, dynamic> _caps({
  bool contracts = true,
  bool rank = true,
  bool leaderboard = true,
  bool invites = true,
  bool starterBundle = true,
  bool starterBundleOwned = false,
  bool daily = true,
  bool dailyAd = true,
  bool banner = true,
  bool extraSpin = true,
  bool extraCoffer = true,
  bool extraSwap = true,
  bool awards = true,
  bool reactions = true,
  bool recoverable = true,
  List<Map<String, Object?>> products = const [],
}) => {
  'version': 2,
  'adSteps': false,
  'daily': daily,
  'dailyAd': dailyAd,
  'recoverable': recoverable,
  'accountTag': 'a' * 64,
  'adFree': false,
  'purchaseDebt': 0,
  'interstitial': {'enabled': false},
  'products': products,
  'council': {
    'contracts': contracts,
    'rank': rank,
    'leaderboard': leaderboard,
    'invites': invites,
    'starterBundle': starterBundle,
    'starterBundleOwned': starterBundleOwned,
  },
  'ads': {
    'appOpen': {'enabled': false},
    'banner': {'enabled': banner},
    'extras': {'spin': extraSpin, 'coffer': extraCoffer, 'swap': extraSwap},
  },
  'fun': {'awards': awards, 'reactions': reactions, 'founder': true, 'known': true},
};

Map<String, dynamic> _contracts({bool weeklyClaimable = true, List<Map<String, Object?>> levelUps = const []}) => {
  'enabled': true,
  'day': '2026-09-26',
  'contracts': [
    {
      'slot': 0,
      'code': 'finish_1',
      'metric': 'finish',
      'target': 1,
      'progress': 1,
      'coins': 15,
      'claimed': false,
      'claimable': true,
    },
    {
      'slot': 1,
      'code': 'finish_mafia',
      'metric': 'mafia',
      'target': 1,
      'progress': 0,
      'coins': 30,
      'claimed': false,
      'claimable': false,
    },
    {
      'slot': 2,
      'code': 'reunion_1',
      'metric': 'reunion',
      'target': 1,
      'progress': 0,
      'coins': 25,
      'claimed': false,
      'claimable': false,
    },
  ],
  'bonus': {'coins': 30, 'claimed': false, 'done': 0},
  'weekly': {
    'week': '2026-W39',
    'target': 10,
    'progress': weeklyClaimable ? 10 : 4,
    'coins': 150,
    'xp': 150,
    'claimed': false,
    'claimable': weeklyClaimable,
  },
  'levelUps': levelUps,
};

Map<String, dynamic> _rank({int xp = 1250, int level = 8, List<Map<String, Object?>> levelUps = const []}) => {
  'enabled': true,
  'xp': xp,
  'level': level,
  'tier': 1,
  'levelXp': 100 * (level - 1) + 10 * (level - 1) * (level - 2),
  'nextLevelXp': 100 * level + 10 * level * (level - 1),
  'nextReward': 25,
  'weekXp': 90,
  'leaderboardVisible': true,
  'levelUps': levelUps,
};

Map<String, dynamic> _invite({bool canRedeem = true}) => {
  'enabled': true,
  'code': 'K7QM2XA',
  'inviterCoins': 100,
  'inviteeCoins': 50,
  'cap': 20,
  'rewarded': 3,
  'pending': 1,
  'redeemed': null,
  'canRedeem': canRedeem,
};

Map<String, dynamic> _leaderboard() => {
  'enabled': true,
  'week': '2026-W39',
  'entries': [
    for (var i = 1; i <= 8; i++)
      {
        'position': i,
        'xp': 1200 - i * 90,
        'name': ['ليلى', 'Omar', 'سلمى', 'Karim', 'نور', 'Yara', 'حسن', 'Mona'][i - 1],
        'gender': i.isEven ? 'male' : 'female',
        'level': 50 - i * 6,
        'me': i == 5,
      },
  ],
  'me': {'position': 5, 'xp': 750},
  'visible': true,
};

Map<String, dynamic> _daily({bool coffer = false, bool spun = false}) => {
  'enabled': true,
  'day': '2026-09-26',
  'coffer': {'claimed': coffer, 'amount': 20},
  'wheel': {
    'spun': spun,
    'slot': spun ? 2 : null,
    'amount': spun ? 35 : null,
    'prizes': [
      {'slot': 0, 'coins': 10, 'weight': 40, 'percent': '40.00'},
      {'slot': 1, 'coins': 20, 'weight': 30, 'percent': '30.00'},
      {'slot': 2, 'coins': 35, 'weight': 20, 'percent': '20.00'},
      {'slot': 3, 'coins': 60, 'weight': 8, 'percent': '8.00'},
      {'slot': 4, 'coins': 100, 'weight': 2, 'percent': '2.00'},
    ],
  },
  'week': {'progress': 3, 'length': 7, 'bonus': 60},
  'ad': {'enabled': true, 'amount': 25, 'state': 'available', 'inMatch': false},
};

Map<String, dynamic> _extras() => {
  'enabled': true,
  'day': '2026-09-26',
  'inMatch': false,
  'spin': {
    'enabled': true,
    'ready': true,
    'state': 'available',
    'prizes': [
      {'slot': 0, 'coins': 10, 'weight': 40, 'percent': '40.00'},
      {'slot': 1, 'coins': 20, 'weight': 30, 'percent': '30.00'},
      {'slot': 2, 'coins': 35, 'weight': 20, 'percent': '20.00'},
      {'slot': 3, 'coins': 60, 'weight': 8, 'percent': '8.00'},
      {'slot': 4, 'coins': 100, 'weight': 2, 'percent': '2.00'},
    ],
  },
  'coffer': {'enabled': true, 'ready': true, 'state': 'available', 'amount': 20},
  'swap': {'enabled': true, 'state': 'available'},
};

Map<String, dynamic> _awards({bool ready = true}) => ready
    ? {
        'enabled': true,
        'ready': true,
        'awards': [
          {'code': 'mvp', 'seats': [2], 'names': ['منى عبد الرحمن'], 'coins': 20},
          {'code': 'sharpEye', 'seats': [3], 'names': ['Karim'], 'coins': 10},
          {
            'code': 'survivor',
            'seats': [2, 3, 4, 5],
            'names': ['Mona', 'Karim', 'Laila', 'Omar'],
            'coins': 5,
          },
        ],
        'mine': ['mvp'],
        'granted': 20,
      }
    : {'enabled': true, 'ready': false, 'awards': []};

/// The single dispatcher every screen's `economy` responder is built from.
Map<String, dynamic> Function(Map<String, dynamic>) economyResponder({
  Map<String, dynamic>? caps,
  bool weeklyClaimable = true,
  List<Map<String, Object?>> rankLevelUps = const [],
  bool dailyCofferClaimed = false,
  bool dailyWheelSpun = false,
  bool awardsReady = true,
}) => (body) => switch (body['action']) {
  'capabilities' => caps ?? _caps(),
  'contracts_get' => _contracts(weeklyClaimable: weeklyClaimable),
  'rank_get' => _rank(levelUps: rankLevelUps),
  'invite_get' => _invite(),
  'leaderboard_get' => _leaderboard(),
  'daily_status' => _daily(coffer: dailyCofferClaimed, spun: dailyWheelSpun),
  'extras_status' => _extras(),
  'awards_get' => _awards(ready: awardsReady),
  'sync' => {'ok': true},
  _ => {'state': 'available', 'amount': 100},
};

// ---------------------------------------------------------------------------
// Small fakes for the ad / billing platform seams.
// ---------------------------------------------------------------------------

class _Ads implements RewardedAds {
  @override
  bool get configured => true;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> checkPrivacyOptions() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async => RewardedAdOutcome.earned;
  @override
  void dispose() {}
}

class _Banner implements BannerAds {
  @override
  bool get configured => true;
  @override
  Widget slot({Key? key, required String label, required double gap}) => Padding(
    padding: EdgeInsets.only(top: gap),
    child: Container(
      key: key,
      height: 50,
      alignment: Alignment.center,
      color: const Color(0xFF2A2A33),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ),
  );
}

class _Billing implements PlayBilling {
  @override
  bool get supported => true;
  @override
  Stream<StorePurchaseEvent> get events => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<bool> available() async => true;
  @override
  Future<Map<String, PlayListing>> listings(Set<String> ids) async => {
    for (final id in ids) id: PlayListing(id: id, title: id, price: 'EGP 79.99'),
  };
  @override
  Future<bool> buy(String productId, {required bool consumable, required String accountTag}) async => true;
  @override
  Future<void> restore() async {}
  @override
  Future<void> finishEntitlement(String token) async {}
  @override
  void dispose() {}
}

class _Accounts implements AccountService {
  @override
  Future<AccountStatus> status() async =>
      const AccountStatus(recoverable: true, email: 'p@example.test');
  @override
  Future<void> requestLink(String email) async {}
  @override
  Future<AccountStatus> confirmLink(String email, String code) async => status();
  @override
  Future<void> requestRecovery(String email) async {}
  @override
  Future<AccountStatus> confirmRecovery(String email, String code) => confirmLink(email, code);
}

/// Reports a room and a transport that already exist, skipping `host()`'s
/// own connect flow (see the comment where this is used).
class _FixedOnlineSession extends OnlineSession {
  final RoomHandle handle;
  final OnlineTransport transport;
  _FixedOnlineSession(this.handle, this.transport);

  @override
  OnlineSessionState build() {
    ref.onDispose(() {});
    return OnlineSessionState(room: handle, transport: transport);
  }
}

/// A `coin_orders` server with no order yet — the pack + method chooser.
class _CoinServer extends FakeBackend {
  _CoinServer() : super(roomId: 'r', state: roomState(phase: 'lobby'), players: roster(5));

  @override
  Future<Map<String, dynamic>> call(String function, Map<String, dynamic> body) async {
    if (function == 'economy') {
      calls.add(FakeCall(function, body));
      return {'balance': 340, 'catalog': [], 'owned': []};
    }
    if (function != 'coin_orders') return super.call(function, body);
    calls.add(FakeCall(function, body));
    if (body['action'] == 'shop') {
      return {
        'enabled': true,
        'recoverable': true,
        'packs': [
          {'code': 'coins_500', 'coins': 500, 'pricePiastres': 5000},
          {'code': 'coins_1200', 'coins': 1200, 'pricePiastres': 11000},
        ],
        'adFree': false,
        'methods': [
          {'code': 'instapay', 'available': true, 'url': 'https://pay.example/instapay/owner'},
          {'code': 'vodafone_cash', 'available': false},
        ],
        'orders': [],
      };
    }
    return {'ok': true};
  }
}

void main() {
  final out = Directory('build/screens101')..createSync(recursive: true);

  Future<void> save(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element)
            .timeout(const Duration(seconds: 2), onTimeout: () {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final image = boundary.toImageSync(pixelRatio: 2);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> surface(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// The plain path: a `FakeBackend`-backed screen, no online session.
  Future<void> show(
    WidgetTester tester,
    Widget child,
    Size size,
    Locale locale, {
    required FakeBackend backend,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    await surface(tester, size);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
            ...extraOverrides,
          ],
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: localizedApp(Scaffold(body: child), locale: locale),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  // --------------------------------------------------------------------
  // 1–2: the vault Council hub — contracts, rank card, weekly contract.
  // --------------------------------------------------------------------
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('council hub ${locale.languageCode}', (tester) async {
      final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
      backend.responders['economy'] = economyResponder();
      await show(tester, const CouncilHubTab(), _phone, locale, backend: backend);
      await save(tester, locale.languageCode == 'ar' ? '01-vault-council-hub-ar' : '02-vault-council-hub-en');
    });
  }

  // --------------------------------------------------------------------
  // 3: the leaderboard sheet.
  // --------------------------------------------------------------------
  testWidgets('leaderboard sheet', (tester) async {
    final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
    backend.responders['economy'] = economyResponder();
    await show(tester, const CouncilHubTab(), _phone, const Locale('ar'), backend: backend);
    await tester.tap(find.byKey(CouncilHubTab.leaderboardKey));
    await tester.pumpAndSettle();
    await save(tester, '03-leaderboard-sheet');
  });

  // --------------------------------------------------------------------
  // 4: the invite panel, standalone.
  // --------------------------------------------------------------------
  testWidgets('invite panel', (tester) async {
    final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
    backend.responders['economy'] = economyResponder();
    await show(
      tester,
      const Padding(padding: EdgeInsets.all(16), child: InviteCard()),
      _phone,
      const Locale('ar'),
      backend: backend,
    );
    await save(tester, '04-invite-panel');
  });

  // --------------------------------------------------------------------
  // 5: the level-up sheet, shown automatically once the hub opens.
  // --------------------------------------------------------------------
  testWidgets('level up sheet', (tester) async {
    final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
    backend.responders['economy'] = economyResponder(
      rankLevelUps: const [
        {'level': 8, 'coins': 25},
      ],
    );
    await show(tester, const CouncilHubTab(), _phone, const Locale('ar'), backend: backend);
    await save(tester, '05-level-up-sheet');
  });

  // --------------------------------------------------------------------
  // 6: the vault Rewards tab — the wheel plus the ad extras panel.
  // --------------------------------------------------------------------
  testWidgets('vault rewards tab', (tester) async {
    final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
    backend.responders['economy'] = economyResponder();
    // Taller than the phone frame: the wheel, the week card and the ad
    // extras panel all need to be in the one shot, and `DailyRewardsTab` is
    // a `ListView` — a 412×915 boundary would just clip it mid-scroll.
    await show(
      tester,
      const DailyRewardsTab(),
      const Size(412, 1900),
      const Locale('ar'),
      backend: backend,
      extraOverrides: [rewardedAdsProvider.overrideWithValue(_Ads())],
    );
    await save(tester, '06-vault-rewards-tab');
  });

  // --------------------------------------------------------------------
  // 7: the Play offers tab — Quiet Pass, coin packs, Starter Bundle.
  // --------------------------------------------------------------------
  testWidgets('play offers tab', (tester) async {
    final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
    backend.responders['economy'] = economyResponder(
      caps: _caps(
        products: const [
          {'id': 'mm_remove_interruptions', 'kind': 'entitlement'},
          {
            'id': 'mm_starter_bundle',
            'kind': 'bundle',
            'coins': 300,
            'item': 'frame_council_seal',
          },
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
          {'id': 'mm_coins_1200', 'kind': 'coins', 'coins': 1200},
        ],
      ),
    );
    await show(
      tester,
      const PlayOffersTab(),
      _phone,
      const Locale('ar'),
      backend: backend,
      extraOverrides: [playBillingProvider.overrideWithValue(_Billing())],
    );
    await save(tester, '07-play-offers-tab');
  });

  // --------------------------------------------------------------------
  // 8: the web coin purchase flow — pack and method choice, no order yet.
  // --------------------------------------------------------------------
  testWidgets('web coin purchase — method choice', (tester) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    await surface(tester, _phone);
    final backend = _CoinServer();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            accountServiceProvider.overrideWithValue(_Accounts()),
            paymentCapabilitiesProvider.overrideWithValue(const PaymentCapabilities(transfer: true)),
            externalLinkOpenerProvider.overrideWithValue((url) => true),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
          ],
          child: localizedApp(const Scaffold(body: CoinPacksTab()), locale: const Locale('ar')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await save(tester, '08-web-coin-purchase-method-choice');
  });

  // --------------------------------------------------------------------
  // 9: the online result screen — awards ribbon, reactions bar, rematch.
  // --------------------------------------------------------------------
  testWidgets('online result screen', (tester) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    // The phone frame: the result's hand scrolls and pins the rematch.
    await surface(tester, _phone);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(
        phase: 'result',
        phaseNumber: 2,
        status: 'finished',
        publicData: const {
          'outcome': 'town',
          'rosterSeats': [0, 1, 2, 3, 4],
          'standings': [
            {'seat': 0, 'role': 'mafia', 'eliminatedPhase': 'day', 'eliminatedNumber': 2},
            {'seat': 1, 'role': 'citizen', 'eliminatedPhase': 'night', 'eliminatedNumber': 1},
            {'seat': 2, 'role': 'doctor'},
            {'seat': 3, 'role': 'detective'},
            {'seat': 4, 'role': 'citizen'},
          ],
        },
      ),
      players: roster(5),
      own: const OwnSeat(seat: 2, role: 'doctor'),
      userId: 'u2',
    );
    backend.responders['economy'] = economyResponder();
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    // `gameTransportProvider` (lib/ui/screens/match_controller.dart) reads
    // `onlineSessionProvider`'s own transport rather than being overridable
    // directly — and `OnlineAwardsStrip`/`ReactionBar`/`CouncilResultStrip`
    // are all gated on `onlineSessionProvider`'s `room.roomId`. Going through
    // the real `host()` flow to get there hangs a widget test on a room
    // that starts out already finished (something in the connect/heartbeat
    // path never yields back without a real event loop), so the session is
    // fixed directly to the transport built above instead.
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
        // No periodic speaking-level sampler outliving the tree.
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
        onlineSessionProvider.overrideWith(
          () => _FixedOnlineSession(
            const RoomHandle(roomId: 'room-1', code: 'ABCDEF', seat: 2),
            transport,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await transport.dispose();
    });
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(
          container: container,
          // Hosted the way `MatchRoute` hosts it (lib/ui/screens/match_route.dart):
          // under a Scaffold, whose Material supplies the DefaultTextStyle. A
          // bare `OnlineTableFlow` drew every Text in the debug fallback style.
          child: localizedApp(
            const Scaffold(
              body: OnlineTableFlow(onExit: _noop, onAnalytics: _noop, onStepCommitted: _noop),
            ),
            locale: const Locale('ar'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    // `OnlineAwardsStrip` and `ReactionBar` read capabilities through
    // `loadedCapabilities`, which never starts that read itself (see
    // lib/ui/fun/loaded_capabilities.dart) — it only picks up once
    // `CouncilResultStrip`'s own post-frame read has gone through and a
    // further frame has rebuilt it, which several short pumps cover more
    // reliably than one long one.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await save(tester, '09-online-result-screen');
  });

  // --------------------------------------------------------------------
  // 10: the lobby — the waiting banner slot and the reactions bar.
  // --------------------------------------------------------------------
  testWidgets('lobby with waiting banner and reactions', (tester) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    seedReturningProfileLocal();
    await surface(tester, _phone);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    backend
      ..responses['browse_rooms'] = {'rooms': []}
      ..responses['create_room'] = {'roomId': 'room-1', 'code': 'ABCDEF'};
    backend.responders['economy'] = economyResponder();
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
        voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
        bannerAdsProvider.overrideWithValue(_Banner()),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerProfileProvider.future);
    await container.read(onlineSessionProvider.notifier).host('A');
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            LobbyScreen(onStarted: () {}, onLeave: () {}),
            locale: const Locale('ar'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await save(tester, '10-lobby');
  });

  // --------------------------------------------------------------------
  // 11: Home — the welcome-back card and the vault's attention dot.
  // --------------------------------------------------------------------
  testWidgets('home with welcome-back card and attention dot', (tester) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    final now = DateTime(2026, 9, 26, 20);
    SharedPreferences.setMockInitialValues({
      'community_rules_2026_09': true,
      ProfileStore.profileKey: '{"name":"A","gender":"male"}',
      welcomeBackLastSeenKey: now.subtract(const Duration(hours: 21)).millisecondsSinceEpoch,
    });
    await surface(tester, _phone);
    final backend = FakeBackend(roomId: 'room', state: roomState(phase: 'lobby'), players: roster(5));
    // Coffer unclaimed → the vault's attention dot lights up.
    backend.responders['economy'] = economyResponder(dailyCofferClaimed: false, dailyWheelSpun: false);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
            welcomeBackClockProvider.overrideWithValue(() => now),
          ],
          child: localizedApp(
            HomeScreen(
              onNewMatch: () {},
              onHistory: () {},
              onSettings: () {},
              onHowToPlay: () {},
              onProfile: () {},
              store: const CoinStoreButton(compact: true),
              banner: const WelcomeBackCard(),
              tiltSource: const LevelTiltSource(),
            ),
            locale: const Locale('ar'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await save(tester, '11-home');
  });

  // Note: no #12 "app-open launch veil" — `AppOpenAds` (see
  // lib/platform/monetization/ad_formats.dart) is a platform interface
  // around a native ad surface, not a Flutter widget in the render tree,
  // so there is nothing here to screenshot.
}

/// A minimal stand-in for `test/support/stores.dart`'s `seedReturningProfile`,
/// used only where a caller has already seeded its own preferences map and
/// only needs the onboarding/terms gates cleared without overwriting it.
void seedReturningProfileLocal() => SharedPreferences.setMockInitialValues({
  'community_rules_2026_09': true,
  ProfileStore.profileKey: '{"name":"A","gender":"male"}',
});

void _noop() {}
