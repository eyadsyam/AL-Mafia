import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/player_group.dart';
import '../data/player_group_provider.dart';
import '../data/repository_provider.dart';
import '../data/online_session_store.dart';
import '../data/player_profile.dart';
import '../engine/models/enums.dart' show Role;
import '../engine/models/match_settings.dart';
import '../platform/audio_director.dart';
import '../ui/economy/interstitial_coordinator.dart';
import '../ui/fun/welcome_back.dart';
import '../ui/l10n_ext.dart';
import '../ui/screens/admin/payments_admin_screen.dart';
import '../ui/screens/match_controller.dart';
import '../ui/screens/match_route.dart';
import '../ui/screens/onboarding/first_run_screen.dart';
import '../ui/screens/onboarding/onboarding_video_screen.dart';
import '../ui/screens/online/lobby_screen.dart';
import '../ui/screens/online/online_entry_screen.dart';
import '../ui/screens/online/online_session.dart';
import '../ui/screens/postgame/analytics_screen.dart';
import '../ui/screens/postgame/history_screen.dart';
import '../ui/screens/setup/add_players_screen.dart';
import '../ui/screens/setup/coin_store.dart';
import '../ui/screens/setup/group_picker_screen.dart';
import '../ui/screens/setup/home_screen.dart';
import '../ui/screens/setup/profile_screen.dart';
import '../ui/screens/setup/mode_screen.dart';
import '../ui/screens/setup/how_to_play_screen.dart';
import '../ui/screens/setup/roles_screen.dart';
import '../ui/screens/setup/settings_screen.dart';
import '../ui/screens/setup/setup_draft.dart';
import '../ui/fun/characters_screen.dart';

/// Route paths, in one place so navigation calls cannot drift from the table.
abstract final class Routes {
  static const home = '/';
  static const profile = '/profile';
  static const characters = '/characters';
  static const mode = '/mode';
  static const groups = '/setup/groups';
  static const players = '/setup/players';
  static const roles = '/setup/roles';
  static const settings = '/setup/settings';
  static const defaults = '/settings';
  static const match = '/match';
  static const analytics = '/analytics';
  static const history = '/history';
  static const howToPlay = '/how-to-play';
  static const onboarding = '/onboarding';

  /// The owner's transfer review queue. A URL, not a secret: the server
  /// refuses every admin action to anyone outside commerce_admins.
  static const adminCoins = '/admin/coins';

  /// The owner's payment review page (Payments v2; web only, in no menu).
  /// The Telegram notice links to `/admin?order=<id>`.
  static const admin = '/admin';
  static const online = '/online';
  static const lobby = '/online/lobby';

  /// Where a room invite lands (doc 12 §3.1).
  ///
  /// The scheme's host is dropped by go_router, which matches on the path — so
  /// `mafiamaster://online/join/K7M2QP` arrives here as `/join/K7M2QP`.
  static const joinByLink = '/join/:code';

  /// That path, for a given code.
  static String joinLink(String code) => '/join/${code.toUpperCase()}';

  /// Analytics for a stored match.
  static String storedAnalytics(int id) => '/history/$id';
}

/// Where the system back control goes from [location], or null where it is
/// the platform's to answer (Home, and the match, which holds its own
/// [PopScope]).
///
/// Every screen navigates with `go`, which replaces the page rather than
/// stacking it, so the Navigator has nothing to pop and an Android back
/// gesture anywhere — the mode choice, the online door, the room settings
/// sheet's parent — used to finish the activity and drop the player on the
/// launcher. This mirrors each screen's own back control, so the two agree.
/// The lobby goes back to the online door *without* leaving the room: the
/// seat is kept, and the door offers to resume it, exactly as a browser
/// refresh does.
String? systemBackTarget(String location, {bool hasGroups = true}) {
  if (location == Routes.mode) return Routes.home;
  if (location == Routes.online) return Routes.mode;
  if (location == Routes.lobby) return Routes.online;
  if (RegExp(r'^/join/[^/]+$').hasMatch(location)) return Routes.online;
  if (location == Routes.profile ||
      location == Routes.characters ||
      location == Routes.defaults ||
      location == Routes.history ||
      location == Routes.analytics ||
      location == Routes.onboarding ||
      location == Routes.groups) {
    return Routes.home;
  }
  if (RegExp(r'^/history/\d+$').hasMatch(location)) return Routes.history;
  if (location == Routes.players)
    return hasGroups ? Routes.groups : Routes.home;
  if (location == Routes.roles) return Routes.players;
  if (location == Routes.settings) return Routes.roles;
  return null;
}

