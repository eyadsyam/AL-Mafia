/// Arabic Play listing art rendered from the real 1.1 widgets.
///
///     flutter test test/screenshots/store_listing_screenshots.dart
///
/// Writes eight 1080x1920 PNGs to `build/store_listing/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/economy/council.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/purchase_reveal.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/fun/welcome_back.dart';
import 'package:mafia_master/ui/missions/casebook_data.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:mafia_master/ui/screens/day/discussion_screen.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/casebook_fixture.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

// 1080x1920 at a common phone density (a 411 dp wide screen).
const _pixelRatio = 2.625;
const _logicalPhone = Size(1080 / _pixelRatio, 1920 / _pixelRatio);
const _names = ['سلمى', 'كريم', 'نور', 'يوسف', 'ليلى', 'حسن'];

class _Daily extends DailyController {
  @override
  Future<DailyStatus?> build() async => const DailyStatus(
    enabled: true,
    day: '2026-09-29',
    cofferClaimed: false,
    cofferAmount: 25,
    wheelSpun: false,
    wheelSlot: null,
    wheelAmount: null,
    prizes: [WheelPrize(0, 10, 40, '40%'), WheelPrize(1, 25, 30, '30%')],
    weekProgress: 4,
    weekLength: 7,
    weekBonus: 100,
    adEnabled: true,
    adAmount: 10,
    adState: 'available',
    inMatch: false,
  );
}

class _Wallet extends WalletController {
  @override
  Future<WalletState?> build() async => const WalletState(
    balance: 1450,
    catalog: [],
    owned: {'plate_ember'},
    equipped: {'nameplate': 'plate_ember'},
    history: [],
  );
}

class _Profile extends PlayerProfileController {
  @override
  Future<PlayerProfile?> build() async =>
      const PlayerProfile(name: 'سلمى', gender: PlayerGender.female);
}

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'IBM Plex Mono': 'assets/fonts/IBMPlexMono-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

List<RoomPlayer> _players({bool firstDead = false}) => [
  for (var seat = 0; seat < _names.length; seat++)
    RoomPlayer(
      userId: 'u$seat',
      seat: seat,
      name: _names[seat],
      alive: !(firstDead && seat == 0),
      cosmetics: SeatCosmetics(
        frame: seat.isEven ? 'frame_crimson' : 'frame_moonlit',
        plate: seat.isEven ? 'plate_ember' : 'plate_gilded',
      ),
    ),
];


