import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/voice/voice_controller.dart';
import '../l10n_ext.dart';
import '../screens/online/voice_session.dart';
import '../theme/mafia_theme.dart';

/// The voice controls — the other of the two widgets doc 10 §7 permits to know
/// something about the transport, and like the banner it reads a value rather
/// than a type.
///
/// ## What it will not do
///
/// Mute. There is no mute button here and there is not going to be one: the
/// microphone is live because the phase permits it and the server granted the
/// floor (doc 10 §6.1), and a control that could contradict either would be a
/// control that lets a player be heard during a night. [VoiceState.microphoneLive]
/// is reported, never set.
///
/// ## What it renders when there is no call
///
/// Nothing, and that is the common case. Offline there is no voice session at
/// all, so this is a zero-height box on every screen of every offline match —
/// which is what makes it safe to mount once, in the phase flow, rather than
/// on each of the screens that happens to have a floor.
class VoiceControls extends ConsumerWidget {
  const VoiceControls({super.key});

  static const Key stripKey = ValueKey('voice_controls');
  static const Key floorButton = ValueKey('voice_floor');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceStateProvider).valueOrNull;
    if (state == null || state.mode == VoiceMode.off) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    // One line, in the order a player asks the questions: can I be heard at
    // all, is anybody speaking, and is it me.
    final String status;
    if (state.mode == VoiceMode.text) {
      status = l10n.voiceTextMode;
    } else if (!state.microphoneAvailable) {
      // V1 and V2 — stated once, as a fact about this device, and never as an
      // error. It stays because it stays true, not because it is repeated.
      status = l10n.voiceMicDenied;
    } else if (state.microphoneLive) {
      status = l10n.voiceMicOn;
    } else if (state.activeSpeakerSeat != null) {
      status = l10n.voiceFloorTaken;
    } else {
      status = l10n.voiceMicOff;
    }

    final controller = ref.read(voiceControllerProvider);

    return Container(
      key: stripKey,
      width: double.infinity,
      color: colors.surfaceRaised,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              status,
              style: type.caption.copyWith(color: colors.textSecondary),
            ),
          ),
          // Words, not a microphone glyph: doc 07 keeps icons for navigation
          // chrome and gives every game action a word.
          if (controller != null &&
              (state.canRequestFloor || state.holdsFloor))
            TextButton(
              key: floorButton,
              onPressed: state.holdsFloor
                  ? controller.yieldFloor
                  : controller.requestFloor,
              child: Text(
                state.holdsFloor ? l10n.voiceYieldFloor : l10n.voiceTakeFloor,
              ),
            ),
        ],
      ),
    );
  }
}
