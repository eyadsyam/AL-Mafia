import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/monetization/play_billing.dart';
import '../../platform/monetization/purchase_store.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'account_protection.dart';
import 'coin_packs.dart' show TransferMethodButtons;
import 'council_art.dart';
import 'economy_capabilities.dart';
import 'mafia_coin.dart';
import 'store_art.dart';
import 'vault_kit.dart';
import 'wallet.dart';

enum PlayNotice {
  none,
  pending,
  verified,
  failed,
  unavailable,
  accountMismatch,
  needsProtection,
  alreadyOwned,
}

class PlayOffersState {
  final bool loading;

  /// Products the server sells *and* Play lists on this device, in the
  /// server's order. Empty means nothing can be bought here right now.
  final List<(PlayProductOffer, PlayListing)> offers;
  final String? busyProduct;
  final PlayNotice notice;
  final bool adFree;

  const PlayOffersState({
    this.loading = false,
    this.offers = const [],
    this.busyProduct,
    this.notice = PlayNotice.none,
    this.adFree = false,
  });

  PlayOffersState copyWith({
    bool? loading,
    List<(PlayProductOffer, PlayListing)>? offers,
    String? busyProduct,
    bool clearBusy = false,
    PlayNotice? notice,
    bool? adFree,
  }) => PlayOffersState(
    loading: loading ?? this.loading,
    offers: offers ?? this.offers,
    busyProduct: clearBusy ? null : (busyProduct ?? this.busyProduct),
    notice: notice ?? this.notice,
    adFree: adFree ?? this.adFree,
  );
}

final playOffersProvider =
    NotifierProvider<PlayOffersController, PlayOffersState>(
      PlayOffersController.new,
    );

/// Quiet Pass and Council Coins packs through Google Play Billing.
///
/// Nothing is granted on the device. Every purchase event's token goes to
/// `play_purchase`, which verifies with Google, credits once and then
/// acknowledges (pass) or consumes (packs). A pending payment grants nothing.
class PlayOffersController extends Notifier<PlayOffersState> {
  StreamSubscription<StorePurchaseEvent>? _events;
  bool _started = false;

  @override
  PlayOffersState build() {
    ref.onDispose(() => unawaited(_events?.cancel()));
    return const PlayOffersState();
  }

  Future<void> start() async {
    final billing = ref.read(playBillingProvider);
    if (_started || !billing.supported) return;
    _started = true;
    state = state.copyWith(loading: true);
    try {
      // Play may redeliver an unfinished purchase before the vault is opened.
      _events ??= billing.events.listen(_handle);
      await billing.start();
      final caps = await ref.read(economyCapabilitiesProvider.future);
      state = state.copyWith(adFree: caps.adFree);
      if (caps.products.isEmpty) {
        // Nothing on sale yet (or not reachable): the next open asks again.
        _started = false;
        state = state.copyWith(loading: false, offers: const []);
        return;
      }
      final listings = await billing.listings({
        for (final p in caps.products) p.id,
      });
      state = state.copyWith(
        loading: false,
        offers: [
          for (final p in caps.products)
            if (listings[p.id] case final listing?) (p, listing),
        ],
      );
      // Unconsumed packs and unacknowledged passes come back through the
      // same event stream and are verified like new purchases.
      await billing.restore();
    } catch (_) {
      _started = false;
      state = state.copyWith(loading: false, notice: PlayNotice.unavailable);
    }
  }

