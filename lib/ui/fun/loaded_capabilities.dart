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

/// Ticks once each time a container starts its capabilities read. Fed by
/// [CapabilitiesReadObserver], which the app's root scope carries.
final ValueNotifier<int> capabilitiesReadStarted = ValueNotifier<int>(0);

/// Tells the surfaces that drew before anything had asked that the read has
/// now started.
///
/// Home used to miss it: its banner looked again one frame after it drew, but
/// the start-up read begins only once the asset list has loaded, which is
/// usually later than that, and nothing rebuilt Home afterwards, so Home never
/// showed its banner (found on the 1.6.0 (22) release build).
class CapabilitiesReadObserver extends ProviderObserver {
  const CapabilitiesReadObserver();

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (provider == economyCapabilitiesProvider) {
      capabilitiesReadStarted.value++;
    }
  }
}

final _waiting = Expando<VoidCallback>('capabilities recheck');

/// For a [ConsumerState] that read [loadedCapabilities] before anything had
/// asked: rebuilds it once, the first frame after the read has started,
/// whether that is the next frame (another widget on the same screen asked)
/// or much later (the start-up read, the app-open check). Once the read
/// exists the state already watches it, so nothing is re-armed; while it does
/// not, the wait costs no rebuild and schedules no frame of its own.
void recheckCapabilitiesAfterFrame(ConsumerState state) {
  if (state.ref.exists(economyCapabilitiesProvider)) return;
  if (_waiting[state] != null) return;

  late final VoidCallback listener;
  void stop() {
    capabilitiesReadStarted.removeListener(listener);
    _waiting[state] = null;
  }

  void look() {
    if (!state.mounted) return stop();
    if (!state.ref.exists(economyCapabilitiesProvider)) return;
    stop();
    // ignore: invalid_use_of_protected_member
    state.setState(() {});
  }

  // The read can start in the middle of a build: look after that frame.
  listener = () {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => look())
      ..ensureVisualUpdate();
  };
  _waiting[state] = listener;
  capabilitiesReadStarted.addListener(listener);
  WidgetsBinding.instance.addPostFrameCallback((_) => look());
}
