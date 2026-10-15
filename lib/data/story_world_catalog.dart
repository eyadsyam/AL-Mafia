import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stories/v2/world.dart';

/// The Stories V2 worlds, keyed by story id. A story with a world plays the
/// new way; the others keep the old flow until they are rewritten.
class StoryWorldCatalog {
  const StoryWorldCatalog({AssetBundle? bundle, this.paths = assetPaths})
    : _bundle = bundle;

  final AssetBundle? _bundle;

  /// The worlds to load; empty keeps every story on the old flow.
  final List<String> paths;

  static const assetPaths = ['assets/stories_v2/qahwet_el_moallem.json'];

  /// One world that fails to read is skipped (and logged), never the hub.
  Future<Map<String, StoryWorld>> load() async {
    final bundle = _bundle ?? rootBundle;
    final worlds = <String, StoryWorld>{};
    for (final path in paths) {
      try {
        final world = StoryWorld.decode(await bundle.loadString(path));
        worlds[world.id] = world;
      } on Object catch (error) {
        debugPrint('story world skipped: $path ($error)');
      }
    }
    return worlds;
  }
}

/// This phone's last culprits per story, so a replay deals someone new.
abstract interface class StoryCulpritHistory {
  Future<Set<String>> recent(String storyId);
  Future<void> remember(String storyId, String culpritId);
}

class SharedPreferencesStoryCulpritHistory implements StoryCulpritHistory {
  const SharedPreferencesStoryCulpritHistory();

  static const storageKey = 'mafia.storyCulprits.v1';

  /// How many past culprits a story avoids.
  static const keep = 3;

  Future<Map<String, List<String>>> _read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw == null) return {};
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          e.key as String: [for (final id in e.value as List) id as String],
      };
    } on Object {
      return {};
    }
  }

  @override
  Future<Set<String>> recent(String storyId) async =>
      ((await _read())[storyId] ?? const []).toSet();

  /// Best effort: a phone that cannot store this only repeats culprits sooner.
  @override
  Future<void> remember(String storyId, String culpritId) async {
    final all = await _read();
    final list = [...?all[storyId]]..remove(culpritId);
    list.add(culpritId);
    all[storyId] = list.length > keep ? list.sublist(list.length - keep) : list;
    try {
      await (await SharedPreferences.getInstance()).setString(
        storageKey,
        jsonEncode(all),
      );
    } on Object catch (error) {
      debugPrint('story culprit history not saved: $error');
    }
  }
}

class MemoryStoryCulpritHistory implements StoryCulpritHistory {
  final Map<String, List<String>> values = {};

  @override
  Future<Set<String>> recent(String storyId) async =>
      (values[storyId] ?? const []).toSet();

  @override
  Future<void> remember(String storyId, String culpritId) async =>
      (values[storyId] ??= []).add(culpritId);
}