/// Builds the app's router.
///
/// Takes a [WidgetRef] rather than reading providers inside each builder so
/// that the setup steps can hand their results straight to the draft and the
/// engine. Routes stay dumb; the screens they host stay reusable in tests
/// without a router at all.
String _safeReturn(String? route) {
  if (route == Routes.online ||
      (route != null && RegExp(r'^/join/[A-Za-z0-9]{6}$').hasMatch(route)))
    return route!;
  return Routes.home;
}

void _previewAudio(WidgetRef ref, MatchSettings settings) {
  ref.read(audioDirectorProvider)
    ..scoreEnabled = settings.scoreEnabled
    ..narrationEnabled = settings.narrationEnabled
    ..muted = settings.muteAllAudio
    ..syncScore();
}

GoRouter buildRouter(
  WidgetRef ref, {
  GlobalKey<NavigatorState>? navigatorKey,

  /// Where this launch starts. Only a test passes it: it is the one way to
  /// model an app opened *by* an invite link rather than one that navigated to
  /// the link after it was already running, and those are different flows —
  /// the first has the whole of onboarding standing between the code and the
  /// room it belongs to.
  String? initialLocation,
}) {
  // Set while the pass-and-play deal ad is being considered, so a second
  // tap cannot start a second match underneath it.
  var dealing = false;

  // Set while a forward menu move waits on the session ad, so a second tap
  // cannot navigate underneath it.
  var forwarding = false;

  /// A menu control moving *forward* to another menu screen: the session ad
  /// (Ads v3), if one is due, is shown first and the move follows. Back
  /// controls and the system back use plain `go` and never show an ad.
  Future<void> forwardTo(BuildContext context, String to) async {
    if (forwarding) return;
    forwarding = true;
    try {
      await ref.read(interstitialCoordinatorProvider).beforeMenuNavigation(to);
    } finally {
      forwarding = false;
    }
    if (!context.mounted) return;
    context.go(to);
  }

  Future<void> startMatch(BuildContext context) async {
    final draft = ref.read(setupDraftProvider);
    final roleCounts = draft.roleCounts;
    if (roleCounts == null || dealing) return;

    // Ads v3 (phase 110): the one pass-and-play ad before a match comes
    // here — setup confirmed, no role dealt yet, nobody holding the phone.
    // Preloaded-or-skip: never waits for a load.
    dealing = true;
    try {
      await ref.read(interstitialCoordinatorProvider).beforeDeal();
    } finally {
      dealing = false;
    }
    if (!context.mounted) return;

    ref
        .read(matchControllerProvider.notifier)
        .startMatch(
          names: draft.names,
          genders: draft.genders,
          roleCounts: roleCounts,
          settings: draft.settings,
        );

    // A group that just started a match gets its play count bumped and its
    // configuration remembered, which is what makes the *next* rematch a
    // three-tap affair. Deliberately not awaited: a database write must never
    // sit between the host tapping start and the first card appearing.
    final group = draft.group;
    if (group != null && group.isSaved) {
      ref
          .read(playerGroupsProvider.notifier)
          .recordPlayed(
            group.id,
            roleCounts: roleCounts,
            settings: draft.settings,
          );
    }

    context.go(Routes.match);
  }

  /// The saved groups, as already loaded. Never awaited here — see
  /// [playerGroupsProvider] for why a synchronous read is the right shape and
  /// why "not loaded yet" degrades to today's behaviour rather than to a stall.
  List<PlayerGroup> loadedGroups() =>
      ref.read(playerGroupsProvider).valueOrNull ?? const [];

  /// Begin the one-phone game: clear the draft and go wherever this host's
  /// history says. Shared by the mode picker and by every "play offline
  /// instead" offer on the online screens, so the two never drift into
  /// landing in different places.
  void goOffline(BuildContext context) {
    ref.read(setupDraftProvider.notifier).resetForNewMatch();
    // First run, or a host who has never saved anyone, goes exactly where
    // they always went. The picker only exists once there is something in it
    // to pick.
    context.go(loadedGroups().isEmpty ? Routes.players : Routes.groups);
  }

  /// Start a match on a group's remembered configuration, skipping the roles
  /// and settings screens entirely. This is the third tap of a rematch.
  Future<void> quickStart(BuildContext context, List<String> names) async {
    final group = ref.read(setupDraftProvider).group;
    final roleCounts = group?.lastRoleCounts;
    final settings = group?.lastSettings;
    // The players screen only offers the action when both exist and still fit
    // the head count; this is the belt to that braces.
    if (roleCounts == null || settings == null) return;

    ref.read(setupDraftProvider.notifier)
      ..setNames(names)
      ..setRoleCounts(roleCounts)
      ..setSettings(settings);
    await startMatch(context);
  }

  return GoRouter(
    // Exposed so app-level overlays (the resume prompt) can reach a context
    // that is *below* the Navigator. `MaterialApp.builder` runs above it, and
    // `showDialog` from there throws.
    navigatorKey: navigatorKey,
    // Debug affordance so a screen can be opened directly for screenshotting:
    //   flutter run --dart-define=START_ROUTE=/history
    // `String.fromEnvironment` is resolved at compile time and defaults to
    // Home, so a release build has no way to start anywhere else.
    initialLocation:
        initialLocation ??
        (kDebugMode
            ? const String.fromEnvironment(
                'START_ROUTE',
                defaultValue: Routes.home,
              )
            : Routes.home),
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => SetupRequired(
          child: HomeScreen(
            // Play now asks which of the two games this is, rather than starting
            // one of them and offering the other in smaller type.
            onNewMatch: () => forwardTo(context, Routes.mode),
            onHistory: () => forwardTo(context, Routes.history),
            onSettings: () => forwardTo(context, Routes.defaults),
            onHowToPlay: () => context.go(Routes.onboarding),
            onProfile: () => forwardTo(context, Routes.profile),
            onCharacters: () => forwardTo(context, Routes.characters),
            store: SupabaseConfig.isConfigured
                ? const CoinStoreButton(compact: true)
                : null,
            banner: const WelcomeBackCard(),
          ),
        ),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => ProfileScreen(
          onSaved: () => context.go(Routes.home),
          onBack: () => context.go(Routes.home),
          onCharacters: () => forwardTo(context, Routes.characters),
        ),
      ),
      // The Four Dossiers (1.1.0): public, outside any match.
      GoRoute(
        path: Routes.characters,
        builder: (context, state) => CharactersScreen(
          initial: Role.values
              .where((r) => r.name == state.uri.queryParameters['role'])
              .firstOrNull,
          // Pushed from a result: back returns to it. Otherwise, Home.
          onBack: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
      ),
      // S-01a. Both answers are the same size, and online is offered whether
      // or not this build has a project — a card that explains itself is
      // something a player can act on, and a card that is not there is not.
      GoRoute(
        path: Routes.mode,
        builder: (context, state) => SetupRequired(
          child: ModeScreen(
            onPlayOffline: () => goOffline(context),
            onPlayOnline: SupabaseConfig.isConfigured
                ? () => forwardTo(context, Routes.online)
                : null,
            onBack: () => context.go(Routes.home),
          ),
        ),
      ),
      // The online front door. Doc 12 §9's four cards used to stand in front
      // of it on the first online match of a run; they are in the how-to-play
      // screen now (task 11c), which is where somebody looking for them would
      // have gone anyway — and this is one fewer screen between a player and a
      // friend who is already in a room.
      GoRoute(
        path: Routes.online,
        builder: (context, state) => SetupRequired(
          child: OnlineEntryScreen(
            onJoined: () => context.go(Routes.lobby),
            onBack: () => context.go(Routes.mode),
          ),
        ),
      ),
      // A room invite, opened from wherever the host pasted it. The code is
      // pre-filled and nothing else happens: the joiner still types their name
      // and still taps join, because a link that seated somebody automatically
      // would be a link anybody could send them.
      GoRoute(
        path: Routes.joinByLink,
        builder: (context, state) => SetupRequired(
          child: OnlineEntryScreen(
            initialCode: state.pathParameters['code'],
            onJoined: () => context.go(Routes.lobby),
            onBack: () => context.go(Routes.mode),
          ),
        ),
      ),
      GoRoute(
        path: Routes.lobby,
        // The lobby is a view of a session. Reached without one — a browser
        // refresh keeps the URL and drops the session — it used to paint an
        // empty room: no code, no seats, «مستني المسؤول» to the host itself.
        // The entry screen is where the seat is taken back.
        redirect: (context, state) =>
            ref.read(onlineSessionProvider).isInRoom ? null : Routes.online,
        builder: (context, state) => LobbyScreen(
          onStarted: () {
            // The state is already there — it arrived from the server before
            // this screen did. The controller adopts it rather than starting
            // anything, which is the whole difference between the two modes at
            // this point in the flow.
            ref.read(matchControllerProvider.notifier).adoptSnapshot();
            context.go(Routes.match);
          },
          onLeave: () => context.go(Routes.home),
        ),
      ),
      GoRoute(
        path: Routes.howToPlay,
        builder: (context, state) => HowToPlayScreen(
          onBack: () =>
              context.go(_safeReturn(state.uri.queryParameters['next'])),
          onStartMatch: () =>
              context.go(_safeReturn(state.uri.queryParameters['next'])),
        ),
      ),
      // One cinematic introduction, followed by the concise rules reference.
      // First launch and Home's help control intentionally share this path.
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) {
          void finishIntro() {
            ref.read(matchRepositoryProvider).markOnboardingSeen();
            ref.read(profileStoreProvider).markIntroSeen();
            context.go(
              Uri(
                path: Routes.howToPlay,
                queryParameters: {
                  'next': _safeReturn(state.uri.queryParameters['next']),
                },
              ).toString(),
            );
          }

          // Setup first (language before a single word of the tutorial);
          // the tutorial stays skippable and skipping it skips nothing else.
          return SetupRequired(
            child: OnboardingVideoScreen(onFinished: finishIntro),
          );
        },
      ),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => PaymentsAdminScreen(
          focusOrder: state.uri.queryParameters['order'],
          onBack: () => context.go(Routes.home),
        ),
      ),
      GoRoute(
        path: Routes.adminCoins,
        redirect: (context, state) => Routes.admin,
      ),
      GoRoute(
        path: Routes.groups,
        builder: (context, state) => GroupPickerScreen(
          onSelect: (group) {
            ref.read(setupDraftProvider.notifier).setGroup(group);
            context.go(Routes.players);
          },
          onNewGroup: () {
            ref.read(setupDraftProvider.notifier).setGroup(null);
            context.go(Routes.players);
          },
          onBack: () => context.go(Routes.home),
          onEmpty: () {
            // The last group has just been deleted. Detaching it matters:
            // without this the roster screen renders in group mode against a
            // group that no longer exists — the deleted names pre-filled, an
            // "ابدأ فوراً" offering to play it, and a match-end prompt that
            // would write the group back into the database it was deleted from.
            ref.read(setupDraftProvider.notifier).setGroup(null);
            context.go(Routes.players);
          },
        ),
      ),
      GoRoute(
        path: Routes.players,
        builder: (context, state) {
          final group = ref.read(setupDraftProvider).group;
          return AddPlayersScreen(
            // Seating order, exactly as saved. Not sorted, not deduplicated,
            // not touched.
            initialNames:
                group?.memberNames ?? ref.read(setupDraftProvider).names,
            initialGenders: {
              ...?group?.genders,
              ...ref.read(setupDraftProvider).genders,
            },
            onGendersChanged: ref.read(setupDraftProvider.notifier).setGenders,
            group: group,
            savedGroups: loadedGroups(),
            onNext: (names) {
              ref.read(setupDraftProvider.notifier).setNames(names);
              context.go(Routes.roles);
            },
            onQuickStart: (names) => quickStart(context, names),
            onSaveGroup: (names) => _saveNewGroup(ref, context, names),
            onBack: () => context.go(
              loadedGroups().isEmpty ? Routes.home : Routes.groups,
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.roles,
        builder: (context, state) {
          final names = ref.read(setupDraftProvider).names;
          // Deep-linking here without names would crash the balance guard;
          // send the host back to the step that produces them.
          if (names.length < 5) return const _RedirectHome();
          return RolesScreen(
            playerCount: names.length,
            onNext: (counts) {
              ref.read(setupDraftProvider.notifier).setRoleCounts(counts);
              context.go(Routes.settings);
            },
            onBack: () => context.go(Routes.players),
          );
        },
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) {
          final draft = ref.read(setupDraftProvider);
          return SettingsScreen(
            initial: draft.settings,
            onAudioPreview: (settings) => _previewAudio(ref, settings),
            // Doc 13 5. The preset row needs the table it is being picked for:
            // the three shapes differ on the Mafia ratio, and a ratio with no
            // count behind it is not a split.
            playerCount: draft.names.length,
            roleCounts: draft.roleCounts,
            onRoleCounts: (counts) =>
                ref.read(setupDraftProvider.notifier).setRoleCounts(counts),
            onSave: (settings) {
              ref.read(setupDraftProvider.notifier).setSettings(settings);
              // These become the defaults for the next match too (FR-005).
              ref.read(matchRepositoryProvider).saveDefaultSettings(settings);
              unawaited(startMatch(context));
            },
            onBack: () => context.go(Routes.roles),
          );
        },
      ),
      // The same screen, reached from Home, editing only the stored defaults.
      GoRoute(
        path: Routes.defaults,
        builder: (context, state) => _DefaultSettingsRoute(ref: ref),
      ),
      GoRoute(
        path: Routes.match,
        // A match lives in memory. On the web a refresh — or a link typed
        // straight to `/match` — arrives here with nothing to show, and the
        // flow rendered an empty scaffold with a close button in the corner.
        // An online room the server still holds is reachable again from the
        // online entry (the resume pointer offers it there); an offline match
        // is offered by the resume gate on Home. Either way, not a blank.
        redirect: (context, state) async {
          if (ref.read(matchControllerProvider) != null) return null;
          if (ref.read(onlineSessionProvider).isInRoom) return null;
          final resume = await OnlineSessionStore.load();
          return resume != null ? Routes.online : Routes.home;
        },
        builder: (context, state) => MatchRoute(
          onExit: () => context.go(Routes.home),
          onAnalytics: () => context.go(Routes.analytics),
          onRematch: () => context.go(Routes.online),
        ),
      ),
      GoRoute(
        path: Routes.analytics,
        builder: (context, state) =>
            LiveAnalyticsScreen(onClose: () => context.go(Routes.home)),
      ),
      GoRoute(
        path: Routes.history,
        builder: (context, state) => HistoryScreen(
          onOpen: (id) => forwardTo(context, Routes.storedAnalytics(id)),
          onBack: () => context.go(Routes.home),
        ),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) => StoredAnalyticsScreen(
          matchId: int.parse(state.pathParameters['id']!),
          onClose: () => context.go(Routes.history),
        ),
      ),
    ],
  );
}