void main() {
  final out = Directory('build/store_listing')..createSync(recursive: true);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    List<Override> overrides = const [],
    Future<void> Function(ProviderContainer)? prepare,
  }) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _logicalPhone * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    if (prepare != null) await prepare(container);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('store_listing_shot'),
        child: UncontrolledProviderScope(
          container: container,
          child: localizedApp(child, locale: const Locale('ar')),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 2), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));
    }
    // Entrance beats (the result card, the elimination beat) run past the
    // image warm-up; the listing shows the screen at rest.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('store_listing_shot')),
    );
    final image = boundary.toImageSync(pixelRatio: _pixelRatio);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(image.width, 1080);
    expect(image.height, 1920);
    image.dispose();
  }

  testWidgets('01 home with daily strip', (tester) async {
    await shoot(
      tester,
      '01_home_daily_ar',
      HomeScreen(
        onNewMatch: () {},
        onHistory: () {},
        onSettings: () {},
        onHowToPlay: () {},
        onProfile: () {},
        banner: const WelcomeBackCard(),
        tiltSource: const LevelTiltSource(),
      ),
      overrides: [
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        dailyProvider.overrideWith(_Daily.new),
        walletProvider.overrideWith(_Wallet.new),
        playerProfileProvider.overrideWith(_Profile.new),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => const EconomyCapabilities(daily: true),
        ),
      ],
      prepare: (container) async {
        await container.read(economyCapabilitiesProvider.future);
        await container.read(dailyProvider.future);
      },
    );
  });

  testWidgets('02 online table discussion', (tester) async {
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(
        phase: 'discuss',
        phaseNumber: 4,
        endsAt: DateTime.now().add(const Duration(minutes: 4)),
        serverNow: DateTime.now(),
      ),
      players: _players(),
      own: const OwnSeat(seat: 0, role: 'citizen'),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);
    await shoot(
      tester,
      '02_online_discussion_ar',
      Scaffold(
        body: OnlineTableFlow(
          onExit: () {},
          onAnalytics: () {},
          onStepCommitted: () {},
        ),
      ),
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
      prepare: (container) async {
        container.read(matchControllerProvider.notifier).adoptSnapshot();
      },
    );
  });

  testWidgets('03 dead witness news', (tester) async {
    // The real witness view: the viewer was killed on night 2 and now sits
    // at the table with every role and night choice open to them.
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(
        phase: 'discuss',
        phaseNumber: 6,
        endsAt: DateTime.now().add(const Duration(minutes: 3)),
        serverNow: DateTime.now(),
      ),
      players: _players(firstDead: true),
      own: const OwnSeat(seat: 0, role: 'citizen', alive: false),
    );
    backend.responders['witness_view'] = (_) => {
      'roles': [
        {'seat': 0, 'role': 'citizen'},
        {'seat': 1, 'role': 'mafia'},
        {'seat': 2, 'role': 'doctor'},
        {'seat': 3, 'role': 'detective'},
        {'seat': 4, 'role': 'citizen'},
        {'seat': 5, 'role': 'mafia'},
      ],
      'actions': [
        {'night': 2, 'seat': 1, 'action': 'kill', 'targetSeat': 0},
        {'night': 2, 'seat': 2, 'action': 'protect', 'targetSeat': 4},
        {'night': 2, 'seat': 3, 'action': 'investigate', 'targetSeat': 5},
      ],
      'whispers': const [],
    };
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);
    await shoot(
      tester,
      '03_witness_news_ar',
      Scaffold(
        body: OnlineTableFlow(
          onExit: () {},
          onAnalytics: () {},
          onStepCommitted: () {},
        ),
      ),
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => const EconomyCapabilities(witnessWhispers: true),
        ),
      ],
      prepare: (container) async {
        container.read(matchControllerProvider.notifier).adoptSnapshot();
      },
    );
  });

  testWidgets('04 casebook', (tester) async {
    await shoot(
      tester,
      '04_casebook_ar',
      const Scaffold(body: CasebookSheet(initialPage: 1)),
      overrides: [casebookProvider.overrideWith(FakeCasebookController.new)],
    );
  });

  testWidgets('05 vault purchase reveal', (tester) async {
    await shoot(
      tester,
      '05_vault_reveal_ar',
      Scaffold(
        body: SafeArea(
          child: PurchaseReveal(
            code: 'frame_crimson',
            onEquip: (_, _) async {},
          ),
        ),
      ),
      overrides: [
        walletProvider.overrideWith(_Wallet.new),
        playerProfileProvider.overrideWith(_Profile.new),
      ],
      prepare: (container) async {
        await container.read(walletProvider.future);
        await container.read(playerProfileProvider.future);
      },
    );
  });

  testWidgets('06 council leaderboard', (tester) async {
    final entries = [
      const LeaderboardEntry(
        position: 1,
        xp: 820,
        name: 'نور',
        gender: 'female',
        frame: 'frame_moonlit',
        plate: 'plate_gilded',
        level: 9,
        me: false,
      ),
      const LeaderboardEntry(
        position: 2,
        xp: 760,
        name: 'سلمى',
        gender: 'female',
        frame: 'frame_crimson',
        plate: 'plate_ember',
        level: 8,
        me: true,
      ),
      const LeaderboardEntry(
        position: 3,
        xp: 690,
        name: 'كريم',
        gender: 'male',
        frame: null,
        level: 7,
        me: false,
      ),
    ];
    await shoot(
      tester,
      '06_council_leaderboard_ar',
      const Scaffold(body: LeaderboardSheet()),
      overrides: [
        leaderboardProvider.overrideWith(
          (ref) async => Leaderboard(
            enabled: true,
            week: '2026-W40',
            entries: entries,
            myPosition: 2,
            myXp: 760,
            visible: true,
          ),
        ),
      ],
    );
  });

  testWidgets('07 tabletop discussion', (tester) async {
    await shoot(
      tester,
      '07_tabletop_discussion_ar',
      DiscussionScreen(
        mode: engine.DiscussionMode.free,
        alivePlayers: [
          for (var seat = 0; seat < 6; seat++)
            PublicPlayer(
              seat: seat,
              name: _names[seat],
              status: engine.PlayerStatus.alive,
            ),
        ],
        perSpeakerTime: const Duration(seconds: 30),
        totalTime: const Duration(minutes: 4),
        tabletop: true,
        onFinished: () {},
      ),
    );
  });

  testWidgets('08 result with progress card', (tester) async {
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'result', status: 'finished'),
      players: _players(),
    );
    backend.responders['economy'] = (body) {
      if (body['action'] == 'resultSummary') {
        return {
          'coins': {'granted': 35, 'balance': 1485},
          'rank': {
            'enabled': true,
            'xp': 760,
            'level': 8,
            'levelXp': 700,
            'nextLevelXp': 800,
            'weekXp': 180,
            'leaderboardVisible': true,
          },
          'contracts': {'enabled': false},
          'deltas': {'councilXp': 60},
        };
      }
      return const {'ok': true};
    };
    await shoot(
      tester,
      '08_result_progress_ar',
      ResultScreen(
        winner: engine.Alignment.town,
        rows: const [
          ResultRow(seat: 0, name: 'سلمى', role: engine.Role.detective),
          ResultRow(
            seat: 1,
            name: 'كريم',
            role: engine.Role.mafia,
            eliminatedLabel: 'اليوم التاني',
          ),
          ResultRow(seat: 2, name: 'نور', role: engine.Role.doctor),
        ],
        inventory: const CouncilResultStrip(roomId: 'room'),
        onHome: () {},
      ),
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => const EconomyCapabilities(
            council: CouncilCapabilities(rank: true, contracts: true),
          ),
        ),
      ],
    );
  });
}
