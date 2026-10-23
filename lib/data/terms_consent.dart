import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The terms a player must have accepted before playing.
///
/// Bump only when the required terms themselves change. A new app build with
/// the same terms must never ask again.
const currentTermsVersion = '2026-09-27';

/// One acceptance, as stored on this install.
class TermsAcceptance {
  final String version;
  final DateTime acceptedAt;

  /// The 18+ confirmation for online voice and public rooms.
  final bool adult;

  /// The online player the server recorded it for, or null. A failed sync
  /// never re-asks.
  ///
  /// A player, not a yes/no: the acceptance is this phone's, but the record
  /// is an online account's, and a phone signed out and back in as somebody
  /// else has not sent it for them.
  final String? syncedFor;

  const TermsAcceptance({
    required this.version,
    required this.acceptedAt,
    required this.adult,
    this.syncedFor,
  });

  bool get current => version == currentTermsVersion && adult;

  /// Whether the server holds it for anybody yet.
  bool get synced => syncedFor != null;
}

class TermsStore {
  static const versionKey = 'mafia.terms.version';
  static const acceptedAtKey = 'mafia.terms.acceptedAt';
  static const adultKey = 'mafia.terms.adult';

  /// The old yes/no, which named nobody. Read by nothing: an install that
  /// has it sends the record once more, for whoever is signed in now.
  static const syncedKey = 'mafia.terms.synced';
  static const syncedForKey = 'mafia.terms.syncedFor';

  Future<TermsAcceptance?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString(versionKey);
      final at = DateTime.tryParse(prefs.getString(acceptedAtKey) ?? '');
      if (version == null || at == null) return null;
      final syncedFor = prefs.get(syncedForKey);
      return TermsAcceptance(
        version: version,
        acceptedAt: at,
        adult: prefs.getBool(adultKey) ?? false,
        syncedFor: syncedFor is String ? syncedFor : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Throws when storage refuses, so setup never completes on a lost write.
  Future<void> save(TermsAcceptance acceptance) async {
    final prefs = await SharedPreferences.getInstance();
    final written =
        await prefs.setString(versionKey, acceptance.version) &&
        await prefs.setString(
          acceptedAtKey,
          acceptance.acceptedAt.toUtc().toIso8601String(),
        ) &&
        await prefs.setBool(adultKey, acceptance.adult) &&
        await switch (acceptance.syncedFor) {
          final user? => prefs.setString(syncedForKey, user),
          null => prefs.remove(syncedForKey),
        };
    if (!written) throw StateError('Terms storage unavailable');
  }
}

final termsStoreProvider = Provider((ref) => TermsStore());

/// Wall clock for the acceptance timestamp. Overridden in tests.
final termsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final termsAcceptanceProvider =
    AsyncNotifierProvider<TermsController, TermsAcceptance?>(
      TermsController.new,
    );

class TermsController extends AsyncNotifier<TermsAcceptance?> {
  @override
  Future<TermsAcceptance?> build() => ref.read(termsStoreProvider).load();

  Future<void> accept({required bool adult}) async {
    final acceptance = TermsAcceptance(
      version: currentTermsVersion,
      acceptedAt: ref.read(termsClockProvider)(),
      adult: adult,
    );
    await ref.read(termsStoreProvider).save(acceptance);
    state = AsyncData(acceptance);
  }

  /// After the server confirmed the record for [user]. Failure here is
  /// harmless: the next online entry sends it again.
  Future<void> markSynced(String user) async {
    final value = state.valueOrNull;
    if (value == null || value.syncedFor == user) return;
    final synced = TermsAcceptance(
      version: value.version,
      acceptedAt: value.acceptedAt,
      adult: value.adult,
      syncedFor: user,
    );
    try {
      await ref.read(termsStoreProvider).save(synced);
      state = AsyncData(synced);
    } catch (_) {}
  }
}
