import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'match_repository.dart';
import 'memory_match_repository.dart';

/// The app's storage.
///
/// Overridden at startup with an [IsarMatchRepository] once the database is
/// open. The default is a [MemoryMatchRepository] so that widget tests — and
/// the app itself, if Isar's native library cannot be loaded — get a working
/// repository rather than a null one. A match that is not persisted is a
/// degraded experience; a crash on boot is not an acceptable alternative.
final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MemoryMatchRepository(MemoryMatchStore()),
);
