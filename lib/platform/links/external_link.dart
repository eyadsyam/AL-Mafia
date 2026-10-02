import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'external_link_stub.dart'
    if (dart.library.js_interop) 'external_link_browser.dart'
    as impl;

/// Opens an https destination outside the game, from a user's tap.
///
/// Web only: a new tab, so the order and the game stay where they were.
/// Everywhere else this returns false and opens nothing: the Play build has no
/// external payment path at all.
typedef ExternalLinkOpener = bool Function(String url);

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => impl.openExternal,
);
