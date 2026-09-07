import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/hint_slot.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/phase_timer.dart';
import '../../widgets/textured_surface.dart';

/// The day's one confrontation (doc 09 §2.6).
///
/// One player is named; one true observation about their own behaviour is put
/// to them; they hold the floor for the configured window and nobody else may
/// interrupt.
///
/// ## What the screen enforces, and what it does not
///
/// It enforces *one speaker*: there is a single control on it and it belongs to
/// the named player («خلّصت»). It does not enforce silence from anyone else —
/// no app can — but it makes whose turn it is unambiguous, which at a table is
/// the whole of what enforcement means. Online the same state drives the mic
/// routing: only this player is unmuted (doc 10 §6.3).
///
/// ## Silence is an outcome
///
/// If the timer runs out with nothing said, that is recorded as a silent
/// answer rather than as an error (C-E5). It is information, and the post-game
/// autopsy is entitled to it.
class ConfrontationScreen extends StatefulWidget {
  final int dayNumber;

  /// The player being asked to explain themselves.
  final String playerName;

  /// The observation, already rendered. See `InformationText`.
  final String observation;

  final Duration window;

  /// Called when the window closes — early via «خلّصت», or by expiry.
  final void Function({required bool silent}) onFinished;

  /// Whether doc 13 §4.2's one-line interface hints are printed at all.
  ///
  /// The slot's space is reserved either way; this only decides whether
  /// anything goes in it. See [HintSlot].
  final bool interfaceHintsEnabled;

  const ConfrontationScreen({
    super.key,
    this.interfaceHintsEnabled = true,
    required this.dayNumber,
    required this.playerName,
    required this.observation,
    required this.window,
    required this.onFinished,
  });

  @override
  State<ConfrontationScreen> createState() => _ConfrontationScreenState();
}

class _ConfrontationScreenState extends State<ConfrontationScreen> {
  Timer? _ticker;
  late Duration _remaining = widget.window;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        setState(() => _remaining = Duration.zero);
        // Expired with nothing said. Recorded as silence, not as a failure.
        _finish(silent: true);
        return;
      }
      setState(() => _remaining = next);
    });
  }

  void _finish({required bool silent}) {
    if (_done) return;
    _done = true;
    _ticker?.cancel();
    widget.onFinished(silent: silent);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.dayNumbered(widget.dayNumber),
                    style: type.caption.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  // Doc 14 Part 6: reserved, and empty inside a match.
                  SizedBox(height: HintSlot.reservedHeight(context)),
                  SizedBox(height: spacing.sm),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.borderSubtle)),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: spacing.sm),
                        child: Text(
                          l10n.confrontationLabel,
                          style:
                              type.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.borderSubtle)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.playerName,
                    style: type.display.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    widget.observation,
                    style: type.title.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    l10n.confrontationExplain,
                    style: type.title.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.xl),
                  PhaseTimer(remaining: _remaining, total: widget.window),
                  const Spacer(),
                  SizedBox(
                    height: spacing.xxl + spacing.sm,
                    child: FilledButton(
                      onPressed: () => _finish(silent: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(l10n.confrontationDone, style: type.title),
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
