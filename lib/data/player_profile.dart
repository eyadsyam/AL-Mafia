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

/// Where an unfinished first run was left: the chapter and the name and
/// gender typed so far.
///
/// Google sign-in leaves the app for the browser. Android may close the app
/// while it is away, and the web reloads the page on the way back; either way
/// the first-run screen used to start again at its first chapter (owner
/// report, 2026-10-01). Cleared once setup is saved.
class FirstRunProgress {
  static const key = 'mafia.firstRun.progress.v1';

  final String chapter;
  final String name;
  final PlayerGender gender;

  /// The «عندي 18 سنة… وموافق» box was ticked before the app was left. The
  /// acceptance itself is still recorded only when setup completes.
  final bool agreed;

  const FirstRunProgress({
    required this.chapter,
    this.name = '',
    this.gender = PlayerGender.unspecified,
    this.agreed = false,
  });

  static Future<FirstRunProgress?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final chapter = json['chapter'];
      if (chapter is! String) return null;
      final name = json['name'];
      return FirstRunProgress(
        chapter: chapter,
        name: name is String ? name : '',
        gender:
            PlayerGender.values
                .where((v) => v.name == json['gender'])
                .firstOrNull ??
            PlayerGender.unspecified,
        agreed: json['agreed'] == true,
      );
    } catch (_) {
      // Unreadable progress is no progress: the first chapter, as before.
      return null;
    }
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode({
          'chapter': chapter,
          'name': name,
          'gender': gender.name,
          'agreed': agreed,
        }),
      );
    } catch (_) {
      /* Best effort: losing the place is the old behaviour, not a failure. */
    }
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
  }
}

/// «أهلاً يا <name>» on Home, once, right after first run. Armed when setup
/// completes, consumed the first time Home shows it.
class WelcomeGreeting {
  static const key = 'mafia.welcome.pending.v1';

  static Future<bool> pending() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> arm() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {}
  }

  static Future<void> consume() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
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
