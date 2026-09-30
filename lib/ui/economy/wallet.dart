import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';
import '../screens/online/online_session.dart';
import 'cosmetics.dart';

/// The server's reward for a finished online match (coin_economy.sql). Used
/// only to explain earning time; the server alone credits coins.
const coinsPerFinishedMatch = 100;

/// Under Economy v3 (`economy.version=3`) a finished eligible match pays 25
/// (plus 10 for a win and 25 for the day's first); the copy must follow the
/// contract the server is actually paying by.
const coinsPerFinishedMatchV3 = 25;

/// One row of the server catalog that this build can draw.
class WalletItem {
  final String code;

  /// List price.
  final int price;

  /// What this player would pay now (bundles subtract what they own).
  final int charge;
  final String kind;
  final String? slot;
  final List<String> contents;

  const WalletItem({
    required this.code,
    required this.price,
    required this.charge,
    required this.kind,
    this.slot,
    this.contents = const [],
  });

  factory WalletItem.fromJson(Map<String, dynamic> json) => WalletItem(
    code: json['code'] as String,
    price: (json['price'] as num?)?.toInt() ?? 0,
    charge:
        (json['charge'] as num?)?.toInt() ??
        (json['price'] as num?)?.toInt() ??
        0,
    kind: json['kind'] as String? ?? '',
    slot: json['slot'] as String?,
    contents: ((json['contents'] as List?) ?? const [])
        .whereType<String>()
        .toList(),
  );
}

class LedgerEntry {
  final String kind;
  final int amount;
  final String? item;
  final DateTime? at;
  const LedgerEntry({
    required this.kind,
    required this.amount,
    this.item,
    this.at,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    kind: json['kind'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    item: json['item'] as String?,
    at: DateTime.tryParse(json['at'] as String? ?? ''),
  );
}

/// The server's word on this player's coins. Nothing here is computed on the
/// device: balance, prices, ownership and equipment all come back from the
/// economy function after every action.
class WalletState {
  final int balance;
  final List<WalletItem> catalog;
  final Set<String> owned;
  final Map<String, String> equipped;
  final List<LedgerEntry> history;

  const WalletState({
    required this.balance,
    required this.catalog,
    required this.owned,
    required this.equipped,
    required this.history,
  });

  factory WalletState.fromJson(Map<String, dynamic> json) => WalletState(
    balance: (json['balance'] as num?)?.toInt() ?? 0,
    catalog: ((json['catalog'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => WalletItem.fromJson(Map<String, dynamic>.from(row)))
        // Only what this build can actually render is offered.
        .where((item) => Cosmetics.knows(item.code))
        .toList(),
    owned: ((json['owned'] as List?) ?? const []).whereType<String>().toSet(),
    equipped: {
      for (final entry in ((json['equipped'] as Map?) ?? const {}).entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    },
    history: ((json['history'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList(),
  );

  WalletItem? item(String code) =>
      catalog.where((item) => item.code == code).firstOrNull;

  /// Owned codes for [slot] that this build can draw.
  List<String> ownedFor(CosmeticSlot slot) => [
    for (final code in owned)
      if (Cosmetics.items[code]?.slot == slot) code,
  ]..sort();
}

/// Thrown by [WalletController] actions with the server's reason.
class WalletActionFailed implements Exception {
  final String? code;
  const WalletActionFailed(this.code);
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState?>(
  WalletController.new,
);

class WalletController extends AsyncNotifier<WalletState?> {
  @override
  Future<WalletState?> build() async => null;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  /// Reads the wallet and credits finished matches (idempotent server-side).
  Future<void> refresh() async {
    state = const AsyncLoading<WalletState?>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () async => WalletState.fromJson(await _call({'action': 'sync'})),
    );
  }

  Future<void> _act(Map<String, Object?> body) async {
    try {
      state = AsyncData(WalletState.fromJson(await _call(body)));
    } on BackendException catch (error) {
      throw WalletActionFailed(error.code);
    } catch (_) {
      throw const WalletActionFailed(null);
    }
  }

  /// The server charges, grants and records in one transaction. A repeated
  /// tap finds the item owned and charges nothing.
  Future<void> buy(String code) => _act({'action': 'buy', 'item': code});

  Future<void> equip(CosmeticSlot slot, String? code) =>
      _act({'action': 'equip', 'slot': slot.wire, 'item': code});
}
