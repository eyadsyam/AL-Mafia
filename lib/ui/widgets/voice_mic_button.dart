import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/voice/voice_controller.dart';
import '../l10n_ext.dart';
import '../screens/online/voice_session.dart';
import '../theme/mafia_theme.dart';

/// The lobby's whole voice surface: one microphone, no words (task 9).
///
/// ## Why the words went
///
/// The lobby said two things about voice at once — a status line in the middle
/// of the screen and a strip at the bottom — and they contradicted each other
/// often enough to be worse than silence. Only one of the two was ever a
/// control. This is that one.
///
/// A microphone with a stroke through it is understood without being read, and
/// the lobby is the one place in the app where nothing is at stake yet: there
/// is no floor to take and no phase policy to explain, so the icon is the whole
/// truth about voice here.
///
/// ## Why it must be mounted even before there is a call
///
/// Watching [voiceStateProvider] is what *builds* the controller — a room that
/// has been made is a room whose microphone is already connecting (doc 10 §6.2)
/// — so this widget starts the call by existing, exactly as the strip it
/// replaced did. It draws nothing until there is something to draw.
///
/// The switch only ever subtracts, like [VoiceControls]': turning the mute off
/// restores what `micPolicyFor` and the server already allow, never more.
class VoiceMicButton extends ConsumerWidget {
  const VoiceMicButton({super.key});

  static const Key micKey = ValueKey('lobby_voice_mic');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceStateProvider).valueOrNull;
    if (state == null || state.mode == VoiceMode.off) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(voiceControllerProvider);
    final colors = context.colors;
    final l10n = context.l10n;

    // A device that refused the microphone is drawn struck through and inert:
    // the state is honest and the tap would do nothing.
    final unavailable = !state.microphoneAvailable ||
        state.mode == VoiceMode.text ||
        controller == null ||
        !state.canMuteSelf;
    final off = state.selfMuted || !state.microphoneAvailable;

    return IconButton(
      key: micKey,
      tooltip: off ? l10n.voiceUnmuteMe : l10n.voiceMuteMe,
      onPressed: unavailable
          ? null
          : () => controller.setSelfMuted(!state.selfMuted),
      icon: Icon(
        off ? Icons.mic_off : Icons.mic_none,
        color: unavailable
            ? colors.textMuted
            : (off ? colors.textMuted : colors.textSecondary),
      ),
    );
  }
}
