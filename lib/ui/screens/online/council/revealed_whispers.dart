import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../economy/vault_kit.dart';
import '../../../l10n_ext.dart';
import '../../../theme/mafia_theme.dart';
import '../online_session.dart';
import '../witness/witness_layer.dart' show WitnessPopup;

/// Doc 09 §7 «كشف محتوى الهمسات بعد المباراة»: one whisper of a finished
/// room that chose to reveal them. Seats, never user ids; [text] is null when
/// the viewer blocked the sender ([masked]).
class RevealedWhisper {
  final int day;
  final int fromSeat;
  final int toSeat;
  final String? text;
  final bool masked;
  const RevealedWhisper({
    required this.day,
    required this.fromSeat,
    required this.toSeat,
    this.text,
    this.masked = false,
  });

  /// The server's list, or null when the room did not reveal (or is not over).
  /// Malformed rows are skipped.
  static List<RevealedWhisper>? listFromJson(Object? json) {
    if (json is! List) return null;
    return [
      for (final row in json)
        if (row is Map &&
            row['day'] is int &&
            row['fromSeat'] is int &&
            row['toSeat'] is int)
          RevealedWhisper(
            day: row['day'] as int,
            fromSeat: row['fromSeat'] as int,
            toSeat: row['toSeat'] as int,
            text: row['text'] is String ? row['text'] as String : null,
            masked: row['masked'] == true,
          ),
    ];
  }
}

/// Read once per finished room, only after the outcome is public, only when
/// the room's rule says so (the caller checks both).
final revealedWhispersProvider = FutureProvider.autoDispose
    .family<List<RevealedWhisper>?, String>((ref, roomId) async {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('economy', {
        'action': 'matchWhispers',
        'roomId': roomId,
      });
      return RevealedWhisper.listFromJson(answer['whispers']);
    });

/// The whispers of the match, over the result (in-scene, Doc 12).
class RevealedWhispers extends ConsumerWidget {
  final String roomId;
  final Map<int, String> names;
  final VoidCallback onClose;

  static const Key sheetKey = ValueKey('revealed_whispers');
  static Key row(int i) => ValueKey('revealed_whisper_$i');

  const RevealedWhispers({
    super.key,
    required this.roomId,
    required this.names,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final type = context.typography;
    final colors = context.colors;
    final s = context.spacing;
    final whispers = ref.watch(revealedWhispersProvider(roomId));
    Widget line(String text, {Color? color}) => Padding(
      padding: EdgeInsets.symmetric(vertical: s.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: type.body.copyWith(color: color ?? colors.textSecondary),
      ),
    );
    return WitnessPopup(
      key: sheetKey,
      onDismiss: onClose,
      child: VaultCard(
        lit: true,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.revealWhispersTitle,
            style: type.title.copyWith(color: colors.accentGold),
          ),
          SizedBox(height: s.sm),
          Flexible(
            child: whispers.when(
              loading: () => Padding(
                padding: EdgeInsets.all(s.md),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => line(l.revealWhispersFailed),
              data: (rows) {
                if (rows == null || rows.isEmpty) {
                  return line(l.revealWhispersEmpty);
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => Divider(color: colors.borderSubtle),
                  itemBuilder: (context, i) {
                    final w = rows[i];
                    return Column(
                      key: row(i),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l.dayNumbered(w.day)} · ${names[w.fromSeat] ?? ''} '
                          '${l.whisperArrow} ${names[w.toSeat] ?? ''}',
                          style: type.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: s.xs),
                        Text(
                          w.masked || w.text == null
                              ? l.revealWhispersMasked
                              : w.text!,
                          style: type.body.copyWith(
                            color: w.masked
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: s.sm),
          TextButton(
            onPressed: onClose,
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// «في الأوضة دي الهمسات هتتكشف للكل بعد الماتش» — shown in the lobby to
/// every seat and over the whisper composer, so nobody whispers without
/// knowing.
class RevealWhispersNotice extends StatelessWidget {
  static const Key noticeKey = ValueKey('reveal_whispers_notice');
  const RevealWhispersNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      key: noticeKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.visibility_outlined,
          size: context.typography.caption.fontSize,
          color: colors.accentGold,
        ),
        SizedBox(width: context.spacing.xs),
        Flexible(
          child: Text(
            context.l10n.revealWhispersNotice,
            textAlign: TextAlign.center,
            style: context.typography.caption.copyWith(
              color: colors.accentGold,
            ),
          ),
        ),
      ],
    );
  }
}
