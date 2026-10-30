import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../platform/audio_director.dart';
import '../../economy/cosmetics.dart';
import '../../economy/store_art.dart';
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../setup/role_rows.dart' show StoreDoor;

/// A room's atmosphere or narrator, chosen by what it is: a scene is picked
/// from its picture and heard opening, a narrator from their portrait and their
/// voice. A row of names told a host nothing about what they were choosing.
///
/// Public before any role exists: the same choice reaches every seat.
class RoomLookPicker extends ConsumerWidget {
  final CosmeticSlot slot;
  final String title;
  final String current;
  final ValueChanged<String> onChanged;

  const RoomLookPicker({
    super.key,
    required this.slot,
    required this.title,
    required this.current,
    required this.onChanged,
  });

  static Key tile(String code) => ValueKey('room_look_$code');
  static Key listen(String code) => ValueKey('room_look_listen_$code');
  static const Key storeKey = ValueKey('room_look_store');

  /// Classic, every code owned for the slot, and the room's current code even
  /// if this host does not own it (a hand-over keeps the previous host's).
  List<String> _codes(WalletState? wallet) => [
    'classic',
    for (final code in {
      ...?wallet?.ownedFor(slot),
      if (current != 'classic') current,
    })
      if (Cosmetics.items[code]?.slot == slot) code,
  ];

  void _hear(WidgetRef ref, String code) {
    final audio = ref.read(audioDirectorProvider);
    if (slot == CosmeticSlot.narrator) {
      audio.previewNarrator(code);
    } else if (Cosmetics.packs[code] case final pack?) {
      audio.playAccent(pack.introSound);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final codes = _codes(ref.watch(walletProvider).valueOrNull);
    final narrator = slot == CosmeticSlot.narrator;
    // A scene is off sale (store v4): no store door for what cannot be bought.
    if (!narrator && codes.length == 1) return const SizedBox.shrink();
    final line = narrator
        ? Cosmetics.narrators[current]?.line(l, NarrationBeat.discussion)
        : Cosmetics.packs[current]?.intro(l);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: type.body.copyWith(color: colors.textPrimary)),
          SizedBox(height: s.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final code in codes)
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: s.sm),
                    child: _LookTile(
                      code: code,
                      slot: slot,
                      selected: code == current,
                      onTap: () {
                        if (code != current) onChanged(code);
                        _hear(ref, code);
                      },
                      onListen: narrator ? () => _hear(ref, code) : null,
                    ),
                  ),
                if (narrator)
                  StoreDoor(
                    builder: (context, open) => _StoreTile(onTap: open),
                  ),
              ],
            ),
          ),
          if (line != null) ...[
            SizedBox(height: s.sm),
            Text(
              '«$line»',
              style: type.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _LookTile extends StatelessWidget {
  final String code;
  final CosmeticSlot slot;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onListen;

  const _LookTile({
    required this.code,
    required this.slot,
    required this.selected,
    required this.onTap,
    required this.onListen,
  });

  String? get _art {
    if (code != 'classic') return StoreArt.forCode(code);
    return slot == CosmeticSlot.roomPack ? AppCouncilArt.backdropDay : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final s = context.spacing;
    final name = code == 'classic'
        ? l.cosmeticClassic
        : Cosmetics.items[code]!.name(l);
    final art = _art;
    return SizedBox(
      width: RoomLookTokens.tile,
      child: Column(
        children: [
          Semantics(
            button: true,
            selected: selected,
            label: name,
            child: InkWell(
              key: RoomLookPicker.tile(code),
              onTap: onTap,
              borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
              child: Container(
                height: RoomLookTokens.art,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
                  border: Border.all(
                    color: selected ? VaultTokens.gold : colors.borderSubtle,
                    width: selected ? RolesTokens.dealOwnedRing : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (art != null)
                      Image.asset(
                        art,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      )
                    else
                      Icon(
                        Icons.record_voice_over_rounded,
                        color: colors.textMuted,
                      ),
                    if (selected)
                      const PositionedDirectional(
                        top: RolesTokens.dealBadgeInset,
                        start: RolesTokens.dealBadgeInset,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: VaultTokens.gold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: s.xs),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.typography.caption.copyWith(
              color: selected ? VaultTokens.gold : colors.textSecondary,
            ),
          ),
          if (onListen != null)
            TextButton.icon(
              key: RoomLookPicker.listen(code),
              onPressed: onListen,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.storeListen),
            ),
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final VoidCallback onTap;
  const _StoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return SizedBox(
      width: RoomLookTokens.tile,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: l.roomLookMore,
            child: InkWell(
              key: RoomLookPicker.storeKey,
              onTap: onTap,
              borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
              child: Container(
                height: RoomLookTokens.art,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Icon(Icons.add_rounded, color: colors.accentGold),
              ),
            ),
          ),
          SizedBox(height: context.spacing.xs),
          ExcludeSemantics(
            child: Text(
              l.roomLookMore,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.typography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
