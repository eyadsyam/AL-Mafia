import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/haptics.dart';
import '../../platform/links/external_link.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/mafia_theme.dart';
import 'account_protection.dart';
import 'mafia_coin.dart';
import 'wallet.dart';
import 'store_art.dart';
import 'vault_kit.dart';
import '../theme/design_tokens.dart';

/// One pack as the server prices it. Amounts are piastres (1/100 EGP).
class CoinPack {
  final String code;
  final int coins;
  final int pricePiastres;

  /// Set for the Quiet Pass: it grants this instead of coins, and the web
  /// buyer's Android app carries it on the same linked account.
  final String? entitlement;
  const CoinPack(this.code, this.coins, this.pricePiastres, [this.entitlement]);

  bool get pass => entitlement != null;
}

class PayMethod {
  final String code;
  final bool available;
  final String? url;
  const PayMethod(this.code, this.available, this.url);
}

class CoinOrder {
  final String id;
  final String reference;
  final int coins;
  final int amountPiastres;
  final String method;
  final String status;
  final String? note;
  const CoinOrder({
    required this.id,
    required this.reference,
    required this.coins,
    required this.amountPiastres,
    required this.method,
    required this.status,
    this.note,
  });

  factory CoinOrder.fromJson(Map<String, dynamic> j) => CoinOrder(
    id: j['id'] as String,
    reference: j['reference'] as String? ?? '',
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    amountPiastres: (j['amountPiastres'] as num?)?.toInt() ?? 0,
    method: j['method'] as String? ?? '',
    status: j['status'] as String? ?? '',
    note: j['playerNote'] as String?,
  );

  bool get open =>
      const {'awaiting_transfer', 'claimed', 'needs_info'}.contains(status);
}

class CoinShop {
  final bool enabled;
  final bool recoverable;
  final List<CoinPack> packs;
  final List<PayMethod> methods;
  final List<CoinOrder> orders;

  /// This account already has the Quiet Pass (from Play or the web).
  final bool adFree;
  const CoinShop({
    required this.enabled,
    required this.recoverable,
    required this.packs,
    required this.methods,
    required this.orders,
    this.adFree = false,
  });

  factory CoinShop.fromJson(Map<String, dynamic> j) => CoinShop(
    enabled: j['enabled'] as bool? ?? false,
    recoverable: j['recoverable'] as bool? ?? false,
    adFree: j['adFree'] == true,
    packs: [
      for (final p in (j['packs'] as List? ?? const []).whereType<Map>())
        if (p['pricePiastres'] is num &&
            ((p['coins'] as num?) ?? 0) >= 0 &&
            (p['entitlement'] == null || p['entitlement'] == 'remove_interruptions'))
          CoinPack(
            p['code'] as String,
            ((p['coins'] as num?) ?? 0).toInt(),
            (p['pricePiastres'] as num).toInt(),
            p['entitlement'] as String?,
          ),
    ],
    methods: [
      for (final m in (j['methods'] as List? ?? const []).whereType<Map>())
        PayMethod(
          m['code'] as String,
          m['available'] == true,
          m['available'] == true ? m['url'] as String? : null,
        ),
    ],
    orders: [
      for (final o in (j['orders'] as List? ?? const []).whereType<Map>())
        CoinOrder.fromJson(Map<String, dynamic>.from(o)),
    ],
  );

  /// The one order this player may still act on (server allows one open).
  CoinOrder? get current =>
      orders.where((o) => o.open).firstOrNull ??
      orders.where((o) => o.status == 'expired').firstOrNull;
}

String egp(int piastres) => piastres % 100 == 0
    ? '${piastres ~/ 100}'
    : (piastres / 100).toStringAsFixed(2);

final coinShopProvider = AsyncNotifierProvider<CoinShopController, CoinShop>(
  CoinShopController.new,
);

