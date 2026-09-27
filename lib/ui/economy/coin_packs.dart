import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/haptics.dart';
import '../../platform/links/external_link.dart';
import '../../platform/payment_capabilities.dart';
import '../../platform/payment_proof.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/mafia_theme.dart';
import 'account_protection.dart';
import 'council_art.dart';
import 'economy_capabilities.dart';
import 'mafia_coin.dart';
import 'wallet.dart';
import 'store_art.dart';
import 'vault_kit.dart';
import '../theme/design_tokens.dart';

/// One product as the server prices it for a transfer. Amounts are piastres
/// (1/100 EGP) and equal the Play product's EGP price ([playProduct]).
class CoinPack {
  final String code;
  final int coins;
  final int pricePiastres;

  /// Set for the Quiet Pass: it grants this instead of coins.
  final String? entitlement;

  /// Set for the Starter Bundle: the cosmetic it adds to its coins.
  final String? item;

  /// The Google Play product this is the transfer twin of.
  final String? playProduct;
  const CoinPack(
    this.code,
    this.coins,
    this.pricePiastres, [
    this.entitlement,
    this.item,
    this.playProduct,
  ]);

  bool get pass => entitlement != null;
  bool get bundle => item != null;
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
  final String pack;
  final int coins;
  final int amountPiastres;
  final String method;
  final String status;
  final String? note;
  final String? senderName;
  final bool proofSubmitted;
  const CoinOrder({
    required this.id,
    required this.reference,
    required this.coins,
    required this.amountPiastres,
    required this.method,
    required this.status,
    this.pack = '',
    this.note,
    this.senderName,
    this.proofSubmitted = false,
  });

  factory CoinOrder.fromJson(Map<String, dynamic> j) => CoinOrder(
    id: j['id'] as String,
    reference: j['reference'] as String? ?? '',
    pack: j['pack'] as String? ?? '',
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    amountPiastres: (j['amountPiastres'] as num?)?.toInt() ?? 0,
    method: j['method'] as String? ?? '',
    status: j['status'] as String? ?? '',
    note: j['playerNote'] as String?,
    senderName: j['senderName'] as String?,
    proofSubmitted: j['proofSubmitted'] == true,
  );

  /// Pending: waiting for the proof, or for the owner's review.
  bool get open =>
      const {'awaiting_transfer', 'claimed', 'needs_info'}.contains(status);

  /// The player can (re)send the screenshot and sender name.
  bool get needsProof =>
      status == 'awaiting_transfer' || status == 'needs_info';
}

class CoinShop {
  final bool enabled;
  final bool recoverable;
  final List<CoinPack> packs;
  final List<PayMethod> methods;
  final List<CoinOrder> orders;

  /// This account already has the Quiet Pass (from Play or a transfer).
  final bool adFree;
  final int maxPending;
  const CoinShop({
    required this.enabled,
    required this.recoverable,
    required this.packs,
    required this.methods,
    required this.orders,
    this.adFree = false,
    this.maxPending = 2,
  });

