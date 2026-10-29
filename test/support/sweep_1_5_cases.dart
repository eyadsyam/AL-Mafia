import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/update_gate.dart';
import 'package:mafia_master/app/router.dart' show Routes;
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/enums.dart' as game;
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/delete_account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart'
    show accountsAvailableProvider;
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
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
import 'package:mafia_master/ui/screens/setup/before_start_sheet.dart';
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
import 'package:mafia_master/ui/theme/design_tokens.dart' show AdTokens;
import 'package:mafia_master/ui/social/titles_partner.dart';
import 'package:mafia_master/ui/fun/characters_screen.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fake_voice_engine.dart';
import 'localized.dart';
import 'platform_channel_mocks.dart';
import 'reveal_flow.dart';

/// A real 20-character Arabic name (the longest a player can type).
const longArabicName = 'عبدالرحمن محمد السيد';

/// Distinct 20-character names, so a roster never repeats one.
const sweepNames = <String>[
  'عبدالرحمن محمد السيد',
  'أحمد عبدالعزيز حسنين',
  'محمود عبدالقادر سالم',
  'مصطفى عبدالحميد علاء',
  'إبراهيم عبدالمنعم زكي',
  'ياسمين عبدالفتاح نور',
  'فاطمة عبدالسلام حسني',
  'سلمى عبدالرحيم خليلة',
];

List<String> sweepRoster(int n) => [for (var i = 0; i < n; i++) sweepNames[i]];

const sweepSizes = <Size>[Size(360, 640), Size(390, 844), Size(640, 360)];

Future<void> loadSweepFonts() async {
  for (final font in <String, String>{
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Aref Ruqaa': 'assets/fonts/ArefRuqaa-Bold.ttf',
    'IBM Plex Mono': 'assets/fonts/IBMPlexMono-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
  }
}

typedef SweepBuilder = Future<Widget> Function(WidgetTester tester);
typedef SweepAction = Future<void> Function(WidgetTester tester);

class SweepCase {
  const SweepCase(
    this.name,
    this.build, {
    this.action,
    this.banner = false,
    this.prefs,
  });
  final String name;
  final SweepBuilder build;
  final SweepAction? action;

  /// A 50 dp band is kept under the screen where a banner sits today.
  final bool banner;

  /// Initial shared preferences; null means a player with a 20-character name.
  final Map<String, Object>? prefs;
}

const _wallet = WalletState(
  balance: 500,
  catalog: [
    WalletItem(
      code: 'frame_gilded',
      price: 150,
      charge: 150,
      kind: 'cosmetic',
      slot: 'frame',
    ),
  ],
  owned: {},
  equipped: {},
  history: [],
);

class _SweepWallet extends WalletController {
  @override
  Future<WalletState?> build() async => _wallet;
}

final _friendsSample = FriendsState.fromJson({
  'friends': [
    {
      'id': 'friend-1',
      'name': sweepNames[1],
      'gender': 'female',
      'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4},
    },
    {
      'id': 'friend-2',
      'name': sweepNames[2],
      'gender': 'male',
      'presence': {'state': 'playing'},
    },
    {'id': 'friend-3', 'name': sweepNames[3]},
  ],
  'incoming': [
    {'id': 'r1', 'name': sweepNames[4]},
    {'id': 'r2', 'name': 'منى'},
  ],
  'outgoing': <Object>[],
  'recent': [
    {'id': 'e', 'name': sweepNames[5], 'matches': 3},
  ],
  'invites': <Object>[],
  'me': {'handle': 'karim', 'searchable': true, 'strangerInvites': true},
});

class _SweepFriends extends FriendsController {
  @override
  Future<FriendsState?> build() async => _friendsSample;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> respond(String id, bool accept) async {}

  @override
  Future<bool> invite(String id, String roomId) async => true;
}

class _SweepHub extends TitleHubController {
  @override
  Future<TitleHub> build() async => TitleHub.fromJson({
    'enabled': true,
    'equipped': 'kabir_elshella',
    'titles': [
      {
        'code': 'kabir_elshella',
        'source': 'invite',
        'nameAr': 'الشبح',
        'nameEn': 'The Ghost',
        'owned': true,
      },
    ],
  });
}

class _MemCache implements UpdatePolicyCache {
  @override
  Future<UpdatePolicy?> load() async => null;
  @override
  Future<void> save(UpdatePolicy policy) async {}
}

FakeBackend? _lastBackend;

/// The real app draws every page under a Material; a bare page here would get
/// the debug yellow underline on all its text.
Widget _material(Widget child) =>
    Material(type: MaterialType.transparency, child: child);

/// Runs an online table through its entrance beats (the curtain, the phase
/// light, the narration) so the shot is the settled screen.
Future<void> _settleTable(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 12));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _settleLong(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// A screen that has already asked the server, as the real app has.
class _Asked extends ConsumerWidget {
  const _Asked({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(economyCapabilitiesProvider);
    ref.watch(friendsProvider);
    ref.watch(titleHubProvider);
    return child;
  }
}

const _allCaps = EconomyCapabilities(
  friends: true,
  titles: true,
  daily: true,
  fun: FunCapabilities(awards: true, reactions: true, known: true),
);

Future<Widget> _plain(Widget child) async {
  final backend = FakeBackend(
    roomId: 'sweep',
    state: roomState(phase: 'lobby'),
    players: roster(7),
  )..responses['browse_rooms'] = {'rooms': []};
  _lastBackend = backend;
  return ProviderScope(
    overrides: [
      walletProvider.overrideWith(_SweepWallet.new),
      friendsProvider.overrideWith(_SweepFriends.new),
      titleHubProvider.overrideWith(_SweepHub.new),
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      onlineHeartbeatProvider.overrideWithValue(Duration.zero),
      voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
    ],
    child: localizedApp(_material(child)),
  );
}

/// The profile page with everything the real one has: a signed-in or guest
/// account, friends, titles, three numbers and the history row.
Future<Widget> _profile({bool signedIn = false}) async {
  final account = signedIn
      ? AccountProfile(
          signedIn: true,
          email: 'abdelrahman.elmenshawy.k@gmail.com',
          emailConfirmed: true,
          google: true,
          password: true,
          since: DateTime(2026, 9, 1),
        )
      : AccountProfile.guest;
  final backend = FakeBackend(
    roomId: 'sweep',
    state: roomState(phase: 'lobby'),
    players: roster(7),
  );
  _lastBackend = backend;
  return ProviderScope(
    overrides: [
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      accountsAvailableProvider.overrideWithValue(true),
      accountProfileProvider.overrideWith((ref) => Stream.value(account)),
      economyCapabilitiesProvider.overrideWith((ref) async => _allCaps),
      friendsProvider.overrideWith(_SweepFriends.new),
      walletProvider.overrideWith(_SweepWallet.new),
      titleHubProvider.overrideWith(_SweepHub.new),
      profileStatsProvider.overrideWith((ref) async => (12, 5)),
      profileLastMatchProvider.overrideWith(
        (ref) async => DateTime(2026, 10, 28, 20),
      ),
      profileClockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 12)),
    ],
    child: localizedApp(
      _Asked(
        child: ProfileScreen(
          onBack: () {},
          onSaved: () {},
          onHistory: () {},
          onCharacters: () {},
          onJoinRoom: (_) {},
        ),
      ),
    ),
  );
}

