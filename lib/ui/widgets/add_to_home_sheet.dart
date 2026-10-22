import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/asset_constants.dart';
import '../../platform/push/push_service.dart';
import '../../platform/review_prompt.dart'
    show SharedPreferencesReviewStateStore;
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'mafia_kit.dart';

/// «خلّي اللعبة على شاشتك»: on an iPhone's browser tab (there is no iPhone
/// app; the web is the game there), once, on arriving Home after the first
/// finished match, the three Safari steps that put the game on the Home
/// Screen, where it opens without the browser bar (owner, 2026-10-22).
abstract final class AddToHome {
  static const shownKey = 'mafia.web.addToHomeShown.v1';
  static const doneKey = ValueKey('add_to_home_done');

  /// Shows the sheet if this is its moment; never twice on one browser.
  static Future<void> maybeOffer(BuildContext context, WidgetRef ref) async {
    if (!ref.read(pushServiceProvider).needsInstall) return;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    if (prefs.getBool(shownKey) == true) return;
    final matches =
        prefs.getInt(SharedPreferencesReviewStateStore.cleanMatchesKey) ?? 0;
    if (matches < 1 || !context.mounted) return;
    await prefs.setBool(shownKey, true);
    if (!context.mounted) return;
    await showMafiaSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surfaceBase,
      builder: (_) => const _AddToHomeSheet(),
    );
  }
}

class _AddToHomeSheet extends StatelessWidget {
  const _AddToHomeSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    Widget step(String index, Widget mark, String text) => Padding(
      padding: EdgeInsets.only(bottom: s.sm),
      child: Row(
        children: [
          Text(index, style: type.title.copyWith(color: colors.textMuted)),
          SizedBox(width: s.sm),
          SizedBox.square(dimension: AddToHomeTokens.mark, child: mark),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              text,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(s.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.addToHomeTitle,
              textAlign: TextAlign.center,
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: s.xs),
            Text(
              l.addToHomeBody,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: s.lg),
            step(
              '1',
              Icon(Icons.ios_share, color: colors.textSecondary),
              l.addToHomeStep1,
            ),
            step(
              '2',
              Icon(Icons.add_box_outlined, color: colors.textSecondary),
              l.addToHomeStep2,
            ),
            step(
              '3',
              Image.asset(AppImages.splashMask, fit: BoxFit.contain),
              l.addToHomeStep3,
            ),
            SizedBox(height: s.sm),
            OutlinedButton(
              key: AddToHome.doneKey,
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l.addToHomeDone),
            ),
          ],
        ),
      ),
    );
  }
}
