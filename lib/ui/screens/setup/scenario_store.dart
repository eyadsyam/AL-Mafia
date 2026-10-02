import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/monetization/purchase_store.dart';
import '../../../platform/optional_service.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/settings_kit.dart';
import '../online/online_session.dart';

class ScenarioPurchaseState {
  final bool configured;
  final bool busy;
  final bool owned;
  final bool pending;
  final bool failed;
  final String? price;

  const ScenarioPurchaseState({
    this.configured = false,
    this.busy = false,
    this.owned = false,
    this.pending = false,
    this.failed = false,
    this.price,
  });

  ScenarioPurchaseState copyWith({
    bool? configured,
    bool? busy,
    bool? owned,
    bool? pending,
    bool? failed,
    String? price,
  }) => ScenarioPurchaseState(
    configured: configured ?? this.configured,
    busy: busy ?? this.busy,
    owned: owned ?? this.owned,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
    price: price ?? this.price,
  );
}

class ScenarioPurchaseController extends Notifier<ScenarioPurchaseState> {
  StreamSubscription<StorePurchaseEvent>? _events;
  bool _started = false;

  @override
  ScenarioPurchaseState build() {
    ref.onDispose(() => unawaited(_events?.cancel()));
    return ScenarioPurchaseState(
      configured: ref.read(purchaseStoreProvider).configured,
    );
  }

  Future<void> start() async {
    if (_started || !state.configured) return;
    _started = true;
    final store = ref.read(purchaseStoreProvider);
    // Listen first. The events are a broadcast stream, and Play delivers
    // restored and unfinished purchases as soon as the store connects: one
    // emitted before this subscription exists is gone for good.
    _events ??= store.events.listen(_handle);
    try {
      await store.initialize();
    } catch (_) {
      // Retryable: the next start() — from the store screen — tries again.
      _started = false;
      rethrow;
    }
    await Future.wait([_loadEntitlement(), _loadProduct()]);
  }

  Future<void> _loadProduct() async {
    try {
      final product = await ref.read(purchaseStoreProvider).product();
      if (product != null) state = state.copyWith(price: product.price);
    } catch (_) {
      state = state.copyWith(failed: true);
    }
  }

  Future<void> _loadEntitlement() async {
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('play_purchase', {'action': 'summary'});
      final owned = ((answer['owned'] as List?) ?? const []).contains(
        'scenario_shadows',
      );
      state = state.copyWith(owned: owned, failed: false);
    } catch (_) {
      // Purchase UI may be revisited. Playing remains available.
    }
  }

  Future<void> _handle(StorePurchaseEvent event) async {
    if (event.state == StorePurchaseState.pending) {
      state = state.copyWith(pending: true, failed: false);
      return;
    }
    if (event.state == StorePurchaseState.canceled) {
      state = state.copyWith(busy: false, pending: false);
      return;
    }
    if (event.state == StorePurchaseState.failed || event.token == null) {
      state = state.copyWith(busy: false, pending: false, failed: true);
      return;
    }
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('play_purchase', {
        'action': 'verify',
        'productId': event.productId,
        'token': event.token,
      });
      final owned = ((answer['owned'] as List?) ?? const []).contains(
        'scenario_shadows',
      );
      state = state.copyWith(
        owned: owned,
        pending: answer['state'] == 'pending',
        busy: false,
        failed: false,
      );
      if (answer['state'] == 'active') {
        await ref.read(purchaseStoreProvider).complete(event.token!);
      }
    } catch (_) {
      state = state.copyWith(busy: false, failed: true);
    }
  }

  Future<void> buy() async {
    if (!state.configured || state.busy || state.owned) return;
    state = state.copyWith(busy: true, failed: false);
    final opened = await ref.read(purchaseStoreProvider).buy();
    if (!opened) state = state.copyWith(busy: false, failed: true);
  }

  Future<void> restore() async {
    if (!state.configured || state.busy) return;
    state = state.copyWith(busy: true, failed: false);
    try {
      await ref.read(purchaseStoreProvider).restore();
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!state.pending) state = state.copyWith(busy: false);
    } catch (_) {
      state = state.copyWith(busy: false, failed: true);
    }
  }
}

final scenarioPurchaseProvider =
    NotifierProvider<ScenarioPurchaseController, ScenarioPurchaseState>(
      ScenarioPurchaseController.new,
    );

class ScenarioStoreButton extends ConsumerStatefulWidget {
  /// Drawn as a settings row.
  final bool tile;
  const ScenarioStoreButton({super.key, this.tile = false});

  @override
  ConsumerState<ScenarioStoreButton> createState() =>
      _ScenarioStoreButtonState();
}

class _ScenarioStoreButtonState extends ConsumerState<ScenarioStoreButton> {
  final _overlay = OverlayPortalController();

  void _open() {
    // A launch-time start that failed (no Play services, no network) gets its
    // retry here, where the player is asking for the store.
    unawaited(
      runOptionalService(
        'purchases',
        ref.read(scenarioPurchaseProvider.notifier).start,
      ),
    );
    _overlay.show();
  }

  @override
  Widget build(BuildContext context) {
    final purchase = ref.watch(scenarioPurchaseProvider);
    if (!purchase.configured) return const SizedBox.shrink();
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (_) =>
          Positioned.fill(child: ScenarioStore(onClose: _overlay.hide)),
      child: widget.tile
          ? SettingsLinkRow(
              icon: Icons.local_mall_outlined,
              label: context.l10n.premiumScenarioTitle,
              onTap: _open,
            )
          : TextButton.icon(
              icon: const Icon(Icons.local_mall_outlined),
              label: Text(context.l10n.premiumScenarioTitle),
              onPressed: _open,
            ),
    );
  }
}

class ScenarioStore extends ConsumerWidget {
  final VoidCallback onClose;
  const ScenarioStore({super.key, required this.onClose});

  static const buyKey = ValueKey('scenario_buy');
  static const restoreKey = ValueKey('scenario_restore');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scenarioPurchaseProvider);
    final l = context.l10n;
    final spacing = context.spacing;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.premiumScenarioTitle),
        leading: IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(spacing.screenMargin),
            children: [
              const Icon(Icons.theater_comedy_outlined),
              SizedBox(height: spacing.lg),
              Text(l.premiumScenarioHint, style: context.typography.body),
              SizedBox(height: spacing.lg),
              if (state.pending)
                Text(l.premiumScenarioPending, style: context.typography.body),
              if (state.failed)
                Text(l.premiumScenarioFailed, style: context.typography.body),
              FilledButton.icon(
                key: ScenarioStore.buyKey,
                onPressed: state.owned || state.busy
                    ? null
                    : () => ref.read(scenarioPurchaseProvider.notifier).buy(),
                icon: Icon(
                  state.owned ? Icons.check_circle_outline : Icons.lock_open,
                ),
                label: Text(
                  state.owned
                      ? l.premiumScenarioOwned
                      : state.price == null
                      ? l.premiumScenarioBuy
                      : '${l.premiumScenarioBuy} — ${state.price}',
                ),
              ),
              TextButton(
                key: ScenarioStore.restoreKey,
                onPressed: state.busy
                    ? null
                    : () =>
                          ref.read(scenarioPurchaseProvider.notifier).restore(),
                child: Text(l.premiumScenarioRestore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
