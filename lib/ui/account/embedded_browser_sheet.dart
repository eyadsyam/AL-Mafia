import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/clipboard.dart';
import '../../platform/links/in_app_browser.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import '../widgets/mafia_kit.dart';

/// Whether this page runs inside Facebook's, Instagram's, TikTok's or
/// Snapchat's own browser, where Google refuses to sign anyone in.
/// A provider so a test can stand in for the browser.
final embeddedBrowserProvider = Provider<bool>(
  (ref) => kIsWeb && inEmbeddedBrowser,
);

/// Before any Google sign-in: inside one of those browsers the player is told
/// to open the game in a real one (and given the way) instead of being sent to
/// Google's refusal page. True when that is what happened; the caller then
/// starts nothing. Email and password still work where they are.
Future<bool> sentToRealBrowser(BuildContext context, WidgetRef ref) async {
  if (!ref.read(embeddedBrowserProvider)) return false;
  // A second tap before the first sheet is up is the same request, not a
  // second sheet stacked on the first.
  if (_realBrowserSheetOpen) return true;
  _realBrowserSheetOpen = true;
  try {
    await showMafiaSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surfaceBase,
      builder: (_) => const EmbeddedBrowserSheet(),
    );
  } finally {
    _realBrowserSheetOpen = false;
  }
  return true;
}

bool _realBrowserSheetOpen = false;

class EmbeddedBrowserSheet extends StatefulWidget {
  const EmbeddedBrowserSheet({super.key});

  static const chromeKey = ValueKey('embedded_open_chrome');
  static const copyKey = ValueKey('embedded_copy_link');

  @override
  State<EmbeddedBrowserSheet> createState() => _EmbeddedBrowserSheetState();
}

class _EmbeddedBrowserSheetState extends State<EmbeddedBrowserSheet> {
  bool _copied = false;

  Future<void> _copy() async {
    final copied = await AppClipboard.copy(pageAddress().toString());
    if (mounted && copied) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(s.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.inAppBrowserTitle,
              textAlign: TextAlign.center,
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: s.sm),
            Text(
              l.inAppBrowserBody,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: s.lg),
            if (embeddedOnAndroid) ...[
              FilledButton(
                key: EmbeddedBrowserSheet.chromeKey,
                onPressed: () => openHere(chromeIntentFor(pageAddress())),
                child: Text(l.inAppBrowserChrome),
              ),
              SizedBox(height: s.sm),
            ],
            OutlinedButton(
              key: EmbeddedBrowserSheet.copyKey,
              onPressed: _copy,
              child: Text(_copied ? l.inAppBrowserCopied : l.inAppBrowserCopy),
            ),
          ],
        ),
      ),
    );
  }
}
