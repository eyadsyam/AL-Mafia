import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'ad_extras.dart';
import 'daily_rewards.dart';
import 'economy_capabilities.dart';

/// P6 — «القعدة»'s result inventory.
///
/// On a finished pass-and-play result, below the fully revealed roles, the
/// rewards this player has *already been offered today* and not yet taken are
/// surfaced: the daily rewarded ad, and the extra wheel / extra coffer. It is
/// not a faucet: nothing here is new, every amount is the existing offer's,
/// and it draws nothing when there is nothing pending or the features are
/// off. It is placed only on the public result, never before the reveal, in
/// a hand-off, before the deal or between the result and the roles.
class PassResultInventory extends ConsumerStatefulWidget {
  const PassResultInventory({super.key});

  static const Key stripKey = ValueKey('pass_result_inventory');
  static const Key openKey = ValueKey('pass_result_inventory_open');
  static const Key sheetKey = ValueKey('pass_result_inventory_sheet');

  @override
  ConsumerState<PassResultInventory> createState() =>
      _PassResultInventoryState();
}

/// Which existing offers are still waiting today.
class PendingOffers {
  final bool dailyAd;
  final bool extraSpin;
  final bool extraCoffer;
  const PendingOffers({
    this.dailyAd = false,
    this.extraSpin = false,
    this.extraCoffer = false,
  });

  bool get any => dailyAd || extraSpin || extraCoffer;

  static PendingOffers of(
    EconomyCapabilities caps,
    DailyStatus? daily,
    AdExtrasStatus? extras,
  ) => PendingOffers(
    dailyAd:
        caps.dailyAd &&
        daily != null &&
        daily.enabled &&
        daily.adEnabled &&
        !daily.inMatch &&
        daily.adState != 'awarded',
    extraSpin:
        caps.ads.extraSpin &&
        extras != null &&
        !extras.inMatch &&
        extras.spin.enabled &&
        !extras.spin.awarded,
    extraCoffer:
        caps.ads.extraCoffer &&
        extras != null &&
        !extras.inMatch &&
        extras.coffer.enabled &&
        !extras.coffer.awarded,
  );
}

class _PassResultInventoryState extends ConsumerState<PassResultInventory> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        // Only capabilities this session already read: the result screen
        // never starts a network call of its own just to decide this.
        final caps = ref.exists(economyCapabilitiesProvider)
            ? ref.read(economyCapabilitiesProvider).valueOrNull
            : null;
        if (caps == null || !mounted) return;
        if (caps.dailyAd) await ref.read(dailyProvider.notifier).refresh();
        if (!mounted) return;
        if (caps.ads.extras) await ref.read(adExtrasProvider.notifier).refresh();
        if (mounted) setState(() => _asked = true);
      } catch (_) {
        // Never load-bearing for the result screen.
      }
    });
  }

  Future<void> _open() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surfaceBase,
    builder: (_) => FractionallySizedBox(
      key: PassResultInventory.sheetKey,
      heightFactor: PassInventoryTokens.sheetHeight,
      child: const SingleChildScrollView(child: DailyRewardsTab()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_asked) return const SizedBox.shrink();
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull;
    if (caps == null) return const SizedBox.shrink();
    final pending = PendingOffers.of(
      caps,
      ref.watch(dailyProvider).valueOrNull,
      ref.watch(adExtrasProvider).valueOrNull,
    );
    if (!pending.any) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final lines = [
      if (pending.dailyAd) l.passInventoryDailyAd,
      if (pending.extraSpin) l.passInventoryExtraSpin,
      if (pending.extraCoffer) l.passInventoryExtraCoffer,
    ];
    // TODO(art): the vault's ticket treatment for this strip.
    return Padding(
      key: PassResultInventory.stripKey,
      padding: EdgeInsets.only(top: s.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(context.radii.card),
        ),
        child: Padding(
          padding: EdgeInsets.all(s.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.passInventoryTitle,
                style: context.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              for (final line in lines)
                Padding(
                  padding: EdgeInsets.only(top: s.xs),
                  child: Text(
                    line,
                    style: context.typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              SizedBox(height: s.sm),
              OutlinedButton(
                key: PassResultInventory.openKey,
                onPressed: _open,
                child: Text(l.passInventoryOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
