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

  /// Online: the room's packs, chosen by the host and copied to every seat.
  const RoomPresentationLayer({super.key, required this.snapshot})
    : _local = false,
      packCode = null,
      narratorCode = null,
      visibleIn = null,
      moment = null;

  /// «القعدة» (store truth): the host phone's own equipped packs, over the
  /// pass-and-play table. [visibleIn] names the phases the phone lies flat
  /// for everyone (never a hand-off, a reveal or the night), and [moment] is
  /// a public announcement on screen (night falls, the vote) whose beat the
  /// narrator marks.
  const RoomPresentationLayer.local({
    super.key,
    required this.snapshot,
    required this.packCode,
    required this.narratorCode,
    required bool Function(GamePhase) this.visibleIn,
    this.moment,
  }) : _local = true;

  final bool _local;
  final String? packCode;
  final String? narratorCode;
  final bool Function(GamePhase)? visibleIn;
  final NarrationBeat? moment;

  @override
  ConsumerState<RoomPresentationLayer> createState() =>
      _RoomPresentationLayerState();
}

class _RoomPresentationLayerState extends ConsumerState<RoomPresentationLayer> {
  String? _caption;

  /// The caption is the narrator pack's own line (styled in its look), not a
  /// presentation pack's intro/outro. A night line stays neutral.
  bool _captionIsNarrator = false;
  Timer? _hide;
  bool _introDone = false;
  bool _outroDone = false;

  PresentationPack? get _pack => Cosmetics.packs[widget._local
      ? widget.packCode
      : widget.snapshot.room.presentationPack];
  NarratorPack? get _narrator => Cosmetics.narrators[widget._local
      ? widget.narratorCode
      : widget.snapshot.room.narratorPack];

  bool _visible(GamePhase phase) =>
      widget.visibleIn?.call(phase) ?? cosmeticsVisibleIn(phase);

  @override
  void didUpdateWidget(RoomPresentationLayer old) {
    super.didUpdateWidget(old);
    final moment = widget.moment;
    if (moment != null && moment != old.moment) {
      _onMoment(moment);
      return;
    }
    final before = old.snapshot.phase;
    final now = widget.snapshot.phase;
    if (before == now && old.snapshot.dayNumber == widget.snapshot.dayNumber) {
      return;
    }
    _onPhase(now);
  }

  /// A public announcement on the flat phone: the narrator marks its beat.
  void _onMoment(NarrationBeat beat) {
    final narrator = _narrator;
    _hide?.cancel();
    if (narrator == null) {
      setState(() => _caption = null);
      return;
    }
    if (beat != NarrationBeat.night) {
      ref.read(audioDirectorProvider).playAccent(narrator.accent);
    }
    _captionIsNarrator = beat != NarrationBeat.night;
    _show(narrator.line(context.l10n, beat));
  }

  void _show(String line) {
    setState(() => _caption = line);
    _hide = Timer(CosmeticTokens.captionHold, () {
      if (mounted) setState(() => _caption = null);
    });
  }

  void _onPhase(GamePhase phase) {
    // A fast phase advance must not carry the preceding caption into it.
    _hide?.cancel();
    _caption = null;
    // «القعدة»: nothing at all outside the flat, public phases.
    if (widget._local && !_visible(phase)) {
      setState(() {});
      return;
    }
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
    _captionIsNarrator = false;
    if (line == null && narrator != null && beat != null) {
      line = narrator.line(l, beat);
      _captionIsNarrator = beat != NarrationBeat.night;
      // Night stays silent: the line is text only.
      if (beat != NarrationBeat.night) sound = narrator.accent;
    }
    if (line == null) return;
    if (sound != null && _visible(phase)) audio.playAccent(sound);
    _hide?.cancel();
    _show(line);
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.snapshot.phase;
    final public = _visible(phase) || widget.moment != null;
    // Online the one night line is text in neutral colours; «القعدة» shows
    // nothing in the night, which is a hand-off there.
    final captionAllowed =
        public || (!widget._local && phase == GamePhase.night);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          PackTransitionOverlay(
            pack: _visible(phase) ? _pack : null,
            trigger: '${phase.name}-${widget.snapshot.dayNumber}',
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: CosmeticTokens.captionTop),
              // Remove the previous subtree immediately on private phases;
              // AnimatedSwitcher would otherwise retain its outgoing text.
              child: captionAllowed
                  ? NarrationCaption(
                      key: ValueKey(public),
                      text: _caption,
                      narrator: _captionIsNarrator ? _narrator : null,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
