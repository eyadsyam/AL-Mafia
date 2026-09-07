/// Doc 13 §4.3's Tier-2 hint — one line about the *game*, in dead time only.
///
/// # Where this is allowed to appear, and where it is not
///
/// *"Shown only in dead time: the lobby, waiting for other players, and the
/// loading beat between phases. Never while a decision is open."* A hint that
/// arrives while somebody is choosing a name is not advice, it is a nudge, and
/// a nudge from the app during a decision is the app playing.
///
/// This widget cannot enforce that on its own — a caller can put it anywhere —
/// so the enforcement is that there are exactly two call sites and both of them
/// are lobbies. `play_hints_test` asserts that.
///
/// # Offline, every phone shows the same sentence
///
/// [HintAudience] is a sealed pair with no `mode` flag: an offline caller
/// cannot construct the role-conditioned case because [OneSeat]'s constructor
/// needs a viewer seat and an offline device has none. See `engine/hints.dart`.
/// The choice within a pool is `deriveSeed(matchSeed, hint, phaseIndex)`, so
/// two players comparing phones find the same line — a difference there would
/// be a difference the app did not mean to give them.
library ui.widgets.play_hint_line;

import 'package:flutter/material.dart';

import '../../engine/hints.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

class PlayHintLine extends StatelessWidget {
  /// Who is reading. Offline this is always [TheTable], by construction.
  final HintAudience audience;

  final int matchSeed;

  /// Which dead beat this is. Doc 13 §4.3: *"maximum one per phase"*, so the
  /// same index must give the same sentence for as long as the phase lasts.
  final int phaseIndex;

  /// Doc 13 §7's «تلميحات اللعب».
  final bool enabled;

  const PlayHintLine({
    super.key,
    required this.audience,
    required this.matchSeed,
    required this.phaseIndex,
    this.enabled = true,
  });

  static const Key text = ValueKey('play_hint_line');

  @override
  Widget build(BuildContext context) {
    final hint = PlayHints.forPhase(
      audience: audience,
      matchSeed: matchSeed,
      phaseIndex: phaseIndex,
      enabled: enabled,
    );
    if (hint == null) return const SizedBox.shrink();

    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    // Doc 13 §4.3: *"Never above the fold — always in a secondary slot."* So:
    // muted, small, and quoted, which is the typographic way of saying this is
    // somebody's general advice and not the app telling you something it knows.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      child: Text(
        EngineCopy.playHint(context.l10n, hint),
        key: PlayHintLine.text,
        textAlign: TextAlign.center,
        style: type.bodySmall.copyWith(
          color: colors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
