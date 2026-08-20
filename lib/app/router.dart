import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/player_group.dart';
import '../data/player_group_provider.dart';
import '../data/repository_provider.dart';
import '../engine/models/match_settings.dart';
import '../ui/l10n_ext.dart';
import '../ui/screens/match_controller.dart';
import '../ui/screens/match_route.dart';
import '../ui/screens/postgame/analytics_screen.dart';
import '../ui/screens/postgame/history_screen.dart';
import '../ui/screens/setup/add_players_screen.dart';
import '../ui/screens/setup/group_picker_screen.dart';
import '../ui/screens/setup/home_screen.dart';
import '../ui/screens/setup/how_to_play_screen.dart';
import '../ui/screens/setup/roles_screen.dart';
import '../ui/screens/setup/settings_screen.dart';
import '../ui/screens/setup/setup_draft.dart';

/// Route paths, in one place so navigation calls cannot drift from the table.
abstract final class Routes {
  static const home = '/';
  static const groups = '/setup/groups';
  static const players = '/setup/players';
  static const roles = '/setup/roles';
  static const settings = '/setup/settings';
  static const defaults = '/settings';
  static const match = '/match';
  static const analytics = '/analytics';
  static const history = '/history';
  static const howToPlay = '/how-to-play';

  /// Analytics for a stored match.
  static String storedAnalytics(int id) => '/history/$id';
}

/// Builds the app's router.
///
/// Takes a [WidgetRef] rather than reading providers inside each builder so
/// that the setup steps can hand their results straight to the draft and the
/// engine. Routes stay dumb; the screens they host stay reusable in tests
/// without a router at all.
GoRouter buildRouter(WidgetRef ref, {GlobalKey<NavigatorState>? navigatorKey}) {
  void startMatch(BuildContext context) {
    final draft = ref.read(setupDraftProvider);
    final roleCounts = draft.roleCounts;
    if (roleCounts == null) return;

    ref.read(matchControllerProvider.notifier).startMatch(
          names: draft.names,
          roleCounts: roleCounts,
          settings: draft.settings,
        );

    // A group that just started a match gets its play count bumped and its
    // configuration remembered, which is what makes the *next* rematch a
    // three-tap affair. Deliberately not awaited: a database write must never
    // sit between the host tapping start and the first card appearing.
    final group = draft.group;
    if (group != null && group.isSaved) {
      ref.read(playerGroupsProvider.notifier).recordPlayed(
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

  /// Start a match on a group's remembered configuration, skipping the roles
  /// and settings screens entirely. This is the third tap of a rematch.
  void quickStart(BuildContext context, List<String> names) {
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
    startMatch(context);
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
    initialLocation: kDebugMode
        ? const String.fromEnvironment('START_ROUTE', defaultValue: Routes.home)
        : Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => HomeScreen(
          onNewMatch: () {
            ref.read(setupDraftProvider.notifier).resetForNewMatch();
            // First run, or a host who has never saved anyone, goes exactly
            // where they always went. The picker only exists once there is
            // something in it to pick.
            context.go(
              loadedGroups().isEmpty ? Routes.players : Routes.groups,
            );
          },
          onHistory: () => context.go(Routes.history),
          onSettings: () => context.go(Routes.defaults),
          onHowToPlay: () => context.go(Routes.howToPlay),
        ),
      ),
      GoRoute(
        path: Routes.howToPlay,
        builder: (context, state) => HowToPlayScreen(
          onBack: () => context.go(Routes.home),
        ),
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
            initialNames: group?.memberNames ?? const [],
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
        builder: (context, state) => SettingsScreen(
          initial: ref.read(setupDraftProvider).settings,
          onSave: (settings) {
            ref.read(setupDraftProvider.notifier).setSettings(settings);
            // These become the defaults for the next match too (FR-005).
            ref.read(matchRepositoryProvider).saveDefaultSettings(settings);
            startMatch(context);
          },
          onBack: () => context.go(Routes.roles),
        ),
      ),
      // The same screen, reached from Home, editing only the stored defaults.
      GoRoute(
        path: Routes.defaults,
        builder: (context, state) => _DefaultSettingsRoute(ref: ref),
      ),
      GoRoute(
        path: Routes.match,
        builder: (context, state) => MatchRoute(
          onExit: () => context.go(Routes.home),
          onAnalytics: () => context.go(Routes.analytics),
        ),
      ),
      GoRoute(
        path: Routes.analytics,
        builder: (context, state) => LiveAnalyticsScreen(
          onClose: () => context.go(Routes.home),
        ),
      ),
      GoRoute(
        path: Routes.history,
        builder: (context, state) => HistoryScreen(
          onOpen: (id) => context.go(Routes.storedAnalytics(id)),
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
  );
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
    return PopScope(
      canPop: false,
      child: Scaffold(body: child),
    );
  }
}
