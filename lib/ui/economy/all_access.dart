import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../transport/supabase_backend.dart';
import '../screens/online/online_session.dart';
import 'wallet.dart';

/// The signed-in account's id, or null. Resolving the backend reads the local
/// session; it does not start one. A build with no server has no account.
final allAccessAccountProvider = StreamProvider<String?>((ref) async* {
  if (!SupabaseConfig.isConfigured) {
    yield null;
    return;
  }
  final backend = await ref.read(onlineBackendFactoryProvider)();
  yield backend.userId;
  if (backend is SupabaseBackend) {
    await for (final _ in backend.client.auth.onAuthStateChange) {
      yield backend.userId;
    }
  }
});

/// The owner grant, as the server's last wallet answer states it. Store items
/// need no check here: the server already lists them as owned for a granted
/// account.
///
/// The last answer is also kept on the device, with the account it belongs
/// to, so a cold start with no network still opens what the server granted.
/// It is read only while the wallet has not answered, and only for the same
/// account; a sign-out or a switch forgets it. Nothing here grants anything
/// the server did not say.
final allAccessProvider = Provider<bool>(
  (ref) => ref.watch(allAccessCacheProvider),
);

final allAccessCacheProvider = NotifierProvider<AllAccessController, bool>(
  AllAccessController.new,
);

class AllAccessController extends Notifier<bool> {
  static const storageKey = 'all_access_v1';
  String? _account;

  @override
  bool build() {
    ref.listen<AsyncValue<String?>>(
      allAccessAccountProvider,
      (_, next) => _accountChanged(next.valueOrNull),
    );
    ref.listen<AsyncValue<WalletState?>>(walletProvider, (_, next) {
      final wallet = next.valueOrNull;
      if (wallet == null) return;
      state = wallet.allAccess;
      unawaited(_save());
    });
    _account = ref.read(allAccessAccountProvider).valueOrNull;
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet != null) {
      unawaited(_save());
      return wallet.allAccess;
    }
    unawaited(_restore());
    return false;
  }

  void _accountChanged(String? account) {
    if (account == _account) return;
    final switched = _account != null;
    _account = account;
    if (switched) {
      // The old grant leaves with the old account; the new account's wallet
      // answer sets it again.
      state = false;
      unawaited(_clear());
      return;
    }
    if (ref.read(walletProvider).valueOrNull != null) {
      unawaited(_save());
    } else {
      unawaited(_restore());
    }
  }

  Future<void> _restore() async {
    final account = _account;
    if (account == null) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is! Map ||
          json['account'] != account ||
          json['allAccess'] is! bool) {
        return;
      }
      // The wallet may have answered, or the account changed, while the disk
      // was being read: either wins.
      if (_account != account || ref.read(walletProvider).valueOrNull != null) {
        return;
      }
      state = json['allAccess'] as bool;
    } catch (_) {}
  }

  Future<void> _save() async {
    final account = _account;
    final wallet = ref.read(walletProvider).valueOrNull;
    if (account == null || wallet == null) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
        storageKey,
        jsonEncode({'account': account, 'allAccess': wallet.allAccess}),
      );
    } catch (_) {}
  }

  Future<void> _clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(storageKey);
    } catch (_) {}
  }
}
