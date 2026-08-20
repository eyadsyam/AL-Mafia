import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/player_group_provider.dart';
import '../platform/audio_director.dart';
import '../ui/screens/setup/setup_draft.dart';
import '../ui/theme/mafia_theme.dart';
import '../ui/widgets/splash_gate.dart';
import 'l10n/app_localizations.dart';
import 'onboarding_gate.dart';
import 'resume_gate.dart';
import 'router.dart';

/// Root app widget for Mafia Master.
///
/// Arabic is the primary locale and the app is RTL-first (FR-034); English is
/// supported but is the fallback, not the default.
class MafiaApp extends ConsumerStatefulWidget {
  const MafiaApp({super.key});

  @override
  ConsumerState<MafiaApp> createState() => _MafiaAppState();
}

class _MafiaAppState extends ConsumerState<MafiaApp>
    with WidgetsBindingObserver {
  /// Owned here, not global: two app instances in one test process would
  /// otherwise fight over the same key.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter _router =
      buildRouter(ref, navigatorKey: _navigatorKey);

  AudioDirector get _audio => ref.read(audioDirectorProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Warm the saved groups now, while the splash is still up.
    //
    // The choice they feed — picker, or straight to an empty roster — is made
    // inside a router callback, which cannot await. Reading here means the list
    // is in hand long before anyone can tap "مباراة جديدة", and the read is a
    // handful of local rows. If it somehow has not landed, the caller treats
    // that as "no groups" and behaves exactly as the app did before groups
    // existed, so the worst case is the old behaviour rather than a stall.
    ref.read(playerGroupsProvider);
    // Started at the app root rather than at the match, because the score is
    // continuous across everything: it does not restart when a match begins, so
    // there is no seam at the one moment the table is paying most attention.
    //
    // The warm-up goes first and is awaited before the score starts, so the
    // session is configured while nothing is sounding. Configuring it *after* a
    // player exists is how the two ended up fighting over audio focus.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _audio.warmUp();
      if (!mounted) return;
      _syncScore();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The one thing that may silence the loop besides a setting: the app going
    // to the background. Leaving it running would have the phone playing music
    // from a pocket, and it is not information about the game either way.
    if (state == AppLifecycleState.resumed) {
      _syncScore();
    } else if (state == AppLifecycleState.paused) {
      _audio.scoreEnabled = false;
      _audio.syncScore();
      _audio.scoreEnabled = _settingsScoreEnabled;
    }
  }

  bool get _settingsScoreEnabled =>
      ref.read(setupDraftProvider).settings.scoreEnabled;

  void _syncScore() {
    final settings = ref.read(setupDraftProvider).settings;
    _audio
      ..muted = settings.muteAllAudio
      ..scoreEnabled = settings.scoreEnabled
      ..syncScore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mafia Master',
      theme: MafiaTheme.dark,
      routerConfig: _router,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      // Wrapping here rather than inside a route means the unfinished-match
      // check runs once per launch, not on every visit to Home.
      // Two wrappers, outermost last. `SplashGate` has to be above everything
      // so the veil covers the resume prompt too — a dialog appearing through a
      // dissolve is the one thing that would make the handover look broken.
      //
      // Text scaling is pinned at 1.0 in both directions, above everything
      // else, so the clamp is in force for the splash, the resume dialog and
      // every route alike.
      //
      // # Why an app that is otherwise careful about accessibility does this
      //
      // This is a pass-the-phone game. Four roles have to produce *structurally
      // identical* night screens — same slots, same rects, same emitted light —
      // and the leakage suite asserts that by measuring pixels. A layout that
      // reflows under the OS font setting reflows by different amounts for
      // different strings, and the strings differ by role. At 130% the turn
      // header already overflowed its reservation by 13px. An overflow that
      // depends on how long a role's prompt is turns the OS font setting into a
      // channel that reports on the role.
      //
      // The cost is real and worth naming: a player who has enlarged type
      // system-wide does not get it here. That is a genuine loss of an
      // accessibility affordance, accepted because the alternative is a game
      // that leaks. The type scale is set generously for a dim table to
      // compensate, and 7:1 contrast is enforced by
      // `role_accent_parity_test.dart`.
      //
      // If this is ever relaxed, clamp to something like 1.0–1.15 rather than
      // removing it — that absorbs most real settings while keeping the
      // reserved slots intact — and re-run the whole leakage suite at the top
      // of the range, not just at 1.0.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.0,
        child: SplashGate(
          child: ResumeGate(
            navigatorKey: _navigatorKey,
            // Inside the resume gate, not outside it: the resume prompt is a
            // dialog and this is a route change, so the two are not competing
            // for the same slot — but a first launch that also has an
            // unfinished match must get the prompt, and `OnboardingGate` stands
            // down on its own when it finds one.
            child: OnboardingGate(
              navigatorKey: _navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
