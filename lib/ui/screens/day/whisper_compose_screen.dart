import 'package:flutter/material.dart';

import '../../../core/whisper_language.dart';
import '../../../engine/information/records.dart';
import '../../../engine/models/enums.dart' show PlayerStatus;
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/player_tile.dart';
import '../../widgets/textured_surface.dart';

/// The whisper composer (doc 14 §3).
///
/// ## Two steps, and the first one used to be "who are you"
///
/// It asked, because offline there is one phone and the app genuinely could
/// not know. Doc 14 §3.1 settles that by removing the layer from offline
/// altogether: one shared screen cannot deliver a private message during a
/// discussion without stopping the discussion to pass the phone, which is the
/// conversation the message existed to influence.
///
/// So the sender is [fromSeat] — this device's own player — and what is left is
/// pick somebody, write, send.
///
/// ## Self-exclusion is structural, not a check
///
/// The recipient list is built from *other living players*. There is no `if`
/// anywhere that removes the sender afterwards, because the list they could be
/// removed from is a list they were never on. Doc 14 Part 0 names this as the
/// original bug: the spec said "self excluded" and the code filtered a list
/// that had already been built from everybody.
class WhisperComposeScreen extends StatefulWidget {
  final List<PublicPlayer> players;

  /// The seat writing this. Never in the recipient list.
  final int fromSeat;

  /// Sends the whisper. The caller writes the body to the whisper store.
  final void Function(int fromSeat, int toSeat, String body) onSend;

  final VoidCallback onCancel;

  /// F21a: players who are out can read whispers, and every writer is told so
  /// by one identical line.
  final bool witnessed;

  const WhisperComposeScreen({
    super.key,
    required this.players,
    required this.fromSeat,
    required this.onSend,
    required this.onCancel,
    this.witnessed = false,
  });

  static const disclosure = ValueKey('whisper_witness_disclosure');

  @override
  State<WhisperComposeScreen> createState() => _WhisperComposeScreenState();
}

class _WhisperComposeScreenState extends State<WhisperComposeScreen> {
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
    return _to != null &&
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
    widget.onSend(widget.fromSeat, _to!, text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    // Doc 14 §3.3. *Other* living players — the sender is not filtered out of
    // this list, they were never put in it.
    final recipients = [
      for (final p in widget.players)
        if (p.status == PlayerStatus.alive && p.seat != widget.fromSeat) p,
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
                    _to == null
                        ? l10n.whisperPickRecipient
                        : l10n.whisperBodyHint,
                    style: type.bodySmall.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Expanded(
                    child: _to == null
                        ? _seatList(
                            recipients,
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
                        style: type.bodySmall.copyWith(
                          color: colors.accentCrimson,
                        ),
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
    List<PublicPlayer> recipients, {
    required ValueChanged<int> onPick,
  }) {
    final spacing = context.spacing;
    return ListView.separated(
      itemCount: recipients.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
      itemBuilder: (context, index) {
        final player = recipients[index];
        return PlayerTile(
          seat: player.seat,
          name: player.name,
          onTap: () => onPick(player.seat),
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
        if (widget.witnessed)
          Text(
            key: WhisperComposeScreen.disclosure,
            context.l10n.witnessWhispersDisclosure,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }
}