  Future<void> _handle(StorePurchaseEvent event) async {
    switch (event.state) {
      case StorePurchaseState.pending:
        // Waiting on the payment method: nothing granted, and nothing else
        // is blocked meanwhile.
        state = state.copyWith(clearBusy: true, notice: PlayNotice.pending);
        return;
      case StorePurchaseState.canceled:
        state = state.copyWith(clearBusy: true, notice: PlayNotice.none);
        return;
      case StorePurchaseState.failed:
        state = state.copyWith(clearBusy: true, notice: PlayNotice.failed);
        return;
      case StorePurchaseState.purchased:
      case StorePurchaseState.restored:
        break;
    }
    final token = event.token;
    if (token == null) {
      state = state.copyWith(clearBusy: true, notice: PlayNotice.failed);
      return;
    }
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('play_purchase', {
        'action': 'verify',
        'productId': event.productId,
        'token': token,
      });
      final granted = answer['granted'] == true;
      // A pass and the Starter Bundle are acknowledged, never consumed: the
      // bundle is once per account. A second bundle the server refused is
      // left unacknowledged, and Google Play refunds it by itself.
      if ((answer['kind'] == 'entitlement' || answer['kind'] == 'bundle') &&
          granted) {
        await ref.read(playBillingProvider).finishEntitlement(token);
      }
      if (answer['alreadyOwned'] == true) {
        ref.invalidate(economyCapabilitiesProvider);
        state = state.copyWith(
          clearBusy: true,
          notice: PlayNotice.alreadyOwned,
        );
        return;
      }
      ref.invalidate(walletProvider);
      ref.invalidate(economyCapabilitiesProvider);
      final caps = await ref.read(economyCapabilitiesProvider.future);
      state = state.copyWith(
        clearBusy: true,
        adFree: caps.adFree,
        notice: answer['state'] == 'pending'
            ? PlayNotice.pending
            : granted
            ? (event.state == StorePurchaseState.purchased
                  ? PlayNotice.verified
                  : state.notice)
            : PlayNotice.failed,
      );
    } on BackendException catch (error) {
      state = state.copyWith(
        clearBusy: true,
        notice: error.code == 'ACCOUNT_MISMATCH'
            ? PlayNotice.accountMismatch
            : error.code == 'NOT_CONFIGURED'
            ? PlayNotice.unavailable
            : PlayNotice.failed,
      );
    } catch (_) {
      // The purchase stays unfinished at Google and is offered again on
      // the next start; nothing was granted here.
      state = state.copyWith(clearBusy: true, notice: PlayNotice.failed);
    }
  }

  Future<void> buy(PlayProductOffer offer) async {
    if (state.busyProduct != null) return;
    // A paid purchase needs an account that survives the phone.
    ref.invalidate(economyCapabilitiesProvider);
    final caps = await ref.read(economyCapabilitiesProvider.future);
    final tag = caps.accountTag;
    if (!caps.recoverable || tag == null) {
      state = state.copyWith(notice: PlayNotice.needsProtection);
      return;
    }
    state = state.copyWith(busyProduct: offer.id, notice: PlayNotice.none);
    final opened = await ref
        .read(playBillingProvider)
        .buy(offer.id, consumable: offer.consumable, accountTag: tag);
    if (!opened) {
      state = state.copyWith(clearBusy: true, notice: PlayNotice.failed);
    }
  }

  Future<void> restore() => ref.read(playBillingProvider).restore();
}

/// «العملات والممر»: the Quiet Pass and the Council Coins packs, priced by
/// Google Play in the player's currency. Android only; the web keeps its
/// own, separate manual-transfer tab.
class PlayOffersTab extends ConsumerStatefulWidget {
  const PlayOffersTab({super.key});

  static Key buyKey(String id) => ValueKey('play_buy_$id');
  static const restoreKey = ValueKey('play_restore');
  static const debtKey = ValueKey('play_debt_notice');

  @override
  ConsumerState<PlayOffersTab> createState() => _PlayOffersTabState();
}

