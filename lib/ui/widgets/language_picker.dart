import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/locale_controller.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'settings_kit.dart';

class LanguagePicker extends ConsumerStatefulWidget {
  const LanguagePicker({super.key});
  static const launcherNoteKey = ValueKey('launcher_label_pending');
  static const arabicKey = ValueKey('language_ar');
  static const englishKey = ValueKey('language_en');
  @override
  ConsumerState<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends ConsumerState<LanguagePicker> {
  bool _saving = false;
  bool _failed = false;
  Future<void> _select(String code) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await ref.read(localeProvider.notifier).select(code);
    if (mounted) {
      setState(() {
        _saving = false;
        _failed = !saved;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsSegments<String>(
        label: context.l10n.languageLabel,
        value: ref.watch(localeProvider).languageCode,
        options: [
          ('ar', context.l10n.languageArabic, LanguagePicker.arabicKey),
          ('en', context.l10n.languageEnglish, LanguagePicker.englishKey),
        ],
        onChanged: _saving ? null : _select,
      ),
      if (_failed)
        Text(
          context.l10n.profileSaveFailed,
          style: context.typography.caption.copyWith(
            color: context.colors.accentCrimson,
          ),
        ),
      if (ref.watch(launcherLabelPendingProvider))
        Padding(
          padding: EdgeInsets.only(bottom: context.spacing.sm),
          child: Text(
            context.l10n.launcherLabelPending,
            key: LanguagePicker.launcherNoteKey,
            style: context.typography.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ),
    ],
  );
}