/// Asks for a name, saves [names] as a new group, and attaches it to the draft.
///
/// Attaching matters: the host said "remember these people" and then played
/// with them, so this match is that group's first, and the configuration it
/// ends up with is what makes the next rematch a three-tap job. Without the
/// attachment the group would be saved with no configuration and the host would
/// have to walk the full setup a second time to earn the quick start.
///
/// Nothing here can block the match. A cancelled dialog simply leaves the
/// roster unsaved and the host carries on.
Future<void> _saveNewGroup(
  WidgetRef ref,
  BuildContext context,
  List<String> names,
) async {
  final groups = ref.read(playerGroupsProvider).valueOrNull ?? const [];
  final suggested = context.l10n.groupNameDefault(groups.length + 1);

  final name = await promptForGroupName(
    context,
    title: context.l10n.saveGroupTitle,
    initial: suggested,
  );
  if (name == null) return;

  final now = DateTime.now();
  final group = PlayerGroup.create(
    name: name,
    memberNames: names,
    now: now,
  ).copyWith(genders: ref.read(setupDraftProvider).genders);
  final id = await ref.read(playerGroupsProvider.notifier).save(group);
  ref.read(setupDraftProvider.notifier).setGroup(group.copyWith(id: id));
}

/// Bounces to Home on the next frame. Used for routes that were entered without
/// the state they need.
class _RedirectHome extends StatefulWidget {
  const _RedirectHome();

