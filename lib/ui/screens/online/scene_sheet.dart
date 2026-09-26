import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';

/// One choice inside a [SceneSheet].
class SceneAction {
  final Key? key;
  final IconData? icon;
  final String label;
  final bool emphasised;
  final VoidCallback onTap;

  const SceneAction({
    required this.label,
    required this.onTap,
    this.key,
    this.icon,
    this.emphasised = false,
  });
}

/// A panel that opens *inside* the scene rather than on a route above it.
///
/// Doc 12 §2.1 is a decision that the online surface is one persistent scene:
/// nothing is pushed on top of the table, because a pushed route is the shape a
/// wizard takes and the table is not one. A pushed dialog would also detach the
/// panel from the snapshot stream that built it — the room can change under a
/// confirmation, and a layer in the same `Stack` rebuilds with it while a route
/// keeps showing the room as it was when it opened.
///
/// It draws nothing when [visible] is false, so a call site is one `SceneSheet`
/// in the Stack and one nullable piece of state.
class SceneSheet extends StatelessWidget {
  final bool visible;
  final String? title;
  final String? body;
  final List<SceneAction> actions;
  final VoidCallback onDismiss;

  static const Key scrim = ValueKey('scene_sheet_scrim');

  const SceneSheet({
    super.key,
    required this.visible,
    required this.actions,
    required this.onDismiss,
    this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: scrim,
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(
              color: colors.surfaceBase.withValues(alpha: 0.72),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(context.radii.card),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.md,
                            vertical: spacing.sm,
                          ),
                          child: Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: type.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      if (body != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            spacing.md,
                            0,
                            spacing.md,
                            spacing.sm,
                          ),
                          child: Text(
                            body!,
                            textAlign: TextAlign.center,
                            style: type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      for (final action in actions)
                        Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            key: action.key,
                            leading: action.icon == null
                                ? null
                                : Icon(
                                    action.icon,
                                    color: action.emphasised
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                            title: Text(
                              action.label,
                              style: type.body.copyWith(
                                color: action.emphasised
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                              ),
                            ),
                            onTap: action.onTap,
                          ),
                        ),
                      Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          title: Text(
                            context.l10n.cancel,
                            textAlign: TextAlign.center,
                            style: type.body.copyWith(color: colors.textMuted),
                          ),
                          onTap: onDismiss,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
