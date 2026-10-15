import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// What the phone remembers between Stories V2 tables: whether the general
/// explanation and each mode's how-to were seen, and the last table's names.
abstract interface class StoryV2Memory {
  Future<bool> aboutSeen();
  Future<void> markAboutSeen();
  Future<bool> howToSeen(String mode);
  Future<void> markHowToSeen(String mode);
  Future<List<String>> lastNames();
  Future<void> saveNames(List<String> names);
}

/// Every read and write is best effort: a phone that cannot store these only
/// sees an explanation again, never a broken Stories hub.
class SharedPreferencesStoryV2Memory implements StoryV2Memory {
  const SharedPreferencesStoryV2Memory();

  static const _about = 'mafia.storiesAboutSeen.v1';
  static const _howTo = 'mafia.storiesHowToSeen.v1.';
  static const _names = 'mafia.storiesNames.v1';

  Future<T> _safe<T>(
    Future<T> Function(SharedPreferences p) body,
    T fallback,
  ) async {
    try {
      return await body(await SharedPreferences.getInstance());
    } on Object catch (error) {
      debugPrint('stories memory unavailable: $error');
      return fallback;
    }
  }

  /// Unreadable counts as seen: the explanation must never block the hub.
  @override
  Future<bool> aboutSeen() =>
      _safe((p) async => p.getBool(_about) ?? false, true);

  @override
  Future<void> markAboutSeen() => _safe((p) async {
    await p.setBool(_about, true);
  }, null);

  @override
  Future<bool> howToSeen(String mode) =>
      _safe((p) async => p.getBool('$_howTo$mode') ?? false, false);

  @override
  Future<void> markHowToSeen(String mode) => _safe((p) async {
    await p.setBool('$_howTo$mode', true);
  }, null);

  @override
  Future<List<String>> lastNames() => _safe(
    (p) async => p.getStringList(_names) ?? const <String>[],
    const <String>[],
  );

  @override
  Future<void> saveNames(List<String> names) => _safe((p) async {
    await p.setStringList(_names, names);
  }, null);
}

class MemoryStoryV2Memory implements StoryV2Memory {
  MemoryStoryV2Memory({this.about = false});

  bool about;
  final Set<String> howTo = {};
  List<String> names = const [];

  @override
  Future<bool> aboutSeen() async => about;

  @override
  Future<void> markAboutSeen() async => about = true;

  @override
  Future<bool> howToSeen(String mode) async => howTo.contains(mode);

  @override
  Future<void> markHowToSeen(String mode) async => howTo.add(mode);

  @override
  Future<List<String>> lastNames() async => names;

  @override
  Future<void> saveNames(List<String> names) async => this.names = names;
}
