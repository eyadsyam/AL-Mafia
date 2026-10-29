import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../mafia_public.dart';

/// A deck sheet for content that has a text field in it: the same dealt card
/// as `showDeckSheet`, but it stands on top of the keyboard instead of under
/// it. The sheet gives up the height the keyboard takes, so a field and what
/// it finds stay in view at any window size; its content scrolls inside.
///
/// The content draws its own title (and may hide it while the keyboard is
/// open, which it can see in `MediaQuery.viewInsetsOf`). Public screens only.
Future<T?> showDeckFormSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showMafiaSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: DeckTokens.panel,
  builder: (sheetContext) => DeckFormSheetFrame(child: Builder(builder: builder)),
);

/// The sheet's body: the handle, then [child] in whatever height is left above
/// the keyboard. Also usable on its own in a test host.
class DeckFormSheetFrame extends StatelessWidget {
  final Widget child;
  const DeckFormSheetFrame({super.key, required this.child});

  static const Key frameKey = ValueKey('deck_form_sheet');

  /// Whether the enclosing sheet already makes room for the keyboard, so a
  /// scrolling child must not add the keyboard's height to its own padding.
  static bool handlesKeyboard(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_KeyboardHandled>() != null;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final available = media.size.height - inset - media.padding.top;
    return _KeyboardHandled(
      child: Padding(
        key: frameKey,
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: available * DeckTokens.sheetMax,
          ),
          child: SafeArea(
            top: false,
            bottom: inset == 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: context.spacing.sm),
                  child: Center(
                    child: Container(
                      width: DeckTokens.sheetHandle.width,
                      height: DeckTokens.sheetHandle.height,
                      decoration: BoxDecoration(
                        color: DeckTokens.silver,
                        borderRadius: BorderRadius.circular(
                          DeckTokens.sheetHandle.height,
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardHandled extends InheritedWidget {
  const _KeyboardHandled({required super.child});

  @override
  bool updateShouldNotify(_KeyboardHandled oldWidget) => false;
}
