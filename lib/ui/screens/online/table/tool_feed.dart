import 'package:flutter/material.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../engine/models/enums.dart' show GamePhase;
import '../../../../transport/game_snapshot.dart';
import '../../../economy/table_tool_names.g.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// The day phases in which announcements are drawn. Never at night: the night
/// screens must stay identical for every role (doc 05).
bool toolFeedVisibleIn(GamePhase phase) => switch (phase) {
  GamePhase.morning ||
  GamePhase.openingRound ||
  GamePhase.confrontation ||
  GamePhase.discussion ||
  GamePhase.voting ||
  GamePhase.reveal => true,
  _ => false,
};

/// One announcement as a single line of copy. Public facts only: a secret
/// entry (no seat) never names the tool or the user.
String toolFeedLine(
  AppLocalizations l10n,
  ToolLogEntry entry,
  Map<int, String> names,
) {
  final note = entry.note;
  if (note != null && entry.tool == 'anon_note') {
    return l10n.toolFeedAnonNote(note);
  }
  if (note != null && entry.tool == 'last_will') {
    return l10n.toolFeedLastWill(note);
  }
  final who = entry.seat == null ? null : names[entry.seat];
  if (who == null) return l10n.toolFeedSecret;
  final tool = tableToolCopy(l10n, entry.tool)?.$1 ?? l10n.toolFeedUnknownTool;
  final used = l10n.toolFeedUsed(who, tool);
  final targets = [
    for (final seat in entry.targets)
      if (names[seat] case final name?) name,
  ];
  if (targets.isEmpty) return used;
  return '$used · ${l10n.toolFeedTargets(targets.join(l10n.toolFeedSeparator))}';
}

/// The newest tool announcements, newest first, older ones fading. A new entry
/// also raises a short snackbar. Draws nothing at night or when empty.
class ToolFeed extends StatefulWidget {
  final GameSnapshot snapshot;

  const ToolFeed({super.key, required this.snapshot});

  static const Key surface = ValueKey('tool_feed');

  @override
  State<ToolFeed> createState() => _ToolFeedState();
}

class _ToolFeedState extends State<ToolFeed> {
  Map<int, String> get _names => {
    for (final p in widget.snapshot.public.players) p.seat: p.name,
  };

  @override
  void didUpdateWidget(ToolFeed old) {
    super.didUpdateWidget(old);
    final before = old.snapshot.toolLog;
    final now = widget.snapshot.toolLog;
    if (now.isEmpty || !toolFeedVisibleIn(widget.snapshot.phase)) return;
    final fresh =
        now.length > before.length ||
        (now.length == before.length &&
            before.isNotEmpty &&
            now.last != before.last);
    if (!fresh) return;
    final entry = now.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(toolFeedLine(context.l10n, entry, _names)),
            duration: context.timing.holdToReveal,
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.snapshot.toolLog;
    if (log.isEmpty || !toolFeedVisibleIn(widget.snapshot.phase)) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;
    final names = _names;
    final newest = log.reversed.take(CouncilTokens.toolFeedMax).toList();
    const opacities = [
      1.0,
      CouncilTokens.toolFeedOlderOpacity,
      CouncilTokens.toolFeedOldestOpacity,
    ];
    return IgnorePointer(
      child: Column(
        key: ToolFeed.surface,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < newest.length; i++)
            Opacity(
              opacity: opacities[i.clamp(0, opacities.length - 1)],
              child: Padding(
                padding: EdgeInsets.only(bottom: spacing.xs),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceOverlay,
                    borderRadius: BorderRadius.circular(context.radii.button),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.sm,
                      vertical: spacing.xs,
                    ),
                    child: Text(
                      toolFeedLine(l10n, newest[i], names),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.caption.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
