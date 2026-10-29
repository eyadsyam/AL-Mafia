import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'back_action.dart';
import 'mafia_kit.dart';

/// Secondary public flows keep the native sheet dismissal and back behavior.
Future<T?> showMafiaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool? showDragHandle,
  Color? backgroundColor,
  AnimationStyle? sheetAnimationStyle,
}) => showModalBottomSheet<T>(
  context: context,
  sheetAnimationStyle: sheetAnimationStyle,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  showDragHandle: showDragHandle,
  backgroundColor: backgroundColor ?? context.colors.surfaceBase,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(context.radii.card),
    ),
    side: BorderSide(color: context.colors.borderSubtle),
  ),
  builder: (context) => MafiaPublicTheme(child: Builder(builder: builder)),
);

/// Public chrome only. Never wrap a private turn or a match route in this
/// theme: night controls must retain their neutral palette (Doc 05).
class MafiaPublicTheme extends StatelessWidget {
  final Widget child;
  const MafiaPublicTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const target = Size(
      IdentityTokens.buttonWidth,
      IdentityTokens.target,
    );
    return Theme(
      data: base.copyWith(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style?.merge(
            vaultGoldStyle(context, minimumSize: target),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: base.outlinedButtonTheme.style?.merge(
            vaultOutlineStyle(context),
          ),
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: context.colors.surfaceBase,
          foregroundColor: context.colors.textPrimary,
          surfaceTintColor: IdentityTokens.transparent,
          elevation: IdentityTokens.flat,
          titleTextStyle: context.typography.headline,
          toolbarHeight: IdentityTokens.headerHeight,
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: VaultTokens.enamel,
          selectedColor: context.colors.surfaceOverlay,
          labelStyle: context.typography.bodySmall.copyWith(
            color: VaultTokens.goldLight,
          ),
          side: BorderSide(color: context.colors.borderSubtle),
          shape: const StadiumBorder(),
        ),
        dividerTheme: DividerThemeData(
          color: context.colors.borderSubtle,
          thickness: VaultTokens.chipRim,
          space: context.spacing.md,
        ),
      ),
      child: MediaQuery.withNoTextScaling(child: child),
    );
  }
}

/// Scaffold for public destinations. Existing composed headers can stay in
/// [body]; new destinations use [title] and [onBack] for the standard header.
/// No navigation or phase is inferred from game state.
class MafiaScaffold extends StatelessWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;
  final String? title;
  final VoidCallback? onBack;
  const MafiaScaffold({
    super.key,
    this.body,
    this.appBar,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => MafiaPublicTheme(
    child: Scaffold(
      backgroundColor: backgroundColor,
      appBar:
          appBar ??
          (title == null
              ? null
              : AppBar(
                  automaticallyImplyLeading: false,
                  leading: onBack == null
                      ? null
                      : BackAction(onPressed: onBack!),
                  title: Text(title!),
                )),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomNavigationBar,
      body: title == null
          ? body
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(context.spacing.screenMargin),
                child: body,
              ),
            ),
    ),
  );
}
