import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const reduceMotionPreferenceKey = 'mafia.pref.reduceMotion';

Future<bool> loadReduceMotionPreference() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(
          reduceMotionPreferenceKey,
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

final initialReduceMotionProvider = Provider<bool>((ref) => false);

/// The in-game "reduce motion" choice. Added on top of the system setting:
/// either one turns animations down (applied once, in `MaterialApp.builder`).
final reduceMotionPreferenceProvider =
    NotifierProvider<ReduceMotionPreference, bool>(ReduceMotionPreference.new);

class ReduceMotionPreference extends Notifier<bool> {
  @override
  bool build() => ref.read(initialReduceMotionProvider);

  Future<bool> set(bool value) async {
    try {
      final saved = await (await SharedPreferences.getInstance()).setBool(
        reduceMotionPreferenceKey,
        value,
      );
      if (!saved) return false;
      state = value;
      return true;
    } catch (_) {
      return false;
    }
  }
}
