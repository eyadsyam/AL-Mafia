export 'external_link_contract.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'external_link_contract.dart';
import 'external_link_stub.dart'
    if (dart.library.js_interop) 'external_link_browser.dart'
    as impl;

/// Opens an https destination outside the game, from a user's tap.
///
/// Web uses same-tab navigation. Native platforms use url_launcher's external
/// app mode, so bank and wallet links never open inside the Flutter surface.

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => impl.openExternal,
);

/// Reserves a web tab during the tap, before an awaited server call can lose
/// the browser's user activation. A blocked new tab falls back to the current
/// tab only after the operation succeeds. Native platforms defer the launch.
final externalLinkReserverProvider = Provider<ExternalLinkReserver>(
  (ref) => impl.reserveExternal,
);
