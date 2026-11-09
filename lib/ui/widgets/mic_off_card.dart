import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/voice/microphone_permission.dart';
import '../../platform/voice/voice_controller.dart';
import '../l10n_ext.dart';
import '../screens/online/voice_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// «افتح المايك»: the system dialog again when the phone can still show it;
/// this app's settings page when the phone stopped asking; the one line that
/// says where a browser keeps the switch. True when the microphone works now.
Future<bool> openMicrophone(BuildContext context, WidgetRef ref) async {
  final access = ref.read(microphoneAccessProvider);
  final controller = ref.read(voiceControllerProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  if (!kIsWeb) {
    var status = await access.status();
    if (status == MicrophoneStatus.denied) status = await access.request();
    if (status == MicrophoneStatus.blocked) {
      messenger?.showSnackBar(SnackBar(content: Text(l.micOffSettingsHint)));
      await access.openSettings();
      return false;
    }
  }
  final ok = await controller?.retryMicrophone() ?? false;
  if (!ok && kIsWeb) {
    messenger?.showSnackBar(SnackBar(content: Text(l.micOffWebHint)));
  }
  return ok;
}

/// The lobby card: red, above the seats, until the microphone works. Asks
/// again by itself when the player comes back from the phone's settings.
class MicOffCard extends ConsumerStatefulWidget {
  const MicOffCard({super.key});

  static const cardKey = ValueKey('mic_off_card');
  static const actionKey = ValueKey('mic_off_action');

  @override
  ConsumerState<MicOffCard> createState() => _MicOffCardState();
}

class _MicOffCardState extends ConsumerState<MicOffCard>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final voice = ref.read(voiceStateProvider).valueOrNull;
    if (voice?.microphoneRefused ?? false) {
      unawaited(ref.read(voiceControllerProvider)?.retryMicrophone());
    }
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    await openMicrophone(context, ref);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceStateProvider).valueOrNull;
    if (voice == null ||
        voice.mode == VoiceMode.off ||
        !voice.microphoneRefused) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return Container(
      key: MicOffCard.cardKey,
      padding: EdgeInsets.all(s.md),
      decoration: BoxDecoration(
        color: colors.accentCrimson.withValues(alpha: MicOffTokens.tintAlpha),
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(
          color: colors.accentCrimson,
          width: MicOffTokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_off,
                size: MicOffTokens.icon,
                color: colors.textPrimary,
              ),
              SizedBox(width: s.sm),
              Expanded(
                child: Text(
                  l.micOffTitle,
                  style: type.title.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: s.xs),
          Text(
            l.micOffBody,
            style: type.body.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: s.sm),
          FilledButton(
            key: MicOffCard.actionKey,
            onPressed: _busy ? null : _open,
            child: Text(l.micOffAction),
          ),
        ],
      ),
    );
  }
}
