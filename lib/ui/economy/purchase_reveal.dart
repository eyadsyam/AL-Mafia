import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_localizations.dart';
import '../../data/player_profile.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/player_avatar.dart';
import 'cosmetic_paint.dart';
import 'cosmetic_preview.dart';
import 'cosmetics.dart';
import 'my_cosmetics.dart';
import 'vault_kit.dart';

/// Store truth: the moment after a purchase shows the item doing its job on
/// the buyer — the frame around their own avatar, the plate under their own
/// name, the pack behind a table, the narrator's line in its own look — with
/// one tap to wear it now. A bundle lists every part as now owned.
///
/// [onEquip] is the store's own equip (one wallet action at a time); null for
/// a bundle, which has nothing to wear as a whole.
Future<void> showPurchaseReveal(
  BuildContext context, {
  required String code,
  Future<void> Function(CosmeticSlot slot, String code)? onEquip,
}) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: EdgeInsets.all(context.spacing.md),
    child: PurchaseReveal(code: code, onEquip: onEquip),
  ),
);

class PurchaseReveal extends ConsumerStatefulWidget {
  final String code;
  final Future<void> Function(CosmeticSlot slot, String code)? onEquip;
  const PurchaseReveal({super.key, required this.code, this.onEquip});

  static const Key revealKey = ValueKey('purchase_reveal');
  static const Key equipNowKey = ValueKey('purchase_reveal_equip_now');
  static const Key laterKey = ValueKey('purchase_reveal_later');
  static Key partKey(String code) => ValueKey('purchase_reveal_part_$code');

  @override
  ConsumerState<PurchaseReveal> createState() => _PurchaseRevealState();
}

class _PurchaseRevealState extends ConsumerState<PurchaseReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: StoreTruthTokens.revealRise,
  );
  bool _working = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Finite, once; reduced motion shows the item at rest.
    if (MediaQuery.disableAnimationsOf(context)) {
      _rise.value = 1;
    } else if (!_rise.isAnimating && _rise.value == 0) {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  Future<void> _equipNow(CosmeticSlot slot) async {
    final onEquip = widget.onEquip;
    if (onEquip == null || _working) return;
    setState(() => _working = true);
    try {
      await onEquip(slot, widget.code);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final item = Cosmetics.items[widget.code];
    if (item == null) return const SizedBox.shrink();
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final mine = ref.watch(myCosmeticsProvider);
    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : l.previewSampleName;
    final slot = item.slot;
    final alreadyWorn = switch (slot) {
      CosmeticSlot.frame => mine.frame == widget.code,
      CosmeticSlot.nameplate => mine.plate == widget.code,
      CosmeticSlot.roomPack => mine.pack == widget.code,
      CosmeticSlot.narrator => mine.narrator == widget.code,
      null => false,
    };
    final preview = switch (item.kind) {
      CosmeticKind.frame || CosmeticKind.nameplate => _OnMe(
        name: name,
        gender: profile?.gender ?? PlayerGender.unspecified,
        frame: item.kind == CosmeticKind.frame ? widget.code : mine.frame,
        plate: item.kind == CosmeticKind.nameplate ? widget.code : mine.plate,
      ),
      CosmeticKind.bundle => _Parts(code: widget.code),
      // Packs and narrators: the same preview the shop shows, which draws
      // through the table's own painters and captions.
      _ => CosmeticPreview(code: widget.code),
    };
    return KeyedSubtree(
      key: PurchaseReveal.revealKey,
      child: VaultCard(
        lit: true,
        mainAxisSize: MainAxisSize.min,
        children: [
          VaultHeading(
            title: l.storeRevealTitle,
            subtitle: item.name(l),
            leading: const Icon(
              Icons.auto_awesome_rounded,
              color: VaultTokens.gold,
            ),
          ),
          SizedBox(height: s.md),
          AnimatedBuilder(
            animation: _rise,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_rise.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * StoreTruthTokens.revealLift),
                  child: child,
                ),
              );
            },
            child: VaultGlint(play: _rise.value < 1, child: Center(child: preview)),
          ),
          SizedBox(height: s.sm),
          Text(
            storeWhatItChanges(l, item.kind),
            textAlign: TextAlign.center,
            style: context.typography.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: s.md),
          if (slot != null && widget.onEquip != null && !alreadyWorn)
            FilledButton(
              key: PurchaseReveal.equipNowKey,
              style: vaultGoldStyle(context),
              onPressed: _working ? null : () => _equipNow(slot),
              child: Text(l.storeEquipNow),
            ),
          if (alreadyWorn)
            Center(child: Text(l.storeEquipped, style: context.typography.body)),
          TextButton(
            key: PurchaseReveal.laterKey,
            onPressed: _working ? null : () => Navigator.of(context).pop(),
            child: Text(slot == null ? l.storeRevealDone : l.storeEquipLater),
          ),
        ],
      ),
    );
  }
}

