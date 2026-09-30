/// The browser's answer to Isar: the same three stores, kept in
/// `localStorage` (through `shared_preferences`) so a reload, a closed tab or a
/// phone that evicted the page from memory does not lose the match, the
/// saved groups, the settings or the "I have seen the tutorial" flag.
///
/// ## Why this exists
///
/// The web build used to run on the in-memory fallback, which is the honest
/// shape for a tab that is a session, but the owner's rule is that the web game
/// is the mobile game: a pass-and-play match that survives a phone call on
/// Android has to survive a reload in the browser too. Nothing about the
/// contract changes: these classes *are* [MemoryMatchRepository],
/// [MemoryPlayerGroupRepository] and a whisper map, with one extra step after
/// each write. Reads come from memory, which was filled from storage when the
/// app opened.
///
/// ## What it must never do
///
/// Throw. A full storage quota, a private window that refuses storage, a
/// corrupt value: each is a failed mirror, the in-memory copy stays correct, and
/// the game goes on (the same best-effort contract as `openLocalStores`).
///
/// No role is ever written anywhere it was not already: the encoded match is
/// exactly what the Isar row holds. Doc 05 is unaffected: the stored match is
/// not readable by the UI until it is finished, and `loadAnalytics` refuses it.
library data.prefs_stores;

import 'dart:convert';

import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_stores.dart';
import 'memory_match_repository.dart';
import 'memory_player_group_repository.dart';
import 'player_group.dart';
import 'whisper_store.dart';

/// Storage keys. One key per store so a corrupt value costs one store.
abstract final class PrefsStoreKeys {
  static const matches = 'mm.store.matches.v1';
  static const defaultSettings = 'mm.store.defaultSettings.v1';
  static const onboardingSeen = 'mm.store.onboardingSeen.v1';
  static const seenHints = 'mm.store.seenHints.v1';
  static const groups = 'mm.store.groups.v1';
  static const groupNextId = 'mm.store.groupNextId.v1';
  static const whispers = 'mm.store.whispers.v1';
}

/// How many matches are kept. Storage in a browser is a few megabytes; a
/// finished match is tens of kilobytes. Oldest first out, and the newest match
/// (the one that may be unfinished) is always newer than anything dropped.
const int prefsMatchCap = 40;

/// Opens the stores over [prefs] (the real instance when null).
Future<LocalStores> openPrefsStores([SharedPreferences? prefs]) async {
  final p = prefs ?? await SharedPreferences.getInstance();

  final matchStore = MemoryMatchStore();
  _readMap(p, PrefsStoreKeys.matches).forEach((key, value) {
    final id = int.tryParse(key);
    if (id != null && value is String) matchStore.matches[id] = value;
  });
  matchStore.defaultSettings = _readString(p, PrefsStoreKeys.defaultSettings);
  matchStore.onboardingSeen = _readBool(p, PrefsStoreKeys.onboardingSeen);
  matchStore.seenHints.addAll(_readStringList(p, PrefsStoreKeys.seenHints));

  final groupStore = MemoryPlayerGroupStore();
  _readMap(p, PrefsStoreKeys.groups).forEach((key, value) {
    final id = int.tryParse(key);
    if (id != null && value is String) groupStore.groups[id] = value;
  });
  final nextId = _readInt(p, PrefsStoreKeys.groupNextId);
  final highest = groupStore.groups.keys.fold<int>(0, (a, b) => a > b ? a : b);
  groupStore.nextId = nextId > highest ? nextId : highest + 1;

  final whispers = PrefsWhisperStore(p)
    ..load(_readMap(p, PrefsStoreKeys.whispers));

  return LocalStores(
    matches: PrefsMatchRepository(matchStore, p),
    groups: PrefsPlayerGroupRepository(groupStore, p),
    whispers: whispers,
  );
}

