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
/// ## The one switch, and the direction it turns
///
/// A player can silence themselves. They cannot un-silence themselves past the
/// phase: [VoiceController.setSelfMuted] only ever subtracts, and turning it
/// back off restores exactly what `micPolicyFor` and the server already allow
/// — which during a night is nothing. So this is not the client-side mute doc
/// 10 §6.1 forbids; that rule is about a client deciding it may be heard, and
/// nothing here can decide that. [VoiceState.microphoneLive] is still reported
/// and never set.
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

  /// The player's own microphone switch. Live from the lobby onwards.
  static const Key micButton = ValueKey('voice_mic');

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
    } else if (state.selfMuted) {
      status = l10n.voiceSelfMuted;
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
          // Task 12 — a microphone, not the words for one. Doc 07 keeps icons
          // for navigation chrome and gives every *game action* a word, and
          // this is not one: muting your own microphone changes nothing about
          // the match and is the same control every call app on the phone
          // draws exactly this way. The floor below it keeps its words,
          // because taking the floor is a move.
          if (controller != null && state.canMuteSelf)
            IconButton(
              key: micButton,
              tooltip: state.selfMuted ? l10n.voiceUnmuteMe : l10n.voiceMuteMe,
              onPressed: () => controller.setSelfMuted(!state.selfMuted),
              icon: Icon(
                state.selfMuted ? Icons.mic_off : Icons.mic_none,
                color: state.selfMuted ? colors.textMuted : colors.textSecondary,
              ),
            ),
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
