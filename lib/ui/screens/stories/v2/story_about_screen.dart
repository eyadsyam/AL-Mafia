import 'package:flutter/material.dart';

import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import 'lamp_kit.dart';

/// «يعني إيه قصص وتحقيقات؟» — shown the first time Stories opens, and from
/// the hub's «إزاي نلعب؟» after that.
class StoryAboutScreen extends StatelessWidget {
  const StoryAboutScreen({super.key, required this.onDone, this.onBack});

  static const goKey = ValueKey('sv2_about_go');

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LampScaffold(
      onBack: onBack,
      footer: LampButton(key: goKey, label: l.sv2AboutGo, onPressed: onDone),
      body: LampScroll(
        children: [
          LampTitle(l.storiesTitle),
          LampMeta(l.sv2AboutLead),
          _mode(
            context,
            l.sv2ModeSoloCount,
            l.sv2ModeSoloTitle,
            l.sv2ModeSoloBody,
          ),
          _mode(
            context,
            l.sv2ModeAllCount,
            l.sv2ModeAllTitle,
            l.sv2ModeAllBody,
          ),
          _mode(
            context,
            l.sv2ModeDetCount,
            l.sv2ModeDetTitle,
            l.sv2ModeDetBody,
          ),
          LampMeta(l.sv2AboutChanges, center: true),
        ],
      ),
    );
  }

  Widget _mode(BuildContext context, String count, String title, String body) {
    final type = context.typography;
    final s = context.spacing;
    return LampPaper(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: StoriesLampTokens.control,
            child: Text(
              count,
              textAlign: TextAlign.center,
              style: type.title.copyWith(
                color: StoriesLampTokens.amberDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: type.body.copyWith(
                    color: StoriesLampTokens.paperInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  body,
                  style: type.bodySmall.copyWith(
                    color: StoriesLampTokens.paperInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
