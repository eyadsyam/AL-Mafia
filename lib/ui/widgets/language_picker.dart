import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/locale_controller.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

class LanguagePicker extends ConsumerStatefulWidget {
  const LanguagePicker({super.key});
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
      Text(context.l10n.languageLabel, style: context.typography.title),
      SizedBox(height: context.spacing.sm),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'ar',
            label: Text(context.l10n.languageNameArabic),
          ),
          ButtonSegment(
            value: 'en',
            label: Text(context.l10n.languageNameEnglish),
          ),
        ],
        selected: {ref.watch(localeProvider).languageCode},
        onSelectionChanged: _saving ? null : (values) => _select(values.single),
      ),
      if (_failed) Text(context.l10n.profileSaveFailed),
    ],
  );
}