/// Runs frames long enough for a sheet to finish its entrance, without
/// waiting for animations that never end.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

SweepAction _tapThenSettle(Key key) => (tester) async {
  await tester.tap(find.byKey(key));
  await _settle(tester);
};

typedef SheetLauncher = Future<void> Function(BuildContext c, WidgetRef ref);

/// A bare page with one button that opens [show]: the sheet is drawn by the
/// same launcher the app uses, so its landscape form is the real one.
Future<Widget> _launcher(SheetLauncher show) => _plain(
  Scaffold(
    body: Consumer(
      builder: (context, ref, _) => Center(
        child: TextButton(
          onPressed: () => show(context, ref),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<void> _openLauncher(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await _settle(tester);
}

Future<Widget> _offline(WidgetTester tester, Widget child, String phase) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final controller = container.read(matchControllerProvider.notifier);
  controller.startMatch(
    names: sweepRoster(7),
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
    child: localizedApp(_material(child)),
  );
}

const _resultPublic = {
  'outcome': 'town',
  'rosterSeats': [0, 1, 2, 3, 4, 5, 6],
  'standings': [
    {'seat': 0, 'role': 'mafia'},
    {'seat': 1, 'role': 'citizen'},
    {'seat': 2, 'role': 'doctor'},
    {'seat': 3, 'role': 'detective'},
    {'seat': 4, 'role': 'citizen'},
    {'seat': 5, 'role': 'mafia'},
    {'seat': 6, 'role': 'citizen'},
  ],
};

Map<String, dynamic> _economy(Map<String, dynamic> body) =>
    switch (body['action']) {
      'capabilities' => {
        'version': 2,
        'fun': {'awards': true, 'reactions': true, 'known': true},
      },
      'awards_get' => {
        'enabled': true,
        'ready': true,
        'awards': [
          {
            'code': 'mvp',
            'seats': [2],
            'names': [sweepNames[2]],
            'coins': 20,
          },
          {
            'code': 'sharpEye',
            'seats': [3],
            'names': [sweepNames[3]],
            'coins': 10,
          },
          {
            'code': 'survivor',
            'seats': [2, 3, 4],
            'names': [sweepNames[2], sweepNames[3], sweepNames[4]],
            'coins': 5,
          },
        ],
        'mine': ['mvp'],
        'granted': 20,
      },
      _ => {'ok': true},
    };

/// An online room. [phase] is a room phase, or `witness` (a dead viewer
/// reading the table). [role] is the viewer's own role.
Future<Widget> _online(
  WidgetTester tester,
  Widget child,
  String phase, {
  String role = 'citizen',
  List<String> teammates = const [],
  bool reactions = false,
}) async {
  final witness = phase == 'witness';
  final result = phase == 'result';
  final backend = FakeBackend(
    roomId: 'room-1',
    state: roomState(
      phase: witness ? 'discussion' : phase,
      phaseNumber: phase == 'lobby' ? 0 : 2,
      status: phase == 'lobby'
          ? 'lobby'
          : result
          ? 'finished'
          : 'playing',
      publicData: result ? _resultPublic : const {},
    ),
    players: [
      for (var i = 0; i < 7; i++)
        RoomPlayer(
          userId: 'u$i',
          seat: i,
          name: sweepNames[i],
          alive: !witness || i != 0,
          lastSeen: DateTime.now(),
        ),
    ],
    own: OwnSeat(
      seat: result ? 2 : 0,
      role: result ? 'doctor' : role,
      alive: !witness,
      teammateNames: teammates,
    ),
    userId: result ? 'u2' : 'u0',
  );
  _lastBackend = backend;
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
  if (reactions) backend.responders['economy'] = _economy;
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
      friendsProvider.overrideWith(_SweepFriends.new),
      onlineSessionProvider.overrideWith(
        () => _SweepSession(transport, result ? 2 : 0),
      ),
      if (reactions)
        economyCapabilitiesProvider.overrideWith((ref) async => _allCaps),
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
    child: localizedApp(
      Consumer(
        builder: (context, ref, inner) {
          if (reactions) ref.watch(economyCapabilitiesProvider);
          return inner!;
        },
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _SweepSession extends OnlineSession {
  _SweepSession(this.transport, this.seat);
  final OnlineTransport transport;
  final int seat;
  @override
  OnlineSessionState build() => OnlineSessionState(
    room: RoomHandle(roomId: 'room-1', code: 'ABCDEF', seat: seat),
    transport: transport,
  );
}

OnlineTableFlow _table() =>
    OnlineTableFlow(onExit: () {}, onAnalytics: () {}, onStepCommitted: () {});

/// Seals arriving for one seat, the same kind three times in a row: one float
/// with ×3, then another seat's.
Future<void> _reactions(WidgetTester tester) async {
  final feed = _lastBackend!.reactionFeed;
  for (var id = 1; id <= 3; id++) {
    feed.add(RoomReactionRow(id: id, seat: 3, kind: 'laugh'));
  }
  feed.add(const RoomReactionRow(id: 4, seat: 5, kind: 'rose'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<Widget> _updateGate(UpdatePolicy policy) async => ProviderScope(
  overrides: [
    updatePolicyFetchProvider.overrideWithValue(() async => policy),
    updatePolicyCacheProvider.overrideWithValue(_MemCache()),
    updateSurfaceProvider.overrideWithValue(UpdateSurface.android),
    appBuildNumberProvider.overrideWithValue(10),
  ],
  child: localizedApp(
    UpdateGate(
      currentPath: () => Routes.home,
      routeChanges: ValueNotifier<String>(Routes.home),
      child: HomeScreen(
        onNewMatch: () {},
        onHistory: () {},
        onSettings: () {},
        onHowToPlay: () {},
      ),
    ),
  ),
);

Map<String, Object> _noProfile() => <String, Object>{};

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
        storiesSoon: true,
        onBack: () {},
      ),
    ),
    action: _settleLong,
    banner: true,
  ),
  SweepCase(
    '01a_mode_stories_hidden',
    (_) => _plain(
      ModeScreen(
        onPlayOffline: () {},
        onPlayOnline: () {},
        onPlayBots: () {},
        onBack: () {},
      ),
    ),
    action: _settleLong,
    banner: true,
  ),
  SweepCase(
    '01b_mode_stories_open',
    (_) => _plain(
      ModeScreen(
        onPlayOffline: () {},
        onPlayOnline: () {},
        onPlayBots: () {},
        onPlayStories: () {},
        onBack: () {},
      ),
    ),
    action: _settleLong,
    banner: true,
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
        initialNames: sweepRoster(7),
        onNext: (_) {},
        onBack: () {},
      ),
    ),
  ),
  SweepCase(
    '04_roles',
    (_) => _plain(RolesScreen(playerCount: 7, onNext: (_) {}, onBack: () {})),
  ),
  SweepCase('05_profile', (_) => _profile(), banner: true),
  SweepCase(
    '05b_profile_signed_in',
    (_) => _profile(signedIn: true),
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
  SweepCase(
    '08_first_run',
    (_) => _plain(const FirstRunScreen()),
    action: _settleLong,
    prefs: _noProfile(),
  ),
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
    action: _settleLong,
    banner: true,
  ),
  SweepCase(
    '12b_lobby_reactions',
    (t) => _online(
      t,
      LobbyScreen(onStarted: () {}, onLeave: () {}),
      'lobby',
      reactions: true,
    ),
    action: (tester) async {
      await _settleLong(tester);
      await _reactions(tester);
    },
    banner: true,
  ),
  SweepCase(
    '13_online_table',
    (t) => _online(t, _table(), 'discussion'),
    action: _settleTable,
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
    '14b_distribution_gate_done',
    (t) => _offline(
      t,
      RoleRevealScreen(onDistributionComplete: () {}),
      'distribution',
    ),
    action: (tester) => tester.confirmIdentity(),
  ),
  SweepCase(
    '14c_distribution_flipped',
    (t) => _offline(
      t,
      RoleRevealScreen(onDistributionComplete: () {}),
      'distribution',
    ),
    action: (tester) async {
      await tester.confirmIdentity();
      await tester.swipeToFlip();
    },
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
        alivePlayers: [
          for (var i = 0; i < 7; i++)
            PublicPlayer(
              seat: i,
              name: sweepNames[i],
              status: PlayerStatus.alive,
            ),
        ],
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
        names: {0: sweepNames[0], 1: sweepNames[1]},
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
        rows: [
          ResultRow(
            seat: 0,
            name: sweepNames[0],
            role: Role.detective,
            eliminatedLabel: 'كمل للآخر',
          ),
          ResultRow(
            seat: 1,
            name: sweepNames[1],
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
    (_) => _launcher((c, _) => showSettingsSheet(c)),
    action: _openLauncher,
  ),
  SweepCase(
    '22_account_sheet',
    (_) => _launcher((c, _) => showAccountSheet(c)),
    action: _openLauncher,
  ),
  SweepCase(
    '22b_account_signup',
    (_) =>
        _launcher((c, _) => showAccountSheet(c, initial: AccountStep.signUp)),
    action: _openLauncher,
  ),
  SweepCase(
    '22c_account_signin',
    (_) =>
        _launcher((c, _) => showAccountSheet(c, initial: AccountStep.signIn)),
    action: _openLauncher,
  ),
  SweepCase(
    '23_friends_sheet',
    (_) => _profile(),
    action: _tapThenSettle(ProfileScreen.friendsKey),
  ),
  SweepCase(
    '23b_friends_invite_sheet',
    (_) => _launcher(
      (c, _) => showFriendsSheet(c, onJoin: (_) {}, inviteRoomId: 'room-1'),
    ),
    action: _openLauncher,
  ),
  SweepCase(
    '24_bot_sheet',
    (_) => _launcher((c, _) => showBotMatchSheet(c)),
    action: _openLauncher,
  ),
  SweepCase(
    '25_help_sheet',
    (_) => _launcher((c, _) => showHowToSheet(c, onVideo: () {})),
    action: _openLauncher,
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
    (_) => _launcher((c, _) => showCasebookSheet(c)),
    action: _openLauncher,
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
    (t) => _online(t, _table(), 'witness'),
    action: _settleTable,
  ),
  SweepCase(
    '31_online_council',
    (t) => _online(t, _table(), 'voting'),
    action: _settleTable,
  ),
  SweepCase(
    '32_delete_account_sheet',
    (_) => _launcher((c, _) => showDeleteAccountSheet(c)),
    action: _openLauncher,
  ),
  SweepCase(
    '33_level_up_sheet',
    (_) => _launcher(
      (c, _) => showModalBottomSheet<void>(
        context: c,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const LevelUpSheet(level: 3, coins: 100),
      ),
    ),
    action: _openLauncher,
  ),
  SweepCase(
    '34_store_item_sheet',
    (_) => _launcher(
      (c, ref) => showStoreItemSheet(
        context: c,
        ref: ref,
        code: 'frame_gilded',
        busy: ValueNotifier(false),
        alive: () => true,
        onEquip: (_, _) async {},
      ),
    ),
    action: _openLauncher,
  ),
  SweepCase(
    '35_titles_sheet',
    (_) => _profile(),
    action: _tapThenSettle(ProfileScreen.titlesKey),
  ),
  SweepCase(
    '36_identity_sheet',
    (_) => _profile(),
    action: _tapThenSettle(ProfileIdentityHeader.headerKey),
  ),
  SweepCase(
    '37_before_start_sheet',
    (_) => _launcher((c, _) => showBeforeStartSheet(c)),
    action: _openLauncher,
  ),
  SweepCase(
    '38_update_soft',
    (_) => _updateGate(
      const UpdatePolicy(min: MinBuild(android: 0, web: 0), latestAndroid: 20),
    ),
    action: _settle,
  ),
  SweepCase(
    '39_update_hard',
    (_) => _updateGate(
      const UpdatePolicy(min: MinBuild(android: 20, web: 0), latestAndroid: 20),
    ),
    action: _settle,
  ),
  SweepCase(
    '40_online_night_citizen',
    (t) => _online(t, _table(), 'night'),
    action: _settleTable,
  ),
  SweepCase(
    '41_online_night_doctor',
    (t) => _online(t, _table(), 'night', role: 'doctor'),
    action: _settleTable,
  ),
  SweepCase(
    '42_online_night_mafia',
    (t) => _online(
      t,
      _table(),
      'night',
      role: 'mafia',
      teammates: [sweepNames[5]],
    ),
    action: _settleTable,
  ),
  SweepCase(
    '43_online_morning',
    (t) => _online(t, _table(), 'morning'),
    action: _settleTable,
  ),
  SweepCase(
    '44_online_result',
    (t) => _online(t, _table(), 'result', reactions: true),
    action: _settleTable,
  ),
  SweepCase(
    '45_online_result_reactions',
    (t) => _online(t, _table(), 'result', reactions: true),
    action: (tester) async {
      await _settleTable(tester);
      await _reactions(tester);
    },
  ),
];

/// One line saying what went wrong and which widget did it: the overflow
/// amount (or the message) and the widget Flutter blames.
String describeSweepError(FlutterErrorDetails details) {
  final text = details.toString(minLevel: DiagnosticLevel.debug);
  final lines = text.split('\n').map((l) => l.trim()).toList();
  final overflow = lines.indexWhere((l) => l.contains('overflowed by'));
  final where = RegExp(r'lib/[^\s:]+\.dart:\d+').firstMatch(text)?.group(0);
  return [
    if (overflow >= 0) lines[overflow] else details.exceptionAsString(),
    if (where != null) 'at $where',
  ].join(' ');
}

Future<void> prepareSweep(
  WidgetTester tester,
  Size size,
  Map<String, Object>? prefs,
) async {
  SharedPreferences.setMockInitialValues(
    prefs ??
        {ProfileStore.profileKey: '{"name":"$longArabicName","gender":"male"}'},
  );
  installPlatformChannelMocks();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The height the shell banner band reserves on a waiting surface (WP4): the
/// large anchored adaptive banner (about a quarter of the width in portrait,
/// never under the reserved floor; a shallow 60 on its side) plus the band's
/// air above and below it. The band is there empty or filled, so the sweep
/// always keeps it.
double sweepBannerBand(Size size) {
  final ad = size.width > size.height
      ? 60.0
      : math.max(AdTokens.bannerAdaptiveFloor, size.width * 0.27);
  return ad + 2 * AdTokens.bannerBandPad;
}

Future<void> pumpSweepCase(
  WidgetTester tester,
  SweepCase item,
  Size size,
) async {
  await prepareSweep(tester, size, item.prefs);
  final child = await item.build(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('shot'),
      child: item.banner
          ? Column(
              children: [
                Expanded(child: child),
                SizedBox(height: sweepBannerBand(size)),
              ],
            )
          : child,
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
  if (item.action != null) await item.action!(tester);
  await tester.pump(const Duration(milliseconds: 250));
}