class _PlayOffersTabState extends ConsumerState<PlayOffersTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(playOffersProvider.notifier).start());
    });
  }

  String? _noticeText(BuildContext context, PlayNotice notice) {
    final l = context.l10n;
    return switch (notice) {
      PlayNotice.none => null,
      PlayNotice.pending => l.playPending,
      PlayNotice.verified => l.playVerified,
      PlayNotice.failed => l.playFailed,
      PlayNotice.unavailable => l.playUnavailable,
      PlayNotice.accountMismatch => l.playAccountMismatch,
      PlayNotice.needsProtection => l.playNeedsProtection,
      PlayNotice.alreadyOwned => l.bundleAlreadyOwned,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final offers = ref.watch(playOffersProvider);
    final notice = _noticeText(context, offers.notice);
    final pass = offers.offers
        .where((o) => o.$1.kind == 'entitlement')
        .toList();
    final bundles = offers.offers.where((o) => o.$1.bundle).toList();
    final bundleOwned =
        ref
            .watch(economyCapabilitiesProvider)
            .valueOrNull
            ?.council
            .starterBundleOwned ??
        false;
    final debt =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.purchaseDebt ?? 0;
    final packs = offers.offers.where((o) => o.$1.consumable).toList();
    // Play gives display prices only, so no per-coin value is claimed here:
    // the largest pack is called what it is.
    final most = packs.isEmpty
        ? null
        : packs.map((p) => p.$1.coins ?? 0).reduce((a, b) => a > b ? a : b);
    final idle = offers.busyProduct == null;
    // «ادفع بجوجل», and under it the same item by InstaPay / Vodafone Cash
    // at the same price when the server has transfers on (Payments v2).
    Widget buy(String id, String price, VoidCallback onPressed) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VaultPress(
          child: FilledButton(
            key: PlayOffersTab.buyKey(id),
            style: vaultGoldStyle(context),
            onPressed: idle ? onPressed : null,
            child: Text(l.payWithGoogle(price)),
          ),
        ),
        TransferMethodButtons(playProduct: id),
      ],
    );
    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        if (notice != null)
          Padding(
            padding: EdgeInsets.only(bottom: s.md),
            child: Semantics(
              liveRegion: true,
              child: _Notice(text: notice, alarm: false),
            ),
          ),
        if (offers.notice == PlayNotice.needsProtection)
          const AccountProtectionCard(),
        if (debt > 0 && offers.offers.any((o) => o.$1.consumable))
          Padding(
            key: PlayOffersTab.debtKey,
            padding: EdgeInsets.only(bottom: s.md),
            child: _Notice(text: l.playDebtNotice(debt), alarm: true),
          ),
        if (offers.loading)
          const SizedBox(
            height: VaultTokens.skeletonCard * 2,
            child: VaultSkeleton(cards: 2),
          )
        else if (offers.offers.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: s.lg),
            child: Text(
              l.playUnavailable,
              textAlign: TextAlign.center,
              style: context.typography.body.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        // The Starter Bundle first: coins and a frame sold nowhere else.
        for (final (offer, listing) in bundles)
          _OfferCard(
            art: null,
            artWidget: const StarterBundleArt(),
            artSize: CouncilLifeTokens.bundleArt,
            title: l.bundleTitle,
            body: l.bundleBody(offer.coins ?? 0),
            rule: l.bundleRefundRule,
            tag: bundleOwned ? null : l.vaultOneTime,
            lit: !bundleOwned,
            owned: bundleOwned ? l.bundleOwned : null,
            action: buy(
              offer.id,
              listing.price,
              () => ref.read(playOffersProvider.notifier).buy(offer),
            ),
          ),
        for (final (offer, listing) in pass)
          _OfferCard(
            art: StoreArt.quietPassCover,
            artSize: DailyTokens.passArt,
            title: l.quietPassTitle,
            body: l.quietPassBody,
            rule: l.quietPassRefundRule,
            action: offers.adFree
                ? null
                : buy(
                    offer.id,
                    listing.price,
                    () => ref.read(playOffersProvider.notifier).buy(offer),
                  ),
            owned: offers.adFree ? l.quietPassOwned : null,
          ),
        if (packs.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: s.md),
            child: VaultCard(
              children: [
                for (final (i, (offer, listing)) in packs.indexed) ...[
                  if (i > 0) const VaultDivider(),
                  _PackRow(
                    art: StoreArt.forPlayProduct(offer.id),
                    coins: offer.coins ?? 0,
                    title: l.playPackTitle(offer.coins ?? 0),
                    tag: packs.length > 1 && offer.coins == most
                        ? l.vaultMostCoins
                        : null,
                    action: buy(
                      offer.id,
                      listing.price,
                      () => ref.read(playOffersProvider.notifier).buy(offer),
                    ),
                  ),
                ],
                const VaultDivider(),
                // One note for every pack: what coins are, and the refund
                // rule, before anything is bought.
                Text(
                  '${l.playCoinsNote}\n\n${l.playRefundRule}',
                  style: context.typography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        if (offers.offers.isNotEmpty)
          TextButton.icon(
            key: PlayOffersTab.restoreKey,
            onPressed: () => ref.read(playOffersProvider.notifier).restore(),
            icon: const Icon(Icons.restore_rounded),
            label: Text(l.playRestore),
          ),
      ],
    );
  }
}

