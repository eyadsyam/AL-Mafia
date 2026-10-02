import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const localePreferenceKey = 'mafia.locale.v1';
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('ar'));
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

Future<Locale> loadSavedLocale() async {
  try {
    final code = (await SharedPreferences.getInstance()).getString(
      localePreferenceKey,
    );
    return Locale(code == 'en' ? 'en' : 'ar');
  } catch (_) {
    return const Locale('ar');
  }
}

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => ref.read(initialLocaleProvider);

  Future<bool> select(String code) async {
    if (code != 'ar' && code != 'en') return false;
    try {
      final saved = await (await SharedPreferences.getInstance()).setString(
        localePreferenceKey,
        code,
      );
      if (!saved) return false;
      state = Locale(code);
      return true;
    } catch (_) {
      return false;
    }
  }
}
