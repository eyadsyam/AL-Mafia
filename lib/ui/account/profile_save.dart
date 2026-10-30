import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_profile.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../screens/setup/player_name.dart';
import '../social/directory.dart' show nameRefusedProvider;
import '../screens/online/online_session.dart'
    show SupabaseConfig, onlineBackendFactoryProvider;
import '../../platform/device/time_zone.dart';

/// Publishes an edited name only for an existing session. A local-only player
/// must not acquire a guest session just by editing their profile.
final profileDirectoryRefreshProvider =
    Provider<Future<void> Function(PlayerProfile)>(
      (ref) => (profile) async {
        if (!SupabaseConfig.isConfigured) return;
        final backend = await ref.read(onlineBackendFactoryProvider)();
        if (backend.userId == null) return;
        await backend.call('friends', {
          'action': 'hello',
          'name': profile.name,
          'gender': profile.gender.name,
          'tz': await deviceTimeZone(),
          'locale': deviceLocaleTag(),
        });
      },
    );

enum ProfileSaveResult { saved, refused, failed }

/// Saves the name and address the player typed: the server's word on the name
/// first, when it can be had quickly (a name every room would refuse is not
/// saved as if it were fine), then the profile itself. One path for the
/// first-run page and for the identity sheet.
Future<ProfileSaveResult> saveProfileDraft(
  WidgetRef ref,
  String rawName,
  PlayerGender gender,
) async {
  try {
    final name = cleanPlayerName(rawName);
    if (await ref.read(nameRefusedProvider)(name, gender)) {
      return ProfileSaveResult.refused;
    }
    final profile = PlayerProfile(name: name, gender: gender);
    await ref.read(playerProfileProvider.notifier).save(profile);
    // The directory is optional; a refusal or outage cannot undo local save.
    unawaited(
      ref
          .read(profileDirectoryRefreshProvider)(profile)
          .catchError((Object _) {}),
    );
    return ProfileSaveResult.saved;
  } catch (_) {
    return ProfileSaveResult.failed;
  }
}
