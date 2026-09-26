import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../economy/economy_capabilities.dart';

/// The server's capabilities if this app has already asked, else null.
///
/// Never starts a read: Home and the profile must not sign in or call the
/// server just because they were drawn (and a widget test must not boot a
/// real client). Once something else has asked, this watches the answer.
EconomyCapabilities? loadedCapabilities(WidgetRef ref) =>
    ref.exists(economyCapabilitiesProvider)
    ? ref.watch(economyCapabilitiesProvider).valueOrNull
    : null;

/// For a [ConsumerState] that read [loadedCapabilities] before anything had
/// asked: looks again after the frame (another widget on the same screen may
/// have started the read meanwhile) and rebuilds once it exists.
void recheckCapabilitiesAfterFrame(ConsumerState state) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (state.mounted && state.ref.exists(economyCapabilitiesProvider)) {
      // ignore: invalid_use_of_protected_member
      state.setState(() {});
    }
  });
}
