import 'package:flutter/material.dart';

import '../../../core/whisper_language.dart';
import '../../../engine/information/records.dart';
import '../../../engine/models/enums.dart' show PlayerStatus;
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/player_tile.dart';
import '../../widgets/textured_surface.dart';

/// The whisper composer (doc 09 §3).
///
/// ## Three steps, and why the first one exists
///
/// Offline there is one phone, so "who is writing this" is a question the app
/// has to ask before it can ask anything else. The seat picker is that
/// question, and it is also the day's only gate: a player picks their own seat,
/// writes, sends, and puts the phone back down.
///
/// A seat that has already used its whisper today is shown and disabled rather
/// than hidden. Hiding it would make the *length of the list* say who had
/// already written — and the whisper graph on the table behind this screen says
/// that out loud anyway, so there is nothing to protect and a disabled tile is
/// the clearer explanation.
///
/// ## What is private here and what is not
///
/// The recipient is public the instant the whisper is sent; the body never is.
/// So this screen is dimmed and held close, but its *secret* is small and
/// short-lived: whoever is holding the phone is visibly composing, and the
/// table will see the edge appear. That is the design (doc 09 §3.1) rather
/// than a compromise in it.
class WhisperComposeScreen extends StatefulWidget {
  final List<PublicPlayer> players;

  /// Seats that have already used today's whisper.
  final Set<int> alreadySent;

  /// Sends the whisper. The caller writes the body to the whisper store.
  final void Function(int fromSeat, int toSeat, String body) onSend;

  final VoidCallback onCancel;

  const WhisperComposeScreen({
    super.key,
    required this.players,
    required this.alreadySent,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<WhisperComposeScreen> createState() => _WhisperComposeScreenState();
}

class _WhisperComposeScreenState extends State<WhisperComposeScreen> {
  int? _from;
  int? _to;
  final TextEditingController _body = TextEditingController();

  /// Set once the profanity warning has been shown and waved through.
  ///
  /// A warning, not a block (doc 09 §3.5): the filter is a word list and word
  /// lists are wrong often enough that refusing to send would be worse than the
  /// thing it is guarding against. It fires once per message.
  bool _languageAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _canSend {
    final text = _body.text.trim();
    return _from != null &&
        _to != null &&
        text.isNotEmpty &&
        text.length <= WhisperLimits.maxLength;
  }

  void _send() {
    if (!_canSend) return;
    final text = _body.text.trim();
    if (!_languageAcknowledged && WhisperLanguage.looksAbusive(text)) {
      setState(() => _languageAcknowledged = true);
      return;
    }
    widget.onSend(_from!, _to!, text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final living = [
      for (final p in widget.players)
        if (p.status == PlayerStatus.alive) p,
    ];
    final remaining = WhisperLimits.maxLength - _body.text.trim().length;

    return AppBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.whisperCompose,
                    style: type.headline.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    _from == null
                        ? l10n.whoAreYou
                        : (_to == null
                            ? l10n.whisperPickRecipient
                            : l10n.whisperBodyHint),
                    style: type.bodySmall.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Expanded(
                    child: _from == null
                        ? _seatList(
                            living,
                            // A seat that has already whispered today cannot
                            // whisper again (H-E1). Shown, not hidden.
                            disabled: widget.alreadySent,
                            onPick: (seat) => setState(() => _from = seat),
                          )
                        : _to == null
                            ? _seatList(
                                living,
                                // No self-whisper (H-E5), and the dead are not
                                // in `living` at all (H-E4).
                                disabled: {_from!},
                                onPick: (seat) => setState(() => _to = seat),
                              )
                            : _composer(remaining),
                  ),
                  SizedBox(height: spacing.md),
                  if (_languageAcknowledged &&
                      WhisperLanguage.looksAbusive(_body.text.trim()))
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing.sm),
                      child: Text(
                        l10n.whisperLanguageWarning,
                        style: type.bodySmall
                            .copyWith(color: colors.accentCrimson),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    height: spacing.xxl + spacing.sm,
                    child: FilledButton(
                      onPressed: _canSend ? _send : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        disabledBackgroundColor: colors.surfaceOverlay,
                        disabledForegroundColor: colors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(l10n.whisperSend, style: type.title),
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textMuted,
                    ),
                    child: Text(l10n.cancel, style: type.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatList(
    List<PublicPlayer> living, {
    required Set<int> disabled,
    required ValueChanged<int> onPick,
  }) {
    final spacing = context.spacing;
    return ListView.separated(
      itemCount: living.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
      itemBuilder: (context, index) {
        final player = living[index];
        final blocked = disabled.contains(player.seat);
        return PlayerTile(
          seat: player.seat,
          name: player.name,
          state: blocked ? PlayerTileState.disabled : PlayerTileState.normal,
          onTap: blocked ? null : () => onPick(player.seat),
        );
      },
    );
  }

  Widget _composer(int remaining) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(radii.card),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: TextField(
                controller: _body,
                // Hard-limited at the input as well as in the engine (H-E6).
                // Never truncated silently: the counter goes negative-looking
                // long before anybody reaches the cap.
                maxLength: WhisperLimits.maxLength,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: type.body.copyWith(color: colors.textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          '$remaining',
          style: type.caption.copyWith(
            color: remaining < 0 ? colors.accentCrimson : colors.textMuted,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
