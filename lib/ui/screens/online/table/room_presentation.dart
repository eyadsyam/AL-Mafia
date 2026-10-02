import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../engine/models/enums.dart' show GamePhase;
import '../../../../platform/audio_director.dart';
import '../../../../transport/game_snapshot.dart';
import '../../../economy/cosmetic_paint.dart';
import '../../../economy/cosmetics.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';

/// The host's presentation and narrator packs, played over the table.
///
/// Everything here is identical on every device in the room: it is keyed on
/// the public phase and nothing else, never on a role, a seat or an action.
/// Doc 05: nothing is drawn or heard in the night, distribution or night
/// lobby (the transition and the colour are for public phases, and the one
/// night line is text in neutral colours with no sound). Nothing waits on it:
/// a missing sound or a reduced-motion setting simply means less decoration.
class RoomPresentationLayer extends ConsumerStatefulWidget {
  final GameSnapshot snapshot;
  const RoomPresentationLayer({super.key, required this.snapshot});

  @override
  ConsumerState<RoomPresentationLayer> createState() =>
      _RoomPresentationLayerState();
}

class _RoomPresentationLayerState extends ConsumerState<RoomPresentationLayer> {
  String? _caption;
  Timer? _hide;
  bool _introDone = false;
  bool _outroDone = false;

  PresentationPack? get _pack =>
      Cosmetics.packs[widget.snapshot.room.presentationPack];
  NarratorPack? get _narrator =>
      Cosmetics.narrators[widget.snapshot.room.narratorPack];

  @override
  void didUpdateWidget(RoomPresentationLayer old) {
    super.didUpdateWidget(old);
    final before = old.snapshot.phase;
    final now = widget.snapshot.phase;
    if (before == now && old.snapshot.dayNumber == widget.snapshot.dayNumber) {
      return;
    }
    _onPhase(now);
  }

  void _onPhase(GamePhase phase) {
    // A fast phase advance must not carry the preceding caption into it.
    _hide?.cancel();
    _caption = null;
    final l = context.l10n;
    final audio = ref.read(audioDirectorProvider);
    final pack = _pack;
    final narrator = _narrator;
    String? line;
    String? sound;
    final firstDay =
        !_introDone &&
        (phase == GamePhase.morning || phase == GamePhase.openingRound);
    if (pack != null && firstDay) {
      _introDone = true;
      line = pack.intro(l);
      sound = pack.introSound;
    } else if (pack != null && phase == GamePhase.result && !_outroDone) {
      _outroDone = true;
      line = pack.outro(l);
      sound = pack.outroSound;
    }
    final beat = beatFor(phase);
    if (line == null && narrator != null && beat != null) {
      line = narrator.line(l, beat);
      // Night stays silent: the line is text only.
      if (beat != NarrationBeat.night) sound = narrator.accent;
    }
    if (line == null) return;
    if (sound != null && cosmeticsVisibleIn(phase)) audio.playAccent(sound);
    _hide?.cancel();
    setState(() => _caption = line);
    _hide = Timer(CosmeticTokens.captionHold, () {
      if (mounted) setState(() => _caption = null);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.snapshot.phase;
    final public = cosmeticsVisibleIn(phase);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          PackTransitionOverlay(
            pack: public ? _pack : null,
            trigger: '${phase.name}-${widget.snapshot.dayNumber}',
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: CosmeticTokens.captionTop),
              // Remove the previous subtree immediately on private phases;
              // AnimatedSwitcher would otherwise retain its outgoing text.
              child: public || phase == GamePhase.night
                  ? NarrationCaption(key: ValueKey(public), text: _caption)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
