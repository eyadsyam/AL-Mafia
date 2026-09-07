import 'package:flutter/material.dart';

import '../../engine/models/player.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// Male or female, as two small marks at the trailing edge of a name field
/// (task 8).
///
/// ## Why it moved
///
/// It used to be a full-width `SegmentedButton` on its own row, under the
/// input. On a phone that row cost about a third of the screen to answer a
/// question with two possible answers, and it pushed the thing the player had
/// actually come to do — type a name and press add — below the fold.
///
/// It belongs to the name because it *is* part of the name: the app addresses
/// players in Arabic, which is a gendered language, so this is the second half
/// of the same field rather than a separate setting.
///
/// ## Selected is cream, unselected is muted
///
/// Not a filled chip and not a border. Two glyphs, one of which is lit — which
/// is the smallest thing that can carry a binary choice, and reads at the size
/// a text field's trailing edge allows.
///
/// Tapping the lit one clears the choice. `unspecified` is a real answer and a
/// player who picked by accident must be able to unpick.
class GenderPicker extends StatelessWidget {
  final PlayerGender value;
  final ValueChanged<PlayerGender> onChanged;

  const GenderPicker({super.key, required this.value, required this.onChanged});

  static const Key maleKey = ValueKey('gender_male');
  static const Key femaleKey = ValueKey('gender_female');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    Widget mark(PlayerGender gender, IconData icon, String label, Key key) {
      final on = value == gender;
      return IconButton(
        key: key,
        tooltip: label,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: spacing.xs),
        constraints: const BoxConstraints(),
        // Tapping the chosen one clears it, which is the only way back to
        // "did not say" once something has been picked.
        onPressed: () =>
            onChanged(on ? PlayerGender.unspecified : gender),
        icon: Icon(
          icon,
          size: spacing.lg,
          color: on ? colors.textPrimary : colors.textMuted,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark(PlayerGender.male, Icons.male, context.l10n.playerMale, maleKey),
        mark(
          PlayerGender.female,
          Icons.female,
          context.l10n.playerFemale,
          femaleKey,
        ),
        SizedBox(width: spacing.xs),
      ],
    );
  }
}
