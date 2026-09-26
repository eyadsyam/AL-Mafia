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

  /// Whether the server has recorded it. A failed sync never re-asks.
  final bool synced;

  const TermsAcceptance({
    required this.version,
    required this.acceptedAt,
    required this.adult,
    this.synced = false,
  });

  bool get current => version == currentTermsVersion && adult;
}

class TermsStore {
  static const versionKey = 'mafia.terms.version';
  static const acceptedAtKey = 'mafia.terms.acceptedAt';
  static const adultKey = 'mafia.terms.adult';
  static const syncedKey = 'mafia.terms.synced';

  Future<TermsAcceptance?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString(versionKey);
      final at = DateTime.tryParse(prefs.getString(acceptedAtKey) ?? '');
      if (version == null || at == null) return null;
      return TermsAcceptance(
        version: version,
        acceptedAt: at,
        adult: prefs.getBool(adultKey) ?? false,
        synced: prefs.getBool(syncedKey) ?? false,
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
        await prefs.setBool(syncedKey, acceptance.synced);
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

  /// After the server confirmed the record. Failure here is harmless: the
  /// next online entry sends it again.
  Future<void> markSynced() async {
    final value = state.valueOrNull;
    if (value == null || value.synced) return;
    final synced = TermsAcceptance(
      version: value.version,
      acceptedAt: value.acceptedAt,
      adult: value.adult,
      synced: true,
    );
    try {
      await ref.read(termsStoreProvider).save(synced);
      state = AsyncData(synced);
    } catch (_) {}
  }
}
