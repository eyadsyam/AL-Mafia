import 'package:flutter/material.dart';

import '../../data/terms_consent.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'settings_kit.dart';

/// The terms and the privacy summary, read in place.
///
/// A sheet over the current route rather than a new route or a browser: back
/// (button or system) closes it and returns to exactly the form that was being
/// filled. Opening it proves nothing and records nothing.
Future<void> showTermsDocument(BuildContext context) => _showDocument(
  context,
  key: LegalDocuments.termsSheetKey,
  title: context.l10n.termsTitle,
  subtitle: context.l10n.termsVersion(currentTermsVersion),
  body: context.l10n.termsBody,
);

Future<void> showPrivacyDocument(BuildContext context) => _showDocument(
  context,
  key: LegalDocuments.privacySheetKey,
  title: context.l10n.privacyLinkLabel,
  body: context.l10n.privacySummaryBody,
);

Future<void> _showDocument(
  BuildContext context, {
  required Key key,
  required String title,
  String? subtitle,
  required String body,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) {
    final s = context.spacing;
    return DraggableScrollableSheet(
      key: key,
      expand: false,
      initialChildSize: SheetTokens.documentInitialFraction,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.all(s.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.typography.headline),
            if (subtitle != null)
              Text(subtitle, style: context.typography.caption),
            SizedBox(height: s.md),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Text(body, style: context.typography.body),
              ),
            ),
            SizedBox(height: s.md),
            FilledButton(
              key: LegalDocuments.closeKey,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.documentClose),
            ),
          ],
        ),
      ),
    );
  },
);

/// Both documents, always reachable from Settings.
class LegalDocuments extends StatelessWidget {
  const LegalDocuments({super.key});

  static const termsSheetKey = ValueKey('legal_terms_sheet');
  static const privacySheetKey = ValueKey('legal_privacy_sheet');
  static const closeKey = ValueKey('legal_close');
  static const termsButtonKey = ValueKey('legal_open_terms');
  static const privacyButtonKey = ValueKey('legal_open_privacy');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsLinkRow(
        key: termsButtonKey,
        icon: Icons.gavel_outlined,
        label: context.l10n.termsTitle,
        onTap: () => showTermsDocument(context),
      ),
      Divider(
        color: context.colors.borderSubtle,
        height: context.spacing.sm + 1,
      ),
      SettingsLinkRow(
        key: privacyButtonKey,
        icon: Icons.shield_outlined,
        label: context.l10n.privacyLinkLabel,
        onTap: () => showPrivacyDocument(context),
      ),
    ],
  );
}
