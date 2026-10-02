import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/launcher_label.dart';

const localePreferenceKey = 'mafia.locale.v1';
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('ar'));
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// True after a language change whose launcher name only updates once the
/// game is closed (switching it live would close the running game).
final launcherLabelPendingProvider = StateProvider<bool>((ref) => false);

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
      // After the choice is saved, so a failed save never renames the icon.
      // Never awaited: the interface has already switched, in place.
      unawaited(
        LauncherLabel.apply(code).then((result) {
          try {
            ref.read(launcherLabelPendingProvider.notifier).state =
                result == LauncherLabelResult.pending;
          } catch (_) {
            // The app (or a test container) went away first; cosmetic.
          }
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