  factory CoinShop.fromJson(Map<String, dynamic> j) => CoinShop(
    enabled: j['enabled'] as bool? ?? false,
    recoverable: j['recoverable'] as bool? ?? false,
    adFree: j['adFree'] == true,
    maxPending: (j['maxPending'] as num?)?.toInt() ?? 2,
    packs: [
      for (final p in (j['packs'] as List? ?? const []).whereType<Map>())
        if (p['pricePiastres'] is num &&
            ((p['coins'] as num?) ?? 0) >= 0 &&
            (p['entitlement'] == null ||
                p['entitlement'] == 'remove_interruptions'))
          CoinPack(
            p['code'] as String,
            ((p['coins'] as num?) ?? 0).toInt(),
            (p['pricePiastres'] as num).toInt(),
            p['entitlement'] as String?,
            p['item'] as String?,
            p['playProduct'] as String?,
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

  List<CoinOrder> get pending => orders.where((o) => o.open).toList();
  bool get full => pending.length >= maxPending;

  CoinPack? forPlayProduct(String id) =>
      packs.where((p) => p.playProduct == id).firstOrNull;

  PayMethod? method(String code) =>
      methods.where((m) => m.code == code).firstOrNull;
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
    final platform = ref.read(paymentCapabilitiesProvider).platform;
    return backend.call('coin_orders', {
      ...body,
      if (platform != null) 'platform': platform,
    });
  }

  @override
  Future<CoinShop> build() async =>
      CoinShop.fromJson(await _call({'action': 'shop'}));

  /// On resume and pull-to-refresh: an approval may have landed while the
  /// player was away; the wallet (and a pass or bundle) is the server's to say.
  Future<void> reload() async {
    final before = {
      for (final o in state.valueOrNull?.orders ?? const <CoinOrder>[])
        if (o.status == 'paid') o.id,
    };
    state = await AsyncValue.guard(build);
    final after = state.valueOrNull?.orders ?? const <CoinOrder>[];
    await ref.read(walletProvider.notifier).refresh();
    if (after.any((o) => o.status == 'paid' && !before.contains(o.id))) {
      ref.invalidate(economyCapabilitiesProvider);
    }
  }

  Future<CoinOrder> create(String pack, String method) async {
    final answer = await _call({
      'action': 'create',
      'pack': pack,
      'method': method,
    });
    state = await AsyncValue.guard(build);
    return CoinOrder.fromJson(
      Map<String, dynamic>.from(answer['order'] as Map),
    );
  }

  /// The proof: the screenshot (already a <=1600px JPEG) and the sender name.
  Future<void> submit(String order, String sender, Uint8List image) async {
    await _call({
      'action': 'submit',
      'order': order,
      'senderName': normalizeSenderName(sender),
      'image': base64Encode(image),
    });
    state = await AsyncValue.guard(build);
  }

  Future<void> cancel(String order) async {
    await _call({'action': 'cancel', 'order': order});
    state = await AsyncValue.guard(build);
  }
}

/// The sender name exactly as the server accepts it (coin_payments.ts
/// `SENDER`): letters, marks and digits of any script, spaces and
/// `.,'’_-@+()`, 2–80 characters after runs of spaces are collapsed.
final _senderPattern = RegExp(
  r"^[\p{L}\p{M}\p{N} .,'’_\-@+()]{2,80}$",
  unicode: true,
);

/// [raw] as it is sent: trimmed, inner runs of whitespace made one space.
String normalizeSenderName(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Whether the server will accept [raw] as the sender name.
bool validSenderName(String raw) =>
    _senderPattern.hasMatch(normalizeSenderName(raw));

String methodName(BuildContext context, String code) => code == 'instapay'
    ? context.l10n.coinPayInstapay
    : context.l10n.coinPayVodafone;

/// A refusal the player can act on, in their words.
String transferError(BuildContext context, Object error) {
  final l = context.l10n;
  final code = error is BackendException ? error.code : '';
  return switch (code) {
    'ALREADY_OWNED' => l.pay2AlreadyOwned,
    'TOO_MANY_PENDING' => l.pay2TooMany,
    'DUPLICATE_PROOF' => l.pay2Duplicate,
    'SENDER_REQUIRED' || 'PROOF_REQUIRED' => l.pay2ProofRequired,
    // An older server said a malformed sender name as a bare BAD_REQUEST.
    'BAD_REQUEST' when error is BackendException &&
        error.message.contains('sender') =>
      l.pay2ProofRequired,
    'SALES_DISABLED' || 'METHOD_UNAVAILABLE' => l.coinPacksUnavailable,
    _ => l.coinOrderFailed,
  };
}

String productName(BuildContext context, CoinPack pack) {
  final l = context.l10n;
  if (pack.pass) return l.quietPassTitle;
  if (pack.bundle) return l.bundleTitle;
  return l.coinPackCoins(pack.coins);
}

String orderProduct(BuildContext context, CoinOrder order) {
  final l = context.l10n;
  if (order.pack == 'quiet_pass' || (order.coins == 0 && order.pack.isEmpty)) {
    return l.quietPassTitle;
  }
  if (order.pack == 'starter_bundle') return l.bundleTitle;
  return l.coinPackCoins(order.coins);
}

void _say(BuildContext context, String text) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(text)));

/// Step 1 done: the order is made first — the server checks the kill
/// switch, the pending cap and what the player already owns — and only when
/// it exists does the chosen method's page open, so nobody pays for an order
/// that was refused. A refusal is said in words and nothing opens. With
/// [sheet], the order's steps open over the current tab (the Play offers tab).
/// Should the browser block the page, the order's own «open» control is there.
Future<void> startTransfer(
  BuildContext context,
  WidgetRef ref,
  CoinPack pack,
  PayMethod method, {
  bool sheet = false,
}) async {
  final CoinOrder order;
  try {
    order = await ref
        .read(coinShopProvider.notifier)
        .create(pack.code, method.code);
  } catch (error) {
    if (context.mounted) _say(context, transferError(context, error));
    return;
  }
  if (!context.mounted) return;
  final opened = ref.read(externalLinkOpenerProvider)(method.url!);
  if (!opened) _say(context, context.l10n.coinOpenFailed);
  if (sheet) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TransferOrderSheet(orderId: order.id),
    );
  }
}