/// Everything goes through `coin_orders`; nothing here changes a balance.
/// Coins appear only when the wallet is re-read after an admin approval.
class CoinShopController extends AsyncNotifier<CoinShop> {
  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('coin_orders', body);
  }

  @override
  Future<CoinShop> build() async =>
      CoinShop.fromJson(await _call({'action': 'shop'}));

  Future<void> reload() async {
    state = await AsyncValue.guard(build);
    // An approval may have landed; the wallet is the server's to say.
    await ref.read(walletProvider.notifier).refresh();
  }

  Future<void> create(String pack, String method) async {
    await _call({'action': 'create', 'pack': pack, 'method': method});
    state = await AsyncValue.guard(build);
  }

  Future<void> claim(String order, String reference, String? payer) async {
    await _call({
      'action': 'claim',
      'order': order,
      'reference': reference,
      if (payer != null && payer.trim().isNotEmpty) 'payerHint': payer,
    });
    state = await AsyncValue.guard(build);
  }

  Future<void> cancel(String order) async {
    await _call({'action': 'cancel', 'order': order});
    state = await AsyncValue.guard(build);
  }
}

String methodName(BuildContext context, String code) => code == 'instapay'
    ? context.l10n.coinPayInstapay
    : context.l10n.coinPayVodafone;

/// The web store's coin packs: manual transfer review, never automatic.
class CoinPacksTab extends ConsumerStatefulWidget {
  const CoinPacksTab({super.key});

  static Key pack(String code) => ValueKey('coin_pack_$code');
  static Key method(String code) => ValueKey('coin_method_$code');
  static const createButton = ValueKey('coin_create_order');
  static const openButton = ValueKey('coin_open_payment');
  static const referenceField = ValueKey('coin_reference');
  static const claimButton = ValueKey('coin_claim');
  static const cancelButton = ValueKey('coin_cancel');
  static const notice = ValueKey('coin_manual_notice');
  static const passNote = ValueKey('coin_pass_note');

  @override
  ConsumerState<CoinPacksTab> createState() => _CoinPacksTabState();
}

class _CoinPacksTabState extends ConsumerState<CoinPacksTab> {
  String? _pack;
  bool _busy = false;

  /// A late (expired) order stays claimable; this sets it aside to start a
  /// new one without losing it (it remains in the list and on the server).
  bool _newOrder = false;
  final _reference = TextEditingController();
  final _payer = TextEditingController();
  final _packScroll = ScrollController();

