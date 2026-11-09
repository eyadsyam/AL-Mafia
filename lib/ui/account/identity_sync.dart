import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_profile.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../../transport/account_auth.dart' show AccountProfile;
import '../social/directory.dart';
import 'account_sheet.dart' show accountProfileProvider;

/// One name per account, on every device.
///
/// The server's entry is the account's name: a phone and a browser signed in
/// with the same email show the same name. A device that was set up before
/// signing in (or under another name) takes the account's name the first time
/// it sees the account, before it publishes anything of its own — otherwise
/// its presence beat would overwrite the account with this device's old name.
/// A name the player changes in the profile sheet is published by that sheet,
/// and every device then follows it.
class IdentitySync {
  IdentitySync(this._ref);
  final Ref _ref;

  String? _syncedFor;
  Future<DirectoryMe?>? _running;

  /// Test hook.
  int fetches = 0;

  /// The account's entry, after the local profile has been made to match it.
  /// Null for a guest, when the server cannot be reached, or when the account
  /// has no entry yet. Fetched once per account per launch.
  Future<DirectoryMe?> ensureSynced() {
    final account =
        _ref.read(accountProfileProvider).valueOrNull ?? AccountProfile.guest;
    final id = account.userId;
    if (!account.signedIn || id == null) return Future.value(null);
    if (_syncedFor == id && _running != null) return _running!;
    _syncedFor = id;
    return _running = _sync();
  }

  Future<DirectoryMe?> _sync() async {
    try {
      fetches++;
      final me = await _ref.read(directoryApiProvider).me();
      final name = me.name;
      if (name == null) return me;
      final local = _ref.read(playerProfileProvider).valueOrNull;
      final gender = me.gender ?? local?.gender ?? PlayerGender.unspecified;
      if (local != null && (local.name != name || local.gender != gender)) {
        await _ref
            .read(playerProfileProvider.notifier)
            .save(PlayerProfile(name: name, gender: gender));
      }
      return me;
    } catch (_) {
      // Next launch tries again; until then the device keeps what it has.
      _running = null;
      _syncedFor = null;
      return null;
    }
  }
}

final identitySyncProvider = Provider<IdentitySync>(IdentitySync.new);
