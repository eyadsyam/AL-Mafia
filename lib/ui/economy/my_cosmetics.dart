import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'all_access.dart' show allAccessAccountProvider;
import 'cosmetics.dart';
import 'wallet.dart';

/// What this player has equipped, for the places their own identity appears
/// (store truth): Profile, the account sheet, Home, the result, the share card
/// and «القعدة» on this phone.
///
/// The server's wallet is the truth. Each time it answers, the equipped codes
/// this build can draw are kept on the device, so a pass-and-play evening with
/// no network still shows what the host paid for. Nothing here grants or
/// equips: an item removed on the server (a revoked bundle, say) disappears
/// here the next time the wallet is read.
class MyCosmetics {
  final String? frame;
  final String? plate;
  final String? pack;
  final String? narrator;
  const MyCosmetics({this.frame, this.plate, this.pack, this.narrator});

  static const none = MyCosmetics();

  bool get isEmpty =>
      frame == null && plate == null && pack == null && narrator == null;

  /// Only codes this build knows, each in its own slot.
  factory MyCosmetics.fromEquipped(Map<String, String> equipped) {
    String? slot(CosmeticSlot slot) {
      final code = equipped[slot.wire];
      return code != null && Cosmetics.items[code]?.slot == slot ? code : null;
    }

    return MyCosmetics(
      frame: slot(CosmeticSlot.frame),
      plate: slot(CosmeticSlot.nameplate),
      pack: slot(CosmeticSlot.roomPack),
      narrator: slot(CosmeticSlot.narrator),
    );
  }

  Map<String, String> toJson() => {
    'frame': ?frame,
    'nameplate': ?plate,
    'room_pack': ?pack,
    'narrator': ?narrator,
  };

  @override
  bool operator ==(Object other) =>
      other is MyCosmetics &&
      other.frame == frame &&
      other.plate == plate &&
      other.pack == pack &&
      other.narrator == narrator;

  @override
  int get hashCode => Object.hash(frame, plate, pack, narrator);
}

final myCosmeticsProvider =
    NotifierProvider<MyCosmeticsController, MyCosmetics>(
      MyCosmeticsController.new,
    );

class MyCosmeticsController extends AccountCache<MyCosmetics> {
  static const storageKey = 'my_cosmetics_v1';

  @override
  String get key => storageKey;

  @override
  MyCosmetics get empty => MyCosmetics.none;

  @override
  MyCosmetics build() {
    // Wherever the equipped codes are kept, the owned roles are kept too.
    ref.read(ownedRolesProvider);
    return super.build();
  }

  @override
  MyCosmetics of(WalletState wallet) =>
      MyCosmetics.fromEquipped(wallet.equipped);

  @override
  Object encode(MyCosmetics value) => value.toJson();

  @override
  MyCosmetics? decode(Object? json) => json is Map
      ? MyCosmetics.fromEquipped({
          for (final e in json.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        })
      : null;
}

/// The bought roles (`role_*` codes) this player owns, kept on the device after
/// every wallet read like [myCosmeticsProvider]: the one-phone setup screens
/// must still offer a bought role when the wallet has not answered (no
/// network, a slow server, a cold start). Nothing here grants anything — the
/// wallet replaces it the next time the server answers.
final ownedRolesProvider = NotifierProvider<OwnedRolesController, Set<String>>(
  OwnedRolesController.new,
);

class OwnedRolesController extends AccountCache<Set<String>> {
  static const storageKey = 'my_owned_roles_v1';

  @override
  String get key => storageKey;

  @override
  Set<String> get empty => const {};

  @override
  Set<String> of(WalletState wallet) => {
    for (final code in wallet.owned)
      if (Cosmetics.isRole(code)) code,
  };

  @override
  bool same(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  Object encode(Set<String> value) => value.toList()..sort();

  @override
  Set<String>? decode(Object? json) => json is List
      ? {
          for (final code in json)
            if (code is String && Cosmetics.isRole(code)) code,
        }
      : null;
}

/// The roles a room's host may switch on: the wallet's word, or until it answers
/// what this phone last heard, so a lobby opened straight after the app never
/// shows a bought role as locked. The server checks ownership regardless.
final hostOwnedRolesProvider = Provider<Set<String>>(
  (ref) =>
      ref.watch(walletProvider).valueOrNull?.owned ??
      ref.watch(ownedRolesProvider),
);

/// What both caches above share: the last wallet answer, kept on the device
/// with the account it belongs to.
///
/// It is read back only while the wallet has not answered, and only for that
/// account. A sign-out or a switch to another account forgets it, and the new
/// account starts empty until its own wallet answers — a deleted account, or
/// another player signing in on the same phone, never finds the last
/// account's purchases here. Like [AllAccessController].
abstract class AccountCache<T> extends Notifier<T> {
  String get key;
  T get empty;
  T of(WalletState wallet);
  Object encode(T value);
  T? decode(Object? json);
  bool same(T a, T b) => a == b;

  String? _account;
  bool _signedOut = false;

  @override
  T build() {
    ref.listen<AsyncValue<String?>>(
      allAccessAccountProvider,
      (_, next) => _accountChanged(next.valueOrNull),
    );
    ref.listen<AsyncValue<WalletState?>>(walletProvider, (_, next) {
      // A wallet being read again still carries the answer from before,
      // which may be the last account's: only a settled answer counts.
      if (next.isLoading) return;
      final wallet = next.valueOrNull;
      if (wallet == null) return;
      final fresh = of(wallet);
      if (!same(fresh, state)) state = fresh;
      unawaited(_save(fresh));
    });
    _account = ref.read(allAccessAccountProvider).valueOrNull;
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet != null) {
      final fresh = of(wallet);
      unawaited(_save(fresh));
      return fresh;
    }
    unawaited(_restore());
    return empty;
  }

  void _accountChanged(String? account) {
    if (account == _account) return;
    final switched = _account != null;
    _account = account;
    if (switched) {
      _signedOut = true;
      state = empty;
      unawaited(_clear());
      return;
    }
    // A new account after a sign-out in this run: nothing is restored until
    // its own wallet answers (the listener above).
    if (_signedOut) return;
    final wallet = ref.read(walletProvider);
    final answered = wallet.isLoading ? null : wallet.valueOrNull;
    if (answered != null) {
      unawaited(_save(of(answered)));
    } else {
      unawaited(_restore());
    }
  }

  Future<void> _restore() async {
    final account = _account;
    if (account == null) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return;
      final json = jsonDecode(raw);
      // Kept before caches named their account: the account signed in on
      // this phone then is the one signed in now, unless it changed in this
      // run (caught by [_signedOut]). The next wallet answer names it.
      final T? value;
      if (json is Map && json.containsKey('account')) {
        if (json['account'] != account) return;
        value = decode(json['value']);
      } else {
        value = decode(json);
      }
      if (value == null) return;
      // The wallet may have answered, or the account changed, while the disk
      // was being read: either wins.
      if (_account != account || _signedOut) return;
      if (ref.read(walletProvider).valueOrNull != null) return;
      state = value;
    } catch (_) {}
  }

  Future<void> _save(T value) async {
    final account = _account;
    if (account == null) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode({'account': account, 'value': encode(value)}),
      );
    } catch (_) {}
  }

  Future<void> _clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
  }
}
