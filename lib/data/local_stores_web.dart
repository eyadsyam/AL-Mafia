/// [openLocalStores] in a browser: the same stores, kept in `localStorage`.
///
/// The Isar database cannot run in a browser (no `dart:ffi`), so the choice is
/// made at the import, see `local_stores.dart`. What this returns is not a
/// lesser store: it is the in-memory repositories with a write-through to
/// `shared_preferences`, so a reload keeps the unfinished match, the saved
/// groups, the settings and the tutorial flag, as the phone does.
library data.local_stores_web;

import 'local_stores.dart';
import 'prefs_stores.dart';

Future<LocalStores?> openLocalStores() async {
  try {
    return await openPrefsStores();
  } catch (_) {
    // Storage refused outright: the app has always had to run with none.
    return null;
  }
}