  @override
  void dispose() {
    _reference.dispose();
    _payer.dispose();
    _packScroll.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _act(Future<void> Function(CoinShopController) step) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await step(ref.read(coinShopProvider.notifier));
    } on BackendException catch (error) {
      if (mounted) {
        _say(
          error.code == 'ALREADY_OWNED'
              ? context.l10n.webPassOwned
              : context.l10n.coinOrderFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final shop = ref.watch(coinShopProvider);
    // Linking or recovering an account changes who is buying.
    ref.listen(
      accountStatusProvider,
      (_, _) => ref.invalidate(coinShopProvider),
    );
    return shop.when(
      loading: () => const VaultSkeleton(cards: 2),
      // A server without the orders feature (or offline) is "not available",
      // said plainly, with a retry.
      error: (_, _) => VaultRetry(
        message: l.coinPacksUnavailable,
        action: l.videoRetry,
        onRetry: () => ref.invalidate(coinShopProvider),
      ),
      data: (shop) {
        if (!shop.enabled) {
          return Padding(
            padding: EdgeInsets.all(s.md),
            child: Text(l.coinPacksUnavailable, style: context.typography.body),
          );
        }
        final current = shop.current;
        final order = current?.status == 'expired' && _newOrder
            ? null
            : current;
        return RefreshIndicator(
          onRefresh: () => ref.read(coinShopProvider.notifier).reload(),
          child: ListView(
            padding: EdgeInsets.all(s.md),
            children: [
              if (!shop.recoverable) ...[
                Text(l.coinPacksNeedAccount, style: context.typography.body),
                SizedBox(height: s.sm),
                const AccountProtectionCard(),
              ] else if (order != null)
                VaultCard(
                  lit: order.status == 'awaiting_transfer',
                  children: [
                    _OrderCard(
                  order: order,
                  method: shop.methods
                      .where((m) => m.code == order.method)
                      .firstOrNull,
                  reference: _reference,
                  payer: _payer,
                  busy: _busy,
                  onClaim: () => _act(
                    (c) =>
                        c.claim(order.id, _reference.text.trim(), _payer.text),
                  ),
                  onCancel: () => _act((c) => c.cancel(order.id)),
                  onOpenFailed: () => _say(l.coinOpenFailed),
                  onNewOrder: order.status == 'expired'
                      ? () => setState(() => _newOrder = true)
                      : null,
                    ),
                  ],
                )
              else
                ..._chooser(shop),
              SizedBox(height: s.lg),
              for (final past in shop.orders)
                if (!past.open && past.id != order?.id)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l.coinOrderTitle(past.reference)),
                    subtitle: Text(settledStatus(context, past)),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// Choose a pack, then tap a method: its payment page opens inside the tap
  /// itself (a real link, never blocked as a pop-up) and the order is made
  /// alongside, so the player comes back to an order waiting for the
  /// transfer reference.
  void _payWith(CoinPack pack, PayMethod method) {
    final opened = ref.read(externalLinkOpenerProvider)(method.url!);
    if (!opened) _say(context.l10n.coinOpenFailed);
    _act((c) => c.create(pack.code, method.code));
  }

  List<Widget> _chooser(CoinShop shop) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final pack = shop.packs.where((p) => p.code == _pack).firstOrNull;
    final passOwned = pack != null && pack.pass && shop.adFree;
    // Best value only where the numbers prove it: the most coins per pound,
    // strictly ahead of every other coin pack.
    final coinPacks = shop.packs
        .where((p) => !p.pass && p.coins > 0 && p.pricePiastres > 0)
        .toList();
    String? best;
    if (coinPacks.length > 1) {
      coinPacks.sort(
        (a, b) =>
            (b.coins / b.pricePiastres).compareTo(a.coins / a.pricePiastres),
      );
      final top = coinPacks[0], next = coinPacks[1];
      if (top.coins / top.pricePiastres > next.coins / next.pricePiastres) {
        best = top.code;
      }
    }
    return [
      _Step(
        number: 1,
        title: l.storeTabCoins,
        hint: pack == null ? l.coinPickPackFirst : null,
      ),
      SizedBox(height: s.sm),
      SizedBox(
        height: StoreTokens.coinRailHeight + VaultTokens.tagLift,
        child: Scrollbar(
          controller: _packScroll,
          thumbVisibility: true,
          child: ListView.separated(
            controller: _packScroll,
            scrollDirection: Axis.horizontal,
            itemCount: shop.packs.length,
            separatorBuilder: (_, _) => SizedBox(width: s.sm),
            itemBuilder: (context, index) {
              final p = shop.packs[index];
              final selected = p.code == _pack;
              final radius = BorderRadius.circular(context.radii.card);
              final card = AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : context.motion.quick,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: VaultTokens.gold.withValues(
                              alpha: VaultTokens.litGlowAlpha * 1.5,
                            ),
                            blurRadius: VaultTokens.litGlowBlur,
                          ),
                        ]
                      : context.elevation.level1,
                ),
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  color: selected
                      ? Color.alphaBlend(
                          VaultTokens.gold.withValues(
                            alpha: VaultTokens.lampWash * 1.6,
                          ),
                          colors.surfaceRaised,
                        )
                      : colors.surfaceRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: radius,
                    side: BorderSide(
                      color: selected ? VaultTokens.gold : colors.borderSubtle,
                      width: selected ? StoreTokens.selectedBorder : 1,
                    ),
                  ),
                  child: InkWell(
                    key: CoinPacksTab.pack(p.code),
                    onTap: _busy
                        ? null
                        : () {
                            Haptics.select();
                            setState(() => _pack = p.code);
                          },
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(s.sm, s.md, s.sm, s.sm),
                      child: Column(
                        children: [
                          Expanded(
                            child: p.pass
                                ? Image.asset(
                                    StoreArt.quietPassCover,
                                    cacheWidth: StoreTokens.frameDecodeWidth,
                                    excludeFromSemantics: true,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  )
                                : StoreProductArt(code: p.code),
                          ),
                          if (p.pass)
                            Text(
                              l.quietPassTitle,
                              style: context.typography.title.copyWith(
                                color: VaultTokens.goldLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            CoinAmount(
                              p.coins,
                              style: context.typography.title.copyWith(
                                color: VaultTokens.goldLight,
                              ),
                            ),
                          Text(
                            l.coinPackPrice(egp(p.pricePiastres)),
                            style: context.typography.body.emphasised.copyWith(
                              color: selected
                                  ? VaultTokens.gold
                                  : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              return Padding(
                padding: EdgeInsets.only(
                  top: VaultTokens.tagLift,
                  bottom: s.md,
                ),
                child: SizedBox(
                  width: StoreTokens.cardWidth,
                  child: Semantics(
                    selected: selected,
                    inMutuallyExclusiveGroup: true,
                    child: VaultPress(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: p.code == best
                                ? VaultGlint(child: card)
                                : card,
                          ),
                          if (p.code == best)
                            PositionedDirectional(
                              top: -VaultTokens.tagLift,
                              start: s.sm,
                              child: VaultTag(l.vaultBestValue, oxblood: true),
                            ),
                          if (selected)
                            PositionedDirectional(
                              top: s.sm,
                              end: s.sm,
                              child: const _Check(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      if (pack != null && pack.pass) ...[
        Text(
          key: CoinPacksTab.passNote,
          passOwned ? l.webPassOwned : l.webPassBody,
          style: context.typography.bodySmall.copyWith(
            color: passOwned ? VaultTokens.gold : colors.textSecondary,
          ),
        ),
        SizedBox(height: s.sm),
      ],
      SizedBox(height: s.sm),
      _Step(number: 2, title: l.coinPayMethod, hint: l.coinPayStep),
      SizedBox(height: s.sm),
      for (final m in shop.methods) ...[
        VaultPress(
          child: FilledButton.icon(
            key: CoinPacksTab.method(m.code),
            style: vaultGoldStyle(context),
            icon: const Icon(Icons.open_in_new),
            onPressed: m.available && pack != null && !passOwned && !_busy
                ? () => _payWith(pack, m)
                : null,
            label: Text(
              pack == null
                  ? l.coinPayWith(methodName(context, m.code))
                  : '${l.coinPayWith(methodName(context, m.code))} · ${l.coinPackPrice(egp(pack.pricePiastres))}',
            ),
          ),
        ),
        if (!m.available)
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: Text(
              l.coinPayMethodOff,
              textAlign: TextAlign.center,
              style: context.typography.caption.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
        SizedBox(height: s.sm),
      ],
      SizedBox(height: s.sm),
      _Notice(),
    ];
  }
}

/// A numbered step: a struck medallion, its title, and what to do.
class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String? hint;
  const _Step({required this.number, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: VaultTokens.dayMedal,
          height: VaultTokens.dayMedal,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.35, -0.45),
              colors: [
                VaultTokens.goldLight,
                VaultTokens.gold,
                VaultTokens.goldDeep,
              ],
            ),
          ),
          child: Text(
            '$number',
            style: context.typography.body.emphasised.copyWith(
              color: VaultTokens.goldInk,
              height: 1.1,
            ),
          ),
        ),
        SizedBox(width: s.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.typography.title.copyWith(
                    color: context.colors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: context.typography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The chosen pack's struck check.
class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) => Container(
    width: VaultTokens.chipHeight,
    height: VaultTokens.chipHeight,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: VaultTokens.gold,
      border: Border.all(color: VaultTokens.goldLight),
      boxShadow: context.elevation.level1,
    ),
    child: const Icon(
      Icons.check_rounded,
      size: VaultTokens.chipCoin,
      color: VaultTokens.goldInk,
    ),
  );
}

class _Notice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => VaultCard(
    key: CoinPacksTab.notice,
    children: [
      VaultHeading(
        leading: const Icon(
          Icons.verified_user_outlined,
          color: VaultTokens.gold,
          size: CouncilLifeTokens.contractIcon * 0.8,
        ),
        title: context.l10n.coinManualNotice,
        compact: true,
      ),
      SizedBox(height: context.spacing.sm),
      Text(
        context.l10n.coinManualDetail,
        style: context.typography.bodySmall.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ],
  );
}

class _OrderCard extends ConsumerWidget {
  final CoinOrder order;
  final PayMethod? method;
  final TextEditingController reference;
  final TextEditingController payer;
  final bool busy;
  final VoidCallback onClaim;
  final VoidCallback onCancel;
  final VoidCallback onOpenFailed;
  final VoidCallback? onNewOrder;
  const _OrderCard({
    this.onNewOrder,
    required this.order,
    required this.method,
    required this.reference,
    required this.payer,
    required this.busy,
    required this.onClaim,
    required this.onCancel,
    required this.onOpenFailed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final name = methodName(context, order.method);
    final canClaim = const {
      'awaiting_transfer',
      'needs_info',
      'expired',
    }.contains(order.status);
    final status = switch (order.status) {
      'awaiting_transfer' => l.coinStatusAwaiting,
      'claimed' => l.coinStatusClaimed,
      'needs_info' => l.coinStatusNeedsInfo(order.note ?? ''),
      'expired' => l.coinStatusExpired,
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.coinOrderTitle(order.reference),
          style: context.typography.title.copyWith(
            color: VaultTokens.goldLight,
          ),
        ),
        Text(
          order.coins == 0
              ? l.coinOrderPassSummary(egp(order.amountPiastres), name)
              : l.coinOrderSummary(order.coins, egp(order.amountPiastres), name),
          style: context.typography.body,
        ),
        SizedBox(height: s.xs),
        Text(status, style: context.typography.bodySmall),
        SizedBox(height: s.md),
        _Notice(),
        if (order.status == 'awaiting_transfer' && method?.url != null) ...[
          SizedBox(height: s.md),
          FilledButton.icon(
            key: CoinPacksTab.openButton,
            style: vaultGoldStyle(context),
            icon: const Icon(Icons.open_in_new),
            label: Text(l.coinOpenPayment(name)),
            // Opened inside the tap itself; the order stays open here.
            onPressed: () {
              if (!ref.read(externalLinkOpenerProvider)(method!.url!)) {
                onOpenFailed();
              }
            },
          ),
          Text(l.coinDesktopHint, style: context.typography.bodySmall),
        ],
        if (canClaim) ...[
          SizedBox(height: s.md),
          TextField(
            key: CoinPacksTab.referenceField,
            controller: reference,
            decoration: InputDecoration(labelText: l.coinTransferReference),
          ),
          TextField(
            controller: payer,
            maxLength: 60,
            decoration: InputDecoration(labelText: l.coinPayerHint),
          ),
          Text(l.coinClaimNote, style: context.typography.bodySmall),
          SizedBox(height: s.sm),
          ListenableBuilder(
            listenable: reference,
            builder: (context, _) => FilledButton(
              key: CoinPacksTab.claimButton,
              style: vaultGoldStyle(context),
              onPressed: busy || reference.text.trim().length < 4
                  ? null
                  : onClaim,
              child: Text(l.coinSentTransfer),
            ),
          ),
        ],
        if (order.status == 'awaiting_transfer')
          TextButton(
            key: CoinPacksTab.cancelButton,
            onPressed: busy ? null : onCancel,
            child: Text(l.coinCancelOrder),
          ),
        if (onNewOrder != null)
          TextButton(
            onPressed: busy ? null : onNewOrder,
            child: Text(l.storeTabCoins),
          ),
      ],
    );
  }
}

/// What happened to a finished order, in the player's words.
String settledStatus(BuildContext context, CoinOrder order) {
  final l = context.l10n;
  return switch (order.status) {
    'paid' => l.coinStatusPaid(order.coins),
    'rejected' => l.coinStatusRejected(order.note ?? ''),
    'cancelled' => l.coinStatusCancelled,
    'refunded' => l.coinStatusRefunded(order.note ?? ''),
    'expired' => l.coinStatusExpired,
    _ => l.coinStatusClaimed,
  };
}