/// «إنستا باي» / «فودافون كاش» under a paid item on the Play tab. Nothing at
/// all when the server has transfers off for this platform (kill switch), the
/// item has no transfer twin, or it is already owned.
class TransferMethodButtons extends ConsumerWidget {
  final String playProduct;
  const TransferMethodButtons({super.key, required this.playProduct});

  static Key button(String product, String method) =>
      ValueKey('transfer_${product}_$method');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(paymentCapabilitiesProvider).transfer) {
      return const SizedBox.shrink();
    }
    final shop = ref.watch(coinShopProvider).valueOrNull;
    final pack = shop?.forPlayProduct(playProduct);
    if (shop == null || !shop.enabled || pack == null) {
      return const SizedBox.shrink();
    }
    if (pack.pass && shop.adFree) return const SizedBox.shrink();
    final methods = shop.methods.where((m) => m.available).toList();
    if (methods.isEmpty) return const SizedBox.shrink();
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: s.sm),
      child: Row(
        children: [
          for (final (i, m) in methods.indexed) ...[
            if (i > 0) SizedBox(width: s.sm),
            Expanded(
              child: OutlinedButton(
                key: button(playProduct, m.code),
                style: vaultOutlineStyle(context),
                onPressed: () =>
                    startTransfer(context, ref, pack, m, sheet: true),
                child: Text(
                  methodName(context, m.code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Re-reads orders and the wallet whenever the app comes back to the front
/// (the player returns from InstaPay / Vodafone Cash, or waits for review).
class _ResumeRefresh extends ConsumerStatefulWidget {
  final Widget child;
  const _ResumeRefresh({required this.child});

  @override
  ConsumerState<_ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends ConsumerState<_ResumeRefresh> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => ref.read(coinShopProvider.notifier).reload(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One order's steps, over the Play tab.
class TransferOrderSheet extends ConsumerWidget {
  final String orderId;
  const TransferOrderSheet({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(coinShopProvider).valueOrNull;
    final order = shop?.orders.where((o) => o.id == orderId).firstOrNull;
    final s = context.spacing;
    return _ResumeRefresh(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          s.md,
          0,
          s.md,
          s.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: order == null
              ? const VaultSkeleton(cards: 1)
              : !shop!.recoverable
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.coinPacksNeedAccount,
                      style: context.typography.body,
                    ),
                    const AccountProtectionCard(),
                  ],
                )
              : ProofOrderCard(order: order, method: shop.method(order.method)),
        ),
      ),
    );
  }
}

/// The transfer store: InstaPay / Vodafone Cash with manual review, on the
/// web and (beside Google Play) on Android.
class CoinPacksTab extends ConsumerStatefulWidget {
  const CoinPacksTab({super.key});

  static Key pack(String code) => ValueKey('coin_pack_$code');
  static Key method(String code) => ValueKey('coin_method_$code');
  static Key status(String id) => ValueKey('coin_status_$id');
  static const notice = ValueKey('coin_manual_notice');
  static const passNote = ValueKey('coin_pass_note');
  static const openButton = ValueKey('coin_open_payment');
  static const cancelButton = ValueKey('coin_cancel');
  static const fullNote = ValueKey('coin_pending_full');

  @override
  ConsumerState<CoinPacksTab> createState() => _CoinPacksTabState();
}

class _CoinPacksTabState extends ConsumerState<CoinPacksTab> {
  String? _pack;
  bool _busy = false;
  final _packScroll = ScrollController();

  @override
  void dispose() {
    _packScroll.dispose();
    super.dispose();
  }

  Future<void> _pay(CoinPack pack, PayMethod method) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startTransfer(context, ref, pack, method);
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
    return _ResumeRefresh(
      child: shop.when(
        loading: () => const VaultSkeleton(cards: 2),
        // A server without the orders feature (or offline) is "not
        // available", said plainly, with a retry.
        error: (_, _) => VaultRetry(
          message: l.coinPacksUnavailable,
          action: l.videoRetry,
          onRetry: () => ref.invalidate(coinShopProvider),
        ),
        data: (shop) => RefreshIndicator(
          onRefresh: () => ref.read(coinShopProvider.notifier).reload(),
          child: ListView(
            padding: EdgeInsets.all(s.md),
            children: [
              if (!shop.enabled)
                Text(l.coinPacksUnavailable, style: context.typography.body)
              else if (!shop.recoverable) ...[
                Text(l.coinPacksNeedAccount, style: context.typography.body),
                SizedBox(height: s.sm),
                const AccountProtectionCard(),
              ] else ...[
                for (final order in shop.pending) ...[
                  VaultCard(
                    lit: order.needsProof,
                    children: [
                      ProofOrderCard(
                        order: order,
                        method: shop.method(order.method),
                      ),
                    ],
                  ),
                  SizedBox(height: s.md),
                ],
                if (shop.full)
                  Text(
                    key: CoinPacksTab.fullNote,
                    l.pay2TooMany,
                    style: context.typography.bodySmall,
                  )
                else
                  ..._chooser(shop),
              ],
              OrderStatusList(orders: shop.orders),
            ],
          ),
        ),
      ),
    );
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
        .where((p) => !p.pass && !p.bundle && p.coins > 0 && p.pricePiastres > 0)
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
        title: l.pay2StepChoose,
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
                                : p.bundle
                                ? const FittedBox(child: StarterBundleArt())
                                : StoreProductArt(code: p.code),
                          ),
                          if (p.pass || p.bundle)
                            Text(
                              productName(context, p),
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
                          if (p.bundle)
                            PositionedDirectional(
                              top: -VaultTokens.tagLift,
                              start: s.sm,
                              child: VaultTag(l.vaultOneTime, oxblood: true),
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
          passOwned
              ? l.webPassOwned
              : kIsWeb
              ? l.webPassBody
              : l.quietPassBody,
          style: context.typography.bodySmall.copyWith(
            color: passOwned ? VaultTokens.gold : colors.textSecondary,
          ),
        ),
        SizedBox(height: s.sm),
      ],
      if (pack != null && pack.bundle) ...[
        Text(
          l.bundleBody(pack.coins),
          style: context.typography.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
        SizedBox(height: s.sm),
      ],
      SizedBox(height: s.sm),
      _Step(number: 2, title: l.coinPayMethod, hint: l.pay2StepPayHint),
      SizedBox(height: s.sm),
      for (final m in shop.methods) ...[
        VaultPress(
          child: FilledButton.icon(
            key: CoinPacksTab.method(m.code),
            style: vaultGoldStyle(context),
            icon: const Icon(Icons.open_in_new),
            onPressed: m.available && pack != null && !passOwned && !_busy
                ? () => _pay(pack, m)
                : null,
            label: Text(
              pack == null
                  ? methodName(context, m.code)
                  : '${methodName(context, m.code)} · ${l.coinPackPrice(egp(pack.pricePiastres))}',
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
      const _Notice(),
    ];
  }
}

/// A numbered step: a struck medallion, its title, and what to do.
class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String? hint;
  final bool done;
  const _Step({
    required this.number,
    required this.title,
    this.hint,
    this.done = false,
  });

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
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  size: VaultTokens.chipCoin,
                  color: VaultTokens.goldInk,
                )
              : Text(
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
  const _Notice();

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
        '${context.l10n.pay2ReviewDetail}\n${context.l10n.pay2ProofPrivacy}',
        style: context.typography.bodySmall.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ],
  );
}

/// One pending order: pay in the other app, then come back with the proof
/// (the screenshot and the sender name, both required).
class ProofOrderCard extends ConsumerStatefulWidget {
  final CoinOrder order;
  final PayMethod? method;
  const ProofOrderCard({super.key, required this.order, required this.method});

  static const pickButton = ValueKey('proof_pick');
  static const senderField = ValueKey('proof_sender');
  static const submitButton = ValueKey('proof_submit');
  static const imageReady = ValueKey('proof_image_ready');

  @override
  ConsumerState<ProofOrderCard> createState() => _ProofOrderCardState();
}

class _ProofOrderCardState extends ConsumerState<ProofOrderCard> {
  final _sender = TextEditingController();
  Uint8List? _image;
  bool _busy = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Android may kill the app while the photo picker is open; the chosen
    // screenshot is then handed back on the next start, not to the picker
    // call that is gone. Asked for here and whenever the app comes back.
    _lifecycle = AppLifecycleListener(onResume: _recover);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<void> _recover() async {
    if (!mounted || _busy || _image != null || !widget.order.needsProof) {
      return;
    }
    try {
      final bytes = await ref.read(lostProofProvider)();
      if (bytes == null || !mounted || _image != null) return;
      setState(() => _image = bytes);
    } catch (_) {}
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(proofPickerProvider)();
      if (!mounted) return;
      if (bytes == null) return;
      setState(() => _image = bytes);
    } catch (_) {
      if (mounted) _say(context, context.l10n.pay2ImageFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final image = _image;
    final sender = normalizeSenderName(_sender.text);
    if (image == null || !validSenderName(sender)) {
      _say(context, context.l10n.pay2ProofRequired);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(coinShopProvider.notifier)
          .submit(widget.order.id, sender, image);
      if (mounted) {
        setState(() => _image = null);
        _say(context, context.l10n.pay2Sent);
      }
    } catch (error) {
      if (mounted) _say(context, transferError(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open() {
    final url = widget.method?.url;
    if (url == null || !ref.read(externalLinkOpenerProvider)(url)) {
      _say(context, context.l10n.coinOpenFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final order = widget.order;
    final name = methodName(context, order.method);
    final amount = egp(order.amountPiastres);
    return Column(
      key: ValueKey('proof_order_${order.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.coinOrderTitle(order.reference),
          style: context.typography.title.copyWith(
            color: VaultTokens.goldLight,
          ),
        ),
        Text(
          l.pay2OrderSummary(orderProduct(context, order), amount, name),
          style: context.typography.body,
        ),
        SizedBox(height: s.md),
        _Step(number: 1, title: l.pay2StepChoose, done: true),
        SizedBox(height: s.sm),
        _Step(
          number: 2,
          title: l.pay2StepPay(amount, name),
          done: !order.needsProof,
        ),
        if (order.needsProof && widget.method?.url != null) ...[
          SizedBox(height: s.xs),
          OutlinedButton.icon(
            key: CoinPacksTab.openButton,
            style: vaultOutlineStyle(context),
            icon: const Icon(Icons.open_in_new),
            label: Text(l.coinOpenPayment(name)),
            onPressed: _open,
          ),
          if (kIsWeb)
            Text(l.coinDesktopHint, style: context.typography.caption),
        ],
        SizedBox(height: s.sm),
        _Step(
          number: 3,
          title: l.pay2StepProof,
          hint: order.status == 'claimed' ? l.pay2StatusPending : null,
          done: order.status == 'claimed',
        ),
        if (order.status == 'needs_info' && (order.note ?? '').isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: Text(
              l.coinStatusNeedsInfo(order.note!),
              style: context.typography.bodySmall.copyWith(
                color: VaultTokens.oxbloodLight,
              ),
            ),
          ),
        if (order.needsProof) ...[
          SizedBox(height: s.sm),
          OutlinedButton.icon(
            key: ProofOrderCard.pickButton,
            style: vaultOutlineStyle(context),
            onPressed: _busy ? null : _pick,
            icon: Icon(
              _image == null
                  ? Icons.add_photo_alternate_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(_image == null ? l.pay2PickImage : l.pay2ImageChosen),
          ),
          if (_image != null)
            Padding(
              key: ProofOrderCard.imageReady,
              padding: EdgeInsets.only(top: s.xs),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.radii.button),
                  child: Image.memory(
                    _image!,
                    height: DailyTokens.passArt,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          SizedBox(height: s.sm),
          TextField(
            key: ProofOrderCard.senderField,
            controller: _sender,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l.pay2SenderName(name)),
          ),
          ListenableBuilder(
            listenable: _sender,
            builder: (context, _) => VaultPress(
              child: FilledButton(
                key: ProofOrderCard.submitButton,
                style: vaultGoldStyle(context),
                onPressed:
                    _busy || _image == null || !validSenderName(_sender.text)
                    ? null
                    : _submit,
                child: Text(l.pay2Submit),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: Text(
              l.pay2ProofRequired,
              style: context.typography.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
        ],
        if (order.status == 'awaiting_transfer')
          TextButton(
            key: CoinPacksTab.cancelButton,
            onPressed: _busy
                ? null
                : () async {
                    try {
                      await ref
                          .read(coinShopProvider.notifier)
                          .cancel(order.id);
                    } catch (error) {
                      if (context.mounted) {
                        _say(context, transferError(context, error));
                      }
                    }
                  },
            child: Text(l.coinCancelOrder),
          ),
      ],
    );
  }
}

/// Every recent order and what happened to it: pending, approved, rejected
/// (with the owner's reason), expired.
class OrderStatusList extends StatelessWidget {
  final List<CoinOrder> orders;
  const OrderStatusList({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: s.lg),
      child: VaultCard(
        children: [
          VaultHeading(title: context.l10n.pay2OrdersTitle, compact: true),
          for (final (i, order) in orders.indexed) ...[
            if (i > 0) const VaultDivider(),
            ListTile(
              key: CoinPacksTab.status(order.id),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${order.reference} · ${orderProduct(context, order)} · ${context.l10n.coinPackPrice(egp(order.amountPiastres))}',
              ),
              subtitle: Text(settledStatus(context, order)),
            ),
          ],
        ],
      ),
    );
  }
}

/// What happened to an order, in the player's words.
String settledStatus(BuildContext context, CoinOrder order) {
  final l = context.l10n;
  return switch (order.status) {
    'awaiting_transfer' => l.pay2StatusAwaiting,
    'claimed' => l.pay2StatusPending,
    'needs_info' => l.coinStatusNeedsInfo(order.note ?? ''),
    'paid' =>
      order.coins > 0 && order.pack != 'starter_bundle'
          ? l.coinStatusPaid(order.coins)
          : l.pay2StatusApproved,
    'rejected' => l.coinStatusRejected(order.note ?? ''),
    'cancelled' => l.coinStatusCancelled,
    'refunded' => l.coinStatusRefunded(order.note ?? ''),
    'expired' => l.pay2StatusExpired,
    _ => l.pay2StatusPending,
  };
}