  @override
  State<_RedirectHome> createState() => _RedirectHomeState();
}

class _RedirectHomeState extends State<_RedirectHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.home);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Loads the stored defaults, then lets the host edit and re-save them.
class _DefaultSettingsRoute extends StatelessWidget {
  final WidgetRef ref;

  const _DefaultSettingsRoute({required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchSettings>(
      future: ref.read(matchRepositoryProvider).loadDefaultSettings(),
      builder: (context, snapshot) {
        final initial = snapshot.data;
        if (initial == null) return const SizedBox.shrink();
        return SettingsScreen(
          initial: initial,
          onAudioPreview: (settings) => _previewAudio(ref, settings),
          // No table yet, so a preset here sets the shape of the game and
          // leaves the split to the screen that asks for it.
          onSave: (settings) {
            ref.read(matchRepositoryProvider).saveDefaultSettings(settings);
            ref.read(setupDraftProvider.notifier).setSettings(settings);
            context.go(Routes.home);
          },
          onBack: () => context.go(Routes.home),
        );
      },
    );
  }
}

/// Scaffold that prevents back navigation during critical game phases.
///
/// Retained for direct use by screens hosted outside [MatchRoute]; the match
/// route applies the same lock itself.
class NightLockScaffold extends StatelessWidget {
  final Widget child;

  const NightLockScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: Scaffold(body: child));
  }
}
