/// Doc 13 §4.2's reserved slot, and nothing else any more.
///
/// # What this file was
///
/// A Tier-1 hint: one line about the *control* — how to pass the phone, how to
/// pick a seat — shown once ever, in a fixed slot, next to the thing it named.
/// It faded in, faded out, and a tap took it away.
///
/// # Why only the height is left
///
/// Doc 14 Part 6: *"No hint, tip, or strategy line appears on any screen during
/// a live match."* Every trigger this slot had was inside a match, so the widget
/// went, and with it the enum, the copy table and the seen-set. What was left
/// after that was a screen-teaching tier that no screen could reach.
///
/// The **reservation** is a different rule and it stays:
///
/// *"All of them appear in a fixed reserved slot that exists on every screen —
/// so a screen showing a hint is the same height as one that is not."*
///
/// That is doc 05 wearing a doc 13 hat, and it outlives what filled it. Four
/// roles' night screens have to be the same height to the pixel, and the height
/// they agree on includes this. `luminance_budget_test` and
/// `night_grid_symmetry_test` both fail the day it changes, which is exactly
/// what a load-bearing number should do.
///
/// So: one measurement, in one place, named for what it is. There is nothing to
/// construct and no state to keep — a caller reserves the space with a plain
/// `SizedBox(height: HintSlot.reservedHeight(context))`.
library ui.widgets.hint_slot;

import 'package:flutter/material.dart';

import '../theme/mafia_theme.dart';

abstract final class HintSlot {
  /// The space every turn screen reserves, hint or no hint.
  ///
  /// One line of caption plus its breathing room, from the tokens rather than
  /// eyeballed, so it tracks the type scale instead of drifting away from it.
  static double reservedHeight(BuildContext context) =>
      context.spacing.lg + context.spacing.sm;
}
