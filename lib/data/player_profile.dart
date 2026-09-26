import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/models/player.dart';

/// Public identity on this installation. No roles, credentials or match data.
class PlayerProfile {
  final String name;
  final PlayerGender gender;
  const PlayerProfile({required this.name, required this.gender});

  bool get complete =>
      name.trim().isNotEmpty &&
      name.length <= 20 &&
      gender != PlayerGender.unspecified;

  Map<String, Object> toJson() => {'name': name.trim(), 'gender': gender.name};
  static PlayerProfile? fromJson(Map<String, dynamic> json) {
    final gender = PlayerGender.values
        .where((v) => v.name == json['gender'])
        .firstOrNull;
    if (json['name'] is! String || gender == null) return null;
    final profile = PlayerProfile(
      name: (json['name'] as String).trim(),
      gender: gender,
    );
    return profile.complete ? profile : null;
  }
}

class ProfileStore {
  static const profileKey = 'mafia.playerProfile.v1';
  static const introKey = 'mafia.introSeen.v1';

  Future<PlayerProfile?> load() async {
    // Storage that cannot be opened at all is the same as storage with nothing
    // in it: the player is asked again, and the app does not fail to start.
    final String? raw;
    try {
      raw = (await SharedPreferences.getInstance()).getString(profileKey);
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    try {
      return PlayerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(PlayerProfile profile) async {
    if (!profile.complete) throw ArgumentError('Incomplete profile');
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      profileKey,
      jsonEncode(profile.toJson()),
    )) {
      throw StateError('Profile storage unavailable');
    }
  }

  Future<bool> get introSeen async {
    try {
      return (await SharedPreferences.getInstance()).getBool(introKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markIntroSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(introKey, true);
    } catch (_) {
      /* Seeing the intro twice beats not starting at all. */
    }
  }
}

final profileStoreProvider = Provider((ref) => ProfileStore());

final playerProfileProvider =
    AsyncNotifierProvider<PlayerProfileController, PlayerProfile?>(
      PlayerProfileController.new,
    );

class PlayerProfileController extends AsyncNotifier<PlayerProfile?> {
  /// The last profile this session wrote. Newer than any read that was
  /// already in flight when it was saved.
  PlayerProfile? _saved;

  @override
  Future<PlayerProfile?> build() async {
    final loaded = await ref.read(profileStoreProvider).load();
    // A slow first read that lands after a save used to replace the saved
    // profile with the old one (phase 99): the player saw, and joined rooms
    // as, the name they had just changed.
    return _saved ?? loaded;
  }

  Future<void> save(PlayerProfile profile) async {
    await ref.read(profileStoreProvider).save(profile);
    _saved = profile;
    state = AsyncData(profile);
  }
}