/// A notice above the offers: gold for news, oxblood for a debt.
class _Notice extends StatelessWidget {
  final String text;
  final bool alarm;
  const _Notice({required this.text, required this.alarm});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final tone = alarm ? VaultTokens.oxbloodLight : VaultTokens.gold;
    return Container(
      padding: EdgeInsets.all(s.sm),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: StoreTokens.badgeWash / 2),
        borderRadius: BorderRadius.circular(context.radii.button),
        border: Border.all(color: tone),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alarm ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: tone,
            size: CosmeticTokens.coinInline,
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              text,
              style: context.typography.body.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One coin pack: its purse, the amount large, and the price on the button.
class _PackRow extends StatelessWidget {
  final String? art;
  final int coins;
  final String title;
  final String? tag;
  final Widget action;
  const _PackRow({
    required this.art,
    required this.coins,
    required this.title,
    required this.tag,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final picture = art == null
        ? const MafiaCoin(size: DailyTokens.passArt / 2)
        : Image.asset(
            art!,
            width: DailyTokens.passArt,
            height: DailyTokens.passArt,
            cacheWidth: StoreTokens.frameDecodeWidth,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const SizedBox.square(dimension: DailyTokens.passArt),
          );
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            tag != null ? LampGlow(child: picture) : picture,
            SizedBox(width: s.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null) VaultTag(tag!, oxblood: true),
                  CoinAmount(
                    coins,
                    size: CosmeticTokens.coinInline * 1.2,
                    style: context.typography.headline.copyWith(
                      color: VaultTokens.goldLight,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    title,
                    style: context.typography.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        action,
      ],
    );
    return tag == null
        ? row
        : VaultGlint(
            borderRadius: BorderRadius.circular(context.radii.button),
            child: row,
          );
  }
}

class _OfferCard extends StatelessWidget {
  final String? art;

  /// Drawn art instead of an image (the Starter Bundle's seal).
  final Widget? artWidget;
  final double artSize;
  final String title;
  final String body;

  /// The refund rule, set apart under the body: read, never buried.
  final String rule;
  final Widget? action;
  final String? owned;
  final String? tag;
  final bool lit;
  const _OfferCard({
    required this.art,
    this.artWidget,
    required this.artSize,
    required this.title,
    required this.body,
    required this.rule,
    this.action,
    this.owned,
    this.tag,
    this.lit = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final colors = context.colors;
    final picture = SizedBox.square(
      dimension: artSize,
      child:
          artWidget ??
          Image.asset(
            art!,
            width: artSize,
            height: artSize,
            cacheWidth: StoreTokens.frameDecodeWidth,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => SizedBox.square(dimension: artSize),
          ),
    );
    final card = VaultCard(
      lit: lit || owned != null,
      tag: tag,
      tagOxblood: true,
      children: [
        Row(
          children: [
            LampGlow(child: picture),
            SizedBox(width: s.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: context.typography.title.copyWith(
                        color: VaultTokens.goldLight,
                      ),
                    ),
                  ),
                  SizedBox(height: s.xs),
                  Text(
                    body,
                    style: context.typography.bodySmall.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        Text(
          rule,
          style: context.typography.caption.copyWith(color: colors.textMuted),
        ),
        SizedBox(height: s.md),
        if (owned != null)
          Center(child: ClaimedMark(owned!))
        else if (action != null)
          action!,
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: s.md),
      child: tag != null ? VaultGlint(child: card) : card,
    );
  }
}
