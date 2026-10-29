import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/enums.dart' as game;
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/delete_account_sheet.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/screens/day/discussion_screen.dart';
import 'package:mafia_master/ui/screens/day/vote_result_screen.dart';
import 'package:mafia_master/ui/screens/day/voting_screen.dart';
import 'package:mafia_master/ui/screens/distribution/role_reveal_screen.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/night/morning_screen.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_play_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_sheet.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/setup/store_shop.dart';
import 'package:mafia_master/ui/screens/setup/settings_sheet.dart';
import 'package:mafia_master/ui/screens/setup/bot_match_sheet.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/fun/characters_screen.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fake_voice_engine.dart';
import 'localized.dart';
import 'platform_channel_mocks.dart';

const longArabicName = 'عبد الرحمن المنشاوي ك';
const sweepSizes = <Size>[Size(360, 640), Size(390, 844), Size(640, 360)];

Future<void> loadSweepFonts() async {
  for (final font in <String, String>{
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Aref Ruqaa': 'assets/fonts/ArefRuqaa-Bold.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
  }
}

typedef SweepBuilder = Future<Widget> Function(WidgetTester tester);
typedef SweepAction = Future<void> Function(WidgetTester tester);

class SweepCase {
  const SweepCase(this.name, this.build, {this.action, this.banner = false});
  final String name;
  final SweepBuilder build;
  final SweepAction? action;
  final bool banner;
}

const _wallet = WalletState(
  balance: 500,
  catalog: [
    WalletItem(code: 'frame_gilded', price: 150, charge: 150,
      kind: 'cosmetic', slot: 'frame'),
  ],
  owned: {}, equipped: {}, history: [],
);

class _SweepWallet extends WalletController {
  @override
  Future<WalletState?> build() async => _wallet;
}

class _SweepFriends extends FriendsController {
  @override
  Future<FriendsState?> build() async => FriendsState.fromJson({
    'friends': [
      {'id': 'friend-1', 'name': longArabicName, 'gender': 'female',
        'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4}},
      {'id': 'friend-2', 'name': '$longArabicName ٢', 'gender': 'male'},
    ],
  });

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> invite(String id, String roomId) async => true;
}

Future<Widget> _plain(Widget child) async {
  final backend = FakeBackend(
    roomId: 'sweep',
    state: roomState(phase: 'lobby'),
    players: roster(7),
  )..responses['browse_rooms'] = {'rooms': []};
  return ProviderScope(
    overrides: [
      walletProvider.overrideWith(_SweepWallet.new),
      friendsProvider.overrideWith(_SweepFriends.new),
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      onlineHeartbeatProvider.overrideWithValue(Duration.zero),
      voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
    ],
    child: localizedApp(child),
  );
}

Future<Widget> _sheet(Widget child) async => _plain(
  Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => child,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<Widget> _offline(WidgetTester tester, Widget child, String phase) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final controller = container.read(matchControllerProvider.notifier);
  controller.startMatch(
    names: List.generate(7, (i) => '$longArabicName ${i + 1}'),
    roleCounts: const {
      Role.mafia: 2,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 3,
    },
    settings: const MatchSettings(),
    seed: 7,
  );
  if (phase == 'night' || phase == 'vote') {
    while (controller.engine.match.phase == GamePhase.distributing) {
      controller.engine.revealFor(controller.engine.match.currentActorSeat!);
      controller.engine.confirmRevealed();
    }
    controller.adoptMatch(controller.engine.match);
    controller.beginNight();
    if (phase == 'night') {
      await controller.openActorTurn();
    } else {
      while (controller.engine.match.currentActorSeat != null) {
        controller.engine.skipNightAction(
          seat: controller.engine.match.currentActorSeat!,
        );
      }
      controller.engine.resolveNight();
      controller.engine.beginDiscussion();
      controller.engine.beginVoting();
      controller.adoptMatch(controller.engine.match);
    }
  }
  return UncontrolledProviderScope(
    container: container,
    child: localizedApp(child),
  );
}

Future<Widget> _online(WidgetTester tester, Widget child, String phase) async {
  final witness = phase == 'witness';
  final backend = FakeBackend(
    roomId: 'room-1',
    state: roomState(
      phase: witness ? 'discussion' : phase,
      phaseNumber: phase == 'lobby' ? 0 : 2,
      status: phase == 'lobby' ? 'lobby' : 'playing',
    ),
    players: [
      for (var i = 0; i < 7; i++)
        RoomPlayer(
          userId: 'u$i',
          seat: i,
          name: '$longArabicName ${i + 1}',
          alive: !witness || i != 0,
          lastSeen: DateTime.now(),
        ),
    ],
    own: OwnSeat(seat: 0, role: 'citizen', alive: !witness),
  );
  if (witness) {
    backend.responses['witness_view'] = {
      'roles': [
        for (var i = 0; i < 7; i++)
          {'seat': i, 'role': i == 1 ? 'mafia' : 'citizen'},
      ],
      'actions': <Object>[],
      'whispers': <Object>[],
    };
  }
  backend.responses['create_room'] = {'roomId': 'room-1', 'code': 'ABCDEF'};
  final transport = await OnlineTransport.connect(
    backend: backend,
    roomId: 'room-1',
    heartbeatInterval: Duration.zero,
  );
  final container = ProviderContainer(
    overrides: [
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      onlineHeartbeatProvider.overrideWithValue(Duration.zero),
      audioDirectorProvider.overrideWithValue(AudioDirector()),
      voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
      onlineSessionProvider.overrideWith(() => _SweepSession(transport)),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await transport.dispose();
  });
  if (phase != 'lobby') {
    container.read(matchControllerProvider.notifier).adoptSnapshot();
  }
  return UncontrolledProviderScope(
    container: container,
    child: localizedApp(Scaffold(body: child)),
  );
}

class _SweepSession extends OnlineSession {
  _SweepSession(this.transport);
  final OnlineTransport transport;
  @override
  OnlineSessionState build() => OnlineSessionState(
    room: const RoomHandle(roomId: 'room-1', code: 'ABCDEF', seat: 0),
    transport: transport,
  );
}

List<SweepCase> sweepCases() => [
  SweepCase(
    '00_home',
    (_) => _plain(
      HomeScreen(
        onNewMatch: () {},
        onHistory: () {},
        onSettings: () {},
        onHowToPlay: () {},
      ),
    ),
    banner: true,
  ),
  SweepCase(
    '01_mode',
    (_) => _plain(
      ModeScreen(
        onPlayOffline: () {},
        onPlayOnline: () {},
        onPlayBots: () {},
        onPlayStories: () {},
        onBack: () {},
      ),
    ),
  ),
  SweepCase(
    '02_settings',
    (_) => _plain(
      SettingsScreen(
        initial: const MatchSettings(),
        onSave: (_) {},
        onBack: () {},
      ),
    ),
  ),
  SweepCase(
    '03_players',
    (_) => _plain(
      AddPlayersScreen(
        initialNames: List.generate(7, (i) => '$longArabicName ${i + 1}'),
        onNext: (_) {},
        onBack: () {},
      ),
    ),
  ),
  SweepCase(
    '04_roles',
    (_) => _plain(RolesScreen(playerCount: 7, onNext: (_) {}, onBack: () {})),
  ),
  SweepCase(
    '05_profile',
    (_) => _plain(ProfileScreen(onBack: () {})),
    banner: true,
  ),
  SweepCase(
    '06_history',
    (_) => _plain(HistoryScreen(onOpen: (_) {}, onBack: () {})),
    banner: true,
  ),
  SweepCase(
    '07_help',
    (_) => _plain(HowToPlayScreen(onBack: () {}, onStartMatch: () {})),
  ),
  SweepCase('08_first_run', (_) => _plain(const FirstRunScreen())),
  SweepCase(
    '09_characters',
    (_) => _plain(CharactersScreen(onBack: () {})),
    banner: true,
  ),
  SweepCase(
    '10_online_entry',
    (_) => _plain(OnlineEntryScreen(onJoined: () {}, onBack: () {})),
    banner: true,
  ),
  SweepCase('11_coin_store', (_) => _plain(const CoinStore()), banner: true),
  SweepCase(
    '12_lobby',
    (t) => _online(t, LobbyScreen(onStarted: () {}, onLeave: () {}), 'lobby'),
    banner: true,
  ),
  SweepCase(
    '13_online_table',
    (t) => _online(
      t,
      OnlineTableFlow(
        onExit: () {},
        onAnalytics: () {},
        onStepCommitted: () {},
      ),
      'discussion',
    ),
  ),
  SweepCase(
    '14_distribution',
    (t) => _offline(
      t,
      RoleRevealScreen(onDistributionComplete: () {}),
      'distribution',
    ),
  ),
  SweepCase(
    '15_night',
    (t) => _offline(t, NightActionScreen(onNightComplete: () {}), 'night'),
  ),
  SweepCase(
    '16_morning',
    (_) => _plain(
      MorningScreen(
        dayNumber: 2,
        victimName: longArabicName,
        someoneSavedUnnamed: false,
        tabletop: true,
        onContinue: () {},
      ),
    ),
  ),
  SweepCase(
    '17_discussion',
    (_) => _plain(
      DiscussionScreen(
        mode: DiscussionMode.structured,
        alivePlayers: List.generate(
          7,
          (i) => PublicPlayer(
            seat: i,
            name: '$longArabicName ${i + 1}',
            status: PlayerStatus.alive,
          ),
        ),
        perSpeakerTime: const Duration(minutes: 1),
        tabletop: true,
        onFinished: () {},
      ),
    ),
  ),
  SweepCase(
    '18_vote',
    (t) => _offline(t, VotingScreen(onVotingComplete: () {}), 'vote'),
  ),
  SweepCase(
    '19_vote_result',
    (_) => _plain(
      VoteResultScreen(
        names: const {0: longArabicName, 1: longArabicName},
        tally: const {0: 1, 1: 2},
        eliminatedSeat: 1,
        eliminatedRole: Role.citizen,
        tabletop: true,
        onContinue: () {},
      ),
    ),
  ),
  SweepCase(
    '20_result',
    (_) => _plain(
      ResultScreen(
        winner: game.Alignment.town,
        rows: const [
          ResultRow(
            seat: 0,
            name: longArabicName,
            role: Role.detective,
            eliminatedLabel: 'كمل للآخر',
          ),
          ResultRow(
            seat: 1,
            name: longArabicName,
            role: Role.mafia,
            eliminatedLabel: 'اليوم التاني',
          ),
        ],
        tabletop: true,
        onHome: () {},
      ),
    ),
  ),
  SweepCase(
    '21_settings_sheet',
    (_) => _sheet(const SettingsSheetBody()),
    action: _openSheet,
  ),
  SweepCase(
    '22_account_sheet',
    (_) => _sheet(const AccountSheet()),
    action: _openSheet,
  ),
  SweepCase(
    '23_friends_sheet',
    (_) => _sheet(FriendsSheet(onJoin: (_) {})),
    action: _openSheet,
  ),
  SweepCase(
    '24_bot_sheet',
    (_) => _plain(
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
    ),
    action: _openSheet,
  ),
  SweepCase(
    '25_help_sheet',
    (_) => _plain(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showHowToSheet(context, onVideo: () {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
    action: _openSheet,
  ),
  SweepCase(
    '26_council_hub',
    (_) => _plain(const Scaffold(body: CouncilHubTab())),
  ),
  SweepCase(
    '27_stories_hub',
    (_) => _plain(StoriesScreen(onBack: () {})),
    banner: true,
  ),
  SweepCase(
    '28_casebook_sheet',
    (_) => _sheet(const CasebookSheet()),
    action: _openSheet,
  ),
  SweepCase(
    '29_store_shop',
    (_) => _plain(
      Scaffold(
        body: StoreShop(
          wallet: _wallet,
          busy: ValueNotifier(false),
          alive: () => true,
          onEquip: (CosmeticSlot slot, String? code) async {},
        ),
      ),
    ),
  ),
  SweepCase(
    '30_witness',
    (t) => _online(
      t,
      OnlineTableFlow(
        onExit: () {},
        onAnalytics: () {},
        onStepCommitted: () {},
      ),
      'witness',
    ),
  ),
  SweepCase(
    '31_online_council',
    (t) => _online(
      t,
      OnlineTableFlow(
        onExit: () {},
        onAnalytics: () {},
        onStepCommitted: () {},
      ),
      'voting',
    ),
  ),
  SweepCase(
    '32_delete_account_sheet',
    (_) => _sheet(const DeleteAccountSheet()),
    action: _openSheet,
  ),
  SweepCase(
    '33_level_up_sheet',
    (_) => _sheet(const LevelUpSheet(level: 3, coins: 100)),
    action: _openSheet,
  ),
  SweepCase(
    '34_store_item_sheet',
    (_) => _sheet(
      StoreItemSheet(
        code: 'frame_gilded',
        busy: ValueNotifier(false),
        onBuy: (_, _) async => null,
        onEquip: (_, _) async {},
      ),
    ),
    action: _openSheet,
  ),
];

Future<void> prepareSweep(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  installPlatformChannelMocks();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpSweepCase(
  WidgetTester tester,
  SweepCase item,
  Size size,
) async {
  await prepareSweep(tester, size);
  final child = await item.build(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('shot'),
      child: item.banner
          ? Column(
              children: [
                Expanded(child: child),
                const SizedBox(height: 50),
              ],
            )
          : child,
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
  if (item.action != null) await item.action!(tester);
  await tester.pump(const Duration(milliseconds: 250));
}
