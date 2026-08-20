import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'hold_pad.dart';
import 'textured_surface.dart';

/// The handoff gate (screen S-05).
///
/// Every in-hand phase is entered through this screen, and it shows exactly one
/// piece of information: the name of the person the phone is meant for. No
/// phase content, no counts, no role, nothing that would reward picking the
/// phone up out of turn (L-12).
///
/// Opening it makes no sound and fires no haptic — the whole point is that the
/// table cannot tell whose turn is starting or how it is going.
class PassScreen extends StatelessWidget {
  /// The player the phone is for.
  final String targetName;

  /// Optional neutral line under the name (e.g. "الليلة الأولى"). Must be the
  /// same for every recipient.
  final String? subtitle;

  final VoidCallback onConfirmed;

  /// "Not <name>?" — hands the phone back without exposing anything.
  final VoidCallback? onWrongPerson;

  const PassScreen({
    super.key,
    required this.targetName,
    required this.onConfirmed,
    this.subtitle,
    this.onWrongPerson,
  });

  static const Key holdPad = ValueKey('pass_screen_hold_pad');
  static const Key wrongPerson = ValueKey('pass_screen_wrong_person');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    return AppBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.passPhoneTo,
                    style: type.caption.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    targetName,
                    style: type.display.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Reserved subtitle line: always laid out, so its presence
                  // never signals anything.
                  SizedBox(
                    height: spacing.lg,
                    child: Center(
                      child: Text(
                        subtitle ?? '',
                        style: type.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  KeyedSubtree(
                    key: holdPad,
                    child: HoldPad(
                      holdDuration: context.timing.holdToReveal,
                      instruction: l10n.iAmHoldInstruction(targetName),
                      onHoldComplete: onConfirmed,
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                  TextButton(
                    key: wrongPerson,
                    onPressed: onWrongPerson,
                    child: Text(
                      l10n.notYouNamed(targetName),
                      style: type.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
