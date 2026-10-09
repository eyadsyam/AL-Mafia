import 'dart:async';

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
    // One unreadable row is skipped, never allowed to blank the whole shelf.
    catalog: [
      for (final row in ((json['catalog'] as List?) ?? const []))
        if (_tryRow(row, WalletItem.fromJson) case final item?)
          // Only what this build can actually render is offered.
          if (Cosmetics.sells(item.code)) item,
    ],
    owned: ((json['owned'] as List?) ?? const []).whereType<String>().toSet(),
    equipped: {
      for (final entry in ((json['equipped'] as Map?) ?? const {}).entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    },
    history: [
      for (final row in ((json['history'] as List?) ?? const []))
        if (_tryRow(row, LedgerEntry.fromJson) case final entry?) entry,
    ],
  );

  static T? _tryRow<T>(Object? row, T Function(Map<String, dynamic>) parse) {
    if (row is! Map) return null;
    try {
      return parse(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  WalletState withBalance(int value) => WalletState(
    balance: value,
    catalog: catalog,
    owned: owned,
    equipped: equipped,
    history: history,
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
      // The server may have applied the purchase before the answer was lost
      // (a timeout, a dropped connection). Show its truth rather than the
      // balance from before, so a retry is not made blind.
      unawaited(_reconcile());
      throw const WalletActionFailed(null);
    }
  }

  /// Best effort: reads the wallet without crediting anything, and keeps the
  /// last state if the server still cannot be reached.
  Future<void> _reconcile() async {
    try {
      state = AsyncData(
        WalletState.fromJson(await _call({'action': 'summary'})),
      );
    } catch (_) {}
  }

  /// Something credited (or charged) coins on the server: every balance on
  /// screen follows at once, without anyone leaving and reopening the vault.
  ///
  /// [credited] is the server's own confirmed amount; it is shown straight
  /// away and the server's number replaces it a moment later. A wallet no
  /// screen has read yet stays unread — the vault reads it when it opens —
  /// so a grant never starts a sign-in or a read of its own.
  ///
  /// This replaces `ref.invalidate(walletProvider)`, which reset the wallet
  /// to "not loaded" and left an open vault blank until it was reopened.
  Future<void> settle({int credited = 0}) async {
    final current = state.valueOrNull;
    // Unread, unless a read is already on its way (a refresh keeps the
    // previous value, so it is loading *with* a value; the first build is
    // loading without one).
    if (current == null && !(state.isLoading && state.hasValue)) return;
    if (current != null && credited != 0) {
      state = AsyncData(current.withBalance(current.balance + credited));
    }
    await _reconcile();
  }

  /// The server charges, grants and records in one transaction. A repeated
  /// tap finds the item owned and charges nothing.
  Future<void> buy(String code) => _act({'action': 'buy', 'item': code});

  Future<void> equip(CosmeticSlot slot, String? code) =>
      _act({'action': 'equip', 'slot': slot.wire, 'item': code});
}
