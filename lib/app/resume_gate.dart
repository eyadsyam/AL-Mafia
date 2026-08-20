import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repository_provider.dart';
import '../data/repository_types.dart';
import '../engine/models/match.dart';
import '../ui/screens/match_controller.dart';
import '../ui/l10n_ext.dart';
import '../ui/theme/mafia_theme.dart';
import 'router.dart';

/// Offers Resume/End once per launch when an unfinished match is in storage
/// (S-17, FR-033).
///
/// The prompt is a dialog over Home rather than an automatic jump into the
/// match. Reopening the app is not the same intent as resuming: the phone may
/// be in a different pair of hands than it was when the match stopped, and
/// dropping straight into the game would be the one moment the pass gate could
/// not protect. Asking first also lets a host abandon a match that has already
/// broken up in real life.
class ResumeGate extends ConsumerStatefulWidget {
  final Widget child;

  /// The router's navigator.
  ///
  /// This widget is mounted from `MaterialApp.builder`, whose context sits
  /// *above* the Navigator — calling `showDialog` with it throws "Navigator
  /// operation requested with a context that does not include a Navigator".
  /// The key gives us a context on the right side of that boundary.
  final GlobalKey<NavigatorState> navigatorKey;

  const ResumeGate({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  static const Key resumeButton = ValueKey('resume_prompt_resume');
  static const Key endButton = ValueKey('resume_prompt_end');

  @override
  ConsumerState<ResumeGate> createState() => _ResumeGateState();
}

class _ResumeGateState extends ConsumerState<ResumeGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;

    final repository = ref.read(matchRepositoryProvider);
    Match? active;
    try {
      active = await repository.loadActiveMatch();
    } catch (_) {
      // Unreadable storage must not stop the app from starting a fresh match.
      return;
    }
    if (active == null || !mounted) return;

    final target = await repository.resolveResume(active);
    if (!mounted) return;

    final resume = await _prompt(active, target);
    if (!mounted) return;

    if (resume == true) {
      ref.read(matchControllerProvider.notifier).adoptMatch(active);
      // Landing on the match route replays the persisted phase, which for any
      // in-hand phase is the pass screen — never the interrupted content.
      // Re-read the key rather than reusing a context captured before the
      // dialog: the navigator may have been torn down while it was open, and a
      // null `currentContext` is the only reliable signal that it has.
      final navigatorContext = widget.navigatorKey.currentContext;
      if (navigatorContext != null && navigatorContext.mounted) {
        GoRouter.of(navigatorContext).go(Routes.match);
      }
    } else if (resume == false) {
      await repository.deleteMatch(active.id);
    }
  }

  Future<bool?> _prompt(Match match, ResumeTarget target) {
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return Future.value(null);

    final colors = navigatorContext.colors;
    final type = navigatorContext.typography;
    final radii = navigatorContext.radii;
    final l10n = navigatorContext.l10n;

    final where = target.screen == ResumeScreen.pass && target.playerName != null
        ? l10n.resumeFromPassTo(target.playerName!)
        : l10n.resumeFromDay(target.dayNumber);

    return showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.dialog),
        ),
        title: Text(
          l10n.unfinishedMatchTitle,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          l10n.unfinishedMatchBody(match.players.length, where),
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            key: ResumeGate.endButton,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.endMatch,
              style: type.body.copyWith(color: colors.accentCrimson),
            ),
          ),
          TextButton(
            key: ResumeGate.resumeButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.resumeAction,
              style: type.body.copyWith(color: colors.accentGold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
