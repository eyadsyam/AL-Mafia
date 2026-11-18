import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/terms_consent.dart';
import 'online_session.dart' show onlineBackendFactoryProvider;

/// Records the setup acceptance on the server once. Never blocks play: a
/// failure (or a server without the table yet) is retried on a later entry
/// and never makes the player tick the box again. Never throws.
///
/// Everything it needs is taken from [ref] before the first await: it runs on
/// after the screen that started it has gone.
Future<void> syncTermsToServer(WidgetRef ref) async {
  final notifier = ref.read(termsAcceptanceProvider.notifier);
  final pending = ref.read(termsAcceptanceProvider.future);
  final connect = ref.read(onlineBackendFactoryProvider);
  try {
    final terms = await pending;
    if (terms == null || !terms.current) return;
    final backend = await connect();
    // Recorded per online player: another account on this phone has not
    // sent it yet.
    final user = await backend.ensureSession();
    if (terms.syncedFor == user) return;
    await backend.call('player_safety', {
      'action': 'accept_terms',
      'version': terms.version,
      'adult': true,
      'acceptedAt': terms.acceptedAt.toUtc().toIso8601String(),
    });
    await notifier.markSynced(user);
  } catch (_) {}
}