/// The item on the buyer's own avatar and name.
class _OnMe extends StatelessWidget {
  final String name;
  final PlayerGender gender;
  final String? frame;
  final String? plate;
  const _OnMe({
    required this.name,
    required this.gender,
    required this.frame,
    required this.plate,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CosmeticFrameRing(
        frame: frame,
        diameter: StoreTruthTokens.revealAvatar,
        child: PlayerAvatar(
          name: name,
          gender: gender,
          diameter: StoreTruthTokens.revealAvatar,
        ),
      ),
      SizedBox(height: context.spacing.md),
      CosmeticNameplate(
        name: name,
        plate: plate,
        textAlign: TextAlign.center,
        style: context.typography.title.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
    ],
  );
}

/// Every part of a bundle, each marked as now owned.
class _Parts extends StatelessWidget {
  final String code;
  const _Parts({required this.code});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: context.spacing.sm,
      runSpacing: context.spacing.xs,
      children: [
        for (final part in Cosmetics.bundles[code] ?? const <String>[])
          Chip(
            key: PurchaseReveal.partKey(part),
            avatar: const Icon(Icons.check_rounded, color: VaultTokens.gold),
            label: Text(Cosmetics.items[part]?.name(l) ?? part),
          ),
      ],
    );
  }
}

/// One line per kind: where the item shows once worn (store truth copy).
String storeWhatItChanges(AppLocalizations l, CosmeticKind kind) =>
    switch (kind) {
      CosmeticKind.frame => l.storeChangesFrame,
      CosmeticKind.nameplate => l.storeChangesPlate,
      CosmeticKind.presentationPack => l.storeChangesPack,
      CosmeticKind.narratorPack => l.storeChangesNarrator,
      CosmeticKind.bundle => l.storeChangesBundle,
    };

/// Collection «جرّبه»: the item on this player's own identity (frame or
/// plate), or the table's own preview (pack, narrator), through the same
/// painters the real placements use. Wearing it is the store's equip button.
Future<void> showTryOn(BuildContext context, String code) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: EdgeInsets.all(context.spacing.md),
    child: TryOnPreview(code: code),
  ),
);

class TryOnPreview extends ConsumerWidget {
  final String code;
  const TryOnPreview({super.key, required this.code});

  static const Key previewKey = ValueKey('store_try_on');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final item = Cosmetics.items[code];
    if (item == null) return const SizedBox.shrink();
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final mine = ref.watch(myCosmeticsProvider);
    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : l.previewSampleName;
    return KeyedSubtree(
      key: previewKey,
      child: VaultCard(
        mainAxisSize: MainAxisSize.min,
        children: [
          VaultHeading(title: l.storeTryOn, subtitle: item.name(l)),
          SizedBox(height: context.spacing.md),
          Center(
            child: switch (item.kind) {
              CosmeticKind.frame || CosmeticKind.nameplate => _OnMe(
                name: name,
                gender: profile?.gender ?? PlayerGender.unspecified,
                frame: item.kind == CosmeticKind.frame ? code : mine.frame,
                plate: item.kind == CosmeticKind.nameplate ? code : mine.plate,
              ),
              CosmeticKind.bundle => _Parts(code: code),
              _ => CosmeticPreview(code: code),
            },
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            storeWhatItChanges(l, item.kind),
            textAlign: TextAlign.center,
            style: context.typography.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.storeRevealDone),
          ),
        ],
      ),
    );
  }
}
