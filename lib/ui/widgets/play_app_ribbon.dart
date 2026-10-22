import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/links/external_link.dart';
import '../../platform/links/in_app_browser.dart';
import '../economy/web_ads.dart' show kPlayListing;
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// Whether this page is the web game on an Android phone, where the app is
/// one tap away. A provider so a test can stand in for the browser.
final playRibbonEligibleProvider = Provider<bool>(
  (ref) => kIsWeb && embeddedOnAndroid,
);

/// «العبها من التطبيق»: a slim line on the web Home of an Android phone that
/// points at the Play listing. Closed once, it never comes back on this
/// browser (owner, 2026-10-22).
class PlayAppRibbon extends ConsumerStatefulWidget {
  const PlayAppRibbon({super.key});

  static const closedKey = 'mafia.web.playRibbonClosed.v1';
  static const ribbonKey = ValueKey('play_app_ribbon');
  static const openKey = ValueKey('play_app_ribbon_open');
  static const closeKey = ValueKey('play_app_ribbon_close');

  @override
  ConsumerState<PlayAppRibbon> createState() => _PlayAppRibbonState();
}

class _PlayAppRibbonState extends ConsumerState<PlayAppRibbon> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(playRibbonEligibleProvider)) return;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && prefs.getBool(PlayAppRibbon.closedKey) != true) {
        setState(() => _show = true);
      }
    }, onError: (_) {});
  }

  Future<void> _close() async {
    setState(() => _show = false);
    try {
      await (await SharedPreferences.getInstance()).setBool(
        PlayAppRibbon.closedKey,
        true,
      );
    } catch (_) {
      /* Shown again next visit; nothing else depends on it. */
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return Padding(
      key: PlayAppRibbon.ribbonKey,
      padding: EdgeInsets.only(top: s.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.borderSubtle),
          borderRadius: BorderRadius.circular(context.radii.button),
        ),
        child: Row(
          children: [
            IconButton(
              key: PlayAppRibbon.closeKey,
              tooltip: l.playRibbonClose,
              onPressed: _close,
              iconSize: HomeTokens.ribbonIcon,
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(
                l.playRibbonText,
                maxLines: 2,
                style: type.caption.copyWith(color: colors.textPrimary),
              ),
            ),
            TextButton(
              key: PlayAppRibbon.openKey,
              onPressed: () =>
                  ref.read(externalLinkOpenerProvider)(kPlayListing),
              child: Text(l.playRibbonOpen),
            ),
          ],
        ),
      ),
    );
  }
}
