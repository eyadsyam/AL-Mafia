import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';

class HelpButton extends StatefulWidget {
  const HelpButton({super.key});

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton> {
  final _overlay = OverlayPortalController();

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    overlayChildBuilder: (_) =>
        Positioned.fill(child: HelpCenter(onClose: _overlay.hide)),
    child: TextButton.icon(
      icon: const Icon(Icons.help_outline),
      label: Text(context.l10n.helpTitle),
      onPressed: _overlay.show,
    ),
  );
}

class HelpCenter extends StatelessWidget {
  final VoidCallback? onClose;
  const HelpCenter({super.key, this.onClose});

  static const closeKey = ValueKey('help_close');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final spacing = context.spacing;
    final entries = <(String, String)>[
      (l.helpPlayQuestion, l.helpPlayAnswer),
      (l.helpOnlineQuestion, l.helpOnlineAnswer),
      (l.helpVoiceQuestion, l.helpVoiceAnswer),
      (l.helpReconnectQuestion, l.helpReconnectAnswer),
      (l.helpSafetyQuestion, l.helpSafetyAnswer),
      (l.helpCoinsQuestion, l.helpCoinsAnswer),
      (l.helpPrivacyQuestion, l.helpPrivacyAnswer),
      (l.helpAgeQuestion, l.helpAgeAnswer),
      (l.helpSupportQuestion, l.helpSupportAnswer),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.helpTitle),
        leading: onClose == null
            ? null
            : IconButton(
                key: closeKey,
                onPressed: onClose,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(spacing.screenMargin),
            children: [
              Text(l.helpIntro, style: context.typography.body),
              SizedBox(height: spacing.md),
              for (final entry in entries)
                ExpansionTile(
                  title: Text(entry.$1, style: context.typography.title),
                  childrenPadding: EdgeInsetsDirectional.fromSTEB(
                    spacing.md,
                    0,
                    spacing.md,
                    spacing.md,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Text(entry.$2, style: context.typography.body)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