Map<String, dynamic> _readMap(SharedPreferences p, String key) {
  try {
    final raw = p.getString(key);
    if (raw == null) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}

String? _readString(SharedPreferences p, String key) {
  try {
    return p.getString(key);
  } catch (_) {
    return null;
  }
}

bool _readBool(SharedPreferences p, String key) {
  try {
    return p.getBool(key) ?? false;
  } catch (_) {
    return false;
  }
}

int _readInt(SharedPreferences p, String key) {
  try {
    return p.getInt(key) ?? 0;
  } catch (_) {
    return 0;
  }
}

List<String> _readStringList(SharedPreferences p, String key) {
  try {
    return p.getStringList(key) ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> _write(Future<bool> Function() action) async {
  try {
    await action();
  } catch (_) {}
}

class PrefsMatchRepository extends MemoryMatchRepository {
  final SharedPreferences _prefs;

  PrefsMatchRepository(super.store, this._prefs);

  Future<void> _mirrorMatches() {
    final matches = store.matches;
    while (matches.length > prefsMatchCap) {
      final oldest = matches.keys.reduce((a, b) => a < b ? a : b);
      matches.remove(oldest);
    }
    return _write(
      () => _prefs.setString(
        PrefsStoreKeys.matches,
        jsonEncode({for (final e in matches.entries) '${e.key}': e.value}),
      ),
    );
  }

  @override
  Future<void> persistStep(Match match) async {
    await super.persistStep(match);
    await _mirrorMatches();
  }

  @override
  Future<void> deleteMatch(int matchId) async {
    await super.deleteMatch(matchId);
    await _mirrorMatches();
  }

  @override
  Future<void> saveDefaultSettings(MatchSettings settings) async {
    await super.saveDefaultSettings(settings);
    final encoded = store.defaultSettings;
    if (encoded == null) return;
    await _write(
      () => _prefs.setString(PrefsStoreKeys.defaultSettings, encoded),
    );
  }

  @override
  Future<void> markOnboardingSeen() async {
    await super.markOnboardingSeen();
    await _write(() => _prefs.setBool(PrefsStoreKeys.onboardingSeen, true));
  }

  @override
  Future<void> markHintSeen(String hintId) async {
    await super.markHintSeen(hintId);
    await _write(
      () => _prefs.setStringList(
        PrefsStoreKeys.seenHints,
        store.seenHints.toList(),
      ),
    );
  }

  @override
  Future<void> resetSeenHints() async {
    await super.resetSeenHints();
    await _write(() => _prefs.remove(PrefsStoreKeys.seenHints));
  }
}

class PrefsPlayerGroupRepository extends MemoryPlayerGroupRepository {
  final SharedPreferences _prefs;

  PrefsPlayerGroupRepository(super.store, this._prefs);

  Future<void> _mirror() async {
    await _write(
      () => _prefs.setString(
        PrefsStoreKeys.groups,
        jsonEncode({for (final e in store.groups.entries) '${e.key}': e.value}),
      ),
    );
    await _write(() => _prefs.setInt(PrefsStoreKeys.groupNextId, store.nextId));
  }

  @override
  Future<int> saveGroup(PlayerGroup group) async {
    final id = await super.saveGroup(group);
    await _mirror();
    return id;
  }

  @override
  Future<void> deleteGroup(int groupId) async {
    await super.deleteGroup(groupId);
    await _mirror();
  }

  @override
  Future<void> recordGroupPlayed(
    int groupId, {
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
  }) async {
    await super.recordGroupPlayed(
      groupId,
      roleCounts: roleCounts,
      settings: settings,
    );
    await _mirror();
  }
}

/// Whisper bodies, kept in storage only until the match is purged, exactly as
/// the Isar store holds them.
class PrefsWhisperStore implements WhisperStore {
  final SharedPreferences _prefs;
  final Map<int, Map<String, String>> _bodies = {};

  PrefsWhisperStore(this._prefs);

  /// Fills memory from what storage held when the app opened.
  void load(Map<String, dynamic> raw) {
    raw.forEach((key, value) {
      final matchId = int.tryParse(key);
      if (matchId == null || value is! Map) return;
      _bodies[matchId] = {
        for (final e in value.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    });
  }

  Future<void> _mirror() => _write(
    () => _prefs.setString(
      PrefsStoreKeys.whispers,
      jsonEncode({for (final e in _bodies.entries) '${e.key}': e.value}),
    ),
  );

  @override
  Future<void> put({
    required int matchId,
    required String whisperId,
    required String body,
  }) async {
    (_bodies[matchId] ??= {})[whisperId] = body;
    await _mirror();
  }

  @override
  Future<String?> read({
    required int matchId,
    required String whisperId,
  }) async => _bodies[matchId]?[whisperId];

  @override
  Future<Map<String, String>> readAll(int matchId) async =>
      Map.unmodifiable(_bodies[matchId] ?? const {});

  @override
  Future<void> purge(int matchId) async {
    if (_bodies.remove(matchId) == null) return;
    await _mirror();
  }
}
