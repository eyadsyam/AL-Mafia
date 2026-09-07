/// [openLocalStores] on a device with a filesystem.
library data.local_stores_io;

import 'package:path_provider/path_provider.dart';

import 'isar/isar_match_repository.dart';
import 'isar/isar_player_group_repository.dart';
import 'isar/isar_whisper_store.dart';
import 'local_stores.dart';

/// Opens the one database, or returns null if it will not open.
///
/// Best-effort by contract. Losing a night's history is bad; refusing to start
/// a game night over it would be worse, so every failure here is a null and
/// the caller falls back to memory.
Future<LocalStores?> openLocalStores() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final matches = await IsarMatchRepository.open(directory: directory.path);
    return LocalStores(
      matches: matches,
      groups: IsarPlayerGroupRepository(matches.isar),
      whispers: IsarWhisperStore(matches.isar),
    );
  } catch (_) {
    return null;
  }
}
