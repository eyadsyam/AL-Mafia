import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_policy.dart';

/// Writes are serialized so delayed callbacks cannot overwrite newer caps.
class AdLedgerStoreV4 {
  static const key = 'ad_fullscreen_ledger_v4';
  Future<void> _tail = Future.value();
  Future<T> _enqueue<T>(Future<T> Function() work) {
    final operation = _tail.then((_) => work());
    _tail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<AdLedgerV4> load() => _enqueue(_read);

  Future<AdLedgerV4> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null) {
      // Corrupt durable pacing must not silently create a fresh budget.
      return AdLedgerV4.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final legacyRaw = prefs.getString('interstitial_ledger_v1');
    final legacy = legacyRaw == null
        ? <String, dynamic>{}
        : jsonDecode(legacyRaw) as Map<String, dynamic>;
    final last = legacy['lastShownMs'] as int?;
    final count = legacy['shownToday'] as int? ?? 0;
    if (count < 0 || count > 64 || (count > 0 && last == null)) {
      throw const FormatException('Invalid legacy ad budget');
    }
    final ledger = AdLedgerV4(
      highWaterMs: legacy['highWaterMs'] as int? ?? 0,
      lastDismissMs: last,
      lastRewardMs: legacy['lastRewardMs'] as int?,
      automaticShows: List.unmodifiable([
        if (last != null)
          for (var i = 0; i < count; i++) last,
      ]),
    );
    if (!await prefs.setString(key, jsonEncode(ledger.toJson()))) {
      throw StateError('Ad ledger migration failed');
    }
    return ledger;
  }

  Future<void> save(AdLedgerV4 ledger) => _enqueue(() async {
    final existing = await _read();
    if (ledger.highWaterMs < existing.highWaterMs) {
      throw StateError('Stale ad ledger snapshot');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(ledger.toJson()))) {
      throw StateError('Ad ledger write failed');
    }
  });

  /// Runtime callbacks must transform the current ledger inside the queue.
  Future<AdLedgerV4> update(AdLedgerV4 Function(AdLedgerV4) change) =>
      _enqueue(() async {
        final existing = await _read();
        final next = change(existing);
        if (next.highWaterMs < existing.highWaterMs)
          throw StateError('Ad clock rollback');
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(key, jsonEncode(next.toJson())))
          throw StateError('Ad ledger write failed');
        return next;
      });
}
