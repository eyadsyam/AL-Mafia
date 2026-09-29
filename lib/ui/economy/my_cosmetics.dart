import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final myCosmeticsProvider = NotifierProvider<MyCosmeticsController, MyCosmetics>(
  MyCosmeticsController.new,
);

class MyCosmeticsController extends Notifier<MyCosmetics> {
  static const storageKey = 'my_cosmetics_v1';

  @override
  MyCosmetics build() {
    ref.listen<AsyncValue<WalletState?>>(walletProvider, (_, next) {
      final wallet = next.valueOrNull;
      if (wallet == null) return;
      final fresh = MyCosmetics.fromEquipped(wallet.equipped);
      if (fresh != state) state = fresh;
      _save(fresh);
    }, fireImmediately: true);
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet != null) return MyCosmetics.fromEquipped(wallet.equipped);
    _restore();
    return MyCosmetics.none;
  }

  Future<void> _restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      // The wallet may have answered while the disk was being read: it wins.
      if (ref.read(walletProvider).valueOrNull != null) return;
      state = MyCosmetics.fromEquipped({
        for (final e in json.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      });
    } catch (_) {}
  }

  Future<void> _save(MyCosmetics value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        storageKey,
        jsonEncode(value.toJson()),
      );
    } catch (_) {}
  }
}
