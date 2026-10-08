import 'package:web/web.dart' as web;

import 'external_link_contract.dart';

/// The explicit fallback button navigates the current tab synchronously.
/// Same-tab navigation is not popup-gated on iOS Safari or Android Chrome.
bool openExternal(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    web.window.location.href = uri.toString();
    return true;
  } catch (_) {
    return false;
  }
}

ExternalLinkReservation reserveExternal(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    return ExternalLinkReservation(commit: () => false, cancel: () {});
  }
  final reserved = (() {
    try {
      // This call is deliberately synchronous. iOS Safari and Android Chrome
      // retain the handle even though the destination is assigned after the
      // order request finishes.
      return web.window.open('', '_blank');
    } catch (_) {
      return null;
    }
  })();
  try {
    reserved?.opener = null;
  } catch (_) {}
  return ExternalLinkReservation(
    commit: () {
      try {
        if (reserved != null) {
          reserved.location.href = uri.toString();
        } else {
          // A popup blocker refused the reserved tab. Same-tab navigation is
          // not popup-gated and guarantees the phone still reaches the page.
          web.window.location.href = uri.toString();
        }
        return true;
      } catch (_) {
        return false;
      }
    },
    cancel: () {
      try {
        reserved?.close();
      } catch (_) {}
    },
  );
}
