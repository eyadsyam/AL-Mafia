/// The three things this installation remembers, and where they come from.
///
/// # Why this is a seam and not just three `Isar.open` calls
///
/// Isar is a native database: it reaches `dart:ffi` for a compiled core, and
/// the schema it generates names its collections with 64-bit ids. Neither of
/// those survives a browser — `dart:ffi` is not there at all, and a JavaScript
/// number cannot hold `-3321931835933376304` exactly, so the *literal* fails
/// to compile long before anything tries to open a file.
///
/// So the platform choice has to happen at the import, not inside a function:
/// a `kIsWeb` guard still compiles the branch it skips. `openLocalStores` is
/// declared once and implemented twice — once against Isar, once returning
/// null — and `main.dart` picks between them with a conditional import.
///
/// The web build therefore runs on the in-memory stores that
/// `repository_provider.dart` already declares as the fallback, which is the
/// honest shape for a browser tab anyway: a tab is a session, not an
/// installation, and the app was already required to survive storage that
/// will not open.
library data.local_stores;

import 'match_repository.dart';
import 'player_group_repository.dart';
import 'whisper_store.dart';

/// One database, three collections, opened together and lost together.
class LocalStores {
  final MatchRepository matches;
  final PlayerGroupRepository groups;
  final WhisperStore whispers;

  const LocalStores({
    required this.matches,
    required this.groups,
    required this.whispers,
  });
}
